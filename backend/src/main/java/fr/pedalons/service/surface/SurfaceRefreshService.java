package fr.pedalons.service.surface;

import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.PreviewSurfacesDocument;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.enums.ElevationState;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.service.route.planner.PlannerStates;
import fr.pedalons.service.route.planner.PlannerStates.DirectRuns;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;

/**
 * The surface along the saved tracks (docs/LEDGER_*.md WEB-100, C1b): the switch, and the reads of
 * the API.
 *
 * <p>The surface is written by the HD catch-up with the profile, from the same answer of
 * osm-route-details ({@code ElevationRefreshService}, docs/LEDGER_*.md API-150), and a track
 * waiting for it reads as pending through its {@code elevation_state}, and through nothing else: a
 * row left in {@code surface_refresh} by a previous release is never read here.
 */
@ApplicationScoped
public class SurfaceRefreshService {

  /**
   * Whether the surface is computed at all: off, the HD catch-up leaves it out, and nothing reads
   * as pending. The stored documents are still served.
   */
  @ConfigProperty(name = "pedalons.surface.enabled", defaultValue = "true")
  boolean enabled;

  @Inject GpxTrackRepository gpxTrackRepository;
  @Inject GpxPreviewRepository gpxPreviewRepository;
  @Inject PlannerStates plannerStates;

  /** Whether the feature runs. */
  public boolean isEnabled() {
    return enabled;
  }

  /** For the tests: sets the switch (the provider is faked). */
  public void setEnabledForTest(boolean enabled) {
    this.enabled = enabled;
  }

  /**
   * The surfaces of a route's tracks, for its detail: a projection. Pending while its HD catch-up,
   * which writes the surface, is to come: {@code elevation_state} is {@code PENDING} exactly as
   * long as an HD request is open, and reading it from the entity costs no query.
   */
  public RouteSurfaces readRoute(Route route) {
    Map<Long, TrackSurfaceDocument> documents = gpxTrackRepository.findSurfaces(route.getId());
    return new RouteSurfaces(documents, awaited(route.getElevationState()));
  }

  /**
   * The surfaces of a batch of routes, for the bulk: one query whatever the number of routes (the
   * page rule). Every requested id has an entry.
   */
  public Map<Long, RouteSurfaces> readRoutes(Collection<Route> routes) {
    if (routes.isEmpty()) {
      return Map.of();
    }
    List<Long> routeIds = routes.stream().map(Route::getId).toList();
    Map<Long, Map<Long, TrackSurfaceDocument>> documents =
        gpxTrackRepository.findSurfacesByRouteIds(routeIds);
    Map<Long, RouteSurfaces> out = new HashMap<>();
    for (Route route : routes) {
      Long id = route.getId();
      out.put(
          id,
          new RouteSurfaces(
              documents.getOrDefault(id, Map.of()), awaited(route.getElevationState())));
    }
    return out;
  }

  /**
   * The surface of each track of a preview, in order: its document when it still describes the
   * current tracks (same revision, same number of tracks), else nothing, and pending while its HD
   * catch-up is to come, as for a route.
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
    boolean pending = awaited(preview.getElevationState());
    List<TrackSurfaceReadout> out = new ArrayList<>(tracks);
    for (int i = 0; i < tracks; i++) {
      out.add(new TrackSurfaceReadout(readable ? document.tracks().get(i) : null, pending));
    }
    return out;
  }

  /**
   * What a preview that was just saved shows, with no query: the document of a track when the save
   * computed one, and a computation to come while its HD catch-up is.
   *
   * @param docs one per track, computed by the save; null when it computed none
   * @param state the elevation state of the save
   */
  public List<TrackSurfaceReadout> savedReadouts(
      @Nullable List<@Nullable TrackSurfaceDocument> docs,
      int tracks,
      @Nullable ElevationState state) {
    boolean pending = awaited(state);
    List<TrackSurfaceReadout> out = new ArrayList<>(tracks);
    for (int i = 0; i < tracks; i++) {
      out.add(new TrackSurfaceReadout(docs == null ? null : docs.get(i), pending));
    }
    return out;
  }

  /**
   * The straight pieces of a planner state, {@code [from, to]} metres along a stored track of
   * length {@code stored}.
   */
  public List<double[]> offNetworkRuns(PlannerState state, double stored) {
    DirectRuns direct = plannerStates.directRuns(state);
    List<double[]> runs = new ArrayList<>(direct.runs().size());
    if (direct.length() > 0 && stored > 0) {
      // The pipeline resamples and simplifies the derived line: the lengths differ by a few
      // metres at most, and the runs follow proportionally. They stay on the stored points even
      // when the raw line is sent: the answer is carried there before they are laid over it
      double scale = stored / direct.length();
      for (double[] run : direct.runs()) {
        runs.add(new double[] {run[0] * scale, run[1] * scale});
      }
    }
    return runs;
  }

  /** Whether a track in this state still has its surface to come. */
  private boolean awaited(@Nullable ElevationState state) {
    return isEnabled() && state == ElevationState.PENDING;
  }
}
