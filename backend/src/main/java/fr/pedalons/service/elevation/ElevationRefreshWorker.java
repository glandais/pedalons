package fr.pedalons.service.elevation;

import fr.pedalons.repository.route.ElevationRefreshRepository.Claim;
import fr.pedalons.repository.route.ElevationRefreshRepository.PreviewClaim;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import org.jboss.logging.Logger;

/**
 * Recomputes with the HD elevation source the tracks (routes, then GPX-tool previews) saved with the fast one, once they have been
 * left alone for a while (docs/LEDGER_*.md API-131, plan {@code
 * docs/plans/archive/2026-10-17-altitude-hd-asynchrone.md} §4.4).
 *
 * <p>Every 30 seconds, one request at a time (IGN's 20 requests per second are shared with
 * whatever the other backend of a rolling deploy does), until none is due or the tick's {@link
 * #TIME_BUDGET} is spent. Each request is claimed in a transaction of its own ({@code FOR UPDATE
 * SKIP LOCKED} and a lease, so two backends never take the same one), computed with no transaction
 * open, then written in a short one that checks the track did not change meanwhile — see {@link
 * ElevationRefreshService}.
 *
 * <p>Keeps draining the queue when {@code pedalons.elevation.async-hd.enabled} is off: that switch
 * only stops new requests, and the routes already saved fast would otherwise stay so.
 *
 * <p>No {@code @Transactional}, as in {@code GpsRouteSyncWorker}. The worker runs without a request
 * domain; everything it reads or writes is keyed by the route id taken from the queue.
 */
@ApplicationScoped
public class ElevationRefreshWorker {

  private static final Logger LOG = Logger.getLogger(ElevationRefreshWorker.class);

  /** No new request is started once a tick has run this long. */
  static final Duration TIME_BUDGET = Duration.ofSeconds(60);

  @Inject ElevationRefreshService service;

  @Scheduled(every = "30s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void tick() {
    try {
      int processed = processDue();
      if (processed > 0) {
        LOG.debugf("Elevation refresh worker: %d request(s) processed", processed);
      }
    } catch (Exception e) {
      LOG.error("Elevation refresh failed", e);
    }
  }

  /**
   * Processes due requests until none is left or the tick's budget is spent. Public for the tests
   * (scheduler off, elevation provider faked).
   *
   * @return how many requests were processed
   */
  public int processDue() {
    Instant started = Instant.now();
    int processed = 0;
    while (Duration.between(started, Instant.now()).compareTo(TIME_BUDGET) <= 0) {
      Optional<Claim> claim = service.claimNext(Instant.now());
      if (claim.isPresent()) {
        service.process(claim.get());
        processed++;
        continue;
      }
      Optional<PreviewClaim> previewClaim = service.claimNextPreview(Instant.now());
      if (previewClaim.isEmpty()) {
        break;
      }
      service.processPreview(previewClaim.get());
      processed++;
    }
    return processed;
  }
}
