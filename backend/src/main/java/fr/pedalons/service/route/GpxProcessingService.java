package fr.pedalons.service.route;

import static org.geolatte.geom.builder.DSL.*;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.GpxWaypoint;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.WindDirection;
import fr.pedalons.infrastructure.exception.NotFoundException;
import fr.pedalons.infrastructure.gpx.FitExporter;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.route.response.TrackMetadata;
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

  /** A single waypoint, fully computed but not yet bound to any entity. */
  public record ComputedWaypoint(String name, org.geolatte.geom.Point<G2D> location) {}

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
   */
  public record ComputedGpx(
      File originalGpx,
      File filteredGpx,
      File fitFile,
      List<ComputedTrack> tracks,
      List<ComputedWaypoint> waypoints,
      TrackMetadata aggregated)
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
   */
  public ComputedGpx computeGpx(GpxDocument source) {
    GpxDocument doc;
    try {
      doc = GpxSanitizer.sanitize(source);
    } catch (Exception e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
    // Tracks and routes alike, as GPXFileReader did: a <rte>-only file is a valid route — the
    // facade's default, which is the one thing a Java caller could not spell before g33.
    List<Path> unfiltered = GpxToPathJvm.tracksAsPaths(doc);
    String name = doc.getName();
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

    File original = null;
    File filtered = null;
    File fit = null;
    try {
      original = writeToTempFile(GpxWriterJvm.write(raw, name, trackNames), ".gpx");

      List<ComputedWaypoint> waypoints = new ArrayList<>();
      for (io.github.glandais.engine.gpx.GpxWaypoint waypoint : doc.getWaypoints()) {
        waypoints.add(
            new ComputedWaypoint(
                // Nullable in vcyclist, empty string in gpx2web, and not-null in gpx_waypoints:
                // without this fallback a <wpt> with no <name> fails the insert at flush time.
                Objects.requireNonNullElse(waypoint.getName(), ""),
                point(WGS84, g(waypoint.getLongitudeDeg(), waypoint.getLatitudeDeg()))));
      }

      List<Path> processed = new ArrayList<>(raw.size());
      for (int i = 0; i < raw.size(); i++) {
        processed.add(pipeline.process(raw.get(i), trackNames.get(i)));
      }

      filtered =
          writeToTempFile(
              GpxWriterJvm.write(processed, name, trackNames, doc.getWaypoints()), ".gpx");
      fit = writeFitToTempFile(processed, name);

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

      return new ComputedGpx(original, filtered, fit, tracks, waypoints, aggregated);
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
  private static File writeFitToTempFile(List<Path> paths, String name) throws IOException {
    byte[] bytes = FitExporter.toFitBytes(paths, name);
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
  record PreparedAsset(
      AssetType type, String fileName, long fileId, AssetService.UploadedFile stored) {}

  record GpxProcessingResult(
      TrackMetadata metadata,
      List<GpxTrack> tracks,
      List<GpxWaypoint> waypoints,
      List<PreparedAsset> uploadedAssets) {}

  /**
   * Phase 1: CPU and S3 work — runs with the caller's transaction SUSPENDED so the DB connection
   * is released during the heavy processing (elevation, file generation, 5 S3 uploads).
   *
   * <p>All entities returned are transient (not yet attached to Hibernate session).
   */
  @Transactional(Transactional.TxType.NOT_SUPPORTED)
  public GpxProcessingResult processGpxData(Route route, GpxDocument gpx) {
    User creator = pedalonsContext.getUser();
    Long routeId = route.getId();
    Team team = route.getTeam();
    try (ComputedGpx computed = computeGpx(gpx)) {
      List<PreparedAsset> uploadedAssets = new ArrayList<>();

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

      List<GpxWaypoint> waypoints =
          computed.waypoints().stream()
              .map(w -> new GpxWaypoint(creator, w.name(), w.location()))
              .toList();

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

      return new GpxProcessingResult(computed.aggregated(), tracks, waypoints, uploadedAssets);
    } catch (PedalonsException e) {
      throw e;
    } catch (Exception e) {
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
    route.getAssets().removeIf(a -> ROUTE_ASSET_TYPES.contains(a.getType()));

    for (PreparedAsset pa : result.uploadedAssets()) {
      assetService.persistAsset(
          route.getTeam(), route, pa.type(), pa.fileId(), pa.fileName(), pa.stored());
    }

    result.waypoints().forEach(route::addWaypoint);
    result.tracks().forEach(route::addTrack);

    return result.metadata();
  }

  /**
   * Cleans up S3 objects from a partially completed {@link #processGpxData} call. Call this in
   * error handlers when the DB persist phase has not yet run (assets not in DB yet).
   */
  public void cleanupUploadedAssets(GpxProcessingResult result, Team team) {
    for (PreparedAsset pa : result.uploadedAssets()) {
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
    float elevationGain = (float) path.getElevationGain();
    return new TrackMetadata(
        distance,
        elevationGain,
        getHilliness(distance, elevationGain),
        // Already negative, like gpx2web's getTotalElevationNegative().
        (int) Math.round(path.getElevationLoss()),
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
