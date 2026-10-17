package fr.pedalons.service.gpx;

import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.GpxPreview.PreviewTrack;
import fr.pedalons.domain.gpx.GpxPreview.PreviewWaypoint;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.gps.response.RouteUploadResponse;
import fr.pedalons.dto.gpx.response.GpxPreviewDto;
import fr.pedalons.dto.gpx.response.GpxPreviewListResponse;
import fr.pedalons.dto.gpx.response.GpxPreviewSummaryDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.infrastructure.imgproxy.ImgProxyService;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.service.gps.GpsService;
import fr.pedalons.service.route.GpxLimits;
import fr.pedalons.service.route.GpxProcessingService;
import fr.pedalons.service.route.GpxProcessingService.ComputedGpx;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.route.response.TrackMetadata;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.SecurityVerifier;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.security.annotation.Public;
import fr.pedalons.service.team.TeamService;
import fr.pedalons.service.thumbnail.ThumbnailService;
import io.github.glandais.engine.gpx.GpxDocument;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
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
import java.util.UUID;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * GPX previews: files uploaded through the GPX tools page, analysed and rendered without ever
 * becoming a {@code Route}.
 *
 * <p>Files live in S3 under {@code gpx-previews/{publicId}/}, written through {@link
 * StorageService} rather than {@code AssetService} — an {@code Asset} requires a team, and a
 * preview has none. Those keys carry no domain prefix, so <b>every</b> access must resolve the
 * preview through {@link GpxPreviewRepository#findByPublicId} first: that domain-filtered lookup is
 * the only thing standing between a leaked identifier and a cross-tenant read.
 */
@ApplicationScoped
public class GpxPreviewService {

  private static final Logger LOG = Logger.getLogger(GpxPreviewService.class);

  private static final String KEY_PREFIX = "gpx-previews/";
  private static final String ORIGINAL_GPX = "original.gpx";
  private static final String FILTERED_GPX = "filtered.gpx";
  private static final String FIT = "route.fit";
  private static final String THUMBNAIL_LIGHT = "thumbnail-light.png";
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

  /**
   * Parses and analyses an uploaded GPX file, stores it, and returns the persisted preview.
   *
   * <p>Deliberately not {@code @Transactional}: the pipeline (SRTM, Douglas-Peucker, climb
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
    User creator = pedalonsContext.getUser();
    Domain domain = pedalonsContext.getDomain();
    UUID publicId = UUID.randomUUID();

    List<PreviewTrack> tracks;
    List<PreviewWaypoint> waypoints;
    TrackMetadata metadata;
    try (ComputedGpx computed = gpxProcessingService.computeGpx(gpx)) {
      upload(publicId, ORIGINAL_GPX, computed.originalGpx());
      upload(publicId, FILTERED_GPX, computed.filteredGpx());
      upload(publicId, FIT, computed.fitFile(), FIT_CONTENT_TYPE);

      tracks = toPreviewTracks(computed);
      waypoints = toPreviewWaypoints(computed);
      metadata = computed.aggregated();
    } catch (IOException e) {
      deleteFiles(publicId);
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    } catch (RuntimeException e) {
      deleteFiles(publicId);
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

    try {
      QuarkusTransaction.requiringNew().run(() -> gpxPreviewRepository.persist(preview));
    } catch (RuntimeException e) {
      deleteFiles(publicId);
      throw e;
    }
    LOG.infov("Created GPX preview {0}", publicId);
    return preview;
  }

  /** Analyses an uploaded GPX file. Entry point for the API layer. */
  @Logged
  public GpxPreviewDto createPreview(Path gpxPath, String fallbackName) {
    return toDto(create(gpxPath, fallbackName));
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
    return toDto(create(merged, name));
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
    checkPlannerAllowed();
    return toDto(create(gpxProcessingService.fromPoints(name, points), name, true));
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
    GpxPreview preview = getByPublicId(publicId);
    if (!preview.getCreatedBy().getId().equals(pedalonsContext.getUserId())) {
      throw new ForbiddenException();
    }
    UUID pid = preview.getPublicId();

    GpxDocument gpx = null;
    // A file replaces the track with an import, points replace it with a drawing: the origin
    // follows the last one (A10).
    boolean drawn = false;
    if (gpxPath != null) {
      gpx = gpxProcessingService.parseGpx(gpxPath);
    } else if (points != null && !points.isEmpty()) {
      checkPlannerAllowed();
      gpx = gpxProcessingService.fromPoints(name, points);
      drawn = true;
    }

    if (gpx == null) {
      // Rename only: nothing to recompute.
      return QuarkusTransaction.requiringNew()
          .call(
              () -> {
                GpxPreview managed = getByPublicId(publicId);
                managed.setName(truncateName(name));
                return toDto(managed);
              });
    }

    List<PreviewTrack> tracks;
    List<PreviewWaypoint> waypoints;
    TrackMetadata metadata;
    try (ComputedGpx computed = gpxProcessingService.computeGpx(gpx)) {
      upload(pid, ORIGINAL_GPX, computed.originalGpx());
      upload(pid, FILTERED_GPX, computed.filteredGpx());
      upload(pid, FIT, computed.fitFile(), FIT_CONTENT_TYPE);
      tracks = toPreviewTracks(computed);
      waypoints = toPreviewWaypoints(computed);
      metadata = computed.aggregated();
    } catch (IOException e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }

    boolean hasThumbnail = renderAndUploadThumbnail(pid, tracks);
    boolean newDrawn = drawn;

    return QuarkusTransaction.requiringNew()
        .call(
            () -> {
              GpxPreview managed = getByPublicId(publicId);
              managed.setName(truncateName(name));
              managed.setDistance(metadata.distance());
              managed.setElevationGain(metadata.elevationGain());
              managed.setElevationLoss(metadata.elevationLoss());
              managed.setHilliness(metadata.hilliness());
              managed.setTracks(tracks);
              managed.setWaypoints(waypoints);
              managed.setHasThumbnail(hasThumbnail);
              managed.setDrawn(newDrawn);
              return toDto(managed);
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
    return toDto(getByPublicId(publicId));
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

  public GpxPreviewDto toDto(GpxPreview preview) {
    boolean owned = preview.getCreatedBy().getId().equals(pedalonsContext.getUserIdNullable());
    return GpxPreviewDto.from(preview, owned);
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
   * (docs/LEDGER_*.md API-127).
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
    Path gpxPath = downloadOriginalGpx(preview);
    try {
      return routeService.createRoute(teamSlug, request, gpxPath);
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
    gpxPreviewRepository.delete(preview);
    deleteFiles(preview.getPublicId());
  }

  /** The filtered GPX, as sent to GPS services. */
  public byte[] getFilteredGpxContent(GpxPreview preview) {
    return retrieveBytes(preview.getPublicId(), FILTERED_GPX);
  }

  /** The FIT export, generated at upload time and stored alongside the GPX files. */
  public byte[] getFitContent(GpxPreview preview) {
    return retrieveBytes(preview.getPublicId(), FIT);
  }

  private byte[] retrieveBytes(UUID publicId, String fileName) {
    try (InputStream is = storageService.retrieve(key(publicId, fileName))) {
      return is.readAllBytes();
    } catch (IOException e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
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
      try (InputStream is = storageService.retrieve(key(preview.getPublicId(), ORIGINAL_GPX))) {
        Files.copy(is, temp, StandardCopyOption.REPLACE_EXISTING);
      }
      return temp;
    } catch (IOException e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  /** Purges previews past their retention window, S3 objects first. */
  @Transactional
  public int purgeExpired() {
    Instant cutoff = Instant.now().minus(RETENTION_DAYS, ChronoUnit.DAYS);
    List<GpxPreview> expired = gpxPreviewRepository.findExpired(cutoff);
    for (GpxPreview preview : expired) {
      deleteFiles(preview.getPublicId());
      gpxPreviewRepository.delete(preview);
    }
    return expired.size();
  }

  /** Deletes every preview a user uploaded, S3 objects first — part of an account erasure. */
  @Transactional
  public void forgetCreator(Long domainId, Long userId) {
    for (GpxPreview preview : gpxPreviewRepository.findAllByCreator(domainId, userId)) {
      deleteFiles(preview.getPublicId());
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

  private void upload(UUID publicId, String fileName, File file) throws IOException {
    upload(publicId, fileName, file, GPX_CONTENT_TYPE);
  }

  private void upload(UUID publicId, String fileName, File file, String contentType)
      throws IOException {
    try (InputStream is = new FileInputStream(file)) {
      storageService.store(key(publicId, fileName), is, contentType, file.length());
    }
  }

  private void deleteFiles(UUID publicId) {
    for (String fileName : List.of(ORIGINAL_GPX, FILTERED_GPX, FIT, THUMBNAIL_LIGHT)) {
      try {
        storageService.delete(key(publicId, fileName));
      } catch (Exception e) {
        LOG.warnf(e, "S3 cleanup failed for GPX preview %s/%s", publicId, fileName);
      }
    }
  }

  /**
   * The stored files of a preview, as {@code fileName -> storage key}.
   *
   * <p>For the GDPR data export, which has to reach these objects without duplicating the key
   * layout. The thumbnail is left out: it is a rendering the server produced, not something the
   * user supplied or would recognise.
   */
  public Map<String, String> exportKeys(GpxPreview preview) {
    UUID publicId = preview.getPublicId();
    return Map.of(
        ORIGINAL_GPX, key(publicId, ORIGINAL_GPX),
        FILTERED_GPX, key(publicId, FILTERED_GPX),
        FIT, key(publicId, FIT));
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

  private static List<PreviewTrack> toPreviewTracks(ComputedGpx computed) {
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

  private static List<PreviewWaypoint> toPreviewWaypoints(ComputedGpx computed) {
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
