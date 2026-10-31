package fr.pedalons.service.route;

import static org.geolatte.geom.builder.DSL.*;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.WindDirection;
import fr.pedalons.infrastructure.exception.NotFoundException;
import fr.pedalons.infrastructure.gpx.CoursePoint;
import fr.pedalons.infrastructure.gpx.FitExporter;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.route.response.TrackMetadata;
import fr.pedalons.service.route.waypoint.AnchoredWaypoint;
import fr.pedalons.service.route.waypoint.TrackAxis;
import fr.pedalons.service.route.waypoint.WaypointAnchoring;
import fr.pedalons.service.route.waypoint.WaypointDraft;
import fr.pedalons.service.route.waypoint.WaypointDrafts;
import fr.pedalons.service.route.waypoint.WaypointExports;
import fr.pedalons.service.route.waypoint.WaypointPlan;
import fr.pedalons.service.route.waypoint.WaypointRows;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import fr.pedalons.service.thumbnail.ThumbnailService;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.github.glandais.engine.gpx.GpxParserJvm;
import io.github.glandais.engine.gpx.GpxToPathJvm;
import io.github.glandais.engine.gpx.GpxTrackPoint;
import io.github.glandais.engine.gpx.GpxWriterJvm;
import io.github.glandais.engine.path.Path;
import io.hypersistence.tsid.TSID;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.awt.Color;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.MalformedInputException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import org.geolatte.geom.G2D;
import org.geolatte.geom.LineString;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Service for processing GPX files for route management.
 * Handles the complete GPX processing pipeline from upload to storage.
 *
 * <p>{@link Path} in this file is vcyclist's immutable point array, <b>not</b>
 * {@code java.nio.file.Path} — the latter is spelled out in full wherever it appears, since the
 * geometry type is by far the more frequent of the two here.
 */
@ApplicationScoped
public class GpxProcessingService {

  private static final Logger LOG = Logger.getLogger(GpxProcessingService.class);

  /** Sibling of the asset temp dir, so temp files can be moved across without copying bytes. */
  private static final String TEMP_DIR = "pedalons-gpx";

  /** What {@code GpxDocument.getName()} returns for a file with no {@code <metadata><name>}. */
  private static final String NO_NAME = "noname";

  @Inject GpxPipeline pipeline;

  @Inject MapThumbnailRenderer mapThumbnailRenderer;

  @Inject AssetService assetService;

  @Inject StorageService storageService;

  @Inject PedalonsQueryContext pedalonsContext;

  /**
   * Parses a GPX file, refused with {@code GPX_TOO_LONG} when its tracks are longer than {@link
   * GpxLimits#MAX_TRACK_DISTANCE_METERS} (SEC-6). The size of an uploaded file is bounded before
   * this, by the resource ({@code api.gpx.GpxUploads}).
   */
  public GpxDocument parseGpx(java.nio.file.Path path) {
    LOG.infov("Processing GPX file");
    GpxDocument gpx;
    try {
      gpx = GpxParserJvm.parse(readGpx(path));
    } catch (Exception e) {
      LOG.errorv("Failed to parse GPX file", e);
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
    GpxLimits.checkTracks(gpx);
    return gpx;
  }

  /**
   * vcyclist's parser takes a {@code String}, so the encoding has to be decided here. UTF-8 first,
   * ISO-8859-1 as a fallback: GPX files inherited from biketeam are frequently latin-1, and the
   * previous {@code InputStream}-based parser absorbed them silently.
   */
  private static String readGpx(java.nio.file.Path path) throws IOException {
    try {
      return Files.readString(path, StandardCharsets.UTF_8);
    } catch (MalformedInputException e) {
      LOG.debugv("GPX {0} is not valid UTF-8, retrying as ISO-8859-1", path);
      return Files.readString(path, StandardCharsets.ISO_8859_1);
    }
  }

  /**
   * A one-track document from planner points — no source file, hence no elevation and no time —
   * refused like {@link #parseGpx} when too long. The request DTOs bound the number of points and
   * their coordinates; the check here repeats the latter for any other caller.
   */
  public GpxDocument fromPoints(String name, List<GeoPoint> points) {
    List<GpxTrackPoint> trackPoints =
        points.stream().map(p -> GpxModelJvm.trackPoint(p.lat(), p.lng())).toList();
    GpxDocument gpx = GpxModelJvm.document(List.of(GpxModelJvm.track(trackPoints, name)), name);
    GpxLimits.checkTracks(gpx);
    return gpx;
  }

  /** A single track, fully computed but not yet bound to any entity. */
  public record ComputedTrack(
      String name,
      LineString<G2D> line,
      List<GpxTrack.TrackPoint> trackPoints,
      List<ClimbData> climbs,
      TrackMetadata metadata) {}

  /**
   * Outcome of {@link #computeGpx}: the two GPX serializations and the FIT export as temp files,
   * plus the computed tracks, waypoints and aggregated metadata.
   *
   * <p>Closing deletes any temp file still present. {@link #processGpxData} consumes the files by
   * moving them, so closing is then a no-op — but on the error path it releases them.
   *
   * <p>The FIT file is produced here rather than by each caller because the export is built from
   * the <b>processed</b> geometry, which only exists inside {@link #computeGpx}: paths are
   * immutable, so the source {@link GpxDocument} never carries the pipeline's output.
   *
   * <p>{@code fallbackAfterErrorKm} sums, over the tracks, what the elevation source failed to
   * serve ({@link GpxPipeline.Processed}): zero when the requested quality was really obtained.
   */
  public record ComputedGpx(
      File originalGpx,
      File filteredGpx,
      File fitFile,
      List<ComputedTrack> tracks,
      List<AnchoredWaypoint> waypoints,
      TrackMetadata aggregated,
      double fallbackAfterErrorKm)
      implements AutoCloseable {

    @Override
    public void close() {
      deleteQuietly(originalGpx);
      deleteQuietly(filteredGpx);
      deleteQuietly(fitFile);
    }
  }

  private static void deleteQuietly(@Nullable File file) {
    if (file != null && file.exists() && !file.delete()) {
      LOG.warnf("Failed to delete temp GPX file %s — may leak on disk", file.getAbsolutePath());
    }
  }

  /**
   * The tracks of a document, ready for the pipeline: sanitized ({@link GpxSanitizer}), one {@link
   * Path} per track of at least two points, with the names aligned on them.
   *
   * @param doc the sanitized document (its waypoints are the ones to keep)
   * @param name the document's name, else its first track's
   */
  public record RawTracks(
      GpxDocument doc, String name, List<Path> paths, List<String> trackNames) {}

  /**
   * Sanitizes {@code source} and extracts its tracks. Refused with {@code GPX_EMPTY} when none has
   * two points, and with {@code GPX_TOO_LONG} past {@link GpxLimits#MAX_TRACK_DISTANCE_METERS}
   * (SEC-6) — before any resampling allocates one point per 10 m of track.
   */
  public RawTracks rawTracks(GpxDocument source) {
    GpxDocument doc;
    try {
      doc = GpxSanitizer.sanitize(source);
    } catch (Exception e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
    // Tracks and routes alike, as GPXFileReader did: a <rte>-only file is a valid route — the
    // facade's default, which is the one thing a Java caller could not spell before g33.
    List<Path> unfiltered = GpxToPathJvm.tracksAsPaths(doc);
    // Written into the stored GPX and FIT files: the track's name when the file has no metadata
    // name, as gpx2web did, rather than vcyclist's "noname" placeholder.
    String name = Objects.requireNonNullElse(documentName(doc), doc.getName());
    // Derived from the same filtered view tracksAsPaths applies, or the indices would drift.
    List<String> unfilteredNames = trackNames(doc);

    // tracksAsPaths only drops empty tracks; gpx2web dropped anything under two points
    // (GPXFileReader.toGPX). Keeping a one-point track would make toLineString throw and take the
    // whole import down with it, valid tracks of the same file included.
    List<Path> raw = new ArrayList<>(unfiltered.size());
    List<String> trackNames = new ArrayList<>(unfiltered.size());
    for (int i = 0; i < unfiltered.size(); i++) {
      if (unfiltered.get(i).getSize() >= 2) {
        raw.add(unfiltered.get(i));
        trackNames.add(unfilteredNames.get(i));
      }
    }
    if (raw.isEmpty()) {
      throw new BusinessException(ErrorCode.GPX_EMPTY);
    }
    // Before the resampling of the pipeline allocates one point per 10 m of track (SEC-6):
    // parseGpx and fromPoints already checked, but this is the funnel every GPX goes through.
    GpxLimits.checkTracks(raw);
    return new RawTracks(doc, name, raw, trackNames);
  }

  /**
   * The pure GPX pipeline: resample, fix elevation, simplify, detect climbs, aggregate metadata,
   * and serialize the three artefacts (original GPX, filtered GPX, FIT).
   *
   * <p>No database, no S3, no entities, no {@link Team} — which is what lets GPX previews (which
   * belong to no team) reuse it. Callers own the returned temp files.
   *
   * <p>Nothing is mutated: the pipeline runs on immutable paths, so {@code original.gpx} (the raw
   * paths re-serialized), {@code filtered.gpx} and the FIT export (both from the processed paths)
   * can be written in any order.
   *
   * <p><b>This is where timestamps and sensor data are stripped</b> ({@link GpxSanitizer},
   * docs/LEDGER_*.md API-44), before anything is computed or written: every stored GPX and FIT
   * file of a route or a GPX-tool preview comes out of this method, whatever the entry point
   * (upload, planner, GPX-tool promotion, biketeam import). {@code original.gpx} is therefore
   * <b>not</b> the uploaded bytes but the sanitized parse of them; never store the source file.
   *
   * @param quality the elevation source of every track ({@link ElevationQuality})
   */
  public ComputedGpx computeGpx(GpxDocument source, ElevationQuality quality) {
    return computeGpx(source, quality, WaypointPlan.FROM_DOCUMENT);
  }

  /**
   * As {@link #computeGpx(GpxDocument, ElevationQuality)}, placing the waypoints of {@code plan}
   * on the processed tracks (docs/LEDGER_*.md WEB-100, C3c) and writing them, typed, into the
   * filtered GPX ({@code sym}, {@code type}, {@code desc}) and the FIT ({@code course_point}).
   * {@code original.gpx} stays the raw tracks without any {@code <wpt>}: it is the source of the HD
   * catch-up and of a preview's promotion, which carry the waypoints on their own.
   */
  public ComputedGpx computeGpx(GpxDocument source, ElevationQuality quality, WaypointPlan plan) {
    return computeGpx(source, quality, plan, null);
  }

  /**
   * As {@link #computeGpx(GpxDocument, ElevationQuality, WaypointPlan)}, the written files named
   * {@code name} — a route's name rather than the one the uploaded file carried, or {@code
   * "noname"} when it carried none. A track the file left unnamed takes it too; a named track keeps
   * its own. {@code null} keeps the file's names.
   */
  public ComputedGpx computeGpx(
      GpxDocument source, ElevationQuality quality, WaypointPlan plan, @Nullable String name) {
    RawTracks rawTracks = rawTracks(source);
    GpxDocument doc = rawTracks.doc();
    List<Path> raw = rawTracks.paths();
    List<String> trackNames = rawTracks.trackNames();
    if (name == null || name.isBlank()) {
      name = rawTracks.name();
    } else {
      // trackNames() gives an unnamed track the document's own name: that one takes the new name
      String unnamed = doc.getName();
      String routeName = name;
      trackNames = trackNames.stream().map(n -> n.equals(unnamed) ? routeName : n).toList();
    }

    File original = null;
    File filtered = null;
    File fit = null;
    try {
      original = writeToTempFile(GpxWriterJvm.write(raw, name, trackNames), ".gpx");

      List<Path> processed = new ArrayList<>(raw.size());
      double fallbackKm = 0.0;
      for (int i = 0; i < raw.size(); i++) {
        GpxPipeline.Processed result =
            pipeline.processReported(raw.get(i), trackNames.get(i), quality);
        processed.add(result.path());
        fallbackKm += result.fallbackAfterErrorKm();
      }

      List<WaypointDraft> drafts = new ArrayList<>(plan.drafts());
      if (plan.withDocumentWaypoints()) {
        // A <wpt> with no <name> gets an empty one: the column is not null
        drafts.addAll(WaypointDrafts.fromDocument(doc));
      }
      List<AnchoredWaypoint> waypoints =
          WaypointAnchoring.anchor(TrackAxis.ofPaths(processed), drafts);

      filtered =
          writeToTempFile(
              GpxWriterJvm.write(processed, name, trackNames, WaypointExports.gpx(waypoints)),
              ".gpx");
      fit = writeFitToTempFile(processed, name, WaypointExports.coursePoints(waypoints));

      List<ComputedTrack> tracks = new ArrayList<>();
      List<TrackMetadata> tracksMetadata = new ArrayList<>();
      for (int i = 0; i < processed.size(); i++) {
        Path path = processed.get(i);
        TrackMetadata metadata = extractMetadata(path);
        tracks.add(
            new ComputedTrack(
                trackNames.get(i),
                toLineString(path),
                toTrackPoints(path),
                pipeline.climbs(path),
                metadata));
        tracksMetadata.add(metadata);
      }

      WindDirection windDirection = WindEstimator.estimate(processed);

      float distance = (float) tracksMetadata.stream().mapToDouble(TrackMetadata::distance).sum();
      float elevationGain =
          (float) tracksMetadata.stream().mapToDouble(TrackMetadata::elevationGain).sum();
      float elevationLoss =
          (float) tracksMetadata.stream().mapToDouble(TrackMetadata::elevationLoss).sum();
      TrackMetadata aggregated =
          new TrackMetadata(
              distance,
              elevationGain,
              getHilliness(distance, elevationGain),
              elevationLoss,
              tracksMetadata.getFirst().start(),
              tracksMetadata.getLast().end(),
              windDirection);

      return new ComputedGpx(original, filtered, fit, tracks, waypoints, aggregated, fallbackKm);
    } catch (PedalonsException e) {
      deleteQuietly(original);
      deleteQuietly(filtered);
      deleteQuietly(fit);
      throw e;
    } catch (Exception e) {
      deleteQuietly(original);
      deleteQuietly(filtered);
      deleteQuietly(fit);
      LOG.errorv("GPX computation failed for {0}", name, e);
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  /**
   * Track names aligned with {@code tracksAsPaths}, which skips point-less tracks — building them
   * from {@code doc.getTracks()} unfiltered would shift every name by one on such a file. A track
   * name is nullable in the GPX schema, the document name is not, and the entity column is not
   * either: hence the two fallbacks.
   */
  private static List<String> trackNames(GpxDocument doc) {
    return doc.getTracks().stream()
        .filter(t -> !t.getPoints().isEmpty())
        .map(t -> t.getName() != null && !t.getName().isBlank() ? t.getName() : doc.getName())
        .toList();
  }

  /**
   * The name a GPX file goes by: its {@code <metadata><name>}, else the name of its first non-empty
   * track, else {@code null}. {@code GpxDocument.getName()} is never null — it falls back to the
   * literal {@code "noname"} — so that placeholder counts as no name. gpx2web applied the same
   * track fallback when parsing; without it, a file named only in its {@code <trk>} — what most
   * exporters write — is titled after its file name (docs/LEDGER_*.md API-115).
   */
  public static @Nullable String documentName(GpxDocument doc) {
    String name = doc.getName();
    if (!name.isBlank() && !NO_NAME.equals(name)) {
      return name;
    }
    return doc.getTracks().stream()
        .filter(t -> !t.getPoints().isEmpty())
        .map(t -> t.getName())
        .filter(n -> n != null && !n.isBlank())
        .findFirst()
        .orElse(null);
  }

  private static File createTempFile(String suffix) throws IOException {
    java.nio.file.Path tempDir =
        Files.createDirectories(
            java.nio.file.Path.of(System.getProperty("java.io.tmpdir"), TEMP_DIR));
    return Files.createTempFile(tempDir, "gpx-", suffix).toFile();
  }

  /** vcyclist's writers return a {@code String}; choosing the encoding is on us. */
  private static File writeToTempFile(String content, String suffix) throws IOException {
    File file = createTempFile(suffix);
    try {
      Files.writeString(file.toPath(), content, StandardCharsets.UTF_8);
    } catch (Exception e) {
      deleteQuietly(file);
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
    return file;
  }

  /** FIT export of the processed geometry — see {@link FitExporter} for what it guards against. */
  private static File writeFitToTempFile(List<Path> paths, String name, List<CoursePoint> points)
      throws IOException {
    return writeFitToTempFile(FitExporter.toFitBytes(paths, name, points));
  }

  private static File writeFitToTempFile(byte[] bytes) throws IOException {
    File file = createTempFile(".fit");
    try {
      Files.write(file.toPath(), bytes);
    } catch (Exception e) {
      deleteQuietly(file);
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
    return file;
  }

  /** Result of the CPU/S3 processing phase, passed to the DB persist phase. */
  public record PreparedAsset(
      AssetType type, String fileName, long fileId, AssetService.UploadedFile stored) {}

  record GpxProcessingResult(
      TrackMetadata metadata,
      List<GpxTrack> tracks,
      List<AnchoredWaypoint> waypoints,
      List<PreparedAsset> uploadedAssets) {}

  /**
   * Phase 1: CPU and S3 work — runs with the caller's transaction SUSPENDED so the DB connection
   * is released during the heavy processing (elevation, file generation, 5 S3 uploads).
   *
   * <p>All entities returned are transient (not yet attached to Hibernate session).
   */
  @Transactional(Transactional.TxType.NOT_SUPPORTED)
  public GpxProcessingResult processGpxData(Route route, GpxDocument gpx) {
    return processGpxData(route, gpx, ElevationQuality.HD);
  }

  /**
   * {@link #processGpxData(Route, GpxDocument)} with the elevation source of the caller: {@code
   * FAST} when the HD catch-up will follow, {@code HD} when it is off (docs/LEDGER_*.md API-131).
   */
  @Transactional(Transactional.TxType.NOT_SUPPORTED)
  public GpxProcessingResult processGpxData(
      Route route, GpxDocument gpx, ElevationQuality quality) {
    return processGpxData(route, gpx, quality, WaypointPlan.FROM_DOCUMENT);
  }

  /**
   * As {@link #processGpxData(Route, GpxDocument, ElevationQuality)}, placing the waypoints of
   * {@code plan} (docs/LEDGER_*.md WEB-100, C3c). The result carries them placed; {@link
   * #persistGpxData} writes the rows.
   */
  @Transactional(Transactional.TxType.NOT_SUPPORTED)
  public GpxProcessingResult processGpxData(
      Route route, GpxDocument gpx, ElevationQuality quality, WaypointPlan plan) {
    User creator = pedalonsContext.getUser();
    Long routeId = route.getId();
    Team team = route.getTeam();
    // Outside the try: the catches below delete what was uploaded before the failure
    List<PreparedAsset> uploadedAssets = new ArrayList<>();
    try (ComputedGpx computed = computeGpx(gpx, quality, plan, route.getName())) {
      uploadedAssets.add(
          prepareAndUpload(
              team,
              AssetType.ROUTE_ORIGINAL_GPX,
              "original.gpx",
              tmp -> moveInto(computed.originalGpx(), tmp)));
      LOG.infov("Saved original GPX to S3");

      uploadedAssets.add(
          prepareAndUpload(
              team,
              AssetType.ROUTE_FILTERED_GPX,
              "filtered.gpx",
              tmp -> moveInto(computed.filteredGpx(), tmp)));
      LOG.infov("Saved filtered GPX to S3");

      // Save FIT file
      uploadedAssets.add(
          prepareAndUpload(
              team, AssetType.ROUTE_FIT, "route.fit", tmp -> moveInto(computed.fitFile(), tmp)));
      LOG.infov("Saved FIT file to S3");

      // Generate thumbnails (failures are non-fatal)
      List<Path> thumbnailPaths =
          ThumbnailService.buildPaths(
              computed.tracks().stream()
                  .map(t -> new ThumbnailService.ThumbnailTrack(t.name(), t.trackPoints()))
                  .toList());
      generateThumbnailAsset(
          team,
          thumbnailPaths,
          routeId,
          MapThumbnailRenderer.LIGHT_STYLE,
          AssetType.ROUTE_THUMBNAIL_LIGHT,
          "thumbnail-light.png",
          uploadedAssets);
      generateThumbnailAsset(
          team,
          thumbnailPaths,
          routeId,
          MapThumbnailRenderer.DARK_STYLE,
          AssetType.ROUTE_THUMBNAIL_DARK,
          "thumbnail-dark.png",
          uploadedAssets);

      LOG.infov("GPX processing complete for route {0}", routeId);

      List<GpxTrack> tracks =
          computed.tracks().stream()
              .map(
                  t ->
                      new GpxTrack(
                          creator,
                          t.name(),
                          t.line(),
                          t.trackPoints(),
                          t.climbs(),
                          t.metadata().distance(),
                          t.metadata().elevationGain(),
                          t.metadata().elevationLoss()))
              .toList();

      return new GpxProcessingResult(
          computed.aggregated(), tracks, computed.waypoints(), uploadedAssets);
    } catch (PedalonsException e) {
      cleanupUploadedAssets(uploadedAssets, team);
      throw e;
    } catch (Exception e) {
      cleanupUploadedAssets(uploadedAssets, team);
      LOG.errorv("GPX processing failed for route {0}", routeId, e);
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  /** Hands a temp file over to {@link #prepareAndUpload}'s destination without copying bytes. */
  private static void moveInto(File source, File destination) throws IOException {
    Files.move(source.toPath(), destination.toPath(), StandardCopyOption.REPLACE_EXISTING);
  }

  @FunctionalInterface
  private interface FileWriter {
    void write(File file) throws Exception;
  }

  private PreparedAsset prepareAndUpload(
      Team team, AssetType type, String fileName, FileWriter writer) throws IOException {
    long fileId = TSID.Factory.getTsid().toLong();
    File tmp = assetService.createTempFile(fileId);
    try {
      writer.write(tmp);
    } catch (Exception e) {
      tmp.delete();
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
    AssetService.UploadedFile stored =
        assetService.uploadTempFileToS3(team, type, fileId, fileName);
    return new PreparedAsset(type, fileName, fileId, stored);
  }

  /**
   * Phase 2: DB-only work — persists the results of {@link #processGpxData} within the caller's
   * transaction (short burst, no heavy I/O).
   */
  @Transactional(Transactional.TxType.REQUIRED)
  public TrackMetadata persistGpxData(Route route, GpxProcessingResult result) {
    // Before anything can throw: files uploaded outside the transaction must not outlive a
    // rollback, whatever type the loop below reaches (docs/LEDGER_*.md API-128).
    for (PreparedAsset pa : result.uploadedAssets()) {
      assetService.deleteUnlessCommitted(assetService.getAssetKey(route.getTeam(), pa.fileId()));
    }
    // First: updateRoute cleared the tracks, an orphan-removal collection, and no query may run
    // between a clear and its refill (HHH90032003 would delete the elements for good). The
    // waypoints are never cleared: they are updated, removed and added in place (WaypointRows).
    result.tracks().forEach(route::addTrack);
    WaypointRows.apply(route, result.waypoints(), pedalonsContext.getUser());

    // The asset rows stay (same id, so the published URLs keep working), only their file changes.
    // In memory only, never a clear-and-refill of the set. docs/LEDGER_*.md API-128.
    for (AssetType type : ROUTE_ASSET_TYPES) {
      PreparedAsset pa =
          result.uploadedAssets().stream().filter(p -> p.type() == type).findFirst().orElse(null);
      if (pa == null) {
        // The render failed: a missing thumbnail beats the previous track's
        assetService.removeAssetsOfTypes(route, List.of(type));
        continue;
      }
      boolean newContent =
          type == AssetType.ROUTE_ORIGINAL_GPX
              || type == AssetType.ROUTE_FILTERED_GPX
              || type == AssetType.ROUTE_FIT;
      assetService.putStoredFile(
          route.getTeam(),
          route,
          type,
          pa.fileId(),
          routeFileName(route, type, pa.fileName()),
          pa.stored(),
          newContent);
    }

    return result.metadata();
  }

  /**
   * The name a route's file is downloaded under: its slug, as {@code RouteService.updateMedia}
   * renames them, rather than the {@code original.gpx} / {@code filtered.gpx} / {@code route.fit}
   * it is uploaded as. The asset URL carries it, but the download looks the asset up by id: an
   * older link with the previous name keeps working.
   */
  static String routeFileName(Route route, AssetType type, String fallback) {
    String slug = route.getSlug();
    if (slug == null || slug.isBlank()) {
      return fallback;
    }
    return switch (type) {
      case ROUTE_ORIGINAL_GPX, ROUTE_FILTERED_GPX -> slug + ".gpx";
      case ROUTE_FIT -> slug + ".fit";
      case ROUTE_THUMBNAIL_LIGHT, ROUTE_THUMBNAIL_DARK -> slug + ".png";
      default -> fallback;
    };
  }

  // ------------------------------------------------------------------ HD catch-up

  /** Raised when the HD source could not serve the whole track: the profile would not be HD. */
  public static class ElevationUnavailableException extends RuntimeException {
    public ElevationUnavailableException(String message) {
      super(message);
    }
  }

  /**
   * A route's track recomputed with the HD source, its filtered GPX and FIT already uploaded under
   * new keys (no row points at them yet).
   */
  public record ElevationRecompute(
      TrackMetadata metadata,
      List<ComputedTrack> tracks,
      PreparedAsset filtered,
      PreparedAsset fit,
      List<AnchoredWaypoint> waypoints,
      List<WaypointDraft> used) {

    /** Without waypoints: the shape this record had before WEB-100 (C3c). */
    public ElevationRecompute(
        TrackMetadata metadata,
        List<ComputedTrack> tracks,
        PreparedAsset filtered,
        PreparedAsset fit) {
      this(metadata, tracks, filtered, fit, List.of(), List.of());
    }
  }

  /**
   * Phase 1 of the HD catch-up (docs/LEDGER_*.md API-131): recomputes {@code gpx} (the route's
   * stored original, plus its waypoints, which the original does not carry) with the HD source and
   * uploads the new filtered GPX and FIT. No transaction, no entity: like {@link #processGpxData}.
   *
   * <p>The original and the thumbnails are not rewritten: the 2D track is the same.
   *
   * @throws ElevationUnavailableException when the HD source failed on part of the track (a tile
   *     IGN could not serve and Mapterhorn answered instead, or no source at all): the route stays
   *     on the fast profile and the attempt is retried later
   */
  @Transactional(Transactional.TxType.NOT_SUPPORTED)
  public ElevationRecompute recomputeHd(Team team, GpxDocument gpx) {
    return recomputeHd(team, gpx, WaypointPlan.FROM_DOCUMENT);
  }

  /**
   * As {@link #recomputeHd(Team, GpxDocument)}, with the waypoints stored (not the file's, which
   * the original does not carry) given as {@code drafts}, to be placed again on the HD track
   * (docs/LEDGER_*.md WEB-100, C3c): the HD simplification may move the vertices, hence the axis.
   */
  @Transactional(Transactional.TxType.NOT_SUPPORTED)
  public ElevationRecompute recomputeHd(Team team, GpxDocument gpx, List<WaypointDraft> drafts) {
    return recomputeHd(team, gpx, new WaypointPlan(drafts, false));
  }

  private ElevationRecompute recomputeHd(Team team, GpxDocument gpx, WaypointPlan plan) {
    List<PreparedAsset> uploaded = new ArrayList<>(2);
    try (ComputedGpx computed = computeGpx(gpx, ElevationQuality.HD, plan)) {
      if (computed.fallbackAfterErrorKm() > 0) {
        throw new ElevationUnavailableException(
            "HD elevation unavailable for %.2f km of the track"
                .formatted(computed.fallbackAfterErrorKm()));
      }
      PreparedAsset filtered =
          prepareAndUpload(
              team,
              AssetType.ROUTE_FILTERED_GPX,
              "filtered.gpx",
              tmp -> moveInto(computed.filteredGpx(), tmp));
      uploaded.add(filtered);
      PreparedAsset fit =
          prepareAndUpload(
              team, AssetType.ROUTE_FIT, "route.fit", tmp -> moveInto(computed.fitFile(), tmp));
      uploaded.add(fit);
      return new ElevationRecompute(
          computed.aggregated(),
          computed.tracks(),
          filtered,
          fit,
          computed.waypoints(),
          plan.drafts());
    } catch (Exception e) {
      cleanupUploadedAssets(uploaded, team);
      throw e instanceof RuntimeException re ? re : new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  /** Deletes what {@link #recomputeHd} uploaded, when its result will not be written. */
  public void discardRecompute(Team team, ElevationRecompute recompute) {
    cleanupUploadedAssets(List.of(recompute.filtered(), recompute.fit()), team);
  }

  /**
   * Phase 2 of the HD catch-up, in the caller's transaction with the route locked: the existing
   * filtered GPX and FIT rows take the new files (same asset ids, so every URL is stable; new
   * content revision, so GPS sync pushes them again), the existing tracks are updated <b>in
   * place</b> — never a clear and refill of the orphan-removal collection, HHH90032003 — and the
   * route takes the HD figures.
   *
   * @return whether the distance changed, in which case the caller refreshes the ends of the
   *     rides riding the route
   * @throws IllegalStateException when the route does not have as many tracks as the recompute; the
   *     transaction is then rolled back and the new files deleted
   */
  @Transactional(Transactional.TxType.REQUIRED)
  public boolean applyRecompute(Route route, ElevationRecompute recompute) {
    // Before anything can throw, as persistGpxData does
    for (PreparedAsset pa : List.of(recompute.filtered(), recompute.fit())) {
      assetService.deleteUnlessCommitted(assetService.getAssetKey(route.getTeam(), pa.fileId()));
    }
    List<GpxTrack> tracks =
        route.getTracks().stream().sorted(Comparator.comparing(GpxTrack::getId)).toList();
    if (tracks.size() != recompute.tracks().size()) {
      throw new IllegalStateException(
          "Route %d has %d track(s), the HD recompute %d"
              .formatted(route.getId(), tracks.size(), recompute.tracks().size()));
    }
    for (PreparedAsset pa : List.of(recompute.filtered(), recompute.fit())) {
      assetService.putStoredFile(
          route.getTeam(),
          route,
          pa.type(),
          pa.fileId(),
          routeFileName(route, pa.type(), pa.fileName()),
          pa.stored(),
          true);
    }
    for (int i = 0; i < tracks.size(); i++) {
      GpxTrack track = tracks.get(i);
      ComputedTrack computed = recompute.tracks().get(i);
      track.setGeometry(computed.line());
      track.setTrackPoints(computed.trackPoints());
      track.setClimbs(computed.climbs());
      track.setDistance(computed.metadata().distance());
      track.setElevationGain(computed.metadata().elevationGain());
      track.setElevationLoss(computed.metadata().elevationLoss());
    }
    // The HD simplification may have moved the vertices: the waypoints keep their place, their
    // distance follows the new axis (docs/LEDGER_*.md WEB-100, C3c)
    WaypointRows.updateDistances(route, recompute.waypoints());
    TrackMetadata metadata = recompute.metadata();
    boolean distanceChanged = !Objects.equals(route.getDistance(), metadata.distance());
    route.setDistance(metadata.distance());
    route.setElevationGain(metadata.elevationGain());
    route.setHilliness(metadata.hilliness());
    route.setElevationLoss(metadata.elevationLoss());
    route.setElevationState(ElevationState.HD);
    return distanceChanged;
  }

  // ------------------------------------------------------------------ waypoints only

  /** A stored track, read before the transaction is suspended. */
  public record StoredTrack(String name, List<GpxTrack.TrackPoint> points) {}

  /** The filtered GPX and FIT rewritten for new waypoints, uploaded under new keys. */
  public record WaypointFiles(PreparedAsset filtered, PreparedAsset fit) {}

  /** The two serialisations of stored tracks with waypoints. */
  public record WaypointFileBytes(String filteredGpx, byte[] fit) {}

  /**
   * The filtered GPX and the FIT of stored tracks (the processed paths, as {@code track_points}
   * keep them) with {@code waypoints}. Pure: no I/O, no entity.
   */
  public static WaypointFileBytes waypointFileBytes(
      String name, List<StoredTrack> tracks, List<AnchoredWaypoint> waypoints) {
    List<io.github.glandais.engine.gpx.GpxTrack> gpxTracks = new ArrayList<>(tracks.size());
    for (StoredTrack track : tracks) {
      gpxTracks.add(
          GpxModelJvm.track(
              track.points().stream()
                  .map(p -> GpxModelJvm.trackPoint(p.lat(), p.lng(), p.ele()))
                  .toList(),
              track.name()));
    }
    List<Path> paths = GpxToPathJvm.tracksAsPaths(GpxModelJvm.document(gpxTracks, name));
    List<String> names = tracks.stream().map(StoredTrack::name).toList();
    return new WaypointFileBytes(
        GpxWriterJvm.write(paths, name, names, WaypointExports.gpx(waypoints)),
        FitExporter.toFitBytes(paths, name, WaypointExports.coursePoints(waypoints)));
  }

  /**
   * The filtered GPX and the FIT of a route whose track did not change, written again for new
   * waypoints (docs/LEDGER_*.md WEB-100, C3c): from the stored track points, which are the
   * processed paths, so neither the original, nor the thumbnails, nor the elevation state, nor
   * the planner state are touched. No transaction, no entity: like {@link #processGpxData}.
   */
  @Transactional(Transactional.TxType.NOT_SUPPORTED)
  public WaypointFiles rewriteWaypointFiles(
      Team team, String routeName, List<StoredTrack> tracks, List<AnchoredWaypoint> waypoints) {
    List<PreparedAsset> uploaded = new ArrayList<>(2);
    try {
      WaypointFileBytes content = waypointFileBytes(routeName, tracks, waypoints);
      byte[] fitBytes = content.fit();
      PreparedAsset filtered =
          prepareAndUpload(
              team,
              AssetType.ROUTE_FILTERED_GPX,
              "filtered.gpx",
              tmp ->
                  Files.writeString(tmp.toPath(), content.filteredGpx(), StandardCharsets.UTF_8));
      uploaded.add(filtered);
      PreparedAsset fit =
          prepareAndUpload(
              team, AssetType.ROUTE_FIT, "route.fit", tmp -> Files.write(tmp.toPath(), fitBytes));
      uploaded.add(fit);
      return new WaypointFiles(filtered, fit);
    } catch (Exception e) {
      cleanupUploadedAssets(uploaded, team);
      throw e instanceof RuntimeException re ? re : new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  /**
   * In the caller's transaction: the existing filtered GPX and FIT rows take the files of {@link
   * #rewriteWaypointFiles} (same asset ids, so every URL is stable; new content revision, so GPS
   * sync pushes the route again).
   */
  @Transactional(Transactional.TxType.REQUIRED)
  public void applyWaypointFiles(Route route, WaypointFiles files) {
    // Before anything can throw, as persistGpxData does
    for (PreparedAsset pa : List.of(files.filtered(), files.fit())) {
      assetService.deleteUnlessCommitted(assetService.getAssetKey(route.getTeam(), pa.fileId()));
    }
    for (PreparedAsset pa : List.of(files.filtered(), files.fit())) {
      assetService.putStoredFile(
          route.getTeam(),
          route,
          pa.type(),
          pa.fileId(),
          routeFileName(route, pa.type(), pa.fileName()),
          pa.stored(),
          true);
    }
  }

  /**
   * Deletes the S3 objects a {@link #processGpxData} call uploaded before failing: no row points at
   * them yet.
   */
  private void cleanupUploadedAssets(List<PreparedAsset> uploaded, Team team) {
    for (PreparedAsset pa : uploaded) {
      try {
        storageService.delete(assetService.getAssetKey(team, pa.fileId()));
      } catch (Exception e) {
        LOG.warnf(e, "S3 cleanup failed for fileId %s", pa.fileId());
      }
    }
  }

  /**
   * Convenience facade: runs both phases sequentially. Used by tests and by the {@code createTracks}
   * legacy call sites until they are migrated.
   */
  @Transactional
  public TrackMetadata createTracks(Route route, GpxDocument gpx) {
    GpxProcessingResult result = processGpxData(route, gpx);
    return persistGpxData(route, result);
  }

  private void generateThumbnailAsset(
      Team team,
      List<Path> paths,
      Long routeId,
      String style,
      AssetType assetType,
      String fileName,
      List<PreparedAsset> uploadedAssets) {
    if (paths.isEmpty()) {
      return;
    }
    try {
      PreparedAsset pa =
          prepareAndUpload(
              team,
              assetType,
              fileName,
              tmp -> mapThumbnailRenderer.render(tmp, paths, style, List.of(Color.RED)));
      uploadedAssets.add(pa);
      LOG.infov("Generated and saved {0} thumbnail to S3", style);
    } catch (Exception e) {
      LOG.warnv(
          "Thumbnail generation ({0}) failed for route {1}, left without one: {2}",
          style, routeId, e.getCause() != null ? e.getCause().getMessage() : e.getMessage());
    }
  }

  /**
   * Convert a path to a PostGIS LineString in WKT format.
   * Format: "LINESTRING(lng lat, lng lat, ...)"
   */
  private static LineString<G2D> toLineString(Path path) {
    G2D[] geomPoints = new G2D[path.getSize()];
    for (int i = 0; i < path.getSize(); i++) {
      geomPoints[i] = g(path.longitudeDeg(i), path.latitudeDeg(i));
    }
    return linestring(WGS84, geomPoints);
  }

  /**
   * Convert a path to simplified track points for frontend JSONB storage.
   */
  private static List<GpxTrack.TrackPoint> toTrackPoints(Path path) {
    List<GpxTrack.TrackPoint> trackPoints = new ArrayList<>(path.getSize());
    for (int i = 0; i < path.getSize(); i++) {
      trackPoints.add(
          new GpxTrack.TrackPoint(
              path.latitudeDeg(i), path.longitudeDeg(i), path.elevation(i), path.distance(i)));
    }
    return trackPoints;
  }

  /**
   * Extract route metadata from a processed path.
   */
  private static TrackMetadata extractMetadata(Path path) {
    int last = path.getSize() - 1;
    float distance = (float) path.getTotalDistance();
    // The dead-band ascent GpxPipeline measured before simplifying, bridge decks included.
    float elevationGain = (float) path.getReportedElevationGain();
    return new TrackMetadata(
        distance,
        elevationGain,
        getHilliness(distance, elevationGain),
        // Already negative, like gpx2web's getTotalElevationNegative().
        (int) Math.round(path.getReportedElevationLoss()),
        point(WGS84, g(path.longitudeDeg(0), path.latitudeDeg(0))),
        point(WGS84, g(path.longitudeDeg(last), path.latitudeDeg(last))),
        null);
  }

  private static float getHilliness(float distance, float elevationGain) {
    if (distance == 0) {
      return 0;
    }
    return (1000.0f * elevationGain) / distance;
  }

  private static final List<AssetType> ROUTE_ASSET_TYPES =
      List.of(
          AssetType.ROUTE_ORIGINAL_GPX,
          AssetType.ROUTE_FILTERED_GPX,
          AssetType.ROUTE_FIT,
          AssetType.ROUTE_THUMBNAIL_LIGHT,
          AssetType.ROUTE_THUMBNAIL_DARK);

  /**
   * Delete all files for a route (cleanup on error or deletion).
   * S3 cleanup is handled automatically by AssetRemoveListener via orphanRemoval.
   */
  public void deleteRouteFiles(Route route) {
    route.getAssets().removeIf(asset -> ROUTE_ASSET_TYPES.contains(asset.getType()));
  }

  /**
   * Get InputStream for filtered GPX download.
   */
  public InputStream getFilteredGpxContent(Route route) {
    return getAssetContent(route, AssetType.ROUTE_FILTERED_GPX);
  }

  /**
   * Get InputStream for FIT download.
   */
  public InputStream getFitContent(Route route) {
    return getAssetContent(route, AssetType.ROUTE_FIT);
  }

  private InputStream getAssetContent(Route route, AssetType assetType) {
    Asset matching = getAsset(route, assetType);
    if (matching != null) {
      return assetService.getAssetContent(matching);
    } else {
      throw new NotFoundException(EntityType.ASSET, "forRoute-" + route.getId());
    }
  }

  private @Nullable Asset getAsset(Route route, AssetType assetType) {
    Asset matching = null;
    for (Asset asset : route.getAssets()) {
      if (asset.getType() == assetType) {
        matching = asset;
      }
    }
    return matching;
  }
}
