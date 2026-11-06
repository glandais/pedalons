package fr.pedalons.service.route;

import com.fasterxml.jackson.databind.JsonNode;
import fr.pedalons.common.GeoDistance;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.OutputPoint;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Segment;
import fr.pedalons.service.surface.RouteSurfaceAnswer;
import io.github.glandais.elevation.CoordinatesElevation;
import io.github.glandais.elevation.LatLonElevation;
import io.github.glandais.engine.path.Path;
import io.github.glandais.engine.path.PathJvm;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.jspecify.annotations.Nullable;

/**
 * The two conversions between a vcyclist {@link Path} and an osm-route-details call, kept pure (no
 * CDI, no network) so they are unit-tested on hand-built answers (docs/LEDGER_*.md API-150): what
 * is sent ({@link #densify}) and what the answer becomes ({@link #toDense}).
 */
final class RouteDetailsTrack {

  /** A source down on a range, accepted by {@code accept_partial}: worth asking again. */
  static final String WARNING_ELEVATION_UNAVAILABLE = "elevation_unavailable";

  /**
   * Warnings that say the profile is knowingly degraded (a source down, or no data on a range):
   * logged at WARN, every other code at DEBUG ({@code unmatched_range}, {@code
   * outside_primary_zone} are routine).
   */
  static final Set<String> DEGRADED_WARNINGS =
      Set.of(
          "terrain_fallback",
          "dsm_unavailable",
          "elevation_missing",
          WARNING_ELEVATION_UNAVAILABLE,
          "typology_unavailable",
          "typology_missing");

  private RouteDetailsTrack() {}

  /** The positions sent to the service, in degrees. */
  record Sent(double[] lat, double[] lon) {
    int size() {
      return lat.length;
    }
  }

  /**
   * The positions of {@code source}, with points added on every gap longer than {@code maxGapM}
   * so that no gap is left wider than it — linear in lat/lon, which at {@code maxGapM} scales is
   * indistinguishable from the great circle.
   *
   * <p>Needed because the service answers the input points plus its breakpoints only: on a
   * two-point planner line, the smoothed profile would otherwise be sampled at a handful of
   * breakpoints and the 150 m smoothing would have nothing to work on. No source point is ever
   * dropped here; the gateway's thinning (closer than 5 m) is the only one. A gap that crosses the
   * antimeridian ({@code |dLon| > 180}) is left as it is: interpolating it would go round the
   * world.
   */
  static Sent densify(Path source, double maxGapM) {
    int n = source.getSize();
    double[] lat = new double[n];
    double[] lon = new double[n];
    for (int i = 0; i < n; i++) {
      lat[i] = source.latitudeDeg(i);
      lon[i] = source.longitudeDeg(i);
    }
    return densify(lat, lon, maxGapM);
  }

  /** {@link #densify(Path, double)} on positions in degrees. */
  static Sent densify(double[] lat, double[] lon, double maxGapM) {
    int n = lat.length;
    int extra = 0;
    int[] added = new int[Math.max(0, n - 1)];
    for (int i = 0; i + 1 < n; i++) {
      added[i] = insertions(lat[i], lon[i], lat[i + 1], lon[i + 1], maxGapM);
      extra += added[i];
    }
    if (extra == 0) {
      return new Sent(lat.clone(), lon.clone());
    }
    double[] outLat = new double[n + extra];
    double[] outLon = new double[n + extra];
    int o = 0;
    for (int i = 0; i < n; i++) {
      outLat[o] = lat[i];
      outLon[o] = lon[i];
      o++;
      if (i + 1 < n && added[i] > 0) {
        int k = added[i] + 1;
        for (int j = 1; j < k; j++) {
          double t = (double) j / k;
          outLat[o] = lat[i] + (lat[i + 1] - lat[i]) * t;
          outLon[o] = lon[i] + (lon[i + 1] - lon[i]) * t;
          o++;
        }
      }
    }
    return new Sent(outLat, outLon);
  }

  /**
   * Two points to ask the elevation of a track too short to send ({@code source}'s first point and
   * one {@code distanceM} due north or south, towards the equator so that no latitude leaves its
   * range): the service refuses fewer than two distinct points.
   */
  static Sent probe(Path source, double distanceM) {
    double lat = source.latitudeDeg(0);
    double lon = source.longitudeDeg(0);
    double step = Math.toDegrees(distanceM / GeoDistance.EARTH_RADIUS_METERS);
    return new Sent(new double[] {lat, lat > 0 ? lat - step : lat + step}, new double[] {lon, lon});
  }

  /**
   * {@code source}'s points, all at the elevation {@code probe} answered at its first point: under
   * a metre, one altitude is all a track can have.
   */
  static Path flat(Path source, Path probe) {
    int n = source.getSize();
    List<CoordinatesElevation> coordinates = new ArrayList<>(n);
    for (int k = 0; k < n; k++) {
      coordinates.add(
          new LatLonElevation(source.latitudeDeg(k), source.longitudeDeg(k), probe.elevation(0)));
    }
    Path path = withoutSensors(PathJvm.fromCoordinates(coordinates));
    for (int k = 0; k < n; k++) {
      path.setSourceElevation(k, probe.sourceElevation(0));
    }
    return path;
  }

  /**
   * {@code path} with its sensor slots marked absent. A new path's array is zero-filled, and the
   * GPX writer takes anything but NaN for a reading: left alone, every point of the stored files
   * would carry an extension with a heart rate, a cadence, a temperature and a power of 0.
   * {@code GpxToPath} writes NaN for the same reason.
   */
  private static Path withoutSensors(Path path) {
    for (int k = 0; k < path.getSize(); k++) {
      path.setHeartRate(k, Double.NaN);
      path.setCadence(k, Double.NaN);
      path.setTemperature(k, Double.NaN);
      path.setPInputPower(k, Double.NaN);
    }
    return path;
  }

  /** The number of points to insert between a and b: {@code ceil(d / maxGap) - 1}. */
  private static int insertions(
      double latA, double lonA, double latB, double lonB, double maxGapM) {
    if (Math.abs(lonB - lonA) > 180) {
      return 0;
    }
    double d = GeoDistance.haversineMeters(latA, lonA, latB, lonB);
    if (!(d > maxGapM)) {
      return 0;
    }
    return (int) Math.ceil(d / maxGapM) - 1;
  }

  /**
   * The dense path built from an answer, before Douglas-Peucker.
   *
   * @param climb the service's cumulative gain at each point of {@code path}, from 0
   * @param fallbackAfterErrorKm see {@link #fallbackKm}
   * @param interpolatedM the length of the ranges without elevation, filled by interpolation
   * @param dM the service's {@code d_m} of each point of {@code path}
   * @param segments the typology of the answer, null when it was not asked for
   * @param dataVersions {@code meta.data_versions}
   * @param complete whether the status of the answer is {@code complete}
   */
  record Dense(
      Path path,
      double[] climb,
      double fallbackAfterErrorKm,
      double interpolatedM,
      double[] dM,
      @Nullable List<Segment> segments,
      @Nullable JsonNode dataVersions,
      boolean complete) {

    /**
     * The surface of this answer for the points Douglas-Peucker kept: each of them, of index {@code
     * indices[k]} here and at {@code simplified.distance(k)} once stored, anchors the two axes.
     */
    RouteSurfaceAnswer surfaceAnswer(List<Segment> typology, int[] indices, Path simplified) {
      double[] stored = new double[simplified.getSize()];
      for (int k = 0; k < stored.length; k++) {
        stored[k] = simplified.distance(k);
      }
      return new RouteSurfaceAnswer(typology, pick(dM, indices), stored, dataVersions, complete);
    }
  }

  /**
   * The path an answer describes: one point per answer point, in {@code d_m} order — the client's
   * own position for an input point ({@code index} into {@code lat}/{@code lon}, the arrays that
   * were sent), the service's for an inserted breakpoint. The elevation is {@code ele_smoothed}
   * (150 m, as gpx2web smoothed), {@code ele} when absent, and {@code sourceElevation} the
   * unsmoothed {@code ele}, the meaning vcyclist's own smoothing gives it.
   *
   * <p>A range without elevation ({@code elevation_missing}: out of every source's coverage, or
   * {@code elevation_unavailable}: a source down) is interpolated on {@code d_m} between the nearest
   * known points and held flat at the ends, so the path never carries a NaN that Douglas-Peucker or
   * the climb detector would choke on.
   *
   * <p>The ascent and the loss are read from the cumulatives ({@code gain_cum_m}, {@code
   * loss_cum_m}) rather than from {@code summary}: the contract only matches the two to the
   * centimetre, and with the cumulatives {@code climb[last]} equals the reported ascent exactly.
   * {@code climb} is non-decreasing whatever the stitching's rounding.
   *
   * @throws IllegalStateException on an answer that cannot be used (fewer than two points, an
   *     index out of the sent arrays, an inserted point without position, no elevation at all): the
   *     caller then keeps the original elevations
   */
  static Dense toDense(double[] lat, double[] lon, RouteDetailsResponse response) {
    List<OutputPoint> points = response.points();
    if (points == null || points.size() < 2) {
      throw new IllegalStateException(
          "osm-route-details answered " + (points == null ? "no" : points.size()) + " point(s)");
    }
    int n = points.size();
    double[] la = new double[n];
    double[] lo = new double[n];
    double[] d = new double[n];
    double[] raw = new double[n];
    double[] smoothed = new double[n];
    for (int k = 0; k < n; k++) {
      OutputPoint p = points.get(k);
      if (p.isInserted()) {
        if (p.lat() == null || p.lon() == null) {
          throw new IllegalStateException("inserted point " + k + " has no position");
        }
        la[k] = p.lat();
        lo[k] = p.lon();
      } else {
        if (p.index() < 0 || p.index() >= lat.length) {
          throw new IllegalStateException(
              "point " + k + " has index " + p.index() + " out of " + lat.length + " sent");
        }
        la[k] = lat[p.index()];
        lo[k] = lon[p.index()];
      }
      d[k] = p.dM();
      raw[k] = p.ele() == null ? Double.NaN : p.ele();
      smoothed[k] = p.eleSmoothed() != null ? p.eleSmoothed() : raw[k];
    }
    double interpolatedM = missingLength(d, smoothed);
    if (!fill(d, smoothed)) {
      throw new IllegalStateException("osm-route-details answered no elevation at all");
    }
    if (!fill(d, raw)) {
      System.arraycopy(smoothed, 0, raw, 0, n);
    }

    List<CoordinatesElevation> coordinates = new ArrayList<>(n);
    for (int k = 0; k < n; k++) {
      coordinates.add(new LatLonElevation(la[k], lo[k], smoothed[k]));
    }
    Path path = withoutSensors(PathJvm.fromCoordinates(coordinates));
    for (int k = 0; k < n; k++) {
      path.setSourceElevation(k, raw[k]);
    }

    // Running maximum: the contract's cumulatives never go down, but a sliced answer's are shifted
    // per slice, and across a flat seam the two sums can differ by an ulp the wrong way. Centimetre
    // values rounded to the planner's tenths turn that into a 0.1 m drop, which PlannerStates
    // refuses on save.
    double[] climb = new double[n];
    double gain0 = points.get(0).gainCumM();
    double reached = 0.0;
    for (int k = 0; k < n; k++) {
      reached = Math.max(reached, points.get(k).gainCumM() - gain0);
      climb[k] = reached;
    }
    double gain = climb[n - 1];
    double loss = Math.max(0.0, points.get(n - 1).lossCumM() - points.get(0).lossCumM());
    // After fromCoordinates: computeDerivedData clears the reported figures
    reportAscent(path, gain, -loss);
    RouteDetailsResponse.Meta meta = response.meta();
    return new Dense(
        path,
        climb,
        fallbackKm(response),
        interpolatedM,
        d,
        response.segments(),
        meta == null ? null : meta.dataVersions(),
        RouteDetailsResponse.STATUS_COMPLETE.equals(response.status()));
  }

  /** {@code values} at each of {@code indices}: the climb of the points Douglas-Peucker kept. */
  static double[] pick(double[] values, int[] indices) {
    double[] out = new double[indices.length];
    for (int k = 0; k < indices.length; k++) {
      out[k] = values[indices[k]];
    }
    return out;
  }

  /**
   * Kilometres of the answer the preferred source failed to serve: the {@code quality.terrain[]}
   * ranges flagged {@code fallback_after_error}, plus every {@code elevation_unavailable} warning's
   * range (the whole length when it has none) — the same "worth asking again" meaning as vcyclist's
   * {@code fallbackAfterErrorKm} (docs/LEDGER_*.md API-131).
   *
   * <p>{@code elevation_missing} and {@code status: partial} are deliberately <b>not</b> counted:
   * they mean "outside the data's coverage", which no retry will change (an outage is a 503, or
   * {@code elevation_unavailable} when {@code accept_partial} is set). Counting them would make the
   * HD catch-up retry a permanent gap five times and abandon the route; vcyclist did not count its
   * {@code noDataKm} either.
   */
  static double fallbackKm(RouteDetailsResponse response) {
    double length = length(response);
    double meters = 0.0;
    RouteDetailsResponse.Quality quality = response.quality();
    if (quality != null) {
      if (quality.terrain() != null) {
        for (RouteDetailsResponse.TerrainRange range : quality.terrain()) {
          if (range.fallbackAfterError()) {
            meters += Math.max(0.0, range.toM() - range.fromM());
          }
        }
      }
      if (quality.warnings() != null) {
        for (RouteDetailsResponse.Warning w : quality.warnings()) {
          if (WARNING_ELEVATION_UNAVAILABLE.equals(w.code())) {
            meters +=
                w.fromM() == null || w.toM() == null ? length : Math.max(0.0, w.toM() - w.fromM());
          }
        }
      }
    }
    if (length > 0) {
      meters = Math.min(meters, length);
    }
    return meters / 1000.0;
  }

  /** The route's length: {@code summary.length_m}, else the last point's distance. */
  private static double length(RouteDetailsResponse response) {
    if (response.summary() != null && response.summary().lengthM() > 0) {
      return response.summary().lengthM();
    }
    List<OutputPoint> points = response.points();
    return points == null || points.isEmpty() ? 0.0 : points.get(points.size() - 1).dM();
  }

  /**
   * Writes the service's ascent and loss onto {@code path}, read back through {@code
   * getReportedElevationGain()} / {@code getReportedElevationLoss()} and carried unchanged by
   * Douglas-Peucker.
   *
   * <p>vcyclist declares these setters Kotlin {@code internal} — compiled as public methods with a
   * mangled name — because in vcyclist only its own dead-band accumulator ({@code ElevationGain})
   * writes them. Here the service's {@code dem} preset <b>replaces</b> that accumulator
   * (docs/LEDGER_*.md API-150): {@code annotate} cannot be tuned to reproduce the service's
   * figures, and the raw sum on the simplified path would depend on its sampling. A vcyclist
   * upgrade that renames the methods fails the compilation, never silently; a public {@code
   * report(path, gain, loss)} is to be asked of vcyclist, after which this is the only call to
   * change.
   *
   * @param lossM {@code <= 0}, vcyclist's convention
   */
  static void reportAscent(Path path, double gainM, double lossM) {
    path.setElevationGainFiltered$io_github_glandais_gpx(gainM);
    path.setElevationLossFiltered$io_github_glandais_gpx(lossM);
  }

  /** The length, in metres, of the ranges of {@code values} that are NaN. */
  private static double missingLength(double[] d, double[] values) {
    double missing = 0.0;
    for (int k = 0; k + 1 < values.length; k++) {
      if (Double.isNaN(values[k]) || Double.isNaN(values[k + 1])) {
        missing += Math.max(0.0, d[k + 1] - d[k]);
      }
    }
    return missing;
  }

  /**
   * Fills the NaN of {@code values} in place: linear on {@code d} between the nearest known values,
   * the nearest known value at either end.
   *
   * @return false when no value is known at all (nothing filled)
   */
  static boolean fill(double[] d, double[] values) {
    int n = values.length;
    int previous = -1;
    for (int k = 0; k < n; k++) {
      if (Double.isNaN(values[k])) {
        continue;
      }
      if (previous == -1) {
        for (int j = 0; j < k; j++) {
          values[j] = values[k];
        }
      } else if (k - previous > 1) {
        double span = d[k] - d[previous];
        for (int j = previous + 1; j < k; j++) {
          double t =
              span > 0 ? (d[j] - d[previous]) / span : (double) (j - previous) / (k - previous);
          values[j] = values[previous] + (values[k] - values[previous]) * t;
        }
      }
      previous = k;
    }
    if (previous == -1) {
      return false;
    }
    for (int j = previous + 1; j < n; j++) {
      values[j] = values[previous];
    }
    return true;
  }
}
