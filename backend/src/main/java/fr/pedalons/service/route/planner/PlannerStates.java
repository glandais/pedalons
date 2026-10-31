package fr.pedalons.service.route.planner;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.planner.PlannerJunction;
import fr.pedalons.common.planner.PlannerJunctionKind;
import fr.pedalons.common.planner.PlannerPiece;
import fr.pedalons.common.planner.PlannerPieceMode;
import fr.pedalons.common.planner.PlannerSource;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.common.planner.UnpavedSpan;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.service.route.GpxLimits;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Validates a planner state sent by a client and derives the track from it (docs/LEDGER_*.md
 * WEB-100, C4a). The state and the track cannot diverge: the track is always the one this derives.
 *
 * <p>Every refusal is a {@code PLANNER_STATE_INVALID}. Each step is bounded before it allocates, so
 * a hostile state costs at most {@link GpxLimits#MAX_PLANNER_STATE_CHARS} characters of decoding.
 *
 * <p>The track is derived from the raw shapes when the state carries them (docs/LEDGER_*.md API-147,
 * phase C): a routed piece from its {@code shape}, an imported piece cut out of its source's {@code
 * shape}; a piece without one, or whose shape {@link RawShapes#consistent} rejects, from its {@code
 * line} as before. A shape is never trusted to match its line, and never fails a state for its size
 * ({@link GpxLimits#MAX_PLANNER_SHAPE_POINTS}): only a malformed one does.
 */
@ApplicationScoped
public class PlannerStates {

  private static final Logger LOG = Logger.getLogger(PlannerStates.class);

  private static final double MAX_ASCEND_SCALE = 100.0;
  private static final double MIN_ELE = -1_000.0;
  private static final double MAX_ELE = 10_000.0;
  private static final double MAX_CLIMB = 100_000.0;

  /**
   * A validated state, decoded.
   *
   * @param raws per piece, the raw interior the track takes instead of the line's, or null
   */
  private record Decoded(
      List<double[][]> sources, List<double[][]> interiors, List<double @Nullable [][]> raws) {}

  /** The points of the track the state stands for, junctions and interiors in order. */
  public List<GeoPoint> validateAndDerive(@Nullable PlannerState state) {
    return derive(state, validate(state, true), null);
  }

  /**
   * The straight pieces of a state as distances along the track it derives (docs/LEDGER_*.md
   * WEB-100, C1b).
   *
   * @param length the length of that derived polyline, metres
   * @param runs {@code [from, to]}, metres along it, one per DIRECT piece
   */
  public record DirectRuns(double length, List<double[]> runs) {}

  /**
   * The DIRECT pieces of a stored state, as {@code [from, to]} metres along the polyline the state's
   * lines derive, and that polyline's length. Empty when the state no longer validates (a stored
   * state is read back, not trusted).
   *
   * <p>The lines, never the raw shapes (docs/LEDGER_*.md API-147, phase C): the caller rescales the
   * runs proportionally onto the stored track, which the pipeline simplified from the raw exactly as
   * the lines were, so their lengths agree within metres. A raw polyline is longer by its GPS jitter
   * and stops, unevenly along the route, and would shift every run after them.
   */
  public DirectRuns directRuns(@Nullable PlannerState state) {
    Decoded decoded;
    try {
      decoded = validate(state, false);
    } catch (BusinessException e) {
      return new DirectRuns(0, List.of());
    }
    PlannerState s = java.util.Objects.requireNonNull(state);
    int[] junctionAt = new int[s.junctions().size()];
    List<GeoPoint> polyline = derive(s, decoded, junctionAt);
    double[] cumulative = new double[polyline.size()];
    for (int i = 1; i < cumulative.length; i++) {
      GeoPoint a = polyline.get(i - 1);
      GeoPoint b = polyline.get(i);
      cumulative[i] =
          cumulative[i - 1] + GeoDistance.haversineMeters(a.lat(), a.lng(), b.lat(), b.lng());
    }
    List<double[]> runs = new ArrayList<>();
    for (int k = 0; k < s.pieces().size(); k++) {
      if (s.pieces().get(k).mode() == PlannerPieceMode.DIRECT) {
        runs.add(new double[] {cumulative[junctionAt[k]], cumulative[junctionAt[k + 1]]});
      }
    }
    return new DirectRuns(cumulative[cumulative.length - 1], runs);
  }

  /**
   * @param junctionAt when not null, receives the index in the result of each junction
   */
  private static List<GeoPoint> derive(
      @Nullable PlannerState state, Decoded decoded, int @Nullable [] junctionAt) {
    PlannerState s = java.util.Objects.requireNonNull(state);
    List<PlannerJunction> junctions = s.junctions();
    List<PlannerPiece> pieces = s.pieces();
    int total = 1;
    for (int k = 0; k < pieces.size(); k++) {
      double[][] raw = decoded.raws().get(k);
      total +=
          (raw != null ? raw.length : interiorSize(pieces.get(k), decoded.interiors().get(k))) + 1;
    }
    List<GeoPoint> out = new ArrayList<>(total);
    out.add(point(junctions.getFirst()));
    if (junctionAt != null) {
      junctionAt[0] = 0;
    }
    for (int k = 0; k < pieces.size(); k++) {
      PlannerPiece piece = pieces.get(k);
      double[][] raw = decoded.raws().get(k);
      if (raw != null) {
        for (double[] p : raw) {
          out.add(new GeoPoint(p[0], p[1]));
        }
      } else if (piece.mode() == PlannerPieceMode.IMPORTED) {
        double[][] source = decoded.sources().get(piece.source());
        for (int i = piece.from() + 1; i < piece.to(); i++) {
          out.add(new GeoPoint(source[i][0], source[i][1]));
        }
      } else {
        for (double[] p : decoded.interiors().get(k)) {
          out.add(new GeoPoint(p[0], p[1]));
        }
      }
      out.add(point(junctions.get(k + 1)));
      if (junctionAt != null) {
        junctionAt[k + 1] = out.size() - 1;
      }
    }
    return out;
  }

  private static GeoPoint point(PlannerJunction j) {
    return new GeoPoint(j.lng(), j.lat());
  }

  private static int interiorSize(PlannerPiece piece, double[][] interior) {
    return piece.mode() == PlannerPieceMode.IMPORTED
        ? piece.to() - piece.from() - 1
        : interior.length;
  }

  /**
   * @param withRaws whether to derive the raw interiors (step 8); without, the track is the lines'
   */
  private static Decoded validate(@Nullable PlannerState state, boolean withRaws) {
    // 1
    if (state == null
        || state.version() != GpxLimits.PLANNER_STATE_VERSION
        || state.profile() == null
        || state.sources() == null
        || state.junctions() == null
        || state.pieces() == null) {
      throw invalid();
    }
    List<PlannerSource> sources = state.sources();
    List<PlannerJunction> junctions = state.junctions();
    List<PlannerPiece> pieces = state.pieces();
    // 2
    if (pieces.isEmpty()
        || pieces.size() > GpxLimits.MAX_PLANNER_PIECES
        || junctions.size() != pieces.size() + 1
        || sources.size() > GpxLimits.MAX_PLANNER_SOURCES) {
      throw invalid();
    }
    // 3
    long chars = 0;
    for (PlannerSource source : sources) {
      if (source == null) {
        throw invalid();
      }
      chars +=
          length(source.line())
              + length(source.ele())
              + length(source.climb())
              + length(source.shape());
    }
    for (PlannerPiece piece : pieces) {
      if (piece == null) {
        throw invalid();
      }
      chars += length(piece.line()) + length(piece.ele()) + length(piece.shape());
    }
    if (chars > GpxLimits.MAX_PLANNER_STATE_CHARS) {
      throw invalid();
    }
    // 4: one budget for all the sources, another for all the raw shapes
    int budget = GpxLimits.MAX_PLANNER_POINTS;
    int[] shapeBudget = {GpxLimits.MAX_PLANNER_SHAPE_POINTS};
    List<double[][]> decodedSources = new ArrayList<>(sources.size());
    List<double @Nullable [][]> sourceShapes = new ArrayList<>(sources.size());
    for (PlannerSource source : sources) {
      if (source.line() == null) {
        throw invalid();
      }
      double[][] line = PolylineCodec.decode2(source.line(), budget);
      if (line.length < 2) {
        throw invalid();
      }
      budget -= line.length;
      if (source.ele() != null) {
        PolylineCodec.decode1(source.ele(), line.length);
      }
      if (source.climb() != null) {
        if (source.ele() == null) {
          throw invalid();
        }
        checkClimb(PolylineCodec.decode1(source.climb(), line.length));
      }
      double scale = source.ascendScale();
      if (!(scale > 0.0 && scale <= MAX_ASCEND_SCALE)) {
        throw invalid();
      }
      decodedSources.add(line);
      double[][] shape = decodeShape(source.shape(), shapeBudget);
      if (shape != null && shape.length < 2) {
        throw invalid();
      }
      sourceShapes.add(shape);
    }
    // 5
    for (int i = 0; i < junctions.size(); i++) {
      PlannerJunction j = junctions.get(i);
      if (j == null || j.kind() == null) {
        throw invalid();
      }
      boolean end = i == 0 || i == junctions.size() - 1;
      if (end && j.kind() != PlannerJunctionKind.CONTROL) {
        throw invalid();
      }
      if (!finite(j.lng())
          || !finite(j.lat())
          || Math.abs(j.lng()) > 180
          || Math.abs(j.lat()) > 90) {
        throw invalid();
      }
      Double ele = j.ele();
      if (ele != null && !(ele >= MIN_ELE && ele <= MAX_ELE)) {
        throw invalid();
      }
      if ((j.source() == null) != (j.idx() == null)) {
        throw invalid();
      }
      if (j.source() != null
          && (j.source() < 0
              || j.source() >= decodedSources.size()
              || j.idx() < 0
              || j.idx() >= decodedSources.get(j.source()).length)) {
        throw invalid();
      }
    }
    // 6, 7
    long total = junctions.size();
    List<double[][]> interiors = new ArrayList<>(pieces.size());
    List<double @Nullable [][]> pieceShapes = new ArrayList<>(pieces.size());
    int interiorBudget = GpxLimits.MAX_PLANNER_POINTS;
    for (int k = 0; k < pieces.size(); k++) {
      PlannerPiece piece = pieces.get(k);
      if (piece.mode() == null) {
        throw invalid();
      }
      if (piece.mode() == PlannerPieceMode.IMPORTED) {
        if (piece.line() != null
            || piece.ele() != null
            || piece.ascend() != null
            || piece.unpaved() != null
            || piece.shape() != null
            || piece.source() == null
            || piece.from() == null
            || piece.to() == null) {
          throw invalid();
        }
        int src = piece.source();
        if (src < 0 || src >= decodedSources.size()) {
          throw invalid();
        }
        int from = piece.from();
        int to = piece.to();
        if (from < 0 || from >= to || to >= decodedSources.get(src).length) {
          throw invalid();
        }
        if (!hasProvenance(junctions.get(k), src, from)
            || !hasProvenance(junctions.get(k + 1), src, to)) {
          throw invalid();
        }
        total += to - from - 1;
        interiors.add(new double[0][]);
        pieceShapes.add(null);
      } else {
        if (piece.line() == null
            || (piece.shape() != null && piece.mode() != PlannerPieceMode.ROUTED)
            || piece.source() != null
            || piece.from() != null
            || piece.to() != null) {
          throw invalid();
        }
        long left = GpxLimits.MAX_PLANNER_POINTS - total;
        if (left < 0) {
          throw invalid();
        }
        double[][] interior =
            PolylineCodec.decode2(piece.line(), (int) Math.min(left, interiorBudget));
        if (piece.ele() != null) {
          PolylineCodec.decode1(piece.ele(), interior.length);
        }
        Double ascend = piece.ascend();
        if (piece.mode() == PlannerPieceMode.DIRECT) {
          if (ascend != null) {
            throw invalid();
          }
        } else if (ascend != null && !(ascend >= 0.0 && finite(ascend))) {
          throw invalid();
        }
        checkUnpaved(piece.unpaved(), piece.mode(), interior.length + 1);
        total += interior.length;
        interiors.add(interior);
        pieceShapes.add(decodeShape(piece.shape(), shapeBudget));
      }
      if (total > GpxLimits.MAX_PLANNER_POINTS) {
        throw invalid();
      }
    }
    if (total < 2) {
      throw invalid();
    }
    // 8
    List<double @Nullable [][]> raws =
        withRaws
            ? raws(state, decodedSources, sourceShapes, interiors, pieceShapes, total)
            : Collections.nCopies(pieces.size(), null);
    return new Decoded(decodedSources, interiors, raws);
  }

  /**
   * A raw shape, decoded within what is left of {@code budget[0]}, which it then takes from. Null
   * when absent or past the budget (ignored, not refused); malformed, refused.
   */
  private static double @Nullable [][] decodeShape(@Nullable String shape, int[] budget) {
    if (shape == null) {
      return null;
    }
    double[][] decoded = PolylineCodec.decode2Within(shape, budget[0]);
    if (decoded == null) {
      LOG.debug("Planner state: raw shapes past their point budget, ignored");
      return null;
    }
    budget[0] -= decoded.length;
    return decoded;
  }

  /**
   * Step 8 (docs/LEDGER_*.md API-147, phase C): per piece, the raw interior the track takes, or
   * null for its line. A routed piece takes its own shape, an imported piece the stretch of its
   * source's shape between its two junctions, located by {@link RawShapes#locate} ({@code from} and
   * {@code to} index the line, not the shape). Either is kept only when {@link
   * RawShapes#consistent} with the line it replaces, and while the derived track stays within
   * {@link GpxLimits#MAX_PLANNER_DERIVED_POINTS}.
   *
   * <p>Locating walks a source line in stations of a few metres, so its cost grows with the
   * line's length, not its point count: the sources walked, lines and shapes together, are bounded
   * by {@link GpxLimits#MAX_TRACK_DISTANCE_METERS} before any walk, and a source past what is left
   * of it keeps its line (a track that long is refused afterwards anyway).
   *
   * @param total the points the state derives from its lines
   */
  private static List<double @Nullable [][]> raws(
      PlannerState state,
      List<double[][]> sources,
      List<double @Nullable [][]> sourceShapes,
      List<double[][]> interiors,
      List<double @Nullable [][]> pieceShapes,
      long total) {
    List<PlannerJunction> junctions = state.junctions();
    List<PlannerPiece> pieces = state.pieces();
    // Where each junction index of an imported piece falls on its source's shape, one walk a source
    List<double @Nullable []> shapeDist = new ArrayList<>(sources.size());
    List<@Nullable Map<Integer, Double>> located = new ArrayList<>(sources.size());
    double walkLeft = GpxLimits.MAX_TRACK_DISTANCE_METERS;
    for (int s = 0; s < sources.size(); s++) {
      double[][] shape = sourceShapes.get(s);
      double[][] line = sources.get(s);
      if (shape != null
          && !RawShapes.consistent(
              line[0], shape, 0, shape.length, line, 1, line.length - 1, line[line.length - 1])) {
        LOG.debugf("Planner source %d: raw shape inconsistent with its line, ignored", s);
        shape = null;
      }
      TreeSet<Integer> indices = new TreeSet<>();
      if (shape != null) {
        for (PlannerPiece piece : pieces) {
          if (piece.mode() == PlannerPieceMode.IMPORTED && piece.source() == s) {
            indices.add(piece.from());
            indices.add(piece.to());
          }
        }
      }
      if (indices.isEmpty()) {
        shapeDist.add(null);
        located.add(null);
        continue;
      }
      double[] dist = RawShapes.cumulative(java.util.Objects.requireNonNull(shape));
      double[] lineDist = RawShapes.cumulative(sources.get(s));
      double walked = lineDist[lineDist.length - 1] + dist[dist.length - 1];
      if (!(walked <= walkLeft)) {
        LOG.debugf("Planner source %d: raw shape past the length that may be walked, ignored", s);
        shapeDist.add(null);
        located.add(null);
        continue;
      }
      walkLeft -= walked;
      int[] sorted = indices.stream().mapToInt(Integer::intValue).toArray();
      double[] along = RawShapes.locate(sources.get(s), lineDist, shape, dist, sorted);
      Map<Integer, Double> map = new HashMap<>();
      for (int i = 0; i < sorted.length; i++) {
        map.put(sorted[i], along[i]);
      }
      shapeDist.add(dist);
      located.add(map);
    }

    List<double @Nullable [][]> out = new ArrayList<>(pieces.size());
    long derived = total;
    for (int k = 0; k < pieces.size(); k++) {
      PlannerPiece piece = pieces.get(k);
      double[] from = lngLat(junctions.get(k));
      double[] to = lngLat(junctions.get(k + 1));
      double[][] raw = null;
      if (piece.mode() == PlannerPieceMode.IMPORTED) {
        int s = piece.source();
        double[][] shape = sourceShapes.get(s);
        double[] dist = shapeDist.get(s);
        Map<Integer, Double> map = located.get(s);
        if (shape != null && dist != null && map != null) {
          int[] range = RawShapes.between(dist, map.get(piece.from()), map.get(piece.to()));
          int lineLength = piece.to() - piece.from() - 1;
          if (derived + (range[1] - range[0]) - lineLength <= GpxLimits.MAX_PLANNER_DERIVED_POINTS
              && RawShapes.consistent(
                  from,
                  shape,
                  range[0],
                  range[1],
                  sources.get(s),
                  piece.from() + 1,
                  piece.to(),
                  to)) {
            raw = Arrays.copyOfRange(shape, range[0], range[1]);
          } else {
            LOG.debugf("Planner piece %d: cut of the raw source inconsistent or too long", k);
          }
        }
      } else {
        double[][] shape = pieceShapes.get(k);
        double[][] line = interiors.get(k);
        if (shape != null) {
          double[][] trimmed = RawShapes.trimEnds(from, shape, to);
          if (derived + trimmed.length - line.length <= GpxLimits.MAX_PLANNER_DERIVED_POINTS
              && RawShapes.consistent(from, trimmed, 0, trimmed.length, line, 0, line.length, to)) {
            raw = trimmed;
          } else {
            LOG.debugf("Planner piece %d: raw shape inconsistent with its line or too long", k);
          }
        }
      }
      if (raw != null) {
        derived += raw.length - interiorSize(piece, interiors.get(k));
      }
      out.add(raw);
    }
    return out;
  }

  private static double[] lngLat(PlannerJunction j) {
    return new double[] {j.lng(), j.lat()};
  }

  /**
   * The unpaved runs of a routed piece (C1a): none on a direct piece (a straight line is off the
   * network, not unpaved), else strictly ascending, disjoint, non-empty, within the piece's {@code
   * edges}. Adjacent runs are refused too: they are one run, and a canonical form keeps the state
   * stable under a round trip.
   */
  private static void checkUnpaved(
      @Nullable List<UnpavedSpan> spans, PlannerPieceMode mode, int edges) {
    if (spans == null) {
      return;
    }
    if (mode != PlannerPieceMode.ROUTED || spans.size() > GpxLimits.MAX_PLANNER_UNPAVED_SPANS) {
      throw invalid();
    }
    long previousTo = -1;
    for (UnpavedSpan span : spans) {
      if (span == null
          || span.from() <= previousTo
          || span.from() < 0
          || span.to() <= span.from()
          || span.to() > edges) {
        throw invalid();
      }
      previousTo = span.to();
    }
  }

  /** An accumulated ascent: from 0 up, never decreasing, within what a track can climb. */
  private static void checkClimb(double[] climb) {
    double previous = 0.0;
    for (double c : climb) {
      if (!(c >= previous && c <= MAX_CLIMB)) {
        throw invalid();
      }
      previous = c;
    }
  }

  private static boolean hasProvenance(PlannerJunction j, int source, int idx) {
    return j.source() != null && j.source() == source && j.idx() == idx;
  }

  private static int length(@Nullable String s) {
    return s == null ? 0 : s.length();
  }

  private static boolean finite(double d) {
    return !Double.isNaN(d) && !Double.isInfinite(d);
  }

  private static BusinessException invalid() {
    return new BusinessException(ErrorCode.PLANNER_STATE_INVALID);
  }
}
