package fr.pedalons.service.elevation;

import fr.pedalons.infrastructure.routedetails.RouteDetailsCapabilities;
import fr.pedalons.infrastructure.routedetails.RouteDetailsGateway;
import fr.pedalons.infrastructure.routedetails.RouteSlicer;
import fr.pedalons.repository.route.NetworkEdgesBackfillRepository;
import fr.pedalons.repository.route.NetworkEdgesBackfillRepository.Budget;
import fr.pedalons.repository.route.NetworkEdgesBackfillRepository.Candidate;
import fr.pedalons.repository.route.NetworkEdgesBackfillRepository.Remaining;
import fr.pedalons.service.route.edges.NetworkEdgesMetrics;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

/**
 * Brings the street edges (docs/LEDGER_*.md API-198, lot 1) to the team routes saved before they
 * were stored: every five minutes, queues the routes (most recent first) whose tracks have no
 * document, or one older than {@code NetworkEdgesDocument.VERSION}, into {@code elevation_refresh}
 * as {@code backfill} requests, under a global hourly cap carried by the due times themselves (a
 * done request is deleted, so there is nothing to count). It is the {@code RouteDetailsBackfill}
 * of the fleet's recompute of November 2026 (docs/LEDGER_*.md API-150, phase D), brought back with
 * another candidate query: {@link ElevationRefreshService} serves these requests with an
 * <b>edges-only</b> call that changes nothing else, where a full recompute would have pushed every
 * route to the GPS services again.
 *
 * <p><b>Off by default</b> ({@code pedalons.network-edges.backfill.enabled}): deploying never starts
 * it, every environment shares one osm-route-details and one IGN budget. Stopped as well while
 * {@code pedalons.network-edges.enabled} is off or the service announces no edges (a queued request
 * would never get its document and the loop would never end); a warning says so once. Switched off,
 * what is queued (the {@link #WINDOW}) still gets served.
 *
 * <p>Any request row excludes a route: an open one brings the full catch-up, which writes the
 * edges, and one given up after five failures is not queued again, so the loop ends by itself; the
 * admin retry and a save are the ways back. All the state is in the database, so a restart, a
 * deploy or switching it off and on resumes where it stopped.
 *
 * <p>A pass runs in one transaction that first takes an advisory lock, so the two backends of a
 * rolling deploy follow each other instead of both reading the same free slot. During a rolling
 * deploy the previous release would serve a queued request with the full recompute (one route
 * pushed again to the GPS services, no document written): deploy with the backfill off.
 */
@ApplicationScoped
public class NetworkEdgesBackfill {

  private static final Logger LOG = Logger.getLogger(NetworkEdgesBackfill.class);

  /**
   * How far ahead the backfill queues: its pending requests never hold more than this much of the
   * cap, counted in service calls (one route longer than that alone, when the queue is empty).
   */
  static final Duration WINDOW = Duration.ofMinutes(10);

  /**
   * The length of one call: the core of a slice under the fallback bounds, 188 km. Only a weight:
   * the published bounds may differ a little, and a route of several tracks counts as one length.
   */
  static final double CALL_M = RouteSlicer.coreM(RouteDetailsCapabilities.FALLBACK_LIMITS);

  @ConfigProperty(name = "pedalons.network-edges.backfill.enabled", defaultValue = "false")
  boolean enabled;

  /** Calls to osm-route-details per hour, across the backends (a slice of 188 km is one call). */
  @ConfigProperty(name = "pedalons.network-edges.backfill.per-hour", defaultValue = "30")
  int perHour;

  /** {@code pedalons.network-edges.enabled}: the backfill makes no sense while it is off. */
  @ConfigProperty(name = "pedalons.network-edges.enabled", defaultValue = "true")
  boolean edgesEnabled;

  @Inject NetworkEdgesBackfillRepository repository;
  @Inject RouteDetailsGateway routeDetails;
  @Inject NetworkEdgesMetrics metrics;

  private volatile boolean foundLastTime;
  private volatile boolean warnedNoEdges;

  /** For the tests: the switches and the cap. */
  public void setForTest(boolean enabled, int perHour, boolean edgesEnabled) {
    this.enabled = enabled;
    this.perHour = perHour;
    this.edgesEnabled = edgesEnabled;
    this.foundLastTime = false;
    this.warnedNoEdges = false;
  }

  @Scheduled(every = "5m", delayed = "2m", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void run() {
    try {
      enqueue(Instant.now());
    } catch (Exception e) {
      LOG.error("Network edges backfill failed", e);
    }
  }

  /**
   * One pass, in a transaction of its own. Public for the tests.
   *
   * @return how many requests were queued
   */
  public int enqueue(Instant now) {
    if (!enabled || perHour <= 0) {
      return 0;
    }
    if (!edgesEnabled || !routeDetails.supportsEdges()) {
      if (!warnedNoEdges) {
        LOG.warn(
            "Network edges backfill switched on, but stopped while the edges are off or the"
                + " service announces none (api 1.7)");
        warnedNoEdges = true;
      }
      return 0;
    }
    warnedNoEdges = false;
    return QuarkusTransaction.requiringNew().call(() -> pass(now));
  }

  private int pass(Instant now) {
    repository.lock();
    Remaining left = repository.remaining(ElevationRefreshService.MAX_ATTEMPTS);
    int queued = queue(now);
    metrics.remaining(left.routes());
    boolean found = left.routes() > 0;
    if (found) {
      LOG.infof(
          "Network edges backfill: %d queued; left %d route(s) (%.0f km); given up %d",
          queued, left.routes(), left.routeMetres() / 1000, left.givenUp());
    } else if (foundLastTime) {
      LOG.infof("Network edges backfill done: nothing without edges, %d given up", left.givenUp());
    }
    foundLastTime = found;
    return queued;
  }

  private int queue(Instant now) {
    double spacing = 3600.0 / perHour;
    int maxPending = Math.max(1, (int) Math.ceil(perHour * WINDOW.toSeconds() / 3600.0));
    Budget budget = repository.budget(spacing, CALL_M, ElevationRefreshService.MAX_ATTEMPTS);
    int room = maxPending - budget.pending();
    if (room <= 0) {
      return 0;
    }
    List<Candidate> routes = repository.findCandidates(room);
    Instant cursor =
        budget.nextFree() != null && budget.nextFree().isAfter(now) ? budget.nextFree() : now;
    int queued = 0;
    int held = budget.pending();
    for (Candidate c : routes) {
      int weight = weight(c);
      // The room is counted in calls: a long route takes several. It waits for the next pass, the
      // ones after it too (most recent first), unless the queue is empty: one longer than the whole
      // window would otherwise block the backfill for good
      if (held > 0 && held + weight > maxPending) {
        break;
      }
      if (repository.insert(c, now, cursor)) {
        cursor = cursor.plusMillis(Math.round(spacing * 1000 * weight));
        held += weight;
        queued++;
      }
    }
    return queued;
  }

  /** The calls to osm-route-details a route takes. */
  static int weight(Candidate c) {
    return Math.max(1, (int) Math.ceil(c.distance() / CALL_M));
  }
}
