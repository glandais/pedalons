package fr.pedalons.service.limits;

import fr.pedalons.common.Crons;
import fr.pedalons.repository.limits.PlannerSaveRepository;
import fr.pedalons.repository.limits.RouterDailyCallRepository;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.LocalDate;
import java.time.ZoneOffset;
import org.jboss.logging.Logger;

/**
 * Purges the journals of the route planner quotas (docs/LEDGER_*.md BILL-10), daily: the saves older
 * than 13 months — a quota reads the current month only, the rest is kept for a year of diagnosis —
 * and the routing counters of the days before yesterday.
 *
 * <p>Idempotent and claiming nothing: two backends running it during a rolling deploy delete the
 * same rows, the second finds none.
 */
@ApplicationScoped
public class PlannerQuotaCleanupScheduler {

  private static final Logger LOG = Logger.getLogger(PlannerQuotaCleanupScheduler.class);

  /** Months a save is kept. */
  static final int RETENTION_MONTHS = 13;

  @Inject PlannerSaveRepository plannerSaveRepository;

  @Inject RouterDailyCallRepository routerDailyCallRepository;

  @Inject LimitsClock clock;

  @Scheduled(cron = "0 50 4 * * ?", timeZone = Crons.ZONE)
  @Transactional
  void purge() {
    LocalDate today = LocalDate.ofInstant(clock.now(), ZoneOffset.UTC);
    long saves =
        plannerSaveRepository.purgeBefore(
            today.minusMonths(RETENTION_MONTHS).atStartOfDay(ZoneOffset.UTC).toInstant());
    long counters = routerDailyCallRepository.purgeBefore(today.minusDays(1));
    if (saves + counters > 0) {
      LOG.infof(
          "Planner quota cleanup completed: %d saves, %d daily routing counters deleted",
          saves, counters);
    }
  }
}
