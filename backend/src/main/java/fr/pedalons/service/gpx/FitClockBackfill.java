package fr.pedalons.service.gpx;

import com.garmin.fit.DecodeOptions;
import com.garmin.fit.DecodeResult;
import com.garmin.fit.FitDecoder;
import com.garmin.fit.RecordMesg;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.AssetType;
import fr.pedalons.infrastructure.gpx.FitExporter;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.gpx.GpxSanitizationBackfill.StoredFile;
import fr.pedalons.service.route.GpxProcessingService;
import fr.pedalons.service.route.GpxProcessingService.StoredTrack;
import fr.pedalons.service.route.waypoint.AnchoredWaypoint;
import io.github.glandais.engine.gpx.GpxParserJvm;
import io.github.glandais.engine.gpx.GpxToPathJvm;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * One-off rewrite of the {@code route.fit} files written between docs/LEDGER_*.md API-44 and
 * API-181 (docs/LEDGER_*.md API-182): a route has no clock since API-44, and until API-181 its FIT
 * carried the same timestamp on every record, which a Garmin Edge draws as one straight line from
 * the start to the finish. Every route and every GPX-tool preview still in the database.
 *
 * <p><b>In place, the FIT only.</b> A stale file is written again under the same storage key, from
 * what a save writes it from: the stored track points and waypoints ({@link
 * GpxProcessingService#waypointFileBytes}), so its course points are kept. A route with no stored
 * track point (legacy data, which has no placed waypoint either) is read from its {@code
 * filtered.gpx}. No GPX, no row but the asset's size, and <b>no new content revision</b>: nothing
 * is sent again to the GPS services.
 *
 * <p><b>Idempotent.</b> A file is stale when it has several records and they all share one
 * timestamp — or none: those files start at the FIT epoch, which a decoder reads as a system time
 * and drops. Anything else is read and left alone. Once a pass ends without an error a marker
 * object in the bucket turns the trigger into one existence check, and a bucket restored
 * from an older backup comes back without it, so the pass runs again.
 */
@ApplicationScoped
public class FitClockBackfill {

  private static final Logger LOG = Logger.getLogger(FitClockBackfill.class);

  /** Written once a pass completes without error; its presence skips every later run. */
  static final String MARKER_KEY = "maintenance/api-182-fit-clocked";

  private static final String FIT_CONTENT_TYPE = "application/vnd.ant.fit";
  private static final String FILTERED_GPX = "filtered.gpx";
  private static final String FIT = "route.fit";

  @Inject StorageService storageService;

  @Inject AssetService assetService;

  @Inject EntityManager entityManager;

  @Inject GpxSanitizationBackfill sanitizationBackfill;

  /** Outcome of one pass: FIT files looked at, rewritten, and those that failed. */
  public record Report(int files, int rewritten, int failed) {}

  /** A route's FIT, and its filtered GPX when it has one. */
  private record RouteFiles(Long routeId, @Nullable StoredFile fit, @Nullable String filteredKey) {}

  /**
   * At startup, then hourly until a pass ends clean; after that, one existence check an hour.
   *
   * <p>Two minutes after the start rather than on it: the pass reads every FIT in the bucket,
   * which has no place on the start path, and a deploy is rolling — for about a minute the
   * previous release still serves saves, and a FIT it writes then has no clock. A pass that began
   * with the application would set the marker over those.
   */
  @Scheduled(
      every = "1h",
      delayed = "2m",
      concurrentExecution = Scheduled.ConcurrentExecution.SKIP,
      identity = "fit-clock-backfill")
  void runOnce() {
    if (storageService.exists(MARKER_KEY)) {
      return;
    }
    Report report = clockAll();
    LOG.infof(
        "FIT clock backfill: %d files checked, %d rewritten, %d failed",
        report.files(), report.rewritten(), report.failed());
    if (report.failed() == 0) {
      byte[] marker =
          ("done " + Instant.now() + " — " + report + "\n").getBytes(StandardCharsets.UTF_8);
      storageService.store(
          MARKER_KEY, new ByteArrayInputStream(marker), "text/plain", marker.length);
    }
  }

  /** One full pass over every route and preview FIT. Safe to run any number of times. */
  public Report clockAll() {
    int files = 0;
    int rewritten = 0;
    int failed = 0;
    for (RouteFiles route : routeFiles()) {
      if (route.fit() == null) {
        continue;
      }
      files++;
      try {
        if (clockRoute(route)) {
          rewritten++;
        }
      } catch (Exception e) {
        failed++;
        LOG.warnf(e, "FIT clock backfill failed for route %s", TsidUtils.toString(route.routeId()));
      }
    }
    for (Long previewId : previewIds()) {
      files++;
      try {
        if (QuarkusTransaction.requiringNew().call(() -> clockPreview(previewId))) {
          rewritten++;
        }
      } catch (Exception e) {
        failed++;
        LOG.warnf(e, "FIT clock backfill failed for preview %d", previewId);
      }
    }
    return new Report(files, rewritten, failed);
  }

  /**
   * Whether every record of this FIT carries the same timestamp, or none (the decoder gives none
   * for a system time, which is what a course starting at the FIT epoch holds). A file that cannot
   * be decoded is not stale: nothing says this pass would write a better one over it.
   */
  static boolean isClockless(byte[] fit) {
    DecodeResult result;
    try {
      result = new FitDecoder(fit).decode(new DecodeOptions());
    } catch (Exception e) {
      return false;
    }
    if (!result.isSuccess()) {
      return false;
    }
    List<RecordMesg> records = result.getMessages().getRecordMesgs();
    if (records.size() < 2) {
      return false;
    }
    Object first = records.getFirst().getTimestamp();
    return records.stream().allMatch(r -> Objects.equals(first, r.getTimestamp()));
  }

  /**
   * No lock on the route: the write is to the key read with the asset, and {@link
   * GpxSanitizationBackfill#store} drops it when a save has replaced the file meanwhile — that
   * save wrote its own FIT, with a clock.
   */
  private boolean clockRoute(RouteFiles files) throws Exception {
    StoredFile fit = Objects.requireNonNull(files.fit());
    byte[] stored = read(fit.key());
    if (stored == null || !isClockless(stored)) {
      return false;
    }
    byte[] clocked =
        QuarkusTransaction.requiringNew()
            .call(() -> routeFit(files.routeId(), files.filteredKey()));
    if (clocked == null) {
      return false;
    }
    sanitizationBackfill.store(fit, clocked);
    return true;
  }

  /** The FIT a save of this route would write today, null when there is nothing to write it from. */
  private byte @Nullable [] routeFit(Long routeId, @Nullable String filteredKey) throws Exception {
    // Deleted routes included: find ignores no row, and a soft-deleted route still holds its files
    Route route = entityManager.find(Route.class, routeId);
    if (route == null) {
      return null;
    }
    List<StoredTrack> tracks =
        route.getTracks().stream()
            .sorted(Comparator.comparing(GpxTrack::getId))
            .map(t -> new StoredTrack(t.getName(), t.getTrackPoints()))
            .toList();
    if (tracks.stream().allMatch(t -> t.points().isEmpty())) {
      return filteredKey == null ? null : fitOfFilteredGpx(filteredKey, route.getName());
    }
    return GpxProcessingService.waypointFileBytes(
            route.getName(), tracks, AnchoredWaypoint.fromRows(route.getWaypoints()))
        .fit();
  }

  /**
   * Under the row lock, like the save that writes a preview's waypoints in place: the key is the
   * one of the revision the row has now, and the tracks are the ones of that revision.
   */
  private boolean clockPreview(Long previewId) throws Exception {
    GpxPreview preview =
        entityManager.find(GpxPreview.class, previewId, LockModeType.PESSIMISTIC_WRITE);
    if (preview == null) {
      return false;
    }
    String key = GpxPreviewService.trackKey(preview, FIT);
    byte[] stored = read(key);
    if (stored == null || !isClockless(stored)) {
      return false;
    }
    List<StoredTrack> tracks =
        preview.getTracks().stream().map(t -> new StoredTrack(t.name(), t.trackPoints())).toList();
    byte[] clocked =
        tracks.stream().allMatch(t -> t.points().isEmpty())
            ? fitOfFilteredGpx(GpxPreviewService.trackKey(preview, FILTERED_GPX), preview.getName())
            : GpxProcessingService.waypointFileBytes(
                    preview.getName(),
                    tracks,
                    PreviewWaypoints.toAnchored(preview.readableWaypoints()))
                .fit();
    if (clocked == null) {
      return false;
    }
    sanitizationBackfill.store(
        new StoredFile(key, FIT_CONTENT_TYPE, Map.of(), null, null), clocked);
    return true;
  }

  private byte @Nullable [] fitOfFilteredGpx(String key, String name) throws Exception {
    byte[] gpx = read(key);
    if (gpx == null) {
      return null;
    }
    return FitExporter.toFitBytes(
        GpxToPathJvm.tracksAsPaths(GpxParserJvm.parse(new String(gpx, StandardCharsets.UTF_8))),
        name);
  }

  private byte @Nullable [] read(String key) throws Exception {
    if (!storageService.exists(key)) {
      return null;
    }
    try (InputStream is = storageService.retrieve(key)) {
      return is.readAllBytes();
    }
  }

  /** Every route's FIT and filtered GPX assets, deleted routes and every domain included. */
  private List<RouteFiles> routeFiles() {
    List<Object[]> rows =
        QuarkusTransaction.requiringNew()
            .call(() ->
                entityManager
                    .createQuery(
                        "select te.id, a.team.id, a.fileId, a.fileName, a.contentType, a.type,"
                            + " a.id from Asset a join a.teamEntity te where a.type in (:types)"
                            + " order by te.id",
                        Object[].class)
                    .setParameter(
                        "types", List.of(AssetType.ROUTE_FILTERED_GPX, AssetType.ROUTE_FIT))
                    .getResultList());
    Map<Long, RouteFiles> byRoute = new LinkedHashMap<>();
    for (Object[] row : rows) {
      Long routeId = (Long) row[0];
      Long teamId = (Long) row[1];
      Long fileId = (Long) row[2];
      String key = assetService.getAssetKey(teamId, fileId);
      RouteFiles known = byRoute.getOrDefault(routeId, new RouteFiles(routeId, null, null));
      if (row[5] == AssetType.ROUTE_FIT) {
        Map<String, String> metadata =
            Map.of(
                "file-id", TsidUtils.toString(fileId),
                "team-id", TsidUtils.toString(teamId),
                "file-name", (String) row[3]);
        StoredFile fit = new StoredFile(key, (String) row[4], metadata, (Long) row[6], fileId);
        byRoute.put(routeId, new RouteFiles(routeId, fit, known.filteredKey()));
      } else {
        byRoute.put(routeId, new RouteFiles(routeId, known.fit(), key));
      }
    }
    return List.copyOf(byRoute.values());
  }

  private List<Long> previewIds() {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            entityManager
                .createQuery("select p.id from GpxPreview p order by p.id", Long.class)
                .getResultList());
  }
}
