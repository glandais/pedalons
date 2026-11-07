package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.OutputPoint;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Quality;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Segment;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Structure;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Summary;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.TerrainRange;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Warning;
import fr.pedalons.infrastructure.routedetails.RouteSlicer.Slice;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.jspecify.annotations.Nullable;

/**
 * Puts the answers of the slices of a route back into one answer, as if a single call had been
 * made (plan §3.1, docs/LEDGER_*.md API-150). Pure.
 *
 * <p><b>Anchors.</b> Each slice answers for its core, from the sent point {@code coreFrom} to the
 * sent point {@code coreTo} ({@link RouteSlicer}); both are input points, which every answer in
 * {@code input_with_breakpoints} carries. Their {@code d_m}, {@code gain_cum_m} and {@code
 * loss_cum_m} in the slice's own answer are the anchors: a slice's values are moved by what the
 * previous cores added up to, measured on the service's own distances. Nothing is recomputed on
 * Pédalons' side, so no drift between the two measures can build up along 600 km.
 *
 * <ul>
 *   <li>points: a slice keeps the points of its core — the input point {@code coreFrom} and every
 *       point up to, not including, {@code coreTo}, which the next slice keeps (the last slice keeps
 *       it). Indices count the whole sent line;
 *   <li>D+ and D−: the sum over the cores of the cumul's difference at the anchors. Not exactly the
 *       gain of one call (the hysteresis restarts at each anchor), a gap the contract states;
 *   <li>segments, structures, terrain ranges, ranged warnings: cut to the core and moved; equal
 *       neighbours across a boundary are merged, so a bridge cut by a slice comes out whole. A
 *       warning without a range is kept once;
 *   <li>{@code quality.structure_correction}: per structure type, the most telling status of the
 *       slices ({@code disabled}, then {@code unavailable}, {@code partial}, {@code applied}, {@code
 *       none_found}); its {@code counts} and {@code counts_by_source} are counted again on the
 *       stitched structures, which a bridge on a boundary or in an overlap enters once;
 *   <li>summary: length, gain and loss from the anchors, elevation bounds from the kept points
 *       (the overlaps would widen the slices' own), terrain lengths from the stitched ranges.
 * </ul>
 */
public final class RouteDetailsStitcher {

  /** Two boundaries closer than this are the same: the anchors are exact up to rounding. */
  static final double JOIN_TOLERANCE_M = 0.01;

  private RouteDetailsStitcher() {}

  /**
   * One answer for {@code slices}, with their {@code responses} in the same order. A single slice
   * that covers the whole line is returned as is.
   *
   * @throws IllegalStateException when a sliced answer has no {@code points}: the anchors are there
   *     (the gateway always asks for the elevation section when it slices)
   */
  public static RouteDetailsResponse stitch(
      List<Slice> slices, List<RouteDetailsResponse> responses) {
    if (slices.size() != responses.size() || slices.isEmpty()) {
      throw new IllegalArgumentException("one response per slice");
    }
    if (slices.size() == 1 && slices.getFirst().from() == 0) {
      return responses.getFirst();
    }
    List<OutputPoint> points = new ArrayList<>();
    List<Segment> segments = new ArrayList<>();
    List<Structure> structures = new ArrayList<>();
    List<TerrainRange> terrain = new ArrayList<>();
    List<Warning> warnings = new ArrayList<>();
    boolean anySegments = false;
    boolean anySummary = false;
    boolean partial = false;
    List<JsonNode> structureCorrections = new ArrayList<>();
    double offsetM = 0;
    double offsetGain = 0;
    double offsetLoss = 0;
    for (int k = 0; k < slices.size(); k++) {
      Slice slice = slices.get(k);
      RouteDetailsResponse r = responses.get(k);
      boolean last = k == slices.size() - 1;
      List<OutputPoint> own = r.points();
      if (own == null || own.isEmpty()) {
        throw new IllegalStateException("a sliced answer without points cannot be stitched");
      }
      OutputPoint from = anchor(own, slice.coreFrom() - slice.from());
      OutputPoint to = anchor(own, slice.coreTo() - slice.from());
      double fromM = from.dM();
      double toM = to.dM();
      double shift = offsetM - fromM;

      for (OutputPoint p : own) {
        int index = slice.from() + p.index();
        if (index < slice.coreFrom() || index > slice.coreTo()) {
          continue;
        }
        if (index == slice.coreTo() && !last) {
          continue;
        }
        points.add(
            new OutputPoint(
                p.dM() + shift,
                index,
                p.origin(),
                p.reasons(),
                p.lat(),
                p.lon(),
                p.ele(),
                p.eleSmoothed(),
                p.eleMethod(),
                offsetGain + p.gainCumM() - from.gainCumM(),
                offsetLoss + p.lossCumM() - from.lossCumM()));
      }

      if (r.segments() != null) {
        anySegments = true;
        for (Segment s : r.segments()) {
          double a = Math.max(fromM, s.fromM());
          double b = Math.min(toM, s.toM());
          if (b <= a) {
            continue;
          }
          Segment moved =
              new Segment(
                  a + shift,
                  b + shift,
                  clamp(slice.from() + s.fromIndex(), slice.coreFrom(), slice.coreTo()),
                  clamp(slice.from() + s.toIndex(), slice.coreFrom(), slice.coreTo()),
                  s.structure(),
                  s.structureSource(),
                  s.surface(),
                  s.wayKind(),
                  s.matched());
          appendSegment(segments, moved);
        }
      }

      Summary summary = r.summary();
      if (summary != null) {
        anySummary = true;
        if (summary.structures() != null) {
          for (Structure s : summary.structures()) {
            double a = Math.max(fromM, s.fromM());
            double b = Math.min(toM, s.toM());
            if (b > a) {
              appendStructure(
                  structures,
                  new Structure(
                      s.kind(), a + shift, b + shift, b - a, s.structureSource(), s.method()));
            }
          }
        }
      }

      Quality quality = r.quality();
      if (quality != null) {
        if (quality.terrain() != null) {
          for (TerrainRange t : quality.terrain()) {
            double a = Math.max(fromM, t.fromM());
            double b = Math.min(toM, t.toM());
            if (b > a) {
              appendTerrain(
                  terrain,
                  new TerrainRange(
                      a + shift, b + shift, t.origin(), t.measured(), t.fallbackAfterError()));
            }
          }
        }
        if (quality.warnings() != null) {
          for (Warning w : quality.warnings()) {
            Warning moved = clipWarning(w, fromM, toM, shift);
            if (moved != null) {
              appendWarning(warnings, moved);
            }
          }
        }
        if (quality.structureCorrection() != null) {
          structureCorrections.add(quality.structureCorrection());
        }
      }
      partial |= r.isPartial();

      offsetM += toM - fromM;
      offsetGain += to.gainCumM() - from.gainCumM();
      offsetLoss += to.lossCumM() - from.lossCumM();
    }

    Summary summary = null;
    if (anySummary) {
      Double eleMin = null;
      Double eleMax = null;
      for (OutputPoint p : points) {
        if (p.ele() != null) {
          eleMin = eleMin == null ? p.ele() : Math.min(eleMin, p.ele());
          eleMax = eleMax == null ? p.ele() : Math.max(eleMax, p.ele());
        }
      }
      Map<String, Double> terrainM = new LinkedHashMap<>();
      for (TerrainRange t : terrain) {
        if (t.origin() != null) {
          terrainM.merge(t.origin(), t.toM() - t.fromM(), Double::sum);
        }
      }
      summary =
          new Summary(
              offsetM, offsetGain, offsetLoss, eleMin, eleMax, List.copyOf(structures), terrainM);
    }
    RouteDetailsResponse first = responses.getFirst();
    return new RouteDetailsResponse(
        first.meta(),
        partial ? RouteDetailsResponse.STATUS_PARTIAL : first.status(),
        List.copyOf(points),
        anySegments ? List.copyOf(segments) : null,
        summary,
        new Quality(
            List.copyOf(terrain),
            List.copyOf(warnings),
            combineStructureCorrection(structureCorrections, anySummary ? structures : null)));
  }

  /**
   * The answer with its indices carried from the sent points to the caller's ({@code sent[k]} is
   * the caller's index of the k-th sent point, {@link RouteSlicer.Plan#sent()}). An inserted
   * point then names the last <em>sent</em> point before it: a point the thinning dropped has no
   * point of its own in the answer.
   */
  public static RouteDetailsResponse reindex(RouteDetailsResponse response, int[] sent) {
    if (isIdentity(sent)) {
      return response;
    }
    List<OutputPoint> points = null;
    if (response.points() != null) {
      points = new ArrayList<>(response.points().size());
      for (OutputPoint p : response.points()) {
        points.add(
            new OutputPoint(
                p.dM(),
                map(sent, p.index()),
                p.origin(),
                p.reasons(),
                p.lat(),
                p.lon(),
                p.ele(),
                p.eleSmoothed(),
                p.eleMethod(),
                p.gainCumM(),
                p.lossCumM()));
      }
    }
    List<Segment> segments = null;
    if (response.segments() != null) {
      segments = new ArrayList<>(response.segments().size());
      for (Segment s : response.segments()) {
        segments.add(
            new Segment(
                s.fromM(),
                s.toM(),
                map(sent, s.fromIndex()),
                map(sent, s.toIndex()),
                s.structure(),
                s.structureSource(),
                s.surface(),
                s.wayKind(),
                s.matched()));
      }
    }
    return new RouteDetailsResponse(
        response.meta(),
        response.status(),
        points,
        segments,
        response.summary(),
        response.quality());
  }

  /**
   * The point an index is anchored on: the first whose index is at least {@code localIndex}, which
   * is that input point (an input point comes before the points inserted after it). A sent point
   * the service dropped as a duplicate of its predecessor falls on the next one: its distance and
   * cumuls are those of the duplicate anyway.
   */
  private static OutputPoint anchor(List<OutputPoint> points, int localIndex) {
    for (OutputPoint p : points) {
      if (p.index() >= localIndex) {
        return p;
      }
    }
    return points.getLast();
  }

  private static void appendSegment(List<Segment> out, Segment s) {
    if (!out.isEmpty()) {
      Segment prev = out.getLast();
      if (Math.abs(prev.toM() - s.fromM()) <= JOIN_TOLERANCE_M
          && Objects.equals(prev.structure(), s.structure())
          && Objects.equals(prev.structureSource(), s.structureSource())
          && Objects.equals(prev.surface(), s.surface())
          && Objects.equals(prev.wayKind(), s.wayKind())
          && prev.matched() == s.matched()) {
        out.set(
            out.size() - 1,
            new Segment(
                prev.fromM(),
                s.toM(),
                prev.fromIndex(),
                s.toIndex(),
                prev.structure(),
                prev.structureSource(),
                prev.surface(),
                prev.wayKind(),
                prev.matched()));
        return;
      }
    }
    out.add(s);
  }

  private static void appendStructure(List<Structure> out, Structure s) {
    if (!out.isEmpty()) {
      Structure prev = out.getLast();
      if (Math.abs(prev.toM() - s.fromM()) <= JOIN_TOLERANCE_M
          && Objects.equals(prev.kind(), s.kind())
          && Objects.equals(prev.structureSource(), s.structureSource())
          && Objects.equals(prev.method(), s.method())) {
        out.set(
            out.size() - 1,
            new Structure(
                prev.kind(),
                prev.fromM(),
                s.toM(),
                s.toM() - prev.fromM(),
                prev.structureSource(),
                prev.method()));
        return;
      }
    }
    out.add(s);
  }

  private static void appendTerrain(List<TerrainRange> out, TerrainRange t) {
    if (!out.isEmpty()) {
      TerrainRange prev = out.getLast();
      if (Math.abs(prev.toM() - t.fromM()) <= JOIN_TOLERANCE_M
          && Objects.equals(prev.origin(), t.origin())
          && prev.measured() == t.measured()
          && prev.fallbackAfterError() == t.fallbackAfterError()) {
        out.set(
            out.size() - 1,
            new TerrainRange(
                prev.fromM(), t.toM(), prev.origin(), prev.measured(), prev.fallbackAfterError()));
        return;
      }
    }
    out.add(t);
  }

  /**
   * A warning added to the stitched ones: one without a range once, a ranged one merged into an
   * earlier one of the same code and message that it touches or overlaps — a warning cut by a
   * boundary comes out whole, and a point warning on a boundary, kept by both slices, once.
   */
  private static void appendWarning(List<Warning> out, Warning w) {
    if (w.fromM() == null || w.toM() == null) {
      if (!out.contains(w)) {
        out.add(w);
      }
      return;
    }
    for (int i = out.size() - 1; i >= 0; i--) {
      Warning prev = out.get(i);
      if (prev.fromM() == null
          || prev.toM() == null
          || !Objects.equals(prev.code(), w.code())
          || !Objects.equals(prev.message(), w.message())) {
        continue;
      }
      if (w.fromM() <= prev.toM() + JOIN_TOLERANCE_M
          && w.toM() >= prev.fromM() - JOIN_TOLERANCE_M) {
        out.set(
            i,
            new Warning(
                prev.code(),
                prev.message(),
                Math.min(prev.fromM(), w.fromM()),
                Math.max(prev.toM(), w.toM())));
        return;
      }
    }
    out.add(w);
  }

  /** From the least to the most telling: an unknown status ranks above them all. */
  private static final List<String> STRUCTURE_STATUSES =
      List.of("none_found", "applied", "partial", "unavailable", "disabled");

  /**
   * The slices' {@code structure_correction} as one, null when none has any. A textual field (a
   * status per structure type) takes the most telling value; {@code counts} and {@code
   * counts_by_source} are counted on {@code structures} when the summary was asked, summed over the
   * slices otherwise; any other field comes from the first slice that has it.
   */
  static @Nullable JsonNode combineStructureCorrection(
      List<JsonNode> slices, @Nullable List<Structure> structures) {
    if (slices.isEmpty()) {
      return null;
    }
    ObjectNode out = JsonNodeFactory.instance.objectNode();
    for (JsonNode slice : slices) {
      if (!slice.isObject()) {
        continue;
      }
      Iterator<Map.Entry<String, JsonNode>> fields = slice.fields();
      while (fields.hasNext()) {
        Map.Entry<String, JsonNode> field = fields.next();
        String name = field.getKey();
        JsonNode value = field.getValue();
        JsonNode prev = out.get(name);
        if (prev == null) {
          out.set(name, value.deepCopy());
        } else if (prev.isTextual() && value.isTextual()) {
          if (statusRank(value.asText()) > statusRank(prev.asText())) {
            out.set(name, value.deepCopy());
          }
        } else if (prev.isObject() && value.isObject()) {
          ObjectNode sum = (ObjectNode) prev;
          Iterator<Map.Entry<String, JsonNode>> counts = value.fields();
          while (counts.hasNext()) {
            Map.Entry<String, JsonNode> count = counts.next();
            JsonNode before = sum.get(count.getKey());
            if (before == null) {
              sum.set(count.getKey(), count.getValue().deepCopy());
            } else if (before.isNumber() && count.getValue().isNumber()) {
              sum.put(count.getKey(), before.asLong() + count.getValue().asLong());
            }
          }
        }
      }
    }
    if (structures != null) {
      if (out.has("counts")) {
        out.set("counts", countBy(structures, true));
      }
      if (out.has("counts_by_source")) {
        out.set("counts_by_source", countBy(structures, false));
      }
    }
    return out;
  }

  private static int statusRank(String status) {
    int rank = STRUCTURE_STATUSES.indexOf(status);
    return rank < 0 ? STRUCTURE_STATUSES.size() : rank;
  }

  private static ObjectNode countBy(List<Structure> structures, boolean byMethod) {
    ObjectNode counts = JsonNodeFactory.instance.objectNode();
    for (Structure s : structures) {
      String key = byMethod ? s.method() : s.structureSource();
      if (key != null) {
        counts.put(key, counts.path(key).asLong(0) + 1);
      }
    }
    return counts;
  }

  /**
   * A ranged warning cut to the core and moved, null when it lies outside; a warning without a
   * range is about the whole slice, and {@link #appendWarning} keeps it once.
   */
  private static @Nullable Warning clipWarning(Warning w, double fromM, double toM, double shift) {
    if (w.fromM() == null || w.toM() == null) {
      return w;
    }
    double a = Math.max(fromM, w.fromM());
    double b = Math.min(toM, w.toM());
    if (b < a || (b == a && w.toM() > w.fromM())) {
      return null;
    }
    return new Warning(w.code(), w.message(), a + shift, b + shift);
  }

  private static int clamp(int index, int min, int max) {
    return Math.max(min, Math.min(max, index));
  }

  private static int map(int[] sent, int index) {
    return sent[clamp(index, 0, sent.length - 1)];
  }

  private static boolean isIdentity(int[] sent) {
    for (int k = 0; k < sent.length; k++) {
      if (sent[k] != k) {
        return false;
      }
    }
    return true;
  }
}
