package fr.pedalons.service.route.network;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.dto.routes.response.BoundsDto;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.GenerateRequest;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorV1.Route;
import fr.pedalons.infrastructure.valhalla.Polyline6Decoder;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The cheap geometric sanity check of each route the engine returns (lot 3b plan §4). The
 * guarantees themselves are checked by the service's independent checker; this only catches a
 * route that cannot be what was asked (a truncated answer, a wrong unit, a contract drift) before it
 * reaches a map. Pure; a failing route is dropped by the caller.
 */
final class GeneratedRouteSanity {
  private GeneratedRouteSanity() {}

  /** What a route failed at. The name is the metric label. */
  enum Check {
    DECODE,
    LENGTH,
    ENDS,
    JUMP,
    SHARES
  }

  static final int MAX_POINTS = 100_000;
  static final double LENGTH_TOLERANCE = 0.10;
  static final double ENGINE_LENGTH_TOLERANCE = 0.01;
  static final double END_RADIUS_M = 2_000;
  static final double LOOP_CLOSING_M = 50;
  static final double MAX_STEP_M = 10_000;

  /** The failed check ({@code null}: the route is sane) and the frame of the route. */
  record Verdict(@Nullable Check failed, @Nullable BoundsDto bounds) {
    boolean sane() {
      return failed == null;
    }
  }

  static Verdict check(GenerateRequest request, Route route) {
    if (!shares(route)) {
      return new Verdict(Check.SHARES, null);
    }
    List<double[]> points = decode(route.polyline());
    if (points == null) {
      return new Verdict(Check.DECODE, null);
    }
    double length = 0;
    double minLon = Double.POSITIVE_INFINITY;
    double minLat = Double.POSITIVE_INFINITY;
    double maxLon = Double.NEGATIVE_INFINITY;
    double maxLat = Double.NEGATIVE_INFINITY;
    boolean jump = false;
    double[] previous = null;
    for (double[] p : points) {
      minLon = Math.min(minLon, p[0]);
      maxLon = Math.max(maxLon, p[0]);
      minLat = Math.min(minLat, p[1]);
      maxLat = Math.max(maxLat, p[1]);
      if (previous != null) {
        double step = GeoDistance.haversineMeters(previous[1], previous[0], p[1], p[0]);
        length += step;
        jump |= step > MAX_STEP_M;
      }
      previous = p;
    }
    double asked = request.distanceM();
    if (Math.abs(length - asked) > asked * LENGTH_TOLERANCE
        || !(Math.abs(route.distanceM() - length) <= length * ENGINE_LENGTH_TOLERANCE)) {
      return new Verdict(Check.LENGTH, null);
    }
    double[] first = points.get(0);
    double[] last = points.get(points.size() - 1);
    if (!within(first, request.start().lat(), request.start().lon(), END_RADIUS_M)) {
      return new Verdict(Check.ENDS, null);
    }
    boolean endsWell =
        request.end() == null
            ? within(last, first[1], first[0], LOOP_CLOSING_M)
            : within(last, request.end().lat(), request.end().lon(), END_RADIUS_M);
    if (!endsWell) {
      return new Verdict(Check.ENDS, null);
    }
    if (jump) {
      return new Verdict(Check.JUMP, null);
    }
    return new Verdict(null, new BoundsDto(minLon, minLat, maxLon, maxLat));
  }

  private static boolean within(double[] lonLat, double lat, double lon, double meters) {
    return GeoDistance.haversineMeters(lonLat[1], lonLat[0], lat, lon) <= meters;
  }

  private static boolean unit(double v) {
    return v >= 0 && v <= 1;
  }

  private static boolean shares(Route r) {
    return unit(r.teamShare())
        && unit(r.unpavedShare())
        && unit(r.offpavementShare())
        && r.tailM() >= 0
        && r.crossings() >= 0
        && Double.isFinite(r.distanceM());
  }

  /** The points as {@code [lon, lat]}, or null when the polyline is not a sane one. */
  static @Nullable List<double[]> decode(@Nullable String polyline) {
    if (polyline == null || polyline.isEmpty() || polyline.length() > MAX_POINTS * 12) {
      return null;
    }
    List<double[]> points;
    try {
      points = Polyline6Decoder.decode(polyline);
    } catch (RuntimeException e) {
      return null;
    }
    if (points.size() < 2 || points.size() > MAX_POINTS) {
      return null;
    }
    for (double[] p : points) {
      if (!Double.isFinite(p[0])
          || !Double.isFinite(p[1])
          || Math.abs(p[0]) > 180
          || Math.abs(p[1]) > 90) {
        return null;
      }
    }
    return points;
  }
}
