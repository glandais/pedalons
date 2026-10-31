package fr.pedalons.dto.routes.response;

import static org.geolatte.geom.builder.DSL.*;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.addLinearSystem;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.addVerticalSystem;

import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.dto.common.GeoJsonLineString;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.TrackSurfaceState;
import fr.pedalons.service.route.ClimbNaming;
import fr.pedalons.service.route.ClimbNaming.NamedPoint;
import fr.pedalons.service.surface.TrackSurfaceReadout;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.geolatte.geom.G3D;
import org.geolatte.geom.G3DM;
import org.geolatte.geom.LineString;
import org.geolatte.geom.crs.CoordinateReferenceSystem;
import org.geolatte.geom.crs.LinearUnit;
import org.jspecify.annotations.Nullable;

/**
 * GPX Track DTO with track points for frontend rendering.
 */
@Schema(description = "GPX track with track points")
@ValidateSchema
public record TrackDto(
    @Schema(implementation = GeoJsonLineString.class, required = true) LineString<G3DM> line,
    @Schema(description = "List of climbs on the route", required = true) List<ClimbDto> climbs,
    @Nullable
        @Schema(
            description =
                "Where the surface of the track stands. Absent: never computed (a track saved"
                    + " before the feature, or the feature off), or not included (bulk endpoint"
                    + " with geometry=false, which carries no track)")
        TrackSurfaceState surfaceState,
    @Nullable
        @Schema(
            description =
                "Surface along the track when surfaceState is READY: contiguous spans from 0 to the"
                    + " track's length, adjacent spans of the same class merged. Derived from"
                    + " OpenStreetMap (© OpenStreetMap contributors, ODbL), VersaTiles vector"
                    + " tiles")
        List<SurfaceSpanDto> surfaces) {

  private static final CoordinateReferenceSystem<G3DM> WGS84_3DM =
      addLinearSystem(
          addVerticalSystem(WGS84, G3D.class, LinearUnit.METER), G3DM.class, LinearUnit.METER);

  /**
   * The stored track, points and climbs untouched.
   *
   * <p>There is no read-time decimation any more, and deliberately so: the points reaching this
   * method were already resampled to ~10 m and run through Douglas-Peucker at import time ({@code
   * GpxProcessingService.computeGpx}), which lands them at roughly one point every 90 m. A second,
   * purely 2D pass on read bought almost nothing on that data and cost the thing clients actually
   * need — it decides on horizontal deviation alone, so it shaves summits off the elevation the
   * same coordinates carry in their Z and M ordinates.
   */
  public static TrackDto from(GpxTrack track) {
    return from(track, List.of());
  }

  /**
   * @param waypoints the route's waypoints, which name the climbs whose top they mark ({@link
   *     ClimbNaming}, docs/LEDGER_*.md API-10)
   */
  public static TrackDto from(GpxTrack track, List<NamedPoint> waypoints) {
    return from(track, waypoints, TrackSurfaceReadout.NONE);
  }

  /** As {@link #from(GpxTrack, List)}, with the surface of the track (docs/LEDGER_*.md WEB-100, C1b). */
  public static TrackDto from(
      GpxTrack track, List<NamedPoint> waypoints, TrackSurfaceReadout surface) {
    return of(track.getTrackPoints(), track.getClimbs(), waypoints, surface);
  }

  /**
   * The elevation and the distance of a point as sent: to the decimetre. They are stored with every
   * digit of a double (« 112.48006398245862 »), which made them half of a long route's payload — and
   * of its page, whose SSR state carries the track (docs/LEDGER_*.md API-145). The climbs are
   * bounded to the metre and the surface spans to the decimetre already, so nothing a client
   * compares with these distances moves.
   */
  static double decimetre(double metres) {
    return Math.round(metres * 10) / 10.0;
  }

  /**
   * A longitude or latitude as sent: to the millionth of a degree, 11 cm of latitude and less of
   * longitude — the decimetre of {@link #decimetre}. Most points come with the seven decimals of
   * their GPX, a recomputed one with every digit of a double.
   */
  static double microdegree(double degrees) {
    return Math.round(degrees * 1e6) / 1e6;
  }

  /** Builds a track DTO straight from computed points and climbs, with no entity involved. */
  public static TrackDto of(
      List<GpxTrack.TrackPoint> trackPoints, List<ClimbData> climbs, List<NamedPoint> waypoints) {
    return of(trackPoints, climbs, waypoints, TrackSurfaceReadout.NONE);
  }

  /** As {@link #of(List, List, List)}, with the surface of the track (docs/LEDGER_*.md WEB-100, C1b). */
  public static TrackDto of(
      List<GpxTrack.TrackPoint> trackPoints,
      List<ClimbData> climbs,
      List<NamedPoint> waypoints,
      TrackSurfaceReadout surface) {
    G3DM[] geomPoints =
        trackPoints.stream()
            .map(
                p ->
                    g(
                        microdegree(p.lng()),
                        microdegree(p.lat()),
                        decimetre(p.ele()),
                        decimetre(p.dist())))
            .toArray(G3DM[]::new);
    LineString<G3DM> line = linestring(WGS84_3DM, geomPoints);
    return new TrackDto(
        line,
        climbs.stream()
            .map(climb -> ClimbDto.from(climb, ClimbNaming.nameOf(climb, trackPoints, waypoints)))
            .toList(),
        surface.state(),
        surface.spans(trackPoints.isEmpty() ? 0 : trackPoints.getLast().dist()));
  }
}
