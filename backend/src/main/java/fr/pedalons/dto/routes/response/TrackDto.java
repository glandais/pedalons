package fr.pedalons.dto.routes.response;

import static org.geolatte.geom.builder.DSL.*;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.WGS84;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.addLinearSystem;
import static org.geolatte.geom.crs.CoordinateReferenceSystems.addVerticalSystem;

import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.dto.common.GeoJsonLineString;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.service.route.ClimbNaming;
import fr.pedalons.service.route.ClimbNaming.NamedPoint;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.geolatte.geom.G3D;
import org.geolatte.geom.G3DM;
import org.geolatte.geom.LineString;
import org.geolatte.geom.crs.CoordinateReferenceSystem;
import org.geolatte.geom.crs.LinearUnit;

/**
 * GPX Track DTO with track points for frontend rendering.
 */
@Schema(description = "GPX track with track points")
@ValidateSchema
public record TrackDto(
    @Schema(implementation = GeoJsonLineString.class, required = true) LineString<G3DM> line,
    @Schema(description = "List of climbs on the route", required = true) List<ClimbDto> climbs) {

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
    return of(track.getTrackPoints(), track.getClimbs(), waypoints);
  }

  /** Builds a track DTO straight from computed points and climbs, with no entity involved. */
  public static TrackDto of(
      List<GpxTrack.TrackPoint> trackPoints, List<ClimbData> climbs, List<NamedPoint> waypoints) {
    G3DM[] geomPoints =
        trackPoints.stream().map(p -> g(p.lng(), p.lat(), p.ele(), p.dist())).toArray(G3DM[]::new);
    LineString<G3DM> line = linestring(WGS84_3DM, geomPoints);
    return new TrackDto(
        line,
        climbs.stream()
            .map(climb -> ClimbDto.from(climb, ClimbNaming.nameOf(climb, trackPoints, waypoints)))
            .toList());
  }
}
