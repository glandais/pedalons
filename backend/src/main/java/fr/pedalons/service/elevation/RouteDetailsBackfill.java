package fr.pedalons.service.elevation;

import fr.pedalons.infrastructure.routedetails.RouteDetailsCapabilities;
import fr.pedalons.infrastructure.routedetails.RouteSlicer;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository.BackfillBudget;
import fr.pedalons.repository.route.ElevationRefreshRepository.BackfillCandidate;
import fr.pedalons.repository.route.ElevationRefreshRepository.BackfillRemaining;
import fr.pedalons.service.gpx.GpxPreviewService;
import fr.pedalons.service.surface.SurfaceRefreshService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

/**
 * The recomputation of the whole fleet on the current pipeline (docs/LEDGER_*.md API-150, phase D,
 * plan {@code docs/plans/2026-11-05-osm-route-details.md} §6): every five minutes, queues the routes
 * (most recent first), then the GPX-tool previews, behind {@code GpxPipeline.VERSION} and without
 * any request, under a global hourly cap carried by the due times themselves (a done request is
 * deleted, so there is nothing to count). Its requests are marked {@code backfill}: {@link
 * ElevationRefreshWorker} serves them, as ordinary HD catch-ups, once no normal request is due.
 *
 * <p><b>Off by default</b> ({@code pedalons.route-details.backfill.enabled}): deploying never starts
 * it, since every environment shares one osm-route-details and one IGN budget. Nothing is queued
 * either while the surface is off ({@code pedalons.surface.enabled}): such a recompute leaves its
 * track behind the pipeline ({@code GpxProcessingService#hdPipeline}), so a pass would queue the
 * same tracks for ever. Switched off, what is queued (the {@link #WINDOW}) still gets served.
 *
 * <p>It never touches {@code elevation_state}: a queued target keeps showing its profile and its
 * surface, and nothing reads as pending. Any request row excludes a target, whatever its attempts:
 * an open one brings its recompute, and one given up after five failures is not queued again, so
 * the loop ends by itself; the admin retry and a save are the ways back. A track that was never
 * recomputed keeps working as it is: profile untouched, version 1 surface document still read.
 *
 * <p>A pass runs in one transaction that first takes an advisory lock, so the two backends of a
 * rolling deploy follow each other instead of both reading the same free slot. The cap holds on
 * the due times. The calls themselves bunch only when the worker was held up (a backlog of normal
 * requests, a restart): it then sends what fell due at once, at most the {@link #WINDOW} held in the
 * queue. Over any hour that is at most {@code per-hour} plus ten minutes of it, the retries of
 * failed requests aside.
 */
@ApplicationScoped
public class RouteDetailsBackfill {

  private static final Logger LOG = Logger.getLogger(RouteDetailsBackfill.class);

  /**
   * How far ahead the catch-up queues: its pending requests never hold more than this much of the
   * cap, counted in service calls (one track longer than that alone, when the queue is empty).
   */
  static final Duration WINDOW = Duration.ofMinutes(10);

  /**
   * The length of one call: the core of a slice under the fallback bounds, 188 km. Only a weight:
   * the published bounds may differ a little, and a route of several tracks counts as one length.
   */
  static final double CALL_M = RouteSlicer.coreM(RouteDetailsCapabilities.FALLBACK_LIMITS);

  @ConfigProperty(name = "pedalons.route-details.backfill.enabled", defaultValue = "false")
  boolean enabled;

  /** Calls to osm-route-details per hour, across the backends (a slice of 188 km is one call). */
  @ConfigProperty(name = "pedalons.route-details.backfill.per-hour", defaultValue = "60")
  int perHour;

  @Inject SurfaceRefreshService surfaceService;
  @Inject ElevationRefreshRepository refreshRepository;

  private volatile boolean foundLastTime;
  private volatile boolean warnedSurfaceOff;

  /** For the tests: the switch and the cap. */
  public void setForTest(boolean enabled, int perHour) {
    this.enabled = enabled;
    this.perHour = perHour;
    this.foundLastTime = false;
  }

  @Scheduled(every = "5m", delayed = "2m", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void run() {
    try {
      enqueue(Instant.now());
    } catch (Exception e) {
      LOG.error("Route details catch-up failed", e);
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
    if (!surfaceService.isEnabled()) {
      if (!warnedSurfaceOff) {
        LOG.warn("Route details catch-up switched on, but stopped while the surface is off");
        warnedSurfaceOff = true;
      }
      return 0;
    }
    warnedSurfaceOff = false;
    return QuarkusTransaction.requiringNew().call(() -> pass(now));
  }

  private int pass(Instant now) {
    refreshRepository.lockBackfill();
    Instant createdAfter = now.minus(GpxPreviewService.RETENTION_DAYS - 1, ChronoUnit.DAYS);
    BackfillRemaining left =
        refreshRepository.backfillRemaining(createdAfter, ElevationRefreshService.MAX_ATTEMPTS);
    int queued = queue(now, createdAfter);
    boolean found = left.routes() + left.previews() > 0;
    if (found) {
      LOG.infof(
          "Route details catch-up: %d request(s) queued; left %d route(s) (%.0f km), %d preview(s);"
              + " given up %d",
          queued, left.routes(), left.routeMetres() / 1000, left.previews(), left.givenUp());
    } else if (foundLastTime) {
      LOG.infof(
          "Route details catch-up done: nothing behind the pipeline, %d given up", left.givenUp());
    }
    foundLastTime = found;
    return queued;
  }

  private int queue(Instant now, Instant createdAfter) {
    double spacing = 3600.0 / perHour;
    int maxPending = Math.max(1, (int) Math.ceil(perHour * WINDOW.toSeconds() / 3600.0));
    BackfillBudget budget =
        refreshRepository.backfillBudget(spacing, CALL_M, ElevationRefreshService.MAX_ATTEMPTS);
    int room = maxPending - budget.pending();
    if (room <= 0) {
      return 0;
    }
    List<BackfillCandidate> routes = refreshRepository.findBackfillRoutes(room);
    List<BackfillCandidate> previews =
        routes.size() < room
            ? refreshRepository.findBackfillPreviews(room - routes.size(), createdAfter)
            : List.of();
    Instant cursor =
        budget.nextFree() != null && budget.nextFree().isAfter(now) ? budget.nextFree() : now;
    int queued = 0;
    int held = budget.pending();
    for (int i = 0; i < routes.size() + previews.size(); i++) {
      boolean route = i < routes.size();
      BackfillCandidate c = route ? routes.get(i) : previews.get(i - routes.size());
      int weight = weight(c);
      // The room is counted in calls: a long track takes several. It waits for the next pass, the
      // ones after it too (most recent first), unless the queue is empty: one longer than the whole
      // window would otherwise block the catch-up for good
      if (held > 0 && held + weight > maxPending) {
        break;
      }
      boolean inserted =
          route
              ? refreshRepository.insertBackfillRoute(c, now, cursor)
              : refreshRepository.insertBackfillPreview(c, now, cursor);
      if (inserted) {
        cursor = cursor.plusMillis(Math.round(spacing * 1000 * weight));
        held += weight;
        queued++;
      }
    }
    return queued;
  }

  /** The calls to osm-route-details a track takes. */
  static int weight(BackfillCandidate c) {
    return Math.max(1, (int) Math.ceil(c.distance() / CALL_M));
  }
}
