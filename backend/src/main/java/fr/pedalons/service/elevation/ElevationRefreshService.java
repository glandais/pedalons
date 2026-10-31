package fr.pedalons.service.elevation;

import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.GpxPreview.PreviewTrack;
import fr.pedalons.domain.gpx.PreviewRawLinesDocument;
import fr.pedalons.domain.gpx.PreviewSurfacesDocument;
import fr.pedalons.domain.gpx.PreviewWaypointDetail;
import fr.pedalons.domain.gpx.PreviewWaypointsDocument;
import fr.pedalons.domain.route.GpxWaypoint;
import fr.pedalons.domain.route.PlannerStateDocument;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository;
import fr.pedalons.repository.route.ElevationRefreshRepository.Claim;
import fr.pedalons.repository.route.ElevationRefreshRepository.PreviewClaim;
import fr.pedalons.repository.route.SurfaceRefreshRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.gpx.GpxPreviewService;
import fr.pedalons.service.gpx.PreviewWaypoints;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.route.GpxProcessingService;
import fr.pedalons.service.route.GpxProcessingService.ComputedGpx;
import fr.pedalons.service.route.GpxProcessingService.ElevationRecompute;
import fr.pedalons.service.route.GpxProcessingService.ElevationUnavailableException;
import fr.pedalons.service.route.response.TrackMetadata;
import fr.pedalons.service.route.waypoint.WaypointDraft;
import fr.pedalons.service.route.waypoint.WaypointDrafts;
import fr.pedalons.service.route.waypoint.WaypointPlan;
import fr.pedalons.service.route.waypoint.WaypointRows;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.Callable;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * The HD catch-up of the tracks saved with the fast elevation source (docs/LEDGER_*.md API-131,
 * plan {@code docs/plans/archive/2026-10-17-altitude-hd-asynchrone.md}): the request made in the saving
 * transaction, and the three phases {@link ElevationRefreshWorker} runs for a route — <b>claim</b>,
 * <b>compute</b> (no transaction, the slow part) and <b>write</b> (a short transaction that checks
 * the track is still the one computed).
 *
 * <p>The same three phases serve the GPX-tool previews (plan §4.6), with the preview's {@code
 * files_revision} as the token instead of the original's {@code file_id}, and {@link
 * GpxPreviewService} owning the layout of the files.
 *
 * <p>The phases are separate, package-visible methods so a test can change the track between
 * compute and write.
 */
@ApplicationScoped
public class ElevationRefreshService {

  private static final Logger LOG = Logger.getLogger(ElevationRefreshService.class);

  /** After this many failed attempts a request stays in the table, untouched, and is logged once. */
  public static final int MAX_ATTEMPTS = 5;

  /** How long a claim holds a request: well above one route's compute, short enough to recover. */
  static final Duration LEASE = Duration.ofMinutes(10);

  /** Delay before the next attempt, indexed by the attempts already made. */
  static final List<Duration> BACKOFF =
      List.of(
          Duration.ofMinutes(2), Duration.ofMinutes(10), Duration.ofHours(1), Duration.ofHours(6));

  private static final int MAX_ERROR_LENGTH = 500;

  /** What became of a claimed request. */
  public enum Outcome {
    /** The HD profile was written and the request removed. */
    REFRESHED,
    /** The track changed during the compute: nothing written, request moved to the new revision. */
    REALIGNED,
    /** The route is gone. */
    GONE,
    /** The attempt failed: backoff, or given up. */
    FAILED
  }

  /** A route recomputed in HD, ready to be written. */
  record Recomputed(Team team, ElevationRecompute recompute) {}

  /**
   * A preview recomputed in HD, its three track files already uploaded under {@code revision} (no
   * row points at them yet).
   */
  record PreviewRecomputed(
      UUID publicId,
      long revision,
      List<PreviewTrack> tracks,
      TrackMetadata metadata,
      List<PreviewWaypointDetail> usedWaypoints,
      List<PreviewWaypointDetail> placedWaypoints) {

    PreviewRecomputed(
        UUID publicId, long revision, List<PreviewTrack> tracks, TrackMetadata metadata) {
      this(publicId, revision, tracks, metadata, List.of(), List.of());
    }
  }

  /**
   * Whether a save computes the fast profile and asks for the catch-up (default), or computes HD
   * on the spot like before. The way back without redeploying code.
   */
  @ConfigProperty(name = "pedalons.elevation.async-hd.enabled", defaultValue = "true")
  boolean enabled;

  /** How long a track must stay unmodified before its catch-up starts. */
  @ConfigProperty(name = "pedalons.elevation.async-hd.quiet", defaultValue = "PT90S")
  Duration quiet;

  /** The longest a stream of saves can postpone the catch-up, from the first of them. */
  @ConfigProperty(name = "pedalons.elevation.async-hd.max-wait", defaultValue = "PT10M")
  Duration maxWait;

  @Inject ElevationRefreshRepository refreshRepository;
  @Inject SurfaceRefreshRepository surfaceRefreshRepository;
  @Inject GpxProcessingService gpxProcessingService;
  @Inject AssetService assetService;
  @Inject AssetRepository assetRepository;
  @Inject StorageService storageService;
  @Inject PublicationEndCalculator publicationEndCalculator;
  @Inject GpxPreviewService gpxPreviewService;
  @Inject EntityManager entityManager;

  public boolean isAsyncHdEnabled() {
    return enabled;
  }

  /** For the tests: flips the switch of {@code pedalons.elevation.async-hd.enabled}. */
  public void setAsyncHdEnabledForTest(boolean enabled) {
    this.enabled = enabled;
  }

  /** The elevation source a save of a track computes with. */
  public ElevationQuality saveQuality() {
    return enabled ? ElevationQuality.FAST : ElevationQuality.HD;
  }

  /** Whether the target is HD, a null state standing for HD. */
  private static boolean isHd(@Nullable ElevationState stored) {
    return ElevationState.orHd(stored) == ElevationState.HD;
  }

  // ------------------------------------------------------------------ request

  /**
   * Asks for the HD recompute of a route saved on the fast source, in the saving transaction (so
   * the request exists exactly when the FAST track does), or postpones the pending one.
   *
   * @param sourceRevision the {@code file_id} of the route's original GPX after the save
   */
  public void requestRoute(Route route, long sourceRevision) {
    refreshRepository.requestForRoute(route.getId(), sourceRevision, Instant.now(), quiet, maxWait);
  }

  /**
   * As {@link #requestRoute}, for a GPX-tool preview saved on the fast source, in the saving
   * transaction and after the preview row is flushed.
   *
   * @param filesRevision the preview's {@code files_revision} after the save
   */
  public void requestPreview(Long previewId, long filesRevision) {
    refreshRepository.requestForPreview(previewId, filesRevision, Instant.now(), quiet, maxWait);
  }

  // ------------------------------------------------------------------ claim

  /** Takes the next due request, in a transaction of its own. */
  public Optional<Claim> claimNext(Instant now) {
    return tx(() -> refreshRepository.claimNextRoute(now, now.plus(LEASE), MAX_ATTEMPTS));
  }

  /** Takes the next due preview request, in a transaction of its own. */
  public Optional<PreviewClaim> claimNextPreview(Instant now) {
    return tx(() -> refreshRepository.claimNextPreview(now, now.plus(LEASE), MAX_ATTEMPTS));
  }

  // ------------------------------------------------------------------ one request

  /** Runs the three phases for a claimed request; a failure is recorded, never thrown. */
  public Outcome process(Claim claim) {
    Recomputed recomputed;
    try {
      Outcome stale = realignIfStale(claim);
      if (stale != null) {
        return stale;
      }
      recomputed = compute(claim);
    } catch (Exception e) {
      return fail(claim, e);
    }
    try {
      return write(claim, recomputed);
    } catch (Exception e) {
      // The write transaction rolled back: its synchronisations deleted the new files
      return fail(claim, e);
    }
  }

  /**
   * Before reading anything: whether the route's original is no longer the requested revision. A
   * save that made no request (the previous release of a rolling deploy, or the switch off) has
   * replaced the original and deleted the requested object, which could then never be read; the
   * request is realigned on the current one instead of failing, unless that one is already HD (a
   * save with the switch off computed it synchronously): then the request is dropped, there is
   * nothing left to catch up on.
   *
   * @return the outcome when the request was settled here, else null
   */
  private @Nullable Outcome realignIfStale(Claim claim) {
    return tx(
        () -> {
          Long original =
              assetRepository.findCurrentFileId(claim.routeId(), AssetType.ROUTE_ORIGINAL_GPX);
          if (original == null || original == claim.sourceRevision()) {
            return null;
          }
          Route route = entityManager.find(Route.class, claim.routeId());
          if (route != null && isHd(route.getElevationState())) {
            refreshRepository.delete("id", claim.id());
            return Outcome.GONE;
          }
          if (route != null) {
            route.setElevationState(ElevationState.PENDING);
          }
          Instant now = Instant.now();
          refreshRepository.realign(claim.id(), original, now, now.plus(quiet));
          LOG.debugf(
              "Route %d changed since its HD elevation was requested, request realigned",
              claim.routeId());
          return Outcome.REALIGNED;
        });
  }

  /**
   * Phase 2, no transaction: reads the original of the requested revision, recomputes it in HD and
   * uploads the new filtered GPX and FIT.
   */
  Recomputed compute(Claim claim) throws IOException {
    Sources sources = tx(() -> sourcesOf(claim));
    GpxDocument original = load(assetService.getAssetKey(claim.teamId(), claim.sourceRevision()));
    // The original file carries no waypoint: the stored rows do, typed (docs/LEDGER_*.md WEB-100,
    // C3c), and are placed again on the HD track
    GpxDocument gpx = GpxModelJvm.document(original.getTracks(), original.getName(), List.of());
    return new Recomputed(
        sources.team(), gpxProcessingService.recomputeHd(sources.team(), gpx, sources.drafts()));
  }

  private record Sources(Team team, List<WaypointDraft> drafts) {}

  private Sources sourcesOf(Claim claim) {
    Team team = entityManager.getReference(Team.class, claim.teamId());
    List<GpxWaypoint> rows =
        entityManager
            .createQuery(
                "select w from GpxWaypoint w where w.route.id = :routeId", GpxWaypoint.class)
            .setParameter("routeId", claim.routeId())
            .getResultList();
    Float distance =
        entityManager
            .createQuery("select r.distance from Route r where r.id = :routeId", Float.class)
            .setParameter("routeId", claim.routeId())
            .getResultStream()
            .findFirst()
            .orElse(null);
    return new Sources(team, WaypointDrafts.fromRows(rows, distance, w -> true));
  }

  private GpxDocument load(String key) throws IOException {
    Path temp = download(key);
    try {
      return gpxProcessingService.parseGpx(temp);
    } finally {
      Files.deleteIfExists(temp);
    }
  }

  /** The stored object as a temp file the caller deletes. */
  private Path download(String key) throws IOException {
    Path temp = Files.createTempFile("elevation-refresh-", ".gpx");
    try (InputStream in = storageService.retrieve(key)) {
      Files.copy(in, temp, StandardCopyOption.REPLACE_EXISTING);
      return temp;
    } catch (IOException | RuntimeException e) {
      Files.deleteIfExists(temp);
      throw e;
    }
  }

  /**
   * Phase 3, a short transaction: locks the route and checks its original is still the revision
   * that was computed. If so the HD profile replaces the fast one; if not (the track was saved
   * again during the compute, or by the previous release of a rolling deploy) nothing is written,
   * the new files are deleted and the request is realigned on the current revision.
   */
  Outcome write(Claim claim, Recomputed recomputed) {
    return tx(
        () -> {
          // First, so that whatever happens below the new files do not outlive a rollback
          for (var pa : List.of(recomputed.recompute().filtered(), recomputed.recompute().fit())) {
            assetService.deleteUnlessCommitted(
                assetService.getAssetKey(claim.teamId(), pa.fileId()));
          }
          Route route =
              entityManager.find(Route.class, claim.routeId(), LockModeType.PESSIMISTIC_WRITE);
          if (route == null) {
            discard(claim, recomputed);
            return Outcome.GONE;
          }
          long current = currentOriginalFileId(route);
          if (current != claim.sourceRevision()) {
            discard(claim, recomputed);
            if (isHd(route.getElevationState())) {
              refreshRepository.delete("id", claim.id());
              return Outcome.GONE;
            }
            route.setElevationState(ElevationState.PENDING);
            Instant now = Instant.now();
            refreshRepository.realign(claim.id(), current, now, now.plus(quiet));
            LOG.debugf(
                "Route %d changed during its HD elevation compute, request realigned",
                claim.routeId());
            return Outcome.REALIGNED;
          }
          if (!WaypointRows.sameContent(
              route.getWaypoints(), recomputed.recompute().waypoints(), false)) {
            // The waypoints were edited during the compute: what was placed is stale
            discard(claim, recomputed);
            Instant now = Instant.now();
            refreshRepository.realign(claim.id(), current, now, now);
            LOG.debugf(
                "Waypoints of route %d changed during its HD elevation compute, request realigned",
                claim.routeId());
            return Outcome.REALIGNED;
          }
          boolean distanceChanged =
              gpxProcessingService.applyRecompute(route, recomputed.recompute());
          if (distanceChanged) {
            // Another distance is another end time for every ride riding the route (API-85)
            publicationEndCalculator.refreshUsersOf(route);
          }
          refreshRepository.deleteIfRevision(claim.id(), claim.sourceRevision());
          return Outcome.REFRESHED;
        });
  }

  /** Deletes the uploaded files whatever this transaction's outcome. */
  private void discard(Claim claim, Recomputed recomputed) {
    for (var pa : List.of(recomputed.recompute().filtered(), recomputed.recompute().fit())) {
      String key = assetService.getAssetKey(claim.teamId(), pa.fileId());
      assetService.deleteAfterCommit(key);
      assetService.deleteUnlessCommitted(key);
    }
  }

  private static long currentOriginalFileId(Route route) {
    return route.getAssets().stream()
        .filter(a -> a.getType() == AssetType.ROUTE_ORIGINAL_GPX)
        .max(Comparator.comparing(Asset::getId))
        .map(Asset::getFileId)
        .orElseThrow(
            () -> new IllegalStateException("Route " + route.getId() + " has no original GPX"));
  }

  /**
   * Records a failed attempt: one more, the next one after the backoff, the lease released. The
   * route keeps its fast profile; after {@value #MAX_ATTEMPTS} attempts the request stays as it is
   * for diagnosis and is logged once.
   */
  Outcome fail(Claim claim, Exception e) {
    return fail(
        claim.id(),
        claim.sourceRevision(),
        claim.attempts(),
        "route " + claim.routeId(),
        () -> lockTarget(Route.class, claim.routeId()),
        () -> abandonTarget("Route", claim.routeId()),
        e);
  }

  /** As {@link #fail(Claim, Exception)}, for a preview. */
  Outcome failPreview(PreviewClaim claim, Exception e) {
    return fail(
        claim.id(),
        claim.sourceRevision(),
        claim.attempts(),
        "preview " + claim.previewId(),
        () -> lockTarget(GpxPreview.class, claim.previewId()),
        () -> abandonTarget("GpxPreview", claim.previewId()),
        e);
  }

  /**
   * The request gave up: the target keeps its fast profile for good and says so (FAST), unless it
   * is no longer waiting for the catch-up. Runs in the transaction that recorded the failure.
   */
  /**
   * Locks the target row before the request row is touched: saves lock the target first and then
   * upsert the request, so giving up must take the locks in the same order or the two deadlock.
   */
  private void lockTarget(Class<?> entity, Long targetId) {
    entityManager.find(entity, targetId, LockModeType.PESSIMISTIC_WRITE);
  }

  private void abandonTarget(String entity, Long targetId) {
    entityManager
        .createQuery(
            "update "
                + entity
                + " t set t.elevationState = :fast where t.id = :id and t.elevationState ="
                + " :pending")
        .setParameter("fast", ElevationState.FAST)
        .setParameter("pending", ElevationState.PENDING)
        .setParameter("id", targetId)
        .executeUpdate();
  }

  private Outcome fail(
      Long id,
      long sourceRevision,
      int made,
      String target,
      Runnable lockTarget,
      Runnable abandon,
      Exception e) {
    int attempts = made + 1;
    Duration delay = BACKOFF.get(Math.min(made, BACKOFF.size() - 1));
    String error = e.getClass().getSimpleName() + ": " + e.getMessage();
    if (error.length() > MAX_ERROR_LENGTH) {
      error = error.substring(0, MAX_ERROR_LENGTH);
    }
    String recorded = error;
    tx(
        () -> {
          if (attempts >= MAX_ATTEMPTS) {
            lockTarget.run();
          }
          boolean recordedFailure =
              refreshRepository.recordFailure(
                  id, sourceRevision, Instant.now().plus(delay), recorded);
          if (recordedFailure && attempts >= MAX_ATTEMPTS) {
            abandon.run();
          }
          return null;
        });
    if (attempts >= MAX_ATTEMPTS) {
      LOG.warnf(
          e,
          "HD elevation of %s given up after %d attempts, it stays on the fast profile",
          target,
          attempts);
    } else {
      LOG.infof(
          "HD elevation of %s failed (attempt %d), next try in %s: %s",
          target, attempts, delay, recorded);
    }
    return Outcome.FAILED;
  }

  // ------------------------------------------------------------------ previews

  /** Runs the three phases for a claimed preview request; a failure is recorded, never thrown. */
  public Outcome processPreview(PreviewClaim claim) {
    PreviewRecomputed recomputed;
    try {
      Outcome stale = realignPreviewIfStale(claim);
      if (stale != null) {
        return stale;
      }
      recomputed = computePreview(claim);
    } catch (Exception e) {
      return failPreview(claim, e);
    }
    try {
      return writePreview(claim, recomputed);
    } catch (Exception e) {
      // The write transaction rolled back: its synchronisations deleted the new files
      return failPreview(claim, e);
    }
  }

  /**
   * Before reading anything: whether the preview is no longer on the requested revision. A save by
   * the previous release of a rolling deploy rewrites the flat files and leaves the revision
   * alone, a save by this one asks again; either way the old revision may be gone, and the request
   * is realigned on the current one rather than failing. A preview back on the flat layout has
   * nothing to catch up on.
   *
   * @return the outcome when the request was settled here, else null
   */
  private @Nullable Outcome realignPreviewIfStale(PreviewClaim claim) {
    return tx(
        () -> {
          GpxPreview preview = entityManager.find(GpxPreview.class, claim.previewId());
          if (preview == null) {
            return Outcome.GONE;
          }
          Long current = preview.getFilesRevision();
          if (current != null && current == claim.sourceRevision()) {
            return null;
          }
          if (current == null) {
            // The previous release rewrote the preview flat, in HD: it must not stay FAST/PENDING
            preview.setElevationState(ElevationState.HD);
            refreshRepository.delete("id", claim.id());
            return Outcome.GONE;
          }
          if (isHd(preview.getElevationState())) {
            // Saved in HD since (the switch was off): nothing to catch up on
            refreshRepository.delete("id", claim.id());
            return Outcome.GONE;
          }
          preview.setElevationState(ElevationState.PENDING);
          Instant now = Instant.now();
          refreshRepository.realign(claim.id(), current, now, now.plus(quiet));
          LOG.debugf(
              "Preview %d changed since its HD elevation was requested, request realigned",
              claim.previewId());
          return Outcome.REALIGNED;
        });
  }

  /**
   * Phase 2 for a preview, no transaction: reads the original of the requested revision, recomputes
   * it in HD and uploads the original (same bytes), the new filtered GPX and the FIT under a
   * revision of their own.
   */
  PreviewRecomputed computePreview(PreviewClaim claim) throws IOException {
    record PreviewSources(UUID publicId, List<PreviewWaypointDetail> waypoints, Float distance) {}
    PreviewSources sources =
        tx(
            () -> {
              GpxPreview preview = entityManager.find(GpxPreview.class, claim.previewId());
              return preview == null
                  ? null
                  : new PreviewSources(
                      preview.getPublicId(), preview.readableWaypoints(), preview.getDistance());
            });
    if (sources == null) {
      throw new IllegalStateException("Preview " + claim.previewId() + " is gone");
    }
    UUID publicId = sources.publicId();
    long revision = GpxPreviewService.newRevision();
    Path originalFile =
        download(GpxPreviewService.trackKey(publicId, claim.sourceRevision(), "original.gpx"));
    try {
      GpxDocument original = gpxProcessingService.parseGpx(originalFile);
      // The original file carries no waypoint: the stored ones are placed again (WEB-100, C3c)
      GpxDocument gpx = GpxModelJvm.document(original.getTracks(), original.getName(), List.of());
      WaypointPlan plan =
          new WaypointPlan(
              PreviewWaypoints.drafts(sources.waypoints(), sources.distance(), true, d -> true),
              false);
      try (ComputedGpx computed = gpxProcessingService.computeGpx(gpx, ElevationQuality.HD, plan)) {
        if (computed.fallbackAfterErrorKm() > 0) {
          throw new ElevationUnavailableException(
              "HD elevation unavailable for %.2f km of the track"
                  .formatted(computed.fallbackAfterErrorKm()));
        }
        gpxPreviewService.uploadTrackFilesForRefresh(
            publicId, revision, originalFile.toFile(), computed.filteredGpx(), computed.fitFile());
        return new PreviewRecomputed(
            publicId,
            revision,
            GpxPreviewService.toPreviewTracks(computed),
            computed.aggregated(),
            sources.waypoints(),
            PreviewWaypoints.toDetails(computed.waypoints()));
      }
    } catch (Exception e) {
      gpxPreviewService.deleteTrackFiles(publicId, revision);
      throw e;
    } finally {
      Files.deleteIfExists(originalFile);
    }
  }

  /**
   * Phase 3 for a preview, a short transaction: locks the preview and checks it is still on the
   * revision that was read. If so the new revision, tracks, figures and quality replace the fast
   * ones and the old files go after commit; if not (saved again meanwhile) nothing is written, the
   * new files are deleted and the request is realigned on the current revision.
   */
  Outcome writePreview(PreviewClaim claim, PreviewRecomputed recomputed) {
    return tx(
        () -> {
          UUID publicId = recomputed.publicId();
          // First, so that whatever happens below the new files do not outlive a rollback
          gpxPreviewService.deleteTrackFilesUnlessCommitted(publicId, recomputed.revision());
          GpxPreview preview =
              entityManager.find(
                  GpxPreview.class, claim.previewId(), LockModeType.PESSIMISTIC_WRITE);
          if (preview == null) {
            gpxPreviewService.deleteTrackFilesAfterCommit(publicId, recomputed.revision());
            return Outcome.GONE;
          }
          Long current = preview.getFilesRevision();
          if (current == null) {
            gpxPreviewService.deleteTrackFilesAfterCommit(publicId, recomputed.revision());
            preview.setElevationState(ElevationState.HD);
            refreshRepository.delete("id", claim.id());
            return Outcome.GONE;
          }
          if (current != claim.sourceRevision()) {
            gpxPreviewService.deleteTrackFilesAfterCommit(publicId, recomputed.revision());
            if (isHd(preview.getElevationState())) {
              refreshRepository.delete("id", claim.id());
              return Outcome.GONE;
            }
            preview.setElevationState(ElevationState.PENDING);
            Instant now = Instant.now();
            refreshRepository.realign(claim.id(), current, now, now.plus(quiet));
            LOG.debugf(
                "Preview %d changed during its HD elevation compute, request realigned",
                claim.previewId());
            return Outcome.REALIGNED;
          }
          if (!PreviewWaypoints.sameIgnoringDistance(
              preview.readableWaypoints(), recomputed.usedWaypoints())) {
            // The waypoints were edited during the compute: what was placed is stale
            gpxPreviewService.deleteTrackFilesAfterCommit(publicId, recomputed.revision());
            Instant now = Instant.now();
            refreshRepository.realign(claim.id(), current, now, now);
            LOG.debugf(
                "Waypoints of preview %d changed during its HD elevation compute, request"
                    + " realigned",
                claim.previewId());
            return Outcome.REALIGNED;
          }
          TrackMetadata metadata = recomputed.metadata();
          preview.setFilesRevision(recomputed.revision());
          // The waypoints follow the track onto its new revision, with the distances of the HD one
          // (WEB-100, C3c)
          preview.setWaypointDetails(
              new PreviewWaypointsDocument(recomputed.revision(), recomputed.placedWaypoints()));
          preview.setWaypoints(PreviewWaypoints.legacy(recomputed.placedWaypoints()));
          // The planner state follows the track it describes onto its new revision (WEB-100, C4a):
          // the catch-up changes the elevations and the simplification, not the drawing.
          PlannerStateDocument planner = preview.getPlannerState();
          if (planner != null && planner.trackRevision() == claim.sourceRevision()) {
            preview.setPlannerState(planner.withTrackRevision(recomputed.revision()));
          }
          // The surface follows the track onto its new revision too (WEB-100, C1b): the catch-up
          // changes the elevations and the simplification, not the 2D track; the spans rescale on
          // read.
          PreviewSurfacesDocument surfaces = preview.getSurfaces();
          if (surfaces != null && surfaces.trackRevision() == claim.sourceRevision()) {
            preview.setSurfaces(surfaces.withTrackRevision(recomputed.revision()));
          }
          // The raw lines follow the track onto its new revision, unchanged: the catch-up never
          // changes the source 2D track (docs/LEDGER_*.md API-147)
          PreviewRawLinesDocument rawLines = preview.getRawLines();
          if (rawLines != null && rawLines.trackRevision() == claim.sourceRevision()) {
            preview.setRawLines(rawLines.withTrackRevision(recomputed.revision()));
          }
          // A request still waiting for the old revision follows it
          surfaceRefreshRepository.forwardPreviewRevision(
              claim.previewId(), claim.sourceRevision(), recomputed.revision());
          preview.setTracks(recomputed.tracks());
          preview.setDistance(metadata.distance());
          preview.setElevationGain(metadata.elevationGain());
          preview.setElevationLoss(metadata.elevationLoss());
          preview.setHilliness(metadata.hilliness());
          preview.setElevationState(ElevationState.HD);
          gpxPreviewService.deleteTrackFilesAfterCommit(publicId, current);
          refreshRepository.deleteIfRevision(claim.id(), claim.sourceRevision());
          return Outcome.REFRESHED;
        });
  }

  private static <T> T tx(Callable<T> work) {
    return QuarkusTransaction.requiringNew().call(work);
  }
}
