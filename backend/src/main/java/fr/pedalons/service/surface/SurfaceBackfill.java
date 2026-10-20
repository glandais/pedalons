package fr.pedalons.service.surface;

import fr.pedalons.repository.route.SurfaceRefreshRepository;
import fr.pedalons.repository.route.SurfaceRefreshRepository.BackfillBudget;
import fr.pedalons.repository.route.SurfaceRefreshRepository.BackfillCandidate;
import fr.pedalons.service.gpx.GpxPreviewService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

/**
 * The catch-up of the tracks saved before the surface existed (docs/LEDGER_*.md WEB-100, C1c):
 * every five minutes, queues the routes (most recent first), then the GPX-tool previews, that have
 * neither a surface nor any request, under a global hourly cap carried by the due times themselves
 * (a done request is deleted, so there is nothing to count). Its requests are marked {@code
 * backfill}: the worker serves them once no normal request is due. Nothing when the surface is off
 * ({@code pedalons.surface.enabled}, or no key), whatever {@code
 * pedalons.surface.backfill.enabled}.
 *
 * <p>A track that is given up (five failures) keeps its request row, and one that is unavailable
 * has a document written: neither is ever a candidate again, so nothing is marked and the loop
 * ends by itself. A pass runs in one transaction that first takes an advisory lock, so the two
 * backends of a rolling deploy follow each other instead of both reading the same free slot.
 *
 * <p>The cap holds on the due times. The calls themselves bunch only when the worker was held up
 * (a backlog of normal requests, the feature switched off a while, a restart): it then sends what
 * fell due at once, at most the {@link #WINDOW} held in the queue. Over any hour that is at most
 * {@code per-hour} plus ten minutes of it, the retries of failed requests aside.
 */
@ApplicationScoped
public class SurfaceBackfill {

  private static final Logger LOG = Logger.getLogger(SurfaceBackfill.class);

  /**
   * How far ahead the catch-up queues: its pending requests never hold more than this much of the
   * cap, counted in provider calls (one track longer than that alone, when the queue is empty).
   */
  static final Duration WINDOW = Duration.ofMinutes(10);

  @ConfigProperty(name = "pedalons.surface.backfill.enabled", defaultValue = "true")
  boolean enabled;

  /** Provider calls per hour (a slice of 188 km is one call, 20 credits). */
  @ConfigProperty(name = "pedalons.surface.backfill.per-hour", defaultValue = "300")
  int perHour;

  @Inject SurfaceRefreshService refreshService;
  @Inject SurfaceRefreshRepository refreshRepository;

  private volatile boolean foundLastTime;

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
      LOG.error("Surface catch-up failed", e);
    }
  }

  /**
   * One pass, in a transaction of its own. Public for the tests.
   *
   * @return how many requests were queued
   */
  public int enqueue(Instant now) {
    if (!enabled || perHour <= 0 || !refreshService.isEnabled()) {
      return 0;
    }
    return QuarkusTransaction.requiringNew().call(() -> pass(now));
  }

  private int pass(Instant now) {
    refreshRepository.lockBackfill();
    double spacing = 3600.0 / perHour;
    int maxPending = Math.max(1, (int) Math.ceil(perHour * WINDOW.toSeconds() / 3600.0));
    BackfillBudget budget =
        refreshRepository.backfillBudget(
            spacing, TraceSurfaceComputer.CORE_M, SurfaceRefreshService.MAX_ATTEMPTS);
    int room = maxPending - budget.pending();
    if (room <= 0) {
      return 0;
    }
    List<BackfillCandidate> routes = refreshRepository.findBackfillRoutes(room);
    List<BackfillCandidate> previews =
        routes.size() < room
            ? refreshRepository.findBackfillPreviews(
                room - routes.size(),
                now.minus(GpxPreviewService.RETENTION_DAYS - 1, ChronoUnit.DAYS))
            : List.of();
    Instant cursor =
        budget.nextFree() != null && budget.nextFree().isAfter(now) ? budget.nextFree() : now;
    int queued = 0;
    int held = budget.pending();
    List<Candidate> all = new ArrayList<>(routes.size() + previews.size());
    routes.forEach(c -> all.add(new Candidate(c, true)));
    previews.forEach(c -> all.add(new Candidate(c, false)));
    for (Candidate candidate : all) {
      BackfillCandidate c = candidate.track();
      int weight = weight(c);
      // The room is counted in calls: a long track takes several. It waits for the next pass, the
      // ones after it too (most recent first), unless the queue is empty: one longer than the whole
      // window would otherwise block the catch-up for good
      if (held > 0 && held + weight > maxPending) {
        break;
      }
      boolean inserted =
          candidate.route()
              ? refreshRepository.insertBackfillRoute(c, now, cursor)
              : refreshRepository.insertBackfillPreview(c, now, cursor);
      if (inserted) {
        cursor = cursor.plusMillis(slot(spacing, c));
        held += weight;
        queued++;
      }
    }
    boolean found = !routes.isEmpty() || !previews.isEmpty();
    if (!found && foundLastTime) {
      LOG.info("Surface catch-up done: no track left without a surface or a request");
    }
    foundLastTime = found;
    LOG.debugf("Surface catch-up: %d request(s) queued", queued);
    return queued;
  }

  private record Candidate(BackfillCandidate track, boolean route) {}

  /** The time a candidate holds under the cap: one slot per provider call (a slice of track). */
  private static long slot(double spacingSeconds, BackfillCandidate c) {
    return Math.round(spacingSeconds * 1000 * weight(c));
  }

  static int weight(BackfillCandidate c) {
    return Math.max(1, (int) Math.ceil(c.distance() / TraceSurfaceComputer.CORE_M));
  }
}
