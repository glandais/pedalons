package fr.pedalons.service.surface;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.infrastructure.valhalla.Polyline6Decoder;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse.Edge;
import fr.pedalons.infrastructure.valhalla.TraceAttributesResponse.MatchedPoint;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.function.Function;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Projects a {@code map_snap} trace attributes answer back onto the points that were sent
 * (docs/LEDGER_*.md WEB-100, C1b; ported from the prototype of
 * docs/research/2026-10-19-stadia-surfaces.md).
 *
 * <p>The answer describes the edges of the network the track was snapped to, and says for every
 * input point which edge it landed on and how far along. Between two consecutive points, the edges
 * are cut where the snapped line crosses them, interpolated on the distance between the two
 * points. When the snap took a detour between two points (a U-turn, a way back), the span is cut in
 * the middle instead: the distance along the snapped line means nothing there.
 */
final class TraceSurfaceProjection {

  private static final Logger LOG = Logger.getLogger(TraceSurfaceProjection.class);

  /** The snapped line may be this much longer than the span it answers for, plus the margin. */
  private static final double SLACK = 1.2;

  private static final double ABS_SLACK_M = 30;

  private TraceSurfaceProjection() {}

  /** A stretch between two distances along the sent points, with the value of the edges there. */
  record Range<V>(double from, double to, @Nullable V value) {}

  /**
   * @param d cumulative distance of each sent point, metres from 0
   * @param key the value read on an edge ({@code null} for none: unknown)
   * @return contiguous ranges from {@code d[0]} to the last point, adjacent equal values merged; a
   *     single null range when the answer cannot be used
   */
  static <V> List<Range<V>> project(
      double[] d, TraceAttributesResponse r, Function<Edge, @Nullable V> key) {
    double[] shapeDistance = shapeDistances(r);
    List<Edge> edges = r.edges();
    List<MatchedPoint> matched = r.matchedPoints();
    if (shapeDistance == null || edges == null || matched == null || matched.size() != d.length) {
      LOG.warnf(
          "Trace attributes answer unusable for a slice of %d points: no surface for it", d.length);
      return List.of(new Range<>(d[0], d[d.length - 1], null));
    }
    List<Range<V>> out = new ArrayList<>();
    for (int i = 0; i < d.length - 1; i++) {
      MatchedPoint m0 = matched.get(i);
      MatchedPoint m1 = matched.get(i + 1);
      if (!onEdge(m0, edges.size()) || !onEdge(m1, edges.size())) {
        emit(out, d[i], d[i + 1], null);
        continue;
      }
      int e0 = Objects.requireNonNull(m0.edgeIndex());
      int e1 = Objects.requireNonNull(m1.edgeIndex());
      if (e0 == e1) {
        emit(out, d[i], d[i + 1], key.apply(edges.get(e0)));
        continue;
      }
      double s0 = position(shapeDistance, edges, m0);
      double s1 = position(shapeDistance, edges, m1);
      double dd = d[i + 1] - d[i];
      // Unlike the prototype, two points snapped onto the same spot of two edges (s1 == s0) are
      // cut halfway too: the interpolation below would give their whole span to nothing, a gap
      if (e1 < e0 || s1 <= s0 || (s1 - s0) > SLACK * dd + ABS_SLACK_M) {
        double mid = (d[i] + d[i + 1]) / 2;
        emit(out, d[i], mid, key.apply(edges.get(e0)));
        emit(out, mid, d[i + 1], key.apply(edges.get(e1)));
        continue;
      }
      for (int k = e0; k <= e1; k++) {
        Edge e = edges.get(k);
        double a = Math.max(shapeDistance[e.beginShapeIndex()], s0);
        double b = Math.min(shapeDistance[e.endShapeIndex()], s1);
        if (b <= a && k != e0 && k != e1) {
          continue;
        }
        emit(
            out,
            at(d[i], dd, s0, s1, Math.max(a, s0)),
            at(d[i], dd, s0, s1, Math.min(b, s1)),
            key.apply(e));
      }
    }
    return out;
  }

  /** Where a position along the snapped line falls between the two points it lies between. */
  private static double at(double d0, double dd, double s0, double s1, double s) {
    return s1 > s0 ? d0 + (s - s0) / (s1 - s0) * dd : d0;
  }

  private static boolean onEdge(MatchedPoint m, int edgeCount) {
    Integer edge = m.edgeIndex();
    return !"unmatched".equals(m.type()) && edge != null && edge >= 0 && edge < edgeCount;
  }

  private static double position(double[] shapeDistance, List<Edge> edges, MatchedPoint m) {
    Edge e = edges.get(Objects.requireNonNull(m.edgeIndex()));
    double a = shapeDistance[e.beginShapeIndex()];
    double b = shapeDistance[e.endShapeIndex()];
    Double along = m.distanceAlongEdge();
    return a + (along == null ? 0 : along) * (b - a);
  }

  private static <V> void emit(List<Range<V>> out, double from, double to, @Nullable V value) {
    if (to <= from) {
      return;
    }
    if (!out.isEmpty()) {
      Range<V> last = out.getLast();
      if (Objects.equals(last.value(), value) && Math.abs(last.to() - from) < 1e-6) {
        out.set(out.size() - 1, new Range<>(last.from(), to, value));
        return;
      }
    }
    out.add(new Range<>(from, to, value));
  }

  /**
   * The cumulative distance along the answer's shape, or null when there is none or an edge points
   * outside it.
   */
  private static double @Nullable [] shapeDistances(TraceAttributesResponse r) {
    if (r.shape() == null || r.edges() == null) {
      return null;
    }
    List<double[]> shape = Polyline6Decoder.decode(r.shape());
    if (shape.size() < 2) {
      return null;
    }
    double[] cumulative = new double[shape.size()];
    for (int i = 1; i < shape.size(); i++) {
      double[] a = shape.get(i - 1);
      double[] b = shape.get(i);
      cumulative[i] = cumulative[i - 1] + GeoDistance.haversineMeters(a[1], a[0], b[1], b[0]);
    }
    for (Edge e : r.edges()) {
      if (e.beginShapeIndex() < 0
          || e.endShapeIndex() < e.beginShapeIndex()
          || e.endShapeIndex() >= cumulative.length) {
        return null;
      }
    }
    return cumulative;
  }
}
