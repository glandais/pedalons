package fr.pedalons.service.router;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.router.request.LineElevationRequest;
import fr.pedalons.dto.router.request.StraightLine;
import fr.pedalons.dto.router.response.GpxImportTrack;
import fr.pedalons.dto.router.response.LineElevationResponse;
import fr.pedalons.enums.ElevationQuality;
import fr.pedalons.service.route.GpxLimits;
import fr.pedalons.service.route.GpxPipeline;
import fr.pedalons.service.route.planner.PolylineCodec;
import fr.pedalons.service.security.annotation.Logged;
import io.github.glandais.elevation.CoordinatesElevation;
import io.github.glandais.elevation.LatLonElevation;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathJvm;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.ArrayList;
import java.util.List;

/**
 * The relief of the straight lines of the route editor (docs/LEDGER_*.md WEB-100, B1b): each line
 * goes through the same pipeline as a routed leg, with the FAST elevations (densified, tunnels
 * corrected, smoothed), so its ascent is comparable to theirs. Nothing is stored and the routing
 * provider is not called.
 *
 * <p>Not transactional: no connection is held while the pipeline waits for the elevation tiles.
 */
@ApplicationScoped
public class LineElevationService {

  @Inject PlannerAccess plannerAccess;

  @Inject GpxPipeline pipeline;

  @Logged
  public LineElevationResponse lineElevation(LineElevationRequest request) {
    plannerAccess.check(request.teamSlug());

    // The lengths are bound before any elevation is read.
    double total = 0.0;
    for (StraightLine line : request.lines()) {
      double meters =
          GeoDistance.haversineMeters(
              line.from().lat(), line.from().lng(), line.to().lat(), line.to().lng());
      total += meters;
      if (!(meters <= GpxLimits.MAX_STRAIGHT_LINE_METERS)
          || !(total <= GpxLimits.MAX_STRAIGHT_LINES_TOTAL_METERS)) {
        throw new BusinessException(ErrorCode.ROUTING_SEGMENT_TOO_LONG);
      }
    }

    List<GpxImportTrack> tracks = new ArrayList<>(request.lines().size());
    boolean fallback = false;
    for (StraightLine line : request.lines()) {
      List<CoordinatesElevation> coordinates =
          List.of(
              new LatLonElevation(line.from().lat(), line.from().lng(), 0.0),
              new LatLonElevation(line.to().lat(), line.to().lng(), 0.0));
      GpxPipeline.ProcessedWithClimb result =
          pipeline.processWithClimb(
              PathJvm.fromCoordinates(coordinates), "straight", ElevationQuality.FAST);
      Path path = result.processed().path();
      fallback |= result.processed().fallbackAfterErrorKm() > 0.0;
      tracks.add(
          path.getSize() >= 2
              ? PlannerTracks.toTrack(path, result.climb())
              : degenerate(line, path));
    }
    return new LineElevationResponse(tracks, fallback);
  }

  /**
   * A line shorter than the pipeline's resolution comes back as a single point: the editor still
   * gets the two ends, flat, with no ascent.
   */
  private static GpxImportTrack degenerate(StraightLine line, Path path) {
    double ele =
        path.getSize() == 1 && Double.isFinite(path.elevation(0)) ? path.elevation(0) : 0.0;
    double[][] lngLat = {
      {line.from().lng(), line.from().lat()}, {line.to().lng(), line.to().lat()}
    };
    return new GpxImportTrack(
        PolylineCodec.encode2(lngLat),
        PolylineCodec.encode1(new double[] {ele, ele}),
        PolylineCodec.encode1(new double[] {0.0, 0.0}),
        0.0,
        0.0);
  }
}
