package fr.pedalons.service.route;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.GpxWaypoint;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.gpx.response.GpxPreviewDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.dto.tags.response.TagDto;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.gpx.GpxPreviewService;
import fr.pedalons.service.route.waypoint.WaypointDraft;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.tag.TagLookup;
import fr.pedalons.service.team.TeamService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Copies of a route (docs/LEDGER_*.md API-178, API-179): a duplicate in its own team, or a GPX
 * preview of the caller's.
 *
 * <p>Neither copies a row. Both replay the creation they stand for — {@link
 * RouteService#createRoute} or {@link GpxPreviewService#createFromRoute} — on the route's original
 * GPX, with its planner state, its surfaces and its waypoints, so slug, statistics, thumbnails, GPX
 * and FIT files and the HD catch-up are those of any new route or preview. Comments, rides and
 * statistics of the source are not touched.
 */
@ApplicationScoped
public class RouteCopyService {

  private static final Logger LOG = Logger.getLogger(RouteCopyService.class);

  @Inject RouteService routeService;

  @Inject GpxPreviewService gpxPreviewService;

  @Inject TeamService teamService;

  @Inject AssetService assetService;

  @Inject AssetRepository assetRepository;

  @Inject GpxTrackRepository gpxTrackRepository;

  @Inject StorageService storageService;

  @Inject TagLookup tagLookup;

  /** What a copy takes from its source, read in one transaction. */
  private record Source(
      String name,
      long teamId,
      long originalFileId,
      @Nullable PlannerState state,
      List<@Nullable TrackSurfaceDocument> surfaces,
      List<WaypointDraft> waypoints) {}

  /**
   * A copy of the route in its own team, named {@code name}, with every other attribute of the
   * source: visibility, surface type, tags, markdown, and a copy of its logo, images and
   * attachments ({@link AssetService#copyMedia}). Requires the right to edit the source — an
   * organizer of the team, routes on — and {@link RouteService#createRoute} checks the right to
   * create one.
   */
  @Transactional
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.UPDATE)
  public RouteDto duplicate(String teamSlug, String routeSlug, String name) {
    Team team = teamService.getTeam(teamSlug);
    Route route = routeService.findBySlug(team, routeSlug);
    Source source = readSource(route);
    List<String> tagIds =
        tagLookup.forContents(List.of(route.getId())).forContent(route.getId()).stream()
            .map(TagDto::id)
            .toList();
    MediaDto media = assetService.copyMedia(route, team);
    RouteRequest request =
        new RouteRequest(
            name, media, route.getSurfaceType(), route.getVisibility(), null, tagIds, null, null);
    Path gpxPath = downloadOriginal(source);
    try {
      return routeService.createRoute(
          teamSlug, request, gpxPath, source.state(), source.surfaces(), source.waypoints());
    } finally {
      deleteQuietly(gpxPath);
    }
  }

  /**
   * A GPX preview of the route, for a signed-in caller who may read it (docs/LEDGER_*.md API-179):
   * same title, track, planner state and waypoints. The preview is the caller's; nothing is created
   * in the team. Deliberately not {@code @Transactional}, like every preview creation: the source
   * is read in a short transaction of its own, the pipeline runs with no connection held.
   */
  @Logged
  @CheckAccess(entityType = EntityType.ROUTE, action = ActionType.READ)
  public GpxPreviewDto createPreview(String teamSlug, String routeSlug) {
    Source source =
        QuarkusTransaction.requiringNew()
            .call(() ->
                readSource(routeService.findBySlug(teamService.getTeam(teamSlug), routeSlug)));
    Path gpxPath = downloadOriginal(source);
    try {
      return gpxPreviewService.createFromRoute(
          gpxPath, source.name(), source.state(), source.waypoints());
    } finally {
      deleteQuietly(gpxPath);
    }
  }

  /**
   * The source of a copy: the current original GPX, the planner state when it still describes the
   * track, the surface of each track (track id order, the order the copy's tracks are saved in) and
   * the waypoints. Four queries whatever the route.
   */
  private Source readSource(Route route) {
    Long originalFileId =
        assetRepository.findCurrentFileId(route.getId(), AssetType.ROUTE_ORIGINAL_GPX);
    if (originalFileId == null) {
      // A route without a stored track (legacy data): nothing to replay.
      throw new BusinessException(ErrorCode.GPX_EMPTY);
    }
    PlannerState state = routeService.readPlannerState(route);
    Map<Long, TrackSurfaceDocument> byTrack = gpxTrackRepository.findSurfaces(route.getId());
    List<@Nullable TrackSurfaceDocument> surfaces = new ArrayList<>();
    route.getTracks().stream()
        .map(GpxTrack::getId)
        .sorted()
        .forEach(id -> surfaces.add(byTrack.get(id)));
    List<WaypointDraft> waypoints =
        route.getWaypoints().stream()
            .sorted(Comparator.comparing(GpxWaypoint::getId))
            .map(RouteCopyService::draftOf)
            .toList();
    return new Source(
        route.getName(), route.getTeam().getId(), originalFileId, state, surfaces, waypoints);
  }

  /**
   * A stored waypoint as a new one of the copy: no id (the row stays the source's), its origin and
   * its distance kept, placed again on the copy's track — the same one.
   */
  private static WaypointDraft draftOf(GpxWaypoint row) {
    return new WaypointDraft(
        null,
        row.getGeometry().getPosition().getLat(),
        row.getGeometry().getPosition().getLon(),
        row.getName(),
        row.getDescription(),
        row.typeOrInfo(),
        row.getOrigin(),
        row.getDistanceM(),
        null);
  }

  /** The source's original GPX in a temp file the caller deletes. */
  private Path downloadOriginal(Source source) {
    String key = assetService.getAssetKey(source.teamId(), source.originalFileId());
    try {
      Path temp = Files.createTempFile("route-copy-", ".gpx");
      try (InputStream in = storageService.retrieve(key)) {
        Files.copy(in, temp, StandardCopyOption.REPLACE_EXISTING);
      } catch (IOException | RuntimeException e) {
        deleteQuietly(temp);
        throw e;
      }
      return temp;
    } catch (IOException e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  private static void deleteQuietly(Path path) {
    try {
      Files.deleteIfExists(path);
    } catch (IOException e) {
      LOG.warnf(e, "Failed to delete temp GPX %s", path);
    }
  }
}
