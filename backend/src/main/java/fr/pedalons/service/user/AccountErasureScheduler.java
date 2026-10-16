package fr.pedalons.service.user;

import fr.pedalons.common.Crons;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.List;
import org.jboss.logging.Logger;

/**
 * Nightly catch-up for {@link AccountErasureService}.
 *
 * <p>Account deletion erases synchronously, so on a healthy day this finds nothing. It exists for
 * the accounts flagged deleted before erasure was written, and for an erasure that failed — the
 * privacy policy promises the data is gone within 30 days, and this is what keeps that true.
 */
@ApplicationScoped
public class AccountErasureScheduler {

  private static final Logger LOG = Logger.getLogger(AccountErasureScheduler.class);

  @Inject AccountErasureService accountErasureService;

  /** 04:45, after the export sweep at 04:30. */
  @Scheduled(cron = "0 45 4 * * ?", timeZone = Crons.ZONE)
  void eraseDeletedAccounts() {
    List<Long> pending = accountErasureService.findPendingErasure();
    int erased = 0;
    for (Long userId : pending) {
      try {
        // With no transaction open: it calls the GPS services (docs/LEDGER_*.md API-120).
        accountErasureService.removeSyncedRoutes(userId);
        accountErasureService.eraseById(userId);
        erased++;
      } catch (RuntimeException e) {
        LOG.errorf(e, "Erasure of deleted account %d failed, retried tomorrow", userId);
      }
    }
    if (!pending.isEmpty()) {
      LOG.infof("Account erasure: %d of %d deleted accounts erased", erased, pending.size());
    }
  }
}
