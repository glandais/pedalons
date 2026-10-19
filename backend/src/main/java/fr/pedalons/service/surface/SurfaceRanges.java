package fr.pedalons.service.surface;

import fr.pedalons.service.surface.TraceSurfaceProjection.Range;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import org.jspecify.annotations.Nullable;

/**
 * Turns the ranges projected from the slices of a track into a clean cover of it (docs/LEDGER_*.md
 * WEB-100, C1b): no gap, no overlap, equal neighbours merged, nothing shorter than {@link
 * #MIN_SPAN_M}, boundaries at the decimetre. Pure, and generic on the value so the surfaces and the
 * ways go through the same rules.
 */
final class SurfaceRanges {

  /** A stretch shorter than this is the noise of the matching, not a change of surface. */
  static final double MIN_SPAN_M = 20;

  private SurfaceRanges() {}

  /**
   * @param length the length of the track: the cover goes from 0 to there
   * @param unknown the value of what the ranges leave uncovered
   */
  static <V> List<Range<V>> normalize(List<Range<V>> ranges, double length, @Nullable V unknown) {
    List<Range<V>> cover = merge(cover(ranges, length, unknown));
    absorbShort(cover);
    return round(cover, length);
  }

  /**
   * The ranges with {@code value} on each of the {@code runs} ({@code [from, to]}): the ranges
   * that overflow a run are cut.
   */
  static <V> List<Range<V>> overlay(List<Range<V>> ranges, List<double[]> runs, @Nullable V value) {
    List<Range<V>> out = new ArrayList<>(ranges);
    for (double[] run : runs) {
      double a = run[0];
      double b = run[1];
      if (!(b > a)) {
        continue;
      }
      List<Range<V>> next = new ArrayList<>(out.size() + 2);
      for (Range<V> r : out) {
        if (r.to() <= a || r.from() >= b) {
          next.add(r);
          continue;
        }
        if (r.from() < a) {
          next.add(new Range<>(r.from(), a, r.value()));
        }
        if (r.to() > b) {
          next.add(new Range<>(b, r.to(), r.value()));
        }
      }
      next.add(new Range<>(a, b, value));
      out = next;
    }
    out.sort(Comparator.comparingDouble(Range::from));
    return out;
  }

  /**
   * Sorted, clipped to {@code [0, length]}, an overlap won by the later range, a gap (and the ends)
   * filled with {@code unknown}.
   */
  private static <V> List<Range<V>> cover(
      List<Range<V>> ranges, double length, @Nullable V unknown) {
    List<Range<V>> sorted = new ArrayList<>(ranges);
    sorted.sort(Comparator.comparingDouble(Range::from));
    // Invariant: out covers [0, out.getLast().to()] without gap nor overlap, in order
    List<Range<V>> out = new ArrayList<>(sorted.size() + 2);
    for (Range<V> r : sorted) {
      double from = Math.max(0, r.from());
      double to = Math.min(length, r.to());
      if (to <= from) {
        continue;
      }
      // The later range wins the overlap, with every earlier range it reaches (not only the
      // last one); what it does not cover of them stays, in order
      List<Range<V>> after = new ArrayList<>();
      while (!out.isEmpty() && out.getLast().to() > from) {
        Range<V> previous = out.removeLast();
        if (previous.to() > to) {
          after.addFirst(
              new Range<>(Math.max(previous.from(), to), previous.to(), previous.value()));
        }
        if (previous.from() < from) {
          out.add(new Range<>(previous.from(), from, previous.value()));
          break;
        }
      }
      double end = out.isEmpty() ? 0 : out.getLast().to();
      if (from > end) {
        out.add(new Range<>(end, from, unknown));
      }
      out.add(new Range<>(from, to, r.value()));
      out.addAll(after);
    }
    double end = out.isEmpty() ? 0 : out.getLast().to();
    if (end < length) {
      out.add(new Range<>(end, length, unknown));
    }
    return out;
  }

  /** Adjacent ranges of the same value become one. */
  private static <V> List<Range<V>> merge(List<Range<V>> ranges) {
    List<Range<V>> out = new ArrayList<>(ranges.size());
    for (Range<V> r : ranges) {
      if (!out.isEmpty() && Objects.equals(out.getLast().value(), r.value())) {
        Range<V> last = out.removeLast();
        out.add(new Range<>(last.from(), r.to(), r.value()));
      } else {
        out.add(r);
      }
    }
    return out;
  }

  /**
   * While a range is shorter than {@link #MIN_SPAN_M} (and it is not the only one): the shortest of
   * them, the first on a tie, goes to the longer of its two neighbours (the left one on a tie), and
   * the neighbours that now agree are merged. Deterministic; quadratic, on a few thousand ranges at
   * most.
   */
  private static <V> void absorbShort(List<Range<V>> cover) {
    while (cover.size() > 1) {
      int shortest = -1;
      for (int i = 0; i < cover.size(); i++) {
        double length = length(cover.get(i));
        if (length < MIN_SPAN_M && (shortest < 0 || length < length(cover.get(shortest)))) {
          shortest = i;
        }
      }
      if (shortest < 0) {
        return;
      }
      Range<V> gone = cover.remove(shortest);
      int into;
      if (shortest == 0) {
        into = 0;
      } else if (shortest == cover.size()) {
        into = shortest - 1;
      } else {
        into =
            length(cover.get(shortest - 1)) >= length(cover.get(shortest))
                ? shortest - 1
                : shortest;
      }
      Range<V> keeper = cover.get(into);
      cover.set(
          into,
          new Range<>(
              Math.min(keeper.from(), gone.from()),
              Math.max(keeper.to(), gone.to()),
              keeper.value()));
      List<Range<V>> merged = merge(cover);
      cover.clear();
      cover.addAll(merged);
    }
  }

  /** Boundaries at the decimetre, from 0 exactly to the length exactly, each range starting where the previous ended. */
  private static <V> List<Range<V>> round(List<Range<V>> cover, double length) {
    List<Range<V>> out = new ArrayList<>(cover.size());
    double from = 0;
    for (int i = 0; i < cover.size(); i++) {
      Range<V> r = cover.get(i);
      double to = i == cover.size() - 1 ? decimetre(length) : decimetre(r.to());
      if (to > from) {
        out.add(new Range<>(from, to, r.value()));
        from = to;
      }
    }
    return merge(out);
  }

  static double decimetre(double metres) {
    return Math.round(metres * 10) / 10.0;
  }

  private static double length(Range<?> r) {
    return r.to() - r.from();
  }
}
