package fr.pedalons.service.asset;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.infrastructure.image.ImageFormat;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.asset.AssetRepository.MetadataPendingRow;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.jboss.logging.Logger;

/**
 * Re-encodes the images stored before storage did it on write (docs/LEDGER_*.md API-43): the
 * assets V47 flagged {@code metadata_pending}, one batch at a time.
 *
 * <p>Each image is downloaded and stored again under the same key, which re-encodes it; its flag
 * is then cleared. A file that is not an image, a file gone from the bucket, are just unflagged. A
 * re-encoded image has its asset's size updated, and its name and content type too when it changed
 * format (a TIFF into a JPEG).
 *
 * <p>No transaction spans the storage calls: the flag of each asset is cleared in its own, after
 * its file is written, so a crash between the two only means the file is re-encoded once more.
 */
@ApplicationScoped
public class AssetMetadataBackfill {

  private static final Logger LOG = Logger.getLogger(AssetMetadataBackfill.class);

  /** What happened to one file. */
  public enum Outcome {
    /** Re-encoded, rewritten without its metadata. */
    REENCODED,
    /** Not an image, or one without metadata (BMP, ICO, SVG). */
    NOT_AN_IMAGE,
    /** JPEG 2000, or an image imgproxy cannot decode: kept as it is, logged — see the WARN. */
    UNREADABLE,
    /** No object under the key. */
    MISSING,
    /** Storage or imgproxy failed: the asset stays flagged and is tried again on a later run. */
    FAILED
  }

  /** @param lastId the highest asset id looked at, to resume after it */
  public record BatchResult(int processed, long lastId, Map<Outcome, Integer> outcomes) {}

  @Inject AssetRepository assetRepository;
  @Inject AssetService assetService;
  @Inject StorageService storageService;

  /**
   * Processes up to {@code limit} flagged assets with an id above {@code afterId}. Starting after
   * the last id of the previous batch keeps a file that keeps failing from blocking the others;
   * start again from 0 once a batch comes back short.
   */
  public BatchResult processBatch(long afterId, int limit) {
    List<MetadataPendingRow> rows =
        QuarkusTransaction.requiringNew()
            .call(() -> assetRepository.findMetadataPending(afterId, limit));
    Map<Outcome, Integer> outcomes = new EnumMap<>(Outcome.class);
    long lastId = afterId;
    for (MetadataPendingRow row : rows) {
      Outcome outcome = process(row);
      outcomes.merge(outcome, 1, Integer::sum);
      lastId = row.assetId();
    }
    if (!rows.isEmpty()) {
      LOG.infof("Asset metadata backfill: %d files, %s", rows.size(), outcomes);
    }
    return new BatchResult(rows.size(), lastId, outcomes);
  }

  Outcome process(MetadataPendingRow row) {
    Outcome outcome;
    try {
      outcome = reencode(row);
    } catch (IOException | RuntimeException e) {
      LOG.warnf(
          e,
          "Asset metadata backfill failed for asset %s, will retry",
          TsidUtils.toString(row.assetId()));
      return Outcome.FAILED;
    }
    QuarkusTransaction.requiringNew()
        .run(() -> assetRepository.clearMetadataPending(row.assetId()));
    return outcome;
  }

  private Outcome reencode(MetadataPendingRow row) throws IOException {
    String key = assetService.getAssetKey(row.teamId(), row.fileId());
    if (!storageService.exists(key)) {
      return Outcome.MISSING;
    }
    // Sniffed from a ranged read first: an attachment can be a large video or PDF, and only an
    // image is worth downloading
    ImageFormat format =
        ImageFormat.sniff(storageService.retrieveHead(key, ImageFormat.SNIFF_LENGTH));
    if (format.isRefused()) {
      LOG.warnf(
          "Asset %s (%s, %s) is a %s image: it cannot be re-encoded, left as is",
          TsidUtils.toString(row.assetId()), row.fileName(), key, format);
      return Outcome.UNREADABLE;
    }
    if (!format.isReencoded()) {
      return Outcome.NOT_AN_IMAGE;
    }
    String fileName = format.storedFileName(row.fileName());
    Path original = Files.createTempFile("pedalons-backfill-", ".orig");
    long size;
    try {
      try (InputStream in = storageService.retrieve(key)) {
        Files.copy(in, original, StandardCopyOption.REPLACE_EXISTING);
      }
      Map<String, String> metadata =
          Map.of(
              "asset-id", TsidUtils.toString(row.assetId()),
              "file-id", TsidUtils.toString(row.fileId()),
              "team-id", TsidUtils.toString(row.teamId()),
              "file-name", fileName);
      try (InputStream in = Files.newInputStream(original)) {
        size = storageService.store(key, in, row.contentType(), Files.size(original), metadata);
      } catch (PedalonsException e) {
        if (e.getErrorCode() != ErrorCode.INVALID_FORMAT) {
          throw e;
        }
        LOG.warnf(
            "Asset %s (%s, %s) is a %s imgproxy cannot decode, left as is",
            TsidUtils.toString(row.assetId()), row.fileName(), key, format);
        return Outcome.UNREADABLE;
      }
    } finally {
      Files.deleteIfExists(original);
    }
    QuarkusTransaction.requiringNew()
        .run(() ->
            assetRepository.updateStoredFile(
                row.assetId(), fileName, format.storedMimeType(), size));
    return Outcome.REENCODED;
  }
}
