package fr.pedalons.service.surface;

import fr.pedalons.repository.route.SurfaceRefreshRepository.Claim;
import fr.pedalons.repository.route.SurfaceRefreshRepository.PreviewClaim;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import org.jboss.logging.Logger;

/**
 * Computes the surface of the tracks (routes, then GPX-tool previews) saved and left alone for a
 * while (docs/LEDGER_*.md WEB-100, C1b). The model of {@code ElevationRefreshWorker}: every 30
 * seconds, one request at a time until none is due or the tick's {@link #TIME_BUDGET} is spent,
 * each claimed in a transaction of its own ({@code FOR UPDATE SKIP LOCKED} and a lease), computed
 * with no transaction open, then written in a short one — see {@link SurfaceRefreshService}.
 *
 * <p>Unlike the HD catch-up, it sends nothing when {@code pedalons.surface.enabled} is off or the
 * key is missing: the switch is what stops the spending, and the queue waits.
 *
 * <p>No {@code @Transactional}. The worker runs without a request domain; everything it reads or
 * writes is keyed by the route or preview id taken from the queue, whatever the domain it belongs
 * to (one Stadia Maps key for all of them).
 */
@ApplicationScoped
public class SurfaceRefreshWorker {

  private static final Logger LOG = Logger.getLogger(SurfaceRefreshWorker.class);

  /**
   * No new request is started once a tick has run this long: a call takes 0.1 to 0.5 s, so a tick
   * sends some forty at most, a modest rate for a provider that publishes no limit for a key. A
   * backlog (a migration) empties in tens of minutes.
   */
  static final Duration TIME_BUDGET = Duration.ofSeconds(20);

  @Inject SurfaceRefreshService service;

  @Scheduled(every = "30s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void tick() {
    try {
      int processed = processDue();
      if (processed > 0) {
        LOG.debugf("Surface refresh worker: %d request(s) processed", processed);
      }
    } catch (Exception e) {
      LOG.error("Surface refresh failed", e);
    }
  }

  /** Processes the next due route request, else preview request, of a kind; false when none. */
  private boolean processNext(boolean backfill) {
    Optional<Claim> claim = service.claimNext(Instant.now(), backfill);
    if (claim.isPresent()) {
      service.process(claim.get());
      return true;
    }
    Optional<PreviewClaim> previewClaim = service.claimNextPreview(Instant.now(), backfill);
    if (previewClaim.isEmpty()) {
      return false;
    }
    service.processPreview(previewClaim.get());
    return true;
  }

  /**
   * Processes due requests until none is left or the tick's budget is spent. Public for the tests
   * (scheduler off, provider faked).
   *
   * @return how many requests were processed, 0 when the feature is off
   */
  public int processDue() {
    if (!service.isEnabled()) {
      return 0;
    }
    Instant started = Instant.now();
    int processed = 0;
    while (Duration.between(started, Instant.now()).compareTo(TIME_BUDGET) <= 0) {
      // Strict priority: normal requests (routes, then previews), then the catch-up's
      if (processNext(false) || processNext(true)) {
        processed++;
        continue;
      }
      break;
    }
    return processed;
  }
}
