package fr.pedalons.service.gpx;

import fr.pedalons.common.Crons;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.enums.AssetType;
import fr.pedalons.infrastructure.gpx.FitExporter;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.route.GpxSanitizer;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxParserJvm;
import io.github.glandais.engine.gpx.GpxToPathJvm;
import io.github.glandais.engine.gpx.GpxWriterJvm;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * One-off rewrite of the GPX and FIT files stored before timestamps and sensor data were stripped
 * at import (docs/LEDGER_*.md API-44): every route's {@code original.gpx}, {@code filtered.gpx} and
 * {@code route.fit}, the same three files of every GPX-tool preview still within retention, and
 * every GPX or FIT stored as a plain attachment (API-49, API-55) — through {@link TrackAttachmentSanitizer}, as an
 * upload is now.
 *
 * <p><b>In place, geometry untouched.</b> A dirty GPX is parsed, passed through {@link
 * GpxSanitizer} and written back under the same storage key; the FIT, which carries the same
 * clock and power values, is regenerated from the sanitized filtered track — exactly what the
 * pipeline writes it from. The pipeline itself (SRTM, simplification, climbs) is <em>not</em>
 * replayed: tracks, climbs and metadata in the database hold no time or sensor value, and
 * re-running it could shift distances and elevations under routes people already know.
 *
 * <p><b>Idempotent.</b> A file is rewritten only when it still holds an {@code <extensions>} block
 * or a {@code <time>} other than the epoch placeholder the gpx2web-era sanitizer wrote (a file
 * sanitized since vcyclist carries no {@code <time>} at all); a clean file is
 * read and left alone. Once a full pass ends without an error, a marker object in the bucket turns
 * the nightly trigger into a single existence check — and a bucket restored from a backup taken
 * before the pass comes back without it, so the pass simply runs again.
 */
@ApplicationScoped
public class GpxSanitizationBackfill {

  private static final Logger LOG = Logger.getLogger(GpxSanitizationBackfill.class);

  /**
   * Written once a pass completes without error; its presence skips every later run. Renamed from
   * {@code maintenance/api-44-gpx-sanitized} when attachments joined the pass (docs/LEDGER_*.md
   * API-49), so a bucket that finished the first pass runs the new one once: routes and previews
   * already clean are only read.
   */
  static final String MARKER_KEY = "maintenance/api-49-gpx-sanitized";

  private static final String GPX_CONTENT_TYPE = "application/gpx+xml";
  private static final String FIT_CONTENT_TYPE = "application/vnd.ant.fit";
  private static final String ORIGINAL_GPX = "original.gpx";
  private static final String FILTERED_GPX = "filtered.gpx";
  private static final String FIT = "route.fit";

  /** What a point sanitized before vcyclist carries — the epoch, gpx2web needing an instant. */
  private static final Pattern REAL_TIME = Pattern.compile("<time>(?!1970-01-01T00:00:00Z<)");

  @Inject StorageService storageService;

  @Inject AssetService assetService;

  @Inject AssetRepository assetRepository;

  @Inject GpxPreviewRepository gpxPreviewRepository;

  @Inject GpxPreviewService gpxPreviewService;

  @Inject TrackAttachmentSanitizer trackAttachmentSanitizer;

  /** Outcome of one pass: file sets looked at, file sets rewritten, file sets that failed. */
  public record Report(int sets, int rewritten, int failed) {}

  /**
   * A stored object, with what it must be written back with.
   *
   * @param assetId the asset whose size to update once rewritten, null for a preview's file
   */
  record StoredFile(
      String key, String contentType, Map<String, String> metadata, @Nullable Long assetId) {}

  /** The three files one route or one preview owns; any of them may be missing. */
  record FileSet(
      String label,
      @Nullable StoredFile original,
      @Nullable StoredFile filtered,
      @Nullable StoredFile fit) {}

  /**
   * Nightly, after the preview purge (4:00) so expired previews are not rewritten just before
   * being deleted. After the first clean pass this is one existence check a night.
   */
  @Scheduled(
      cron = "0 15 4 * * ?",
      timeZone = Crons.ZONE,
      concurrentExecution = Scheduled.ConcurrentExecution.SKIP,
      identity = "gpx-sanitization-backfill")
  void runOnce() {
    if (storageService.exists(MARKER_KEY)) {
      return;
    }
    Report report = sanitizeAll();
    LOG.infof(
        "GPX sanitization backfill: %d file sets checked, %d rewritten, %d failed",
        report.sets(), report.rewritten(), report.failed());
    if (report.failed() == 0) {
      byte[] marker =
          ("done " + Instant.now() + " — " + report + "\n").getBytes(StandardCharsets.UTF_8);
      storageService.store(
          MARKER_KEY, new ByteArrayInputStream(marker), "text/plain", marker.length);
    }
  }

  /** One full pass over every stored route and preview file. Safe to run any number of times. */
  public Report sanitizeAll() {
    List<FileSet> sets = new ArrayList<>(routeFileSets());
    sets.addAll(previewFileSets());
    int rewritten = 0;
    int failed = 0;
    for (FileSet set : sets) {
      try {
        if (sanitize(set)) {
          rewritten++;
        }
      } catch (Exception e) {
        failed++;
        LOG.warnf(e, "GPX sanitization backfill failed for %s", set.label());
      }
    }
    List<StoredFile> attachments = attachmentFiles();
    for (StoredFile attachment : attachments) {
      try {
        if (sanitizeAttachment(attachment)) {
          rewritten++;
        }
      } catch (Exception e) {
        failed++;
        LOG.warnf(e, "GPX sanitization backfill failed for attachment %s", attachment.key());
      }
    }
    return new Report(sets.size() + attachments.size(), rewritten, failed);
  }

  /** Rewrites the dirty files of one set; {@code true} if anything was written. */
  boolean sanitize(FileSet set) throws Exception {
    boolean changed = false;
    if (set.original() != null) {
      GpxDocument original = readIfDirty(set.original());
      if (original != null) {
        store(set.original(), toGpxBytes(original));
        changed = true;
      }
    }
    if (set.filtered() != null) {
      GpxDocument filtered = readIfDirty(set.filtered());
      if (filtered != null) {
        // Written from the same in-memory track as the filtered GPX, so dirty exactly when it is.
        // The FIT goes first: the filtered GPX is the only dirtiness signal for the pair, so if
        // the second write fails the next pass must still see it dirty and redo the FIT too.
        if (set.fit() != null) {
          store(set.fit(), toFitBytes(filtered));
        }
        store(set.filtered(), toGpxBytes(filtered));
        changed = true;
      }
    }
    return changed;
  }

  /**
   * Rewrites one GPX or FIT attachment when its cleaned form differs from what is stored; {@code true} if
   * written. Judged by {@link TrackAttachmentSanitizer#isClean} rather than {@link #isDirty}: an
   * attachment comes from any software, and an author or a device in its metadata is no {@code
   * <time>}. A file that is not a
   * readable GPX or FIT is left as it is and logged — it cannot be cleaned, and failing on it would keep
   * the marker from ever being written.
   */
  boolean sanitizeAttachment(StoredFile file) throws Exception {
    if (!storageService.exists(file.key())) {
      return false;
    }
    byte[] raw;
    try (InputStream is = storageService.retrieve(file.key())) {
      raw = is.readAllBytes();
    }
    byte[] clean;
    try {
      if (trackAttachmentSanitizer.isClean(raw, file.contentType())) {
        return false;
      }
      clean = trackAttachmentSanitizer.sanitize(raw, file.contentType());
    } catch (BusinessException e) {
      LOG.warnf(
          "Track attachment %s left as is: not a readable GPX or FIT (%s)",
          file.key(), e.getMessage());
      return false;
    }
    store(file, clean);
    return true;
  }

  /** The sanitized parse of a stored GPX, or null when it is missing or already clean. */
  private @Nullable GpxDocument readIfDirty(StoredFile file) throws Exception {
    if (!storageService.exists(file.key())) {
      return null;
    }
    byte[] raw;
    try (InputStream is = storageService.retrieve(file.key())) {
      raw = is.readAllBytes();
    }
    if (!isDirty(new String(raw, StandardCharsets.UTF_8))) {
      return null;
    }
    // Every stored GPX was written by gpx2web's writer, which only ever emitted UTF-8.
    return GpxSanitizer.sanitize(GpxParserJvm.parse(new String(raw, StandardCharsets.UTF_8)));
  }

  static boolean isDirty(String gpxXml) {
    return gpxXml.contains("<extensions>") || REAL_TIME.matcher(gpxXml).find();
  }

  private static byte[] toGpxBytes(GpxDocument gpx) {
    return GpxWriterJvm.write(gpx, false).getBytes(StandardCharsets.UTF_8);
  }

  private static byte[] toFitBytes(GpxDocument gpx) {
    return FitExporter.toFitBytes(GpxToPathJvm.tracksAsPaths(gpx), gpx.getName());
  }

  private void store(StoredFile file, byte[] content) {
    long size =
        storageService.store(
            file.key(),
            new ByteArrayInputStream(content),
            file.contentType(),
            content.length,
            file.metadata());
    Long assetId = file.assetId();
    if (assetId != null) {
      // docs/LEDGER_*.md API-7: AssetDto.size is the size of what a download returns
      QuarkusTransaction.requiringNew().run(() -> assetRepository.updateSize(assetId, size));
    }
  }

  /**
   * Every route's GPX and FIT assets, grouped by route — deleted routes and every domain included:
   * a soft-deleted route still holds its files.
   */
  private List<FileSet> routeFileSets() {
    List<Object[]> rows =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    assetRepository
                        .getEntityManager()
                        .createQuery(
                            "select te.id, a.team.id, a.fileId, a.fileName, a.contentType, a.type,"
                                + " a.id from Asset a join a.teamEntity te where a.type in (:types)"
                                + " order by te.id",
                            Object[].class)
                        .setParameter(
                            "types",
                            List.of(
                                AssetType.ROUTE_ORIGINAL_GPX,
                                AssetType.ROUTE_FILTERED_GPX,
                                AssetType.ROUTE_FIT))
                        .getResultList());

    Map<Long, Map<AssetType, StoredFile>> byRoute = new LinkedHashMap<>();
    for (Object[] row : rows) {
      Long routeId = (Long) row[0];
      Long teamId = (Long) row[1];
      Long fileId = (Long) row[2];
      String fileName = (String) row[3];
      Map<String, String> metadata =
          Map.of(
              "file-id", TsidUtils.toString(fileId),
              "team-id", TsidUtils.toString(teamId),
              "file-name", fileName);
      byRoute
          .computeIfAbsent(routeId, id -> new LinkedHashMap<>())
          .put(
              (AssetType) row[5],
              new StoredFile(
                  assetService.getAssetKey(teamId, fileId),
                  (String) row[4],
                  metadata,
                  (Long) row[6]));
    }

    List<FileSet> sets = new ArrayList<>(byRoute.size());
    byRoute.forEach(
        (routeId, files) ->
            sets.add(
                new FileSet(
                    "route " + TsidUtils.toString(routeId),
                    files.get(AssetType.ROUTE_ORIGINAL_GPX),
                    files.get(AssetType.ROUTE_FILTERED_GPX),
                    files.get(AssetType.ROUTE_FIT))));
    return sets;
  }

  /**
   * Every GPX and FIT stored as a plain attachment, whatever its domain and whether or not its content
   * still exists — an attachment not yet linked to any content holds its file too.
   */
  private List<StoredFile> attachmentFiles() {
    List<Object[]> rows =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    assetRepository
                        .getEntityManager()
                        .createQuery(
                            "select a.team.id, a.fileId, a.fileName, a.contentType, a.id from Asset"
                                + " a where a.type = :type and a.contentType in (:contentTypes)"
                                + " order by a.id",
                            Object[].class)
                        .setParameter("type", AssetType.ATTACHMENT)
                        .setParameter(
                            "contentTypes",
                            List.of(
                                TrackAttachmentSanitizer.GPX_CONTENT_TYPE,
                                TrackAttachmentSanitizer.FIT_CONTENT_TYPE))
                        .getResultList());
    List<StoredFile> files = new ArrayList<>(rows.size());
    for (Object[] row : rows) {
      Long teamId = (Long) row[0];
      Long fileId = (Long) row[1];
      Map<String, String> metadata =
          Map.of(
              "file-id", TsidUtils.toString(fileId),
              "team-id", TsidUtils.toString(teamId),
              "file-name", (String) row[2]);
      files.add(
          new StoredFile(
              assetService.getAssetKey(teamId, fileId), (String) row[3], metadata, (Long) row[4]));
    }
    return files;
  }

  /** The three files of every preview still in the database, whatever its domain. */
  private List<FileSet> previewFileSets() {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                gpxPreviewRepository.listAll().stream()
                    .map(
                        preview -> {
                          Map<String, String> keys = gpxPreviewService.exportKeys(preview);
                          return new FileSet(
                              "preview " + preview.getPublicId(),
                              new StoredFile(
                                  keys.get(ORIGINAL_GPX), GPX_CONTENT_TYPE, Map.of(), null),
                              new StoredFile(
                                  keys.get(FILTERED_GPX), GPX_CONTENT_TYPE, Map.of(), null),
                              new StoredFile(keys.get(FIT), FIT_CONTENT_TYPE, Map.of(), null));
                        })
                    .toList());
  }
}
