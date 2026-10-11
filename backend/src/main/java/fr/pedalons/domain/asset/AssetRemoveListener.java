package fr.pedalons.domain.asset;

import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.service.asset.AssetService;
import jakarta.inject.Inject;
import jakarta.persistence.PreRemove;
import jakarta.transaction.Status;
import jakarta.transaction.Synchronization;
import jakarta.transaction.TransactionSynchronizationRegistry;
import org.jboss.logging.Logger;

/**
 * Deletes an asset's stored file when its row is removed.
 *
 * <p>{@code @PreRemove} fires inside {@code em.remove()}, before the SQL DELETE is flushed, so the
 * file is only deleted once the transaction has <b>committed</b>. A rolled-back removal (the orphan
 * sweep failing its version check because a save attached the asset meanwhile, or any later error)
 * keeps both the row and its file — docs/LEDGER_*.md API-97.
 */
public class AssetRemoveListener {

  private static final Logger LOG = Logger.getLogger(AssetRemoveListener.class);

  @Inject StorageService storageService;

  @Inject AssetService assetService;

  @Inject TransactionSynchronizationRegistry txRegistry;

  @PreRemove
  void onPreRemove(Asset asset) {
    // Resolved now, while the persistence context is still open.
    String key = assetService.getAssetKey(asset.getTeam(), asset.getFileId());
    Long assetId = asset.getId();
    int status = txRegistry.getTransactionStatus();
    if (status == Status.STATUS_NO_TRANSACTION) {
      deleteFile(assetId, key);
      return;
    }
    if (status != Status.STATUS_ACTIVE) {
      // Marked for rollback or already completing: the row survives, so must its file.
      return;
    }
    // Never before the commit: docs/LEDGER_*.md API-97.
    txRegistry.registerInterposedSynchronization(
        new Synchronization() {
          @Override
          public void beforeCompletion() {
            // the outcome is not known yet
          }

          @Override
          public void afterCompletion(int status) {
            if (status == Status.STATUS_COMMITTED) {
              deleteFile(assetId, key);
            }
          }
        });
  }

  private void deleteFile(Long assetId, String key) {
    try {
      storageService.delete(key);
    } catch (Exception e) {
      LOG.warnv("Failed to delete asset {0} from storage: {1}", assetId, e.getMessage());
    }
  }
}
