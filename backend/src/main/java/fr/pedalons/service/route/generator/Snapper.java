package fr.pedalons.service.route.generator;

import java.util.function.IntPredicate;
import org.jspecify.annotations.Nullable;

/** Nearest point on the network within a maximum distance. */
public final class Snapper {
  private Snapper() {}

  /**
   * Searches the segment grid in growing boxes until the best hit is closer than the box radius, so
   * that nothing closer can have been missed. Ties go to the smaller edge id.
   */
  public static @Nullable Snap snap(NetworkGraph g, LatLon p, double maxM) {
    return snap(g, p, maxM, e -> true);
  }

  /**
   * Same, but prefers the nearest edge that {@code admitted} accepts (the ride type allows it): a
   * forbidden edge is chosen only when no admitted edge lies within {@code maxM}, so a start beside
   * a footway that runs along a road snaps onto the road (plan §5.5).
   */
  public static @Nullable Snap snap(NetworkGraph g, LatLon p, double maxM, IntPredicate admitted) {
    if (g.edgeCount() == 0) {
      return null;
    }
    LocalProjection proj = g.projection();
    double px = proj.toX(p.lat(), p.lon());
    double py = proj.toY(p.lat(), p.lon());
    double pad = g.segmentGrid().cellSize() / 4;
    double radius = Math.min(100, maxM);
    while (true) {
      // [0] = nearest admitted edge, [1] = nearest edge whatever its type
      int[] bestEdge = {-1, -1};
      double[] best = {Double.POSITIVE_INFINITY, Double.POSITIVE_INFINITY};
      double[] bestAlong = {0, 0};
      double[][] bestXY = {{0, 0}, {0, 0}};
      double r = radius;
      g.segmentGrid()
          .query(
              px - r - pad,
              py - r - pad,
              px + r + pad,
              py + r + pad,
              e -> {
                Geo.Projection pr = Geo.project(px, py, g.geometryX(e), g.geometryY(e));
                boolean ok = admitted.test(e);
                for (int k = ok ? 0 : 1; k < 2; k++) {
                  if (pr.distance() < best[k] || (pr.distance() == best[k] && e < bestEdge[k])) {
                    best[k] = pr.distance();
                    bestEdge[k] = e;
                    bestAlong[k] = pr.along();
                    bestXY[k] = new double[] {pr.x(), pr.y()};
                  }
                }
              });
      int k = -1;
      if (bestEdge[0] >= 0 && best[0] <= radius) {
        k = 0;
      } else if (radius >= maxM && bestEdge[1] >= 0) {
        k = 1; // no admitted edge within reach: the nearest forbidden one, as a last resort
      }
      if (k >= 0) {
        if (best[k] > maxM) {
          return null;
        }
        int e = bestEdge[k];
        double projected = Geo.polylineLength(g.geometryX(e), g.geometryY(e));
        double scale = projected <= 0 ? 0 : g.length(e) / projected;
        double offset = Math.max(0, Math.min(g.length(e), bestAlong[k] * scale));
        return new Snap(e, offset, proj.toLatLon(bestXY[k][0], bestXY[k][1]), best[k]);
      }
      if (radius >= maxM) {
        return null;
      }
      radius = Math.min(radius * 2, maxM);
    }
  }
}
