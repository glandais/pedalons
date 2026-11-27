package fr.pedalons.service.thumbnail;

import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.enums.AssetType;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.thumbnail.ThumbnailBackfillRepository;
import fr.pedalons.service.asset.AssetService;
import io.github.glandais.elevation.CoordinatesElevation;
import io.github.glandais.elevation.LatLonElevation;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathJvm;
import io.hypersistence.tsid.TSID;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.awt.Color;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import org.jboss.logging.Logger;

@ApplicationScoped
public class ThumbnailService {

  private static final Logger LOG = Logger.getLogger(ThumbnailService.class);

  private static final List<Color> ROUTE_COLORS =
      List.of(
          Color.decode("#566B13"),
          Color.decode("#1d32a8"),
          Color.decode("#732C7B"),
          Color.decode("#bdbd22"),
          Color.decode("#c90808"),
          Color.decode("#b81491"),
          Color.decode("#628de3"),
          Color.decode("#6dcc5c"),
          Color.decode("#c694d4"),
          Color.decode("#e3a209"));

  /** A route's own thumbnail draws every track in red, as {@code GpxProcessingService} does. */
  static final List<Color> ROUTE_TRACK_COLORS = List.of(Color.RED);

  @Inject MapThumbnailRenderer renderer;

  @Inject AssetService assetService;

  @Inject StorageService storageService;

  @Inject ThumbnailBackfillRepository backfillRepository;

  /**
   * What a ride's thumbnails are drawn from: its routes in drawing order, each with its tracks. A
   * track is never edited in place — a new GPX replaces the route's tracks with new rows — so their
   * ids change exactly when the geometry does. Read it before an edit, hand it to {@link
   * #refreshRideThumbnails} after.
   */
  public static List<List<Long>> rideInput(Ride ride) {
    return input(collectRideRoutes(ride));
  }

  /** {@link #rideInput} for a trip: its own route, then its live stages' in order. */
  public static List<List<Long>> tripInput(Trip trip) {
    return input(collectTripRoutes(trip));
  }

  /**
   * Redraws a ride's thumbnails only when what they are drawn from changed since {@code before}
   * ({@link #rideInput}), or when they are missing — a render that failed last time is retried. A
   * migration replay rewrites every ride with the same routes: drawing them again each time was its
   * last cost (docs/LEDGER_*.md MIG-4).
   */
  public void refreshRideThumbnails(Ride ride, List<List<Long>> before) {
    if (unchanged(ride, before, rideInput(ride), RIDE_TYPES)) {
      return;
    }
    generateRideThumbnails(ride);
  }

  /** {@link #refreshRideThumbnails} for a trip. */
  public void refreshTripThumbnails(Trip trip, List<List<Long>> before) {
    if (unchanged(trip, before, tripInput(trip), TRIP_TYPES)) {
      return;
    }
    generateTripThumbnails(trip);
  }

  private static final Set<AssetType> RIDE_TYPES =
      Set.of(AssetType.RIDE_THUMBNAIL_LIGHT, AssetType.RIDE_THUMBNAIL_DARK);
  private static final Set<AssetType> TRIP_TYPES =
      Set.of(AssetType.TRIP_THUMBNAIL_LIGHT, AssetType.TRIP_THUMBNAIL_DARK);
  private static final Set<AssetType> THUMBNAIL_TYPES =
      EnumSet.of(
          AssetType.ROUTE_THUMBNAIL_LIGHT,
          AssetType.ROUTE_THUMBNAIL_DARK,
          AssetType.RIDE_THUMBNAIL_LIGHT,
          AssetType.RIDE_THUMBNAIL_DARK,
          AssetType.TRIP_THUMBNAIL_LIGHT,
          AssetType.TRIP_THUMBNAIL_DARK);

  private static boolean unchanged(
      TeamEntity entity, List<List<Long>> before, List<List<Long>> after, Set<AssetType> types) {
    if (!before.equals(after)) {
      return false;
    }
    // No route, nothing to draw — as generateThumbnails itself decides.
    if (after.isEmpty()) {
      return true;
    }
    Set<AssetType> present = new HashSet<>();
    for (var asset : entity.getAssets()) {
      present.add(asset.getType());
    }
    return present.containsAll(types);
  }

  private static List<List<Long>> input(List<Route> routes) {
    List<List<Long>> input = new ArrayList<>();
    for (Route route : routes) {
      List<Long> ids = new ArrayList<>();
      ids.add(route.getId());
      route.getTracks().stream().map(GpxTrack::getId).sorted().forEach(ids::add);
      input.add(ids);
    }
    return input;
  }

  public void generateRideThumbnails(Ride ride) {
    draw(ride, false);
  }

  public void generateTripThumbnails(Trip trip) {
    draw(trip, false);
  }

  /**
   * Redraws a route's thumbnails from the track geometry already in the database — the GPX import
   * draws them from the parsed file ({@code GpxProcessingService}), this is for fixing them later.
   */
  public void generateRouteThumbnails(Route route) {
    draw(route, false);
  }

  /**
   * Redraws the thumbnails of a route, a ride or a trip from the geometry in the database, the way
   * the admin regeneration wants it: a failed render leaves the entity without that thumbnail. A
   * success stamps the entity with {@link MapThumbnailRenderer#VERSION}.
   *
   * @return whether both thumbnails were drawn (or there was nothing to draw)
   */
  public boolean redraw(TeamEntity owner) {
    return redraw(owner, false);
  }

  /**
   * As {@link #redraw}, for the catch-up of the fleet ({@code ThumbnailBackfill}): a failure must
   * <b>keep</b> the existing thumbnails, a restyle being no reason to lose a good one (and a
   * tileserver outage must not wipe the fleet's). Both files are drawn and uploaded first; only
   * when both made it are they stored, otherwise nothing is touched. With nothing to draw the
   * existing thumbnails stay too.
   *
   * @return whether the entity is up to date: false when a render or an upload failed
   */
  public boolean redrawKeepingOnFailure(TeamEntity owner) {
    return redraw(owner, true);
  }

  private boolean redraw(TeamEntity owner, boolean keepOnFailure) {
    boolean drawn = draw(owner, keepOnFailure);
    // Drawn on the admin's request or by a job, but the entity's own thumbnail: keep the admin,
    // possibly from another domain, out of its creator's data export
    owner.getAssets().stream()
        .filter(a -> THUMBNAIL_TYPES.contains(a.getType()))
        .forEach(a -> a.setCreatedBy(owner.getCreatedBy()));
    return drawn;
  }

  private boolean draw(TeamEntity owner, boolean keepOnFailure) {
    return switch (owner) {
      case Route route ->
          generateThumbnails(
              route,
              List.of(route),
              AssetType.ROUTE_THUMBNAIL_LIGHT,
              AssetType.ROUTE_THUMBNAIL_DARK,
              ROUTE_TRACK_COLORS,
              keepOnFailure);
      case Ride ride ->
          generateThumbnails(
              ride,
              collectRideRoutes(ride),
              AssetType.RIDE_THUMBNAIL_LIGHT,
              AssetType.RIDE_THUMBNAIL_DARK,
              ROUTE_COLORS,
              keepOnFailure);
      case Trip trip ->
          generateThumbnails(
              trip,
              collectTripRoutes(trip),
              AssetType.TRIP_THUMBNAIL_LIGHT,
              AssetType.TRIP_THUMBNAIL_DARK,
              ROUTE_COLORS,
              keepOnFailure);
      default ->
          throw new IllegalArgumentException(
              "No thumbnail on " + owner.getClass().getSimpleName() + " " + owner.getId());
    };
  }

  private static List<Route> collectRideRoutes(Ride ride) {
    LinkedHashSet<Long> seenIds = new LinkedHashSet<>();
    List<Route> routes = new ArrayList<>();

    if (ride.getRoute() != null) {
      seenIds.add(ride.getRoute().getId());
      routes.add(ride.getRoute());
    }

    ride.getGroups().stream()
        .sorted(Comparator.comparing(RideGroup::getSortOrder))
        .map(RideGroup::getRoute)
        .filter(r -> r != null && seenIds.add(r.getId()))
        .forEach(routes::add);

    return routes;
  }

  private static List<Route> collectTripRoutes(Trip trip) {
    LinkedHashSet<Long> seenIds = new LinkedHashSet<>();
    List<Route> routes = new ArrayList<>();

    if (trip.getRoute() != null) {
      seenIds.add(trip.getRoute().getId());
      routes.add(trip.getRoute());
    }

    trip.getStages().stream()
        .filter(s -> !s.isDeleted())
        .sorted(Comparator.comparing(TripStage::getSortOrder))
        .map(TripStage::getRoute)
        .filter(r -> r != null && seenIds.add(r.getId()))
        .forEach(routes::add);

    return routes;
  }

  private boolean generateThumbnails(
      TeamEntity entity,
      List<Route> routes,
      AssetType lightType,
      AssetType darkType,
      List<Color> colors,
      boolean keepOnFailure) {
    if (routes.isEmpty()) {
      // Nothing to draw, nothing left to redraw
      stamp(entity);
      return true;
    }

    // Build combined GPX with one path per route track
    List<ThumbnailTrack> tracks = new ArrayList<>();
    for (Route route : routes) {
      for (GpxTrack track : route.getTracks()) {
        tracks.add(new ThumbnailTrack(track.getName(), track.getTrackPoints()));
      }
    }

    List<Path> paths = buildPaths(tracks);
    if (paths.isEmpty()) {
      if (!keepOnFailure) {
        // One that no longer matches the routes is worse than none, which the clients replace with
        // their own placeholder
        removeExistingThumbnails(entity, lightType, darkType);
      }
      stamp(entity);
      return true;
    }

    boolean drawn;
    if (keepOnFailure) {
      drawn = generateThumbnailPair(entity, paths, colors, lightType, darkType);
    } else {
      boolean light =
          generateThumbnail(
              entity,
              paths,
              MapThumbnailRenderer.LIGHT_STYLE,
              colors,
              lightType,
              "thumbnail-light.png");
      boolean dark =
          generateThumbnail(
              entity,
              paths,
              MapThumbnailRenderer.DARK_STYLE,
              colors,
              darkType,
              "thumbnail-dark.png");
      drawn = light && dark;
    }
    if (drawn) {
      stamp(entity);
    }
    return drawn;
  }

  /**
   * Records that the entity's thumbnails are drawn with the current version, by a native update
   * (the entity's own version is not bumped). Not for an entity not persisted yet.
   */
  private void stamp(TeamEntity entity) {
    if (entity.getId() != null) {
      backfillRepository.stamp(entity.getId());
    }
  }

  /** Track geometry reduced to what the map renderer needs — decoupled from {@code Asset}/team. */
  public record ThumbnailTrack(String name, List<GpxTrack.TrackPoint> points) {}

  /**
   * Renders track geometry to a light-style map PNG at {@code output}, the same way ride/route
   * thumbnails are drawn, but to a plain file instead of an {@code Asset}. GPX previews have no team
   * and therefore no asset to hang a thumbnail on, so they render straight to storage. Returns
   * {@code false} (leaving no usable file) when there is nothing to draw or rendering fails —
   * callers treat a thumbnail as best-effort.
   */
  public boolean renderLightThumbnail(File output, List<ThumbnailTrack> tracks) {
    List<Path> paths = buildPaths(tracks);
    if (paths.isEmpty()) {
      return false;
    }
    try {
      renderer.render(output, paths, MapThumbnailRenderer.LIGHT_STYLE, ROUTE_COLORS);
      return true;
    } catch (Exception e) {
      LOG.warnv("Preview thumbnail generation failed: {0}", e.getMessage());
      return false;
    }
  }

  /**
   * Rebuilds renderable geometry from stored track points. {@code public} so {@code
   * GpxProcessingService} draws its route thumbnails from exactly the same geometry the rest of the
   * app renders, instead of maintaining a second conversion.
   */
  public static List<Path> buildPaths(List<ThumbnailTrack> tracks) {
    List<Path> paths = new ArrayList<>();
    for (ThumbnailTrack track : tracks) {
      List<CoordinatesElevation> coordinates = new ArrayList<>(track.points().size());
      for (GpxTrack.TrackPoint tp : track.points()) {
        coordinates.add(new LatLonElevation(tp.lat(), tp.lng(), tp.ele()));
      }
      if (coordinates.isEmpty()) {
        continue;
      }
      paths.add(PathJvm.fromCoordinates(coordinates));
    }
    return paths;
  }

  /**
   * Draws first, and only then touches the asset: a failed render leaves the entity without this
   * thumbnail rather than with an asset whose file is missing or wrong. The asset row of a previous
   * thumbnail is kept and given the new file, so the URLs already published stay valid
   * (docs/LEDGER_*.md API-128). Runs in the caller's transaction: {@code replaceStoredFile} cleans
   * the files up according to its outcome.
   */
  private boolean generateThumbnail(
      TeamEntity entity,
      List<Path> paths,
      String style,
      List<Color> colors,
      AssetType assetType,
      String fileName) {
    File rendered = null;
    File temp = null;
    long fileId = TSID.Factory.getTsid().toLong();
    AssetService.UploadedFile stored;
    try {
      rendered = File.createTempFile("thumbnail-", ".png");
      renderer.render(rendered, paths, style, colors);
      temp = assetService.createTempFile(fileId);
      Files.move(rendered.toPath(), temp.toPath(), StandardCopyOption.REPLACE_EXISTING);
      stored = assetService.uploadTempFileToS3(entity.getTeam(), assetType, fileId, fileName);
    } catch (Exception e) {
      LOG.warnv(
          "Thumbnail generation ({0}) failed for {1} {2}, left without one: {3}",
          style, entity.getClass().getSimpleName(), entity.getId(), e.getMessage());
      // A missing thumbnail beats a wrong one
      assetService.removeAssetsOfTypes(entity, List.of(assetType));
      return false;
    } finally {
      if (rendered != null) {
        rendered.delete();
      }
      // Still there only when the upload did not complete (or does not delete it itself).
      if (temp != null) {
        temp.delete();
      }
    }
    assetService.putStoredFile(
        entity.getTeam(), entity, assetType, fileId, fileName, stored, false);
    LOG.infov(
        "Generated {0} thumbnail for {1} {2}",
        style, entity.getClass().getSimpleName(), entity.getId());
    return true;
  }

  /** A thumbnail drawn and uploaded, waiting to become the file of its asset row. */
  private record Uploaded(
      AssetType type, long fileId, String fileName, AssetService.UploadedFile stored) {}

  /**
   * Both thumbnails of the catch-up, light and dark: drawn and uploaded first, stored only when
   * both made it, so a failure leaves the asset rows and their files exactly as they were (the
   * files already uploaded are deleted). Same transaction rules as {@link #generateThumbnail}.
   */
  private boolean generateThumbnailPair(
      TeamEntity entity,
      List<Path> paths,
      List<Color> colors,
      AssetType lightType,
      AssetType darkType) {
    String owner = entity.getClass().getSimpleName() + " " + entity.getId();
    File light = null;
    File dark = null;
    List<Uploaded> uploaded = new ArrayList<>();
    try {
      light = File.createTempFile("thumbnail-", ".png");
      renderer.render(light, paths, MapThumbnailRenderer.LIGHT_STYLE, colors);
      dark = File.createTempFile("thumbnail-", ".png");
      renderer.render(dark, paths, MapThumbnailRenderer.DARK_STYLE, colors);
      uploaded.add(upload(entity, light, lightType, "thumbnail-light.png"));
      uploaded.add(upload(entity, dark, darkType, "thumbnail-dark.png"));
    } catch (Exception e) {
      LOG.warnv("Thumbnail redraw failed for {0}, kept as they were: {1}", owner, e.getMessage());
      for (Uploaded u : uploaded) {
        try {
          storageService.delete(assetService.getAssetKey(entity.getTeam(), u.fileId()));
        } catch (RuntimeException cleanup) {
          LOG.warnv(
              "Cleanup of an unused thumbnail failed for {0}: {1}", owner, cleanup.getMessage());
        }
      }
      return false;
    } finally {
      if (light != null) {
        light.delete();
      }
      if (dark != null) {
        dark.delete();
      }
    }
    // Both files are in the bucket: from here, a rollback (the transaction timing out, a store that
    // throws) must take both away, not only the one being stored
    for (Uploaded u : uploaded) {
      assetService.deleteUnlessCommitted(assetService.getAssetKey(entity.getTeam(), u.fileId()));
    }
    for (Uploaded u : uploaded) {
      assetService.putStoredFile(
          entity.getTeam(), entity, u.type(), u.fileId(), u.fileName(), u.stored(), false);
    }
    LOG.infov("Redrawn thumbnails of {0}", owner);
    return true;
  }

  private Uploaded upload(TeamEntity entity, File rendered, AssetType type, String fileName)
      throws Exception {
    long fileId = TSID.Factory.getTsid().toLong();
    File temp = assetService.createTempFile(fileId);
    try {
      Files.move(rendered.toPath(), temp.toPath(), StandardCopyOption.REPLACE_EXISTING);
      return new Uploaded(
          type,
          fileId,
          fileName,
          assetService.uploadTempFileToS3(entity.getTeam(), type, fileId, fileName));
    } finally {
      // Still there only when the upload did not complete
      temp.delete();
    }
  }

  private void removeExistingThumbnails(
      TeamEntity entity, AssetType lightType, AssetType darkType) {
    assetService.removeAssetsOfTypes(entity, List.of(lightType, darkType));
  }
}
