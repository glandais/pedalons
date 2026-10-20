package fr.pedalons.service.surface;

import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.PreviewSurfacesDocument;
import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.domain.route.PlannerStateDocument;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.enums.AssetType;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.repository.route.GpxTrackRepository.TrackPoints;
import fr.pedalons.repository.route.SurfaceRefreshRepository;
import fr.pedalons.repository.route.SurfaceRefreshRepository.Claim;
import fr.pedalons.repository.route.SurfaceRefreshRepository.PreviewClaim;
import fr.pedalons.service.route.planner.PlannerStates;
import fr.pedalons.service.route.planner.PlannerStates.DirectRuns;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.Callable;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * The surface along the saved tracks (docs/LEDGER_*.md WEB-100, C1b): the request made in the saving
 * transaction, the three phases {@link SurfaceRefreshWorker} runs — <b>claim</b>, <b>compute</b>
 * (no transaction, the call to the provider) and <b>write</b> (a short transaction that checks the
 * track is still the one computed) — and the reads of the API. Modelled on {@code
 * ElevationRefreshService}, whose queue and phases it repeats.
 *
 * <p>The token of a request is the {@code file_id} of a route's original GPX, the {@code
 * files_revision} of a preview: a result computed for another one is never written, the request is
 * moved to the current one instead. A request that fails five times stays in its table for
 * diagnosis, and no document is written: the API then says nothing, neither pending nor ready.
 *
 * <p>The phases are separate, package-visible methods so a test can change the track between
 * compute and write.
 */
@ApplicationScoped
public class SurfaceRefreshService {

  private static final Logger LOG = Logger.getLogger(SurfaceRefreshService.class);

  /** After this many failed attempts a request stays in the table, untouched, and is logged once. */
  public static final int MAX_ATTEMPTS = 5;

  /** How long a claim holds a request: well above one track's compute, short enough to recover. */
  static final Duration LEASE = Duration.ofMinutes(10);

  /** Delay before the next attempt, indexed by the attempts already made. */
  static final List<Duration> BACKOFF =
      List.of(
          Duration.ofMinutes(2), Duration.ofMinutes(10), Duration.ofHours(1), Duration.ofHours(6));

  private static final int MAX_ERROR_LENGTH = 500;

  /** What became of a claimed request. */
  public enum Outcome {
    /** The surface was written and the request removed. */
    REFRESHED,
    /** The track changed during the compute: nothing written, request moved to the new revision. */
    REALIGNED,
    /** The target is gone. */
    GONE,
    /** The attempt failed: backoff, or given up. */
    FAILED
  }

  /** One track to send. */
  record TrackInput(
      @Nullable Long trackId, List<TrackPoint> points, String costing, List<double[]> offNetwork) {}

  /** What the first phase found: the request settled there, or the tracks to compute. */
  private record Read(@Nullable Outcome settled, List<TrackInput> inputs) {
    static Read settled(Outcome outcome) {
      return new Read(outcome, List.of());
    }
  }

  /** The documents of a computed target, in the order of its tracks. */
  record Computed(List<@Nullable Long> trackIds, List<TrackSurfaceDocument> documents) {}

  /**
   * Whether a save queues a request and the worker sends it. Off, nothing is asked and nothing
   * sent (the queue waits): the switch that stops the spending.
   */
  @ConfigProperty(name = "pedalons.surface.enabled", defaultValue = "true")
  boolean enabled;

  /** How long a track must stay unmodified before its surface is computed. */
  @ConfigProperty(name = "pedalons.surface.quiet", defaultValue = "PT90S")
  Duration quiet;

  /** The longest a stream of saves can postpone the computation, from the first of them. */
  @ConfigProperty(name = "pedalons.surface.max-wait", defaultValue = "PT10M")
  Duration maxWait;

  /** Only asked whether it is set: never logged, never put in an error. */
  @ConfigProperty(name = "pedalons.routing.stadiamaps.api-key")
  Optional<String> apiKey;

  private boolean keyOverride;

  @Inject SurfaceRefreshRepository refreshRepository;
  @Inject TraceSurfaceComputer computer;
  @Inject AssetRepository assetRepository;
  @Inject GpxTrackRepository gpxTrackRepository;
  @Inject GpxPreviewRepository gpxPreviewRepository;
  @Inject PlannerStates plannerStates;
  @Inject EntityManager entityManager;

  /** Whether the feature runs: switched on, and a key to call the provider with. */
  public boolean isEnabled() {
    return enabled && (keyOverride || apiKey.filter(k -> !k.isBlank()).isPresent());
  }

  /** For the tests: sets the switch, and stands for the key (the provider is faked). */
  public void setEnabledForTest(boolean enabled) {
    this.enabled = enabled;
    this.keyOverride = enabled;
  }

  // ------------------------------------------------------------------ request

  /**
   * Asks for the surface of a route's track, in the saving transaction (so the request exists
   * exactly when the track does), or postpones the pending one. No-op when the feature is off.
   *
   * @param originalFileId the {@code file_id} of the route's original GPX after the save
   */
  public void requestRoute(Route route, long originalFileId) {
    if (isEnabled()) {
      refreshRepository.requestForRoute(
          route.getId(), originalFileId, Instant.now(), quiet, maxWait);
    }
  }

  /**
   * As {@link #requestRoute}, for a GPX-tool preview, in the saving transaction and after the
   * preview row is flushed.
   *
   * @param filesRevision the preview's {@code files_revision} after the save
   */
  public void requestPreview(Long previewId, long filesRevision) {
    if (isEnabled()) {
      refreshRepository.requestForPreview(previewId, filesRevision, Instant.now(), quiet, maxWait);
    }
  }

  /**
   * Drops the normal request a bulk import (the biketeam migration) just made for a route, so that
   * the capped catch-up takes it (C1c), in the caller's transaction. No-op when the feature is off.
   */
  public void leaveToBackfill(Long routeId) {
    if (isEnabled()) {
      refreshRepository.dropNormalRequest(routeId);
    }
  }

  // ------------------------------------------------------------------ read

  /** The surfaces of a route's tracks, for its detail: a projection and one existence query. */
  public RouteSurfaces readRoute(Long routeId) {
    Map<Long, TrackSurfaceDocument> documents = gpxTrackRepository.findSurfaces(routeId);
    boolean pending = isEnabled() && refreshRepository.isPendingForRoute(routeId, MAX_ATTEMPTS);
    return new RouteSurfaces(documents, pending);
  }

  /**
   * The surfaces of a batch of routes, for the bulk: the same two queries whatever the number of
   * routes (the page rule). Every requested id has an entry; no pending query when the feature is
   * off.
   */
  public Map<Long, RouteSurfaces> readRoutes(Collection<Long> routeIds) {
    if (routeIds.isEmpty()) {
      return Map.of();
    }
    Map<Long, Map<Long, TrackSurfaceDocument>> documents =
        gpxTrackRepository.findSurfacesByRouteIds(routeIds);
    Set<Long> pending =
        isEnabled()
            ? refreshRepository.findPendingRouteIds(routeIds, MAX_ATTEMPTS)
            : Collections.emptySet();
    Map<Long, RouteSurfaces> out = new HashMap<>();
    for (Long id : routeIds) {
      out.put(id, new RouteSurfaces(documents.getOrDefault(id, Map.of()), pending.contains(id)));
    }
    return out;
  }

  /**
   * The surface of each track of a preview, in order: its document when it still describes the
   * current tracks (same revision, same number of tracks), else nothing, and pending while a
   * request is queued.
   */
  public List<TrackSurfaceReadout> readPreview(GpxPreview preview) {
    int tracks = preview.getTracks().size();
    PreviewSurfacesDocument document = gpxPreviewRepository.findSurfaces(preview.getId());
    Long revision = preview.getFilesRevision();
    boolean readable =
        document != null
            && revision != null
            && document.trackRevision() == revision
            && document.tracks().size() == tracks;
    boolean pending =
        isEnabled() && refreshRepository.isPendingForPreview(preview.getId(), MAX_ATTEMPTS);
    List<TrackSurfaceReadout> out = new ArrayList<>(tracks);
    for (int i = 0; i < tracks; i++) {
      out.add(new TrackSurfaceReadout(readable ? document.tracks().get(i) : null, pending));
    }
    return out;
  }

  /**
   * What a preview that was just saved shows: a computation to come for each track, none read
   * (the entity is detached, and the request is made but not due yet).
   */
  public List<TrackSurfaceReadout> pendingReadouts(int tracks) {
    return Collections.nCopies(tracks, new TrackSurfaceReadout(null, isEnabled()));
  }

  // ------------------------------------------------------------------ claim

  /**
   * Takes the next due route request, in a transaction of its own. {@code backfill} picks the
   * catch-up's requests (C1c) or the normal ones.
   */
  public Optional<Claim> claimNext(Instant now, boolean backfill) {
    return tx(() -> refreshRepository.claimNextRoute(now, now.plus(LEASE), MAX_ATTEMPTS, backfill));
  }

  /** Takes the next due preview request, in a transaction of its own. */
  public Optional<PreviewClaim> claimNextPreview(Instant now, boolean backfill) {
    return tx(
        () -> refreshRepository.claimNextPreview(now, now.plus(LEASE), MAX_ATTEMPTS, backfill));
  }

  // ------------------------------------------------------------------ one route

  /** Runs the three phases for a claimed route request; a failure is recorded, never thrown. */
  public Outcome process(Claim claim) {
    Read read;
    Computed computed;
    try {
      read = tx(() -> readRoute(claim));
      if (read.settled() != null) {
        return read.settled();
      }
      computed = compute(read.inputs());
    } catch (Exception e) {
      return fail(
          claim.id(), claim.sourceRevision(), claim.attempts(), "route " + claim.routeId(), e);
    }
    try {
      return writeRoute(claim, computed);
    } catch (Exception e) {
      return fail(
          claim.id(), claim.sourceRevision(), claim.attempts(), "route " + claim.routeId(), e);
    }
  }

  /**
   * Phase 1, a short transaction: the track must still be the requested revision (a save that made
   * no request — the previous release of a rolling deploy — has replaced it: the request is moved
   * on the current one), then its points, and its planner state when that still describes it.
   */
  private Read readRoute(Claim claim) {
    Long current = assetRepository.findCurrentFileId(claim.routeId(), AssetType.ROUTE_ORIGINAL_GPX);
    if (current == null) {
      refreshRepository.delete("id", claim.id());
      return Read.settled(Outcome.GONE);
    }
    if (current != claim.sourceRevision()) {
      realign(claim.id(), current);
      return Read.settled(Outcome.REALIGNED);
    }
    List<TrackPoints> tracks = gpxTrackRepository.findPoints(claim.routeId());
    PlannerState state = null;
    if (tracks.size() == 1) {
      List<@Nullable PlannerStateDocument> states =
          gpxTrackRepository.findPlannerStates(claim.routeId());
      PlannerStateDocument document = states.size() == 1 ? states.getFirst() : null;
      if (document != null && document.trackRevision() == current) {
        state = document.state();
      }
    }
    List<TrackInput> inputs = new ArrayList<>(tracks.size());
    for (TrackPoints t : tracks) {
      inputs.add(input(t.trackId(), t.points(), state));
    }
    return new Read(null, inputs);
  }

  /**
   * Phase 3, a short transaction: locks the route and checks its original is still the revision
   * that was computed, and its tracks the ones computed. If not (saved again during the compute,
   * or by the previous release) nothing is written and the request is moved to the current
   * revision.
   */
  Outcome writeRoute(Claim claim, Computed computed) {
    return tx(
        () -> {
          Route route =
              entityManager.find(Route.class, claim.routeId(), LockModeType.PESSIMISTIC_WRITE);
          if (route == null) {
            return Outcome.GONE;
          }
          Long current =
              assetRepository.findCurrentFileId(claim.routeId(), AssetType.ROUTE_ORIGINAL_GPX);
          List<Long> trackIds =
              gpxTrackRepository
                  .findIdsByRouteIds(List.of(claim.routeId()))
                  .getOrDefault(claim.routeId(), List.of());
          if (current == null) {
            refreshRepository.delete("id", claim.id());
            return Outcome.GONE;
          }
          if (current != claim.sourceRevision() || !trackIds.equals(computed.trackIds())) {
            realign(claim.id(), current);
            return Outcome.REALIGNED;
          }
          for (int i = 0; i < trackIds.size(); i++) {
            gpxTrackRepository.updateSurfaces(trackIds.get(i), computed.documents().get(i));
          }
          refreshRepository.deleteIfRevision(claim.id(), claim.sourceRevision());
          return Outcome.REFRESHED;
        });
  }

  // ------------------------------------------------------------------ one preview

  /** Runs the three phases for a claimed preview request; a failure is recorded, never thrown. */
  public Outcome processPreview(PreviewClaim claim) {
    Read read;
    Computed computed;
    try {
      read = tx(() -> readPreview(claim));
      if (read.settled() != null) {
        return read.settled();
      }
      computed = compute(read.inputs());
    } catch (Exception e) {
      return fail(
          claim.id(), claim.sourceRevision(), claim.attempts(), "preview " + claim.previewId(), e);
    }
    try {
      return writePreview(claim, computed);
    } catch (Exception e) {
      return fail(
          claim.id(), claim.sourceRevision(), claim.attempts(), "preview " + claim.previewId(), e);
    }
  }

  private Read readPreview(PreviewClaim claim) {
    GpxPreview preview = entityManager.find(GpxPreview.class, claim.previewId());
    if (preview == null) {
      return Read.settled(Outcome.GONE);
    }
    Long current = preview.getFilesRevision();
    if (current == null) {
      refreshRepository.delete("id", claim.id());
      return Read.settled(Outcome.GONE);
    }
    if (current != claim.sourceRevision()) {
      realign(claim.id(), current);
      return Read.settled(Outcome.REALIGNED);
    }
    PlannerState state = null;
    PlannerStateDocument document = preview.getPlannerState();
    if (preview.getTracks().size() == 1
        && document != null
        && document.trackRevision() == current) {
      state = document.state();
    }
    List<TrackInput> inputs = new ArrayList<>(preview.getTracks().size());
    for (GpxPreview.PreviewTrack t : preview.getTracks()) {
      inputs.add(input(null, t.trackPoints(), state));
    }
    return new Read(null, inputs);
  }

  /** As {@link #writeRoute}, for a preview: one document holding every track's, with the revision. */
  Outcome writePreview(PreviewClaim claim, Computed computed) {
    return tx(
        () -> {
          GpxPreview preview =
              entityManager.find(
                  GpxPreview.class, claim.previewId(), LockModeType.PESSIMISTIC_WRITE);
          if (preview == null) {
            return Outcome.GONE;
          }
          Long current = preview.getFilesRevision();
          if (current == null) {
            refreshRepository.delete("id", claim.id());
            return Outcome.GONE;
          }
          if (current != claim.sourceRevision()
              || preview.getTracks().size() != computed.documents().size()) {
            realign(claim.id(), current);
            return Outcome.REALIGNED;
          }
          preview.setSurfaces(
              new PreviewSurfacesDocument(
                  claim.sourceRevision(), new ArrayList<>(computed.documents())));
          refreshRepository.deleteIfRevision(claim.id(), claim.sourceRevision());
          return Outcome.REFRESHED;
        });
  }

  // ------------------------------------------------------------------ shared

  /**
   * The costing and the straight pieces of a track, from the planner state when it describes it
   * (one track, a current token): a state-less track — a file — is cycled.
   */
  private TrackInput input(
      @Nullable Long trackId, List<TrackPoint> points, @Nullable PlannerState state) {
    if (state == null) {
      return new TrackInput(trackId, points, TraceSurfaceComputer.costingOf(null), List.of());
    }
    DirectRuns direct = plannerStates.directRuns(state);
    double stored = points.isEmpty() ? 0 : points.getLast().dist();
    List<double[]> runs = new ArrayList<>(direct.runs().size());
    if (direct.length() > 0 && stored > 0) {
      // The pipeline resamples and simplifies the derived line: the lengths differ by a few
      // metres at most, and the runs follow proportionally
      double scale = stored / direct.length();
      for (double[] run : direct.runs()) {
        runs.add(new double[] {run[0] * scale, run[1] * scale});
      }
    }
    return new TrackInput(trackId, points, TraceSurfaceComputer.costingOf(state.profile()), runs);
  }

  /** Phase 2, no transaction: the calls to the provider. */
  Computed compute(List<TrackInput> inputs) {
    Instant now = Instant.now();
    List<@Nullable Long> ids = new ArrayList<>(inputs.size());
    List<TrackSurfaceDocument> documents = new ArrayList<>(inputs.size());
    for (TrackInput input : inputs) {
      ids.add(input.trackId());
      documents.add(computer.compute(input.points(), input.costing(), input.offNetwork(), now));
    }
    return new Computed(ids, documents);
  }

  private void realign(Long id, long current) {
    Instant now = Instant.now();
    refreshRepository.realign(id, current, now, now.plus(quiet));
    LOG.debugf("Track of request %d changed before its surface was written, request realigned", id);
  }

  /**
   * Records a failed attempt: one more, the next one after the backoff, the lease released. After
   * {@value #MAX_ATTEMPTS} attempts the request stays as it is for diagnosis and is logged once;
   * nothing is written for the target.
   */
  Outcome fail(Long id, long sourceRevision, int made, String target, Exception e) {
    int attempts = made + 1;
    Duration delay = BACKOFF.get(Math.min(made, BACKOFF.size() - 1));
    String error = e.getClass().getSimpleName() + ": " + e.getMessage();
    if (error.length() > MAX_ERROR_LENGTH) {
      error = error.substring(0, MAX_ERROR_LENGTH);
    }
    String recorded = error;
    tx(
        () ->
            refreshRepository.recordFailure(
                id, sourceRevision, Instant.now().plus(delay), recorded));
    if (attempts >= MAX_ATTEMPTS) {
      LOG.warnf("Surface of %s given up after %d attempts: %s", target, attempts, recorded);
    } else {
      LOG.infof(
          "Surface of %s failed (attempt %d), next try in %s: %s",
          target, attempts, delay, recorded);
    }
    return Outcome.FAILED;
  }

  private static <T> T tx(Callable<T> work) {
    return QuarkusTransaction.requiringNew().call(work);
  }
}
