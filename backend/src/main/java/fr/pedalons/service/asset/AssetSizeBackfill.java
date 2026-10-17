package fr.pedalons.service.asset;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.asset.AssetRepository.SizeUnknownRow;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.jboss.logging.Logger;

/**
 * Records the size of the assets stored before it was recorded on write (docs/LEDGER_*.md API-7),
 * one batch at a time: one HEAD on the bucket per asset, nothing downloaded.
 *
 * <p>Also the safety net of a rolling deploy: the previous release, which does not know the
 * column, writes rows without a size for about a minute, and they are found here the same way.
 */
@ApplicationScoped
public class AssetSizeBackfill {

  private static final Logger LOG = Logger.getLogger(AssetSizeBackfill.class);

  /** What happened to one asset. */
  public enum Outcome {
    /** Its size is recorded. */
    RECORDED,
    /**
     * No object under the key: a file gone from the bucket, or one being written — a generated
     * thumbnail's row exists before its file does, and the writer records the size itself.
     */
    MISSING,
    /** Storage failed: the size stays unknown, and is looked up again after the next restart. */
    FAILED
  }

  /** @param lastId the highest asset id looked at, to resume after it */
  public record BatchResult(int processed, long lastId, Map<Outcome, Integer> outcomes) {}

  @Inject AssetRepository assetRepository;
  @Inject AssetService assetService;
  @Inject StorageService storageService;

  /** Processes up to {@code limit} assets of unknown size with an id above {@code afterId}. */
  public BatchResult processBatch(long afterId, int limit) {
    List<SizeUnknownRow> rows =
        QuarkusTransaction.requiringNew()
            .call(() -> assetRepository.findSizeUnknown(afterId, limit));
    Map<Outcome, Integer> outcomes = new EnumMap<>(Outcome.class);
    long lastId = afterId;
    for (SizeUnknownRow row : rows) {
      outcomes.merge(process(row), 1, Integer::sum);
      lastId = row.assetId();
    }
    if (!rows.isEmpty()) {
      LOG.infof("Asset size backfill: %d files, %s", rows.size(), outcomes);
    }
    return new BatchResult(rows.size(), lastId, outcomes);
  }

  Outcome process(SizeUnknownRow row) {
    long size;
    try {
      size = storageService.size(assetService.getAssetKey(row.teamId(), row.fileId()));
    } catch (RuntimeException e) {
      LOG.warnf(e, "Asset size backfill failed for asset %s", TsidUtils.toString(row.assetId()));
      return Outcome.FAILED;
    }
    if (size < 0) {
      return Outcome.MISSING;
    }
    QuarkusTransaction.requiringNew()
        .run(() -> assetRepository.recordSizeIfUnknown(row.assetId(), row.fileId(), size));
    return Outcome.RECORDED;
  }
}
