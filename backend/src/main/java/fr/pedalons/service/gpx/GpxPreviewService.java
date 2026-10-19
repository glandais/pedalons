package fr.pedalons.service.gpx;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.GpxPreview.PreviewTrack;
import fr.pedalons.domain.gpx.GpxPreview.PreviewWaypoint;
import fr.pedalons.domain.gpx.PreviewSurfacesDocument;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.route.PlannerStateDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.gps.response.RouteUploadResponse;
import fr.pedalons.dto.gpx.response.GpxPreviewDto;
import fr.pedalons.dto.gpx.response.GpxPreviewListResponse;
import fr.pedalons.dto.gpx.response.GpxPreviewSummaryDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.PlannerStateResponse;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.infrastructure.imgproxy.ImgProxyService;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.elevation.ElevationRefreshService;
import fr.pedalons.service.gps.GpsService;
import fr.pedalons.service.route.GpxLimits;
import fr.pedalons.service.route.GpxProcessingService;
import fr.pedalons.service.route.GpxProcessingService.ComputedGpx;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.route.planner.PlannerStates;
import fr.pedalons.service.route.response.TrackMetadata;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.SecurityVerifier;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.security.annotation.Public;
import fr.pedalons.service.surface.SurfaceRefreshService;
import fr.pedalons.service.surface.TrackSurfaceReadout;
import fr.pedalons.service.team.TeamService;
import fr.pedalons.service.thumbnail.ThumbnailService;
import io.github.glandais.engine.gpx.GpxDocument;
import io.hypersistence.tsid.TSID;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.LockModeType;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.core.Response;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;

/**
 * GPX previews: files uploaded through the GPX tools page, analysed and rendered without ever
 * becoming a {@code Route}.
 *
 * <p>Files live in S3 under {@code gpx-previews/{publicId}/}, written through {@link
 * StorageService} rather than {@code AssetService} — an {@code Asset} requires a team, and a
 * preview has none. Those keys carry no domain prefix, so <b>every</b> access must resolve the
 * preview through {@link GpxPreviewRepository#findByPublicId} first: that domain-filtered lookup is
 * the only thing standing between a leaked identifier and a cross-tenant read.
 *
 * <p>The three track files (original GPX, filtered GPX, FIT) live under {@code
 * gpx-previews/{publicId}/{filesRevision}/}: every save of the track writes a <b>new</b> revision,
 * switched in the final transaction, and the old one is deleted after commit, so the HD catch-up
 * ({@code ElevationRefreshService}, docs/LEDGER_*.md API-131) can tell whether the track it read is
 * still the current one. A {@code null} {@link GpxPreview#getFilesRevision()} is the flat layout
 * ({@code gpx-previews/{publicId}/original.gpx}) of the previews that predate it; <b>every</b> key
 * of a track file goes through {@link #trackKey} to honour both. The thumbnail stays flat.
 */
@ApplicationScoped
public class GpxPreviewService {

  private static final Logger LOG = Logger.getLogger(GpxPreviewService.class);

  private static final String KEY_PREFIX = "gpx-previews/";
  private static final String ORIGINAL_GPX = "original.gpx";
  private static final String FILTERED_GPX = "filtered.gpx";
  private static final String FIT = "route.fit";
  private static final String THUMBNAIL_LIGHT = "thumbnail-light.png";
  private static final List<String> TRACK_FILES = List.of(ORIGINAL_GPX, FILTERED_GPX, FIT);
  private static final String GPX_CONTENT_TYPE = "application/gpx+xml";
  private static final String FIT_CONTENT_TYPE = "application/vnd.ant.fit";
  private static final String PNG_CONTENT_TYPE = "image/png";

  /** Previews are throwaway artifacts; keep them for a month, like biketeam's /gpxtool. */
  public static final int RETENTION_DAYS = 30;

  @Inject GpxProcessingService gpxProcessingService;

  @Inject GpxPreviewRepository gpxPreviewRepository;

  @Inject StorageService storageService;

  @Inject GpsService gpsService;

  @Inject RouteService routeService;

  @Inject TeamService teamService;

  @Inject SecurityVerifier securityVerifier;

  @Inject ThumbnailService thumbnailService;

  @Inject ImgProxyService imgProxyService;

  @Inject PedalonsQueryContext pedalonsContext;

  @Inject ElevationRefreshService elevationRefreshService;

  @Inject AssetService assetService;

  @Inject PlannerStates plannerStates;

  @Inject SurfaceRefreshService surfaceRefreshService;

  /**
   * Parses and analyses an uploaded GPX file, stores it, and returns the persisted preview.
   *
   * <p>Deliberately not {@code @Transactional}: the pipeline (elevation, Douglas-Peucker, climb
   * detection) and the two S3 uploads run with no DB connection held, and only the final insert
   * opens a transaction.
   */
  public GpxPreview create(Path gpxPath, String fallbackName) {
    return create(gpxProcessingService.parseGpx(gpxPath), fallbackName);
  }

  /**
   * Shared core: analyses an already-parsed {@link GpxDocument} (from an uploaded file or from
   * planner points), stores it, and returns the persisted preview. See {@link #create(Path,
   * String)} for why this is deliberately not {@code @Transactional}.
   */
  public GpxPreview create(GpxDocument gpx, String fallbackName) {
    return create(gpx, fallbackName, false);
  }

  /**
   * As {@link #create(GpxDocument, String)}, recording whether the track was {@code drawn} in the
   * planner (true) or comes from an imported file (false).
   */
  public GpxPreview create(GpxDocument gpx, String fallbackName, boolean drawn) {
    return create(gpx, fallbackName, drawn, null);
  }

  /**
   * As {@link #create(GpxDocument, String, boolean)}, also keeping the planner {@code state} the
   * track was derived from, for the edit page to read back (docs/LEDGER_*.md WEB-100, C4a).
   */
  public GpxPreview create(
      GpxDocument gpx, String fallbackName, boolean drawn, @Nullable PlannerState state) {
    User creator = pedalonsContext.getUser();
    Domain domain = pedalonsContext.getDomain();
    UUID publicId = UUID.randomUUID();
    long revision = newRevision();
    ElevationQuality quality = elevationRefreshService.saveQuality();

    List<PreviewTrack> tracks;
    List<PreviewWaypoint> waypoints;
    TrackMetadata metadata;
    try (ComputedGpx computed = gpxProcessingService.computeGpx(gpx, quality)) {
      uploadTrackFiles(
          publicId, revision, computed.originalGpx(), computed.filteredGpx(), computed.fitFile());

      tracks = toPreviewTracks(computed);
      waypoints = toPreviewWaypoints(computed);
      metadata = computed.aggregated();
    } catch (IOException e) {
      deleteFiles(publicId, revision);
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    } catch (RuntimeException e) {
      deleteFiles(publicId, revision);
      throw e;
    }

    String name = documentName(gpx, fallbackName);
    GpxPreview preview =
        new GpxPreview(
            publicId,
            domain,
            creator,
            truncateName(name),
            metadata.distance(),
            metadata.elevationGain(),
            metadata.elevationLoss(),
            metadata.hilliness(),
            tracks,
            waypoints);
    preview.setHasThumbnail(renderAndUploadThumbnail(publicId, tracks));
    preview.setDrawn(drawn);
    preview.setFilesRevision(revision);
    preview.setElevationState(stateOf(quality));
    if (state != null) {
      preview.setPlannerState(new PlannerStateDocument(revision, state));
    }

    try {
      QuarkusTransaction.requiringNew()
          .run(
              () -> {
                gpxPreviewRepository.persist(preview);
                if (quality == ElevationQuality.FAST || surfaceRefreshService.isEnabled()) {
                  // The row first: the requests point at it
                  gpxPreviewRepository.flush();
                }
                if (quality == ElevationQuality.FAST) {
                  elevationRefreshService.requestPreview(preview.getId(), revision);
                }
                surfaceRefreshService.requestPreview(preview.getId(), revision);
              });
    } catch (RuntimeException e) {
      deleteFiles(publicId, revision);
      throw e;
    }
    LOG.infov("Created GPX preview {0}", publicId);
    return preview;
  }

  /** Analyses an uploaded GPX file. Entry point for the API layer. */
  @Logged
  public GpxPreviewDto createPreview(Path gpxPath, String fallbackName) {
    return toDtoJustSaved(create(gpxPath, fallbackName));
  }

  /**
   * Merges several uploaded GPX files into one track ({@link GpxTrackMerger}: the order and
   * direction of the tracks minimising the gaps between them), then runs the same pipeline as a
   * single upload. Entry point for the API layer (docs/LEDGER_*.md API-112).
   *
   * <p>Each file is parsed — and bounded like a single upload — in turn; the distance bound is
   * checked again on the merged track, gaps included, before the pipeline resamples it. Named after
   * the files' own names (or their file names) joined by « + »: the member renames it afterwards.
   *
   * @param gpxPaths the uploaded files, in upload order
   * @param fileNames their client-side names, same order (an entry may be null)
   */
  @Logged
  public GpxPreviewDto createMergedPreview(List<Path> gpxPaths, List<@Nullable String> fileNames) {
    if (gpxPaths.size() < GpxLimits.MIN_MERGE_FILES
        || gpxPaths.size() > GpxLimits.MAX_MERGE_FILES) {
      throw new BusinessException(ErrorCode.GPX_MERGE_FILE_COUNT);
    }
    List<GpxDocument> docs = new ArrayList<>();
    List<String> names = new ArrayList<>();
    for (int i = 0; i < gpxPaths.size(); i++) {
      GpxDocument doc = gpxProcessingService.parseGpx(gpxPaths.get(i));
      docs.add(doc);
      names.add(documentName(doc, baseName(i < fileNames.size() ? fileNames.get(i) : null)));
    }
    String name = truncateName(String.join(" + ", names));
    GpxDocument merged = GpxTrackMerger.merge(docs, name);
    GpxLimits.checkTracks(merged);
    return toDtoJustSaved(create(merged, name));
  }

  /** A client-side file name without its {@code .gpx} extension, or "GPX" when there is none. */
  private static String baseName(@Nullable String fileName) {
    if (fileName == null || fileName.isBlank()) {
      return "GPX";
    }
    String trimmed = fileName.strip();
    return trimmed.toLowerCase(Locale.ROOT).endsWith(".gpx") && trimmed.length() > 4
        ? trimmed.substring(0, trimmed.length() - 4)
        : trimmed;
  }

  /**
   * Builds a preview from scratch from planner points (routing already done on the frontend), then
   * runs the same elevation/climb pipeline as an uploaded file. Entry point for the API layer.
   */
  @Logged
  public GpxPreviewDto createPreviewFromPoints(String name, List<GeoPoint> points) {
    return createPreviewFromPoints(name, points, null);
  }

  /**
   * As {@link #createPreviewFromPoints(String, List)}, from the planner state instead of points:
   * the track is derived from the state, which is kept for the edit page (docs/LEDGER_*.md WEB-100,
   * C4a). Points and a state together are refused, and so is neither.
   */
  @Logged
  public GpxPreviewDto createPreviewFromPoints(
      String name, @Nullable List<GeoPoint> points, @Nullable PlannerState plannerState) {
    boolean hasPoints = points != null && !points.isEmpty();
    if (hasPoints && plannerState != null) {
      throw new BusinessException(ErrorCode.PLANNER_STATE_INVALID);
    }
    if (!hasPoints && plannerState == null) {
      throw new BusinessException(ErrorCode.GPX_EMPTY);
    }
    checkPlannerAllowed();
    if (plannerState == null) {
      return toDtoJustSaved(create(gpxProcessingService.fromPoints(name, points), name, true));
    }
    GpxDocument gpx =
        gpxProcessingService.fromPoints(name, plannerStates.validateAndDerive(plannerState));
    return toDtoJustSaved(create(gpx, name, plannerState.drawn(), plannerState));
  }

  /**
   * Refuse a drawn track when the domain's planner is closed. Uploading a {@code .gpx} to the tools,
   * reading and exporting stay open — the flag governs drawing only.
   */
  private void checkPlannerAllowed() {
    if (!pedalonsContext.getDomain().isEnableGpxPlanner()) {
      throw new BusinessException(ErrorCode.ROUTE_PLANNER_DISABLED);
    }
  }

  /**
   * The file's own name — metadata, then first track ({@link GpxProcessingService#documentName}) —
   * else the caller's fallback, the client-side file name.
   */
  private static String documentName(GpxDocument gpx, String fallbackName) {
    String name = GpxProcessingService.documentName(gpx);
    return name != null ? name : fallbackName;
  }

  /**
   * Renames a preview and, when a new GPX file or planner points are supplied, replays the full
   * pipeline to recompute its track and overwrite the stored files. Only the creator may edit.
   *
   * <p>Like {@link #create}, the heavy work (pipeline + S3) runs with no DB connection held; only
   * the final reload-and-mutate opens a transaction. The DTO is built inside that transaction so the
   * lazy {@code createdBy} association resolves while the session is open.
   */
  @Logged
  public GpxPreviewDto updatePreview(
      String publicId, String name, @Nullable Path gpxPath, @Nullable List<GeoPoint> points) {
    return updatePreview(publicId, name, gpxPath, points, null);
  }

  /**
   * As {@link #updatePreview(String, String, Path, List)}, also taking the planner state the new
   * track is derived from (docs/LEDGER_*.md WEB-100, C4a). A file wins over it, and the state is
   * then ignored. Every replacement of the track rewrites or clears the stored state; a rename
   * leaves it.
   */
  @Logged
  public GpxPreviewDto updatePreview(
      String publicId,
      String name,
      @Nullable Path gpxPath,
      @Nullable List<GeoPoint> points,
      @Nullable PlannerState plannerState) {
    GpxPreview preview = getByPublicId(publicId);
    if (!preview.getCreatedBy().getId().equals(pedalonsContext.getUserId())) {
      throw new ForbiddenException();
    }
    UUID pid = preview.getPublicId();
    boolean hasPoints = points != null && !points.isEmpty();
    if (hasPoints && plannerState != null) {
      throw new BusinessException(ErrorCode.PLANNER_STATE_INVALID);
    }

    GpxDocument gpx = null;
    // A file replaces the track with an import, points replace it with a drawing: the origin
    // follows the last one (A10). A file also wins over a planner state.
    boolean drawn = false;
    PlannerState newState = null;
    if (gpxPath != null) {
      gpx = gpxProcessingService.parseGpx(gpxPath);
    } else if (plannerState != null) {
      checkPlannerAllowed();
      gpx = gpxProcessingService.fromPoints(name, plannerStates.validateAndDerive(plannerState));
      drawn = plannerState.drawn();
      newState = plannerState;
    } else if (hasPoints) {
      checkPlannerAllowed();
      gpx = gpxProcessingService.fromPoints(name, points);
      drawn = true;
    }

    Long previewId = preview.getId();
    if (gpx == null) {
      // Rename only: nothing to recompute, no request, no new revision. The row is locked first,
      // or this flush of every column could undo the switch of a catch-up committing meanwhile.
      return QuarkusTransaction.requiringNew()
          .call(
              () -> {
                lockForUpdate(previewId);
                GpxPreview managed = getByPublicId(publicId);
                managed.setName(truncateName(name));
                return toDto(managed, surfaceRefreshService.readPreview(managed));
              });
    }

    long revision = newRevision();
    ElevationQuality quality = elevationRefreshService.saveQuality();
    List<PreviewTrack> tracks;
    List<PreviewWaypoint> waypoints;
    TrackMetadata metadata;
    try (ComputedGpx computed = gpxProcessingService.computeGpx(gpx, quality)) {
      uploadTrackFiles(
          pid, revision, computed.originalGpx(), computed.filteredGpx(), computed.fitFile());
      tracks = toPreviewTracks(computed);
      waypoints = toPreviewWaypoints(computed);
      metadata = computed.aggregated();
    } catch (IOException e) {
      deleteTrackFiles(pid, revision);
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    } catch (RuntimeException e) {
      deleteTrackFiles(pid, revision);
      throw e;
    }

    boolean hasThumbnail = renderAndUploadThumbnail(pid, tracks);
    boolean newDrawn = drawn;
    PlannerState stateToStore = newState;

    return QuarkusTransaction.requiringNew()
        .call(
            () -> {
              // Whatever happens below, the new revision must not outlive a rollback
              deleteTrackFilesUnlessCommitted(pid, revision);
              lockForUpdate(previewId);
              GpxPreview managed = getByPublicId(publicId);
              // Read under the lock: a catch-up may have switched revisions since the load above
              Long previous = managed.getFilesRevision();
              managed.setName(truncateName(name));
              managed.setFilesRevision(revision);
              managed.setElevationState(stateOf(quality));
              managed.setDistance(metadata.distance());
              managed.setElevationGain(metadata.elevationGain());
              managed.setElevationLoss(metadata.elevationLoss());
              managed.setHilliness(metadata.hilliness());
              managed.setTracks(tracks);
              managed.setWaypoints(waypoints);
              managed.setHasThumbnail(hasThumbnail);
              managed.setDrawn(newDrawn);
              // Written or cleared with the track it describes, never left over a new one
              managed.setPlannerState(
                  stateToStore == null ? null : new PlannerStateDocument(revision, stateToStore));
              // The surface of the old track left with it (WEB-100, C1b)
              managed.setSurfaces(null);
              if (quality == ElevationQuality.FAST || surfaceRefreshService.isEnabled()) {
                gpxPreviewRepository.flush();
              }
              if (quality == ElevationQuality.FAST) {
                elevationRefreshService.requestPreview(previewId, revision);
              }
              surfaceRefreshService.requestPreview(previewId, revision);
              deleteTrackFilesAfterCommit(pid, previous);
              return toDto(managed, surfaceRefreshService.pendingReadouts(tracks.size()));
            });
  }

  /**
   * Reads a preview by its public identifier. Entry point for the API layer.
   *
   * <p>Open to anonymous visitors: the link is what grants access, and an unguessable UUID is what
   * makes it shareable. Creating and deleting still require an account.
   */
  @Public
  public GpxPreviewDto getPreview(String publicId) {
    GpxPreview preview = getByPublicId(publicId);
    return toDto(preview, surfaceRefreshService.readPreview(preview));
  }

  /**
   * The planner state of a preview, for its edit page (docs/LEDGER_*.md WEB-100, C4a). Only the
   * creator reads it: a preview is readable by anyone holding its link, its editing state is not.
   * Null when there is none to read back, or when the track was replaced since by a path that does
   * not carry it ({@code files_revision} no longer matches).
   */
  @Logged
  @Transactional
  public PlannerStateResponse getPlannerState(String publicId) {
    GpxPreview preview = getByPublicId(publicId);
    if (!isCreator(preview)) {
      throw new ForbiddenException();
    }
    PlannerStateDocument document = readableState(preview);
    return new PlannerStateResponse(document == null ? null : document.state());
  }

  private boolean isCreator(GpxPreview preview) {
    return preview.getCreatedBy().getId().equals(pedalonsContext.getUserIdNullable());
  }

  /** The stored state when it still describes the current track of the preview, else null. */
  private static @Nullable PlannerStateDocument readableState(GpxPreview preview) {
    PlannerStateDocument document = preview.getPlannerState();
    Long revision = preview.getFilesRevision();
    if (document == null || revision == null || document.trackRevision() != revision) {
      return null;
    }
    return document;
  }

  /**
   * The stored surface documents when they still describe the current tracks of the preview (same
   * revision, same number of tracks), else null.
   */
  private @Nullable List<@Nullable TrackSurfaceDocument> readableSurfaces(GpxPreview preview) {
    PreviewSurfacesDocument document = gpxPreviewRepository.findSurfaces(preview.getId());
    Long revision = preview.getFilesRevision();
    if (document == null
        || revision == null
        || document.trackRevision() != revision
        || document.tracks().size() != preview.getTracks().size()) {
      return null;
    }
    return document.tracks();
  }

  /**
   * Lists the current user's previews still within the retention window, most recent first. Scoped
   * to the caller: only previews they created, in their domain.
   */
  @Logged
  public GpxPreviewListResponse listMine(int page, int size) {
    Instant cutoff = Instant.now().minus(RETENTION_DAYS, ChronoUnit.DAYS);
    PedalonsPage<GpxPreview> previews =
        gpxPreviewRepository.findByCreator(
            pedalonsContext.getDomainId(), pedalonsContext.getUserId(), cutoff, page, size);
    List<GpxPreviewSummaryDto> dtos =
        previews.items().stream().map(GpxPreviewSummaryDto::from).toList();
    return new GpxPreviewListResponse(dtos, previews.total(), page, size);
  }

  /** Resolves a preview within the current domain. Every read path goes through here. */
  public GpxPreview getByPublicId(String publicId) {
    return gpxPreviewRepository
        .findByPublicId(pedalonsContext.getDomainId(), parseUuid(publicId))
        .orElseThrow(() -> new NotFoundException(ErrorCode.GPX_NOT_FOUND));
  }

  /** The DTO of a preview, its surface read ({@link SurfaceRefreshService#readPreview}). */
  public GpxPreviewDto toDto(GpxPreview preview) {
    return toDto(preview, surfaceRefreshService.readPreview(preview));
  }

  /**
   * @param surfaces the surface of each track of the preview
   *     ({@link SurfaceRefreshService#readPreview})
   */
  public GpxPreviewDto toDto(GpxPreview preview, List<TrackSurfaceReadout> surfaces) {
    boolean owned = preview.getCreatedBy().getId().equals(pedalonsContext.getUserIdNullable());
    return GpxPreviewDto.from(preview, owned, surfaces);
  }

  /**
   * The DTO of a preview just saved, whose entity is detached: no read of its surface, which is
   * queued and not computed yet (docs/LEDGER_*.md WEB-100, C1b).
   */
  private GpxPreviewDto toDtoJustSaved(GpxPreview preview) {
    return toDto(preview, surfaceRefreshService.pendingReadouts(preview.getTracks().size()));
  }

  /** Sends a preview's filtered GPX to one of the current user's connected GPS services. */
  @Logged
  public RouteUploadResponse uploadToGpsService(String publicId, GpsServiceType serviceType) {
    GpxPreview preview = getByPublicId(publicId);
    return gpsService.uploadGpx(serviceType, getFilteredGpxContent(preview), preview.getName());
  }

  /**
   * Turns a preview into a real route on a team.
   *
   * <p>Replays the pipeline on the original upload rather than reusing the preview's computed
   * tracks, so the route gets its own FIT file and thumbnails and stays independent of whatever
   * processing the preview happened to receive.
   *
   * <p>Team authorization is enforced by {@code RouteService.createRoute}'s {@code @CheckAccess}.
   * A preview that was drawn in the planner is refused here, before the download, when the team has
   * no route planner ({@code ROUTE_PLANNER_DISABLED}): the route is rebuilt from the original GPX,
   * so {@code RouteService} would see a file and let the drawing through. An imported file stays
   * open to every team, like {@code RouteService.checkPlannerAllowed}. Members' rights are checked
   * first, so the flag is not revealed to a non-member.
   *
   * <p>Not watertight, by decision: the GPX of a preview is public, so a drawn track can be exported
   * and re-imported as a file ({@code drawn=false}). Only the drawing is governed
   * (docs/LEDGER_*.md API-127). Same for a planner state made only of imported pieces
   * ({@code PlannerState#drawn()} is false): its source geometry comes from the client, which the
   * server cannot tell from a file it stored, and the effect is that of exporting and re-importing
   * the GPX. Deliberate, owner's decision (WEB-100, C4a).
   */
  @Logged
  public RouteDto createRoute(String publicId, String teamSlug, RouteRequest request) {
    GpxPreview preview = getByPublicId(publicId);
    if (preview.isDrawn()) {
      securityVerifier.verifyAccess(EntityType.ROUTE, ActionType.CREATE, List.of(teamSlug));
      if (!teamService.getTeam(teamSlug).isEnableRoutePlanner()) {
        throw new BusinessException(ErrorCode.ROUTE_PLANNER_DISABLED);
      }
    }
    // Only the creator takes the planner state along: promoting someone else's preview must not
    // make its editing state readable by the editors of the team (WEB-100, C4a).
    PlannerState copied =
        isCreator(preview)
            ? QuarkusTransaction.requiringNew()
                .call(
                    () -> {
                      PlannerStateDocument document = readableState(getByPublicId(publicId));
                      return document == null ? null : document.state();
                    })
            : null;
    // The surface, on the other hand, is public on the page of the preview: any caller takes it
    // along, and the route then asks for no computation of its own (WEB-100, C1b)
    List<@Nullable TrackSurfaceDocument> copiedSurfaces =
        QuarkusTransaction.requiringNew().call(() -> readableSurfaces(getByPublicId(publicId)));
    Path gpxPath = downloadOriginalGpx(preview);
    try {
      return routeService.createRoute(teamSlug, request, gpxPath, copied, copiedSurfaces);
    } finally {
      try {
        Files.deleteIfExists(gpxPath);
      } catch (IOException e) {
        LOG.warnf(e, "Failed to delete temp GPX %s", gpxPath);
      }
    }
  }

  /** Only the creator may delete a preview; anyone with the link may read it. */
  @Logged
  @Transactional
  public void delete(String publicId) {
    GpxPreview preview = getByPublicId(publicId);
    if (!preview.getCreatedBy().getId().equals(pedalonsContext.getUserId())) {
      throw new ForbiddenException();
    }
    lockFresh(preview);
    gpxPreviewRepository.delete(preview);
    deleteFiles(preview);
  }

  /** The filtered GPX, as sent to GPS services. */
  public byte[] getFilteredGpxContent(GpxPreview preview) {
    return retrieveBytes(preview, FILTERED_GPX);
  }

  /** The FIT export, generated at upload time and stored alongside the GPX files. */
  public byte[] getFitContent(GpxPreview preview) {
    return retrieveBytes(preview, FIT);
  }

  private byte[] retrieveBytes(GpxPreview preview, String fileName) {
    try {
      return readBytes(trackKey(preview, fileName));
    } catch (NoSuchKeyException e) {
      GpxPreview fresh = reloadIfRevisionChanged(preview);
      if (fresh == null) {
        throw e;
      }
      try {
        return readBytes(trackKey(fresh, fileName));
      } catch (IOException ioe) {
        throw new BusinessException(ErrorCode.GPX_FAILURE, ioe);
      }
    } catch (IOException e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  private byte[] readBytes(String key) throws IOException {
    try (InputStream is = storageService.retrieve(key)) {
      return is.readAllBytes();
    }
  }

  /**
   * A reader that loaded the row just before an HD catch-up switched its revision asks for files
   * that commit has deleted. The preview as committed now, when it is on another revision; null
   * when it is not (the object is really missing).
   */
  private @Nullable GpxPreview reloadIfRevisionChanged(GpxPreview preview) {
    UUID publicId = preview.getPublicId();
    GpxPreview fresh =
        QuarkusTransaction.requiringNew().call(() -> getByPublicId(publicId.toString()));
    return Objects.equals(fresh.getFilesRevision(), preview.getFilesRevision()) ? null : fresh;
  }

  /**
   * Streams the preview's filtered GPX as an attachment download. Public, like {@link #getPreview}:
   * anyone holding the link may download it.
   */
  @Public
  public Response downloadGpx(String publicId) {
    GpxPreview preview = getByPublicId(publicId);
    return fileDownload(
        getFilteredGpxContent(preview), GPX_CONTENT_TYPE, preview.getName(), ".gpx");
  }

  /** Streams the preview's FIT export as an attachment download. Public, like {@link #downloadGpx}. */
  @Public
  public Response downloadFit(String publicId) {
    GpxPreview preview = getByPublicId(publicId);
    return fileDownload(getFitContent(preview), FIT_CONTENT_TYPE, preview.getName(), ".fit");
  }

  private static Response fileDownload(
      byte[] content, String contentType, String name, String extension) {
    return Response.ok(content)
        .type(contentType)
        .header(
            "Content-Disposition",
            "attachment; filename=\"" + downloadFileName(name, extension) + "\"")
        .build();
  }

  /** A safe download filename derived from the preview name, e.g. {@code "Col du Galibier.gpx"}. */
  private static String downloadFileName(String name, String extension) {
    String base = name.replaceAll("[^a-zA-Z0-9-_. ]", "_").strip();
    return (base.isEmpty() ? "track" : base) + extension;
  }

  /**
   * Downloads the stored original — the upload's full-resolution track, already stripped of
   * timestamps and sensor data ({@code GpxSanitizer}) — to a temp file, so route creation can
   * replay the full pipeline on it and produce its own FIT and thumbnails.
   *
   * <p>The caller owns the returned file and must delete it.
   */
  public Path downloadOriginalGpx(GpxPreview preview) {
    try {
      Path temp = Files.createTempFile("gpx-preview-", ".gpx");
      try {
        copyOriginal(trackKey(preview, ORIGINAL_GPX), temp);
      } catch (NoSuchKeyException e) {
        // The row was read just before a catch-up switched revisions: follow it once
        GpxPreview fresh = reloadIfRevisionChanged(preview);
        if (fresh == null) {
          Files.deleteIfExists(temp);
          throw e;
        }
        copyOriginal(trackKey(fresh, ORIGINAL_GPX), temp);
      }
      return temp;
    } catch (IOException e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  private void copyOriginal(String key, Path temp) throws IOException {
    try (InputStream is = storageService.retrieve(key)) {
      Files.copy(is, temp, StandardCopyOption.REPLACE_EXISTING);
    }
  }

  /** Purges previews past their retention window, S3 objects first. */
  @Transactional
  public int purgeExpired() {
    Instant cutoff = Instant.now().minus(RETENTION_DAYS, ChronoUnit.DAYS);
    List<GpxPreview> expired = gpxPreviewRepository.findExpired(cutoff);
    for (GpxPreview preview : expired) {
      lockFresh(preview);
      deleteFiles(preview);
      gpxPreviewRepository.delete(preview);
    }
    return expired.size();
  }

  /** Deletes every preview a user uploaded, S3 objects first — part of an account erasure. */
  @Transactional
  public void forgetCreator(Long domainId, Long userId) {
    for (GpxPreview preview : gpxPreviewRepository.findAllByCreator(domainId, userId)) {
      lockFresh(preview);
      deleteFiles(preview);
      gpxPreviewRepository.delete(preview);
    }
  }

  /**
   * Serves the preview's rendered map thumbnail through imgproxy (used as the Open Graph image).
   * Public: like {@link #getPreview}, the unguessable link is what grants access, and the lookup is
   * domain-filtered. A preview without a stored thumbnail 404s rather than reaching imgproxy.
   */
  @Public
  public Response getThumbnail(String publicId, int size, String accept) {
    GpxPreview preview = getByPublicId(publicId);
    if (!preview.isHasThumbnail()) {
      throw new NotFoundException(ErrorCode.GPX_NOT_FOUND);
    }
    return Response.fromResponse(
            imgProxyService.getPhoto(
                accept, key(preview.getPublicId(), THUMBNAIL_LIGHT), size, size))
        .build();
  }

  /**
   * Renders a map thumbnail for the preview's tracks and stores it alongside the GPX files. Purely
   * best-effort: any failure logs and returns {@code false} so it never blocks preview creation —
   * the preview simply falls back to the default Open Graph image.
   */
  private boolean renderAndUploadThumbnail(UUID publicId, List<PreviewTrack> tracks) {
    List<ThumbnailService.ThumbnailTrack> thumbnailTracks =
        tracks.stream()
            .map(t -> new ThumbnailService.ThumbnailTrack(t.name(), t.trackPoints()))
            .toList();
    Path temp = null;
    try {
      temp = Files.createTempFile("gpx-preview-thumb-", ".png");
      if (!thumbnailService.renderLightThumbnail(temp.toFile(), thumbnailTracks)) {
        return false;
      }
      upload(publicId, THUMBNAIL_LIGHT, temp.toFile(), PNG_CONTENT_TYPE);
      return true;
    } catch (Exception e) {
      LOG.warnf(e, "Thumbnail render/upload failed for GPX preview %s", publicId);
      return false;
    } finally {
      if (temp != null) {
        try {
          Files.deleteIfExists(temp);
        } catch (IOException e) {
          LOG.warnf(e, "Failed to delete temp thumbnail %s", temp);
        }
      }
    }
  }

  /** The state a save computed with {@code quality} leaves the preview in. */
  private static ElevationState stateOf(ElevationQuality quality) {
    return quality == ElevationQuality.FAST ? ElevationState.PENDING : ElevationState.HD;
  }

  /** A fresh token for a set of track files. */
  public static long newRevision() {
    return TSID.Factory.getTsid().toLong();
  }

  /** Uploads one flat file (the thumbnail). */
  private void upload(UUID publicId, String fileName, File file, String contentType)
      throws IOException {
    store(key(publicId, fileName), file, contentType);
  }

  private void store(String key, File file, String contentType) throws IOException {
    try (InputStream is = new FileInputStream(file)) {
      storageService.store(key, is, contentType, file.length());
    }
  }

  /** Uploads the three track files under {@code revision}: no row points at them yet. */
  private void uploadTrackFiles(
      UUID publicId, long revision, File original, File filtered, File fit) throws IOException {
    store(trackKey(publicId, revision, ORIGINAL_GPX), original, GPX_CONTENT_TYPE);
    store(trackKey(publicId, revision, FILTERED_GPX), filtered, GPX_CONTENT_TYPE);
    store(trackKey(publicId, revision, FIT), fit, FIT_CONTENT_TYPE);
  }

  /**
   * Uploads the three track files of a preview under {@code revision}, for the HD catch-up. No row
   * points at them until the caller switches {@code files_revision}.
   */
  public void uploadTrackFilesForRefresh(
      UUID publicId, long revision, File original, File filtered, File fit) throws IOException {
    uploadTrackFiles(publicId, revision, original, filtered, fit);
  }

  /** Every file of a freshly created preview, which has no other revision. */
  private void deleteFiles(UUID publicId, @Nullable Long revision) {
    deleteTrackFiles(publicId, revision);
    deleteQuietly(key(publicId, THUMBNAIL_LIGHT));
  }

  /**
   * Every file of a stored preview. The current revision and the thumbnail by name, then whatever
   * else sits under the preview's folder: a revision orphaned by a crash between its upload and its
   * commit, or by a failed cleanup, would otherwise keep the user's full-resolution track forever
   * (erasure included).
   */
  private void deleteFiles(GpxPreview preview) {
    deleteFiles(preview.getPublicId(), preview.getFilesRevision());
    String prefix = KEY_PREFIX + preview.getPublicId() + "/";
    try {
      storageService.deleteByPrefix(prefix);
    } catch (Exception e) {
      LOG.warnf(e, "S3 prefix cleanup failed for GPX preview folder %s", prefix);
    }
  }

  /** Deletes the three track files of {@code revision} now ({@code null}: the flat layout). */
  public void deleteTrackFiles(UUID publicId, @Nullable Long revision) {
    for (String fileName : TRACK_FILES) {
      deleteQuietly(trackKey(publicId, revision, fileName));
    }
  }

  /** Deletes the track files of {@code revision} once the transaction has committed. */
  public void deleteTrackFilesAfterCommit(UUID publicId, @Nullable Long revision) {
    for (String fileName : TRACK_FILES) {
      assetService.deleteAfterCommit(trackKey(publicId, revision, fileName));
    }
  }

  /** Deletes the track files of {@code revision} unless the transaction commits. */
  public void deleteTrackFilesUnlessCommitted(UUID publicId, @Nullable Long revision) {
    for (String fileName : TRACK_FILES) {
      assetService.deleteUnlessCommitted(trackKey(publicId, revision, fileName));
    }
  }

  private void deleteQuietly(String key) {
    try {
      storageService.delete(key);
    } catch (Exception e) {
      LOG.warnf(e, "S3 cleanup failed for GPX preview file %s", key);
    }
  }

  /**
   * Locks the preview's row for the rest of the transaction and loads it from it. Called first in
   * a transaction that rewrites the row, so it starts from what a concurrent catch-up committed
   * and the flush does not overwrite its switch of revision.
   */
  private void lockForUpdate(Long previewId) {
    gpxPreviewRepository
        .getEntityManager()
        .find(GpxPreview.class, previewId, LockModeType.PESSIMISTIC_WRITE);
  }

  /** As {@link #lockForUpdate}, for an entity this transaction already holds: reloads it. */
  private void lockFresh(GpxPreview preview) {
    gpxPreviewRepository.getEntityManager().refresh(preview, LockModeType.PESSIMISTIC_WRITE);
  }

  /**
   * The stored files of a preview, as {@code fileName -> storage key}.
   *
   * <p>For the GDPR data export, which has to reach these objects without duplicating the key
   * layout. The thumbnail is left out: it is a rendering the server produced, not something the
   * user supplied or would recognise.
   */
  public Map<String, String> exportKeys(GpxPreview preview) {
    return Map.of(
        ORIGINAL_GPX, trackKey(preview, ORIGINAL_GPX),
        FILTERED_GPX, trackKey(preview, FILTERED_GPX),
        FIT, trackKey(preview, FIT));
  }

  /**
   * The storage key of a track file ({@code original.gpx}, {@code filtered.gpx}, {@code route.fit})
   * of a preview, in the revision it currently has: the one place that knows the flat layout of a
   * preview with no {@code files_revision}.
   */
  public static String trackKey(GpxPreview preview, String fileName) {
    return trackKey(preview.getPublicId(), preview.getFilesRevision(), fileName);
  }

  public static String trackKey(UUID publicId, @Nullable Long revision, String fileName) {
    return revision == null
        ? key(publicId, fileName)
        : KEY_PREFIX + publicId + "/" + revision + "/" + fileName;
  }

  private static String key(UUID publicId, String fileName) {
    return KEY_PREFIX + publicId + "/" + fileName;
  }

  private static UUID parseUuid(String publicId) {
    try {
      return UUID.fromString(publicId);
    } catch (IllegalArgumentException e) {
      throw new NotFoundException(ErrorCode.GPX_NOT_FOUND);
    }
  }

  private static String truncateName(String name) {
    return name.length() <= 250 ? name : name.substring(0, 250);
  }

  public static List<PreviewTrack> toPreviewTracks(ComputedGpx computed) {
    return computed.tracks().stream()
        .map(
            t ->
                new PreviewTrack(
                    t.name(),
                    t.trackPoints(),
                    t.climbs(),
                    t.metadata().distance(),
                    t.metadata().elevationGain(),
                    t.metadata().elevationLoss()))
        .toList();
  }

  public static List<PreviewWaypoint> toPreviewWaypoints(ComputedGpx computed) {
    return computed.waypoints().stream()
        .map(
            w ->
                new PreviewWaypoint(
                    w.name(),
                    w.location().getPosition().getLat(),
                    w.location().getPosition().getLon()))
        .toList();
  }
}
