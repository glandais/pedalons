package fr.pedalons.service.gps.sync;

import fr.pedalons.repository.gps.GpsRouteSyncRepository;
import fr.pedalons.repository.gps.GpsRouteSyncRepository.Claim;
import fr.pedalons.service.gps.sync.GpsRouteSyncExecutor.Outcome;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.jboss.logging.Logger;

/**
 * Calls the GPS services for the rows the planner left out of sync (docs/LEDGER_*.md API-120
 * §4.2) — the only scheduled code that calls them.
 *
 * <p>Every 20 seconds, domain by domain, in rounds of up to {@value #BATCH} rows, nearest departure
 * first:
 *
 * <ol>
 *   <li><b>claim</b>, in its own transaction: {@code FOR UPDATE SKIP LOCKED}, then a lease ({@code
 *       claimed_until}), so that the calls run with no transaction and no row lock open, and the
 *       second backend of a rolling deploy skips these rows — Hammerhead and Garmin deduplicate
 *       nothing, two creations would be two routes on the device;
 *   <li><b>call</b> and <b>write</b>, by {@link GpsRouteSyncExecutor}, the write conditioned on the
 *       lease.
 * </ol>
 *
 * <p>A budget of {@value #MAX_CALLS_PER_TICK} calls and {@link #TIME_BUDGET} per tick keeps a
 * backlog under Wahoo's production quota (200 calls per 5 minutes, the tightest of the three). A
 * connection paused by a 429 or waiting for a reconnection is skipped for the rest of the tick;
 * the claim query skips it afterwards.
 *
 * <p>No {@code @Transactional}, as in {@code FeedbackGithubWorker} and {@code WeatherFetchWorker}.
 */
@ApplicationScoped
public class GpsRouteSyncWorker {

  private static final Logger LOG = Logger.getLogger(GpsRouteSyncWorker.class);

  static final int BATCH = 20;
  static final int MAX_CALLS_PER_TICK = 30;
  static final Duration TIME_BUDGET = Duration.ofSeconds(10);

  @Inject GpsRouteSyncPlanner planner;
  @Inject GpsRouteSyncExecutor executor;
  @Inject GpsRouteSyncRepository syncRepository;

  @Scheduled(every = "20s", concurrentExecution = Scheduled.ConcurrentExecution.SKIP)
  void tick() {
    if (!planner.isEnabled()) {
      return;
    }
    try {
      int processed = processDue();
      if (processed > 0) {
        LOG.debugf("Route sync worker: %d row(s) processed", processed);
      }
    } catch (Exception e) {
      LOG.error("Route sync failed", e);
    }
  }

  /**
   * Processes due rows until none is left or the tick's budget is spent. Public for the tests
   * (scheduler off, clients mocked).
   *
   * @return how many rows were processed
   */
  public int processDue() {
    Instant started = Instant.now();
    int calls = 0;
    int processed = 0;
    List<Long> domainIds =
        tx(
            () ->
                syncRepository.findDomainsWithDueWork(
                    Instant.now(), GpsRouteSyncExecutor.MAX_ATTEMPTS));
    for (Long domainId : domainIds) {
      while (true) {
        if (spent(started, calls)) {
          return processed;
        }
        Instant now = Instant.now();
        Instant lease = GpsRouteSyncExecutor.leaseEnd(now);
        List<Claim> claims = claim(domainId, now, lease);
        if (claims.isEmpty()) {
          break;
        }
        Set<Long> stopped = new HashSet<>();
        for (Claim claim : claims) {
          if (stopped.contains(claim.connectionId()) || spent(started, calls)) {
            tx(() -> syncRepository.release(claim.id(), claim.lease()));
            continue;
          }
          Outcome outcome = executor.process(claim);
          calls += outcome.calls();
          processed++;
          if (outcome.connectionStopped()) {
            stopped.add(claim.connectionId());
          }
        }
        if (claims.size() < BATCH) {
          break;
        }
      }
    }
    return processed;
  }

  List<Claim> claim(Long domainId, Instant now, Instant lease) {
    return tx(
        () -> {
          List<Long> ids =
              syncRepository.findDueIdsSkipLocked(
                  domainId, now, GpsRouteSyncExecutor.MAX_ATTEMPTS, BATCH);
          if (ids.isEmpty()) {
            return List.of();
          }
          syncRepository.lease(ids, lease);
          return syncRepository.findClaims(ids, lease);
        });
  }

  private static boolean spent(Instant started, int calls) {
    return calls >= MAX_CALLS_PER_TICK
        || Duration.between(started, Instant.now()).compareTo(TIME_BUDGET) > 0;
  }

  private static <T> T tx(java.util.concurrent.Callable<T> work) {
    return QuarkusTransaction.requiringNew().call(work);
  }
}
