package fr.pedalons.service.surface;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.infrastructure.valhalla.Polyline6Decoder;
import fr.pedalons.infrastructure.valhalla.Polyline6Encoder;
import fr.pedalons.infrastructure.valhalla.TraceAttributesRequest;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse.Edge;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse.MatchedPoint;
import java.util.ArrayList;
import java.util.List;
import java.util.function.DoubleFunction;
import java.util.function.IntFunction;

/**
 * Synthetic tracks and provider answers for the surface tests: straight lines along a meridian
 * (round coordinates, nothing real), and the answer a perfect map_snap would give for them.
 */
final class TraceFixtures {

  private TraceFixtures() {}

  /** A line going north from (lat 48, lng 2), a point every {@code stepM} metres. */
  static List<TrackPoint> line(int n, double stepM) {
    List<TrackPoint> points = new ArrayList<>(n);
    double dLat = Math.toDegrees(stepM / GeoDistance.EARTH_RADIUS_METERS);
    double dist = 0;
    for (int i = 0; i < n; i++) {
      double lat = 48 + i * dLat;
      if (i > 0) {
        dist += GeoDistance.haversineMeters(48 + (i - 1) * dLat, 2, lat, 2);
      }
      points.add(new TrackPoint(lat, 2, 100, dist));
    }
    return points;
  }

  /**
   * The answer to a request, as if the track followed the network exactly: one edge per run of
   * equal surface of the segments ({@code surfaceOfSegment} gets the segment index within the
   * sent polyline).
   */
  static TraceAttributesResponse answer(
      TraceAttributesRequest request, IntFunction<String> surfaceOfSegment) {
    String shape = request.encodedPolyline();
    List<double[]> decoded = Polyline6Decoder.decode(shape);
    int n = decoded.size();
    double[] cumulative = new double[n];
    for (int i = 1; i < n; i++) {
      double[] a = decoded.get(i - 1);
      double[] b = decoded.get(i);
      cumulative[i] = cumulative[i - 1] + GeoDistance.haversineMeters(a[1], a[0], b[1], b[0]);
    }
    List<Edge> edges = new ArrayList<>();
    int begin = 0;
    for (int segment = 1; segment < n - 1; segment++) {
      if (!surfaceOfSegment.apply(segment).equals(surfaceOfSegment.apply(begin))) {
        edges.add(new Edge(surfaceOfSegment.apply(begin), "road", "none", begin, segment));
        begin = segment;
      }
    }
    edges.add(new Edge(surfaceOfSegment.apply(begin), "road", "none", begin, n - 1));
    List<MatchedPoint> matched = new ArrayList<>(n);
    for (int i = 0; i < n; i++) {
      int e = edgeOf(edges, i);
      Edge edge = edges.get(e);
      double a = cumulative[edge.beginShapeIndex()];
      double b = cumulative[edge.endShapeIndex()];
      matched.add(new MatchedPoint("matched", e, b > a ? (cumulative[i] - a) / (b - a) : 0.0));
    }
    return new TraceAttributesResponse(shape, edges, matched, 190_674_135L);
  }

  /**
   * As {@link #answer}, the surface of a segment given by where its middle lies along the whole
   * {@link #line} ({@code surfaceAt} gets metres from its first point): what a slice answers then
   * depends on where it sits, so a slice put back at the wrong place shows.
   */
  static TraceAttributesResponse answerAlong(
      TraceAttributesRequest request, DoubleFunction<String> surfaceAt) {
    List<double[]> decoded = Polyline6Decoder.decode(request.encodedPolyline());
    double[] along = new double[decoded.size()];
    for (int i = 0; i < along.length; i++) {
      along[i] = GeoDistance.haversineMeters(48, 2, decoded.get(i)[1], decoded.get(i)[0]);
    }
    return answer(request, segment -> surfaceAt.apply((along[segment] + along[segment + 1]) / 2));
  }

  private static int edgeOf(List<Edge> edges, int point) {
    for (int e = 0; e < edges.size(); e++) {
      if (point < edges.get(e).endShapeIndex()) {
        return e;
      }
    }
    return edges.size() - 1;
  }

  /** A shape made of the given [lat, lon] positions, for hand-built answers. */
  static String shape(double[]... latLon) {
    double[] lat = new double[latLon.length];
    double[] lon = new double[latLon.length];
    for (int i = 0; i < latLon.length; i++) {
      lat[i] = latLon[i][0];
      lon[i] = latLon[i][1];
    }
    return Polyline6Encoder.encode(lat, lon, 0, latLon.length - 1);
  }
}
