package fr.pedalons.service.route.generator;

import java.util.HashMap;
import java.util.Map;
import java.util.function.IntConsumer;

/**
 * Uniform hash grid on projected coordinates. Read-only once built, hence thread-safe. Queries scan
 * cells in a fixed order so results never depend on hash iteration order.
 */
final class SpatialGrid {
  private final double cell;
  private final Map<Long, IntList> cells = new HashMap<>();

  SpatialGrid(double cellM) {
    this.cell = cellM;
  }

  double cellSize() {
    return cell;
  }

  private static long key(long cx, long cy) {
    return (cx << 32) ^ (cy & 0xffffffffL);
  }

  private long cellOf(double v) {
    return (long) Math.floor(v / cell);
  }

  void add(double x, double y, int item) {
    IntList list = cells.computeIfAbsent(key(cellOf(x), cellOf(y)), k -> new IntList(2));
    if (list.isEmpty() || list.last() != item) {
      list.add(item);
    }
  }

  /** Visits every item stored in a cell intersecting the box; an item may be visited twice. */
  void query(double minX, double minY, double maxX, double maxY, IntConsumer visitor) {
    long x0 = cellOf(minX);
    long x1 = cellOf(maxX);
    long y0 = cellOf(minY);
    long y1 = cellOf(maxY);
    for (long cx = x0; cx <= x1; cx++) {
      for (long cy = y0; cy <= y1; cy++) {
        IntList list = cells.get(key(cx, cy));
        if (list != null) {
          for (int i = 0; i < list.size(); i++) {
            visitor.accept(list.get(i));
          }
        }
      }
    }
  }
}
