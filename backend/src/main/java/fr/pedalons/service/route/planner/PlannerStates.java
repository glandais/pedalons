package fr.pedalons.service.route.planner;

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
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * Validates a planner state sent by a client and derives the track from it (docs/LEDGER_*.md
 * WEB-100, C4a). The state and the track cannot diverge: the track is always the one this derives.
 *
 * <p>Every refusal is a {@code PLANNER_STATE_INVALID}. Each step is bounded before it allocates, so
 * a hostile state costs at most {@link GpxLimits#MAX_PLANNER_STATE_CHARS} characters of decoding.
 */
@ApplicationScoped
public class PlannerStates {

  private static final double MAX_ASCEND_SCALE = 100.0;
  private static final double MIN_ELE = -1_000.0;
  private static final double MAX_ELE = 10_000.0;
  private static final double MAX_CLIMB = 100_000.0;

  /** A validated state, decoded. */
  private record Decoded(List<double[][]> sources, List<double[][]> interiors) {}

  /** The points of the track the state stands for, junctions and interiors in order. */
  public List<GeoPoint> validateAndDerive(@Nullable PlannerState state) {
    Decoded decoded = validate(state);
    PlannerState s = java.util.Objects.requireNonNull(state);
    List<PlannerJunction> junctions = s.junctions();
    List<PlannerPiece> pieces = s.pieces();
    int total = 1;
    for (int k = 0; k < pieces.size(); k++) {
      total += interiorSize(pieces.get(k), decoded.interiors().get(k)) + 1;
    }
    List<GeoPoint> out = new ArrayList<>(total);
    out.add(point(junctions.getFirst()));
    for (int k = 0; k < pieces.size(); k++) {
      PlannerPiece piece = pieces.get(k);
      if (piece.mode() == PlannerPieceMode.IMPORTED) {
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

  private static Decoded validate(@Nullable PlannerState state) {
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
      chars += length(source.line()) + length(source.ele()) + length(source.climb());
    }
    for (PlannerPiece piece : pieces) {
      if (piece == null) {
        throw invalid();
      }
      chars += length(piece.line()) + length(piece.ele());
    }
    if (chars > GpxLimits.MAX_PLANNER_STATE_CHARS) {
      throw invalid();
    }
    // 4: one budget for all the sources
    int budget = GpxLimits.MAX_PLANNER_POINTS;
    List<double[][]> decodedSources = new ArrayList<>(sources.size());
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
      } else {
        if (piece.line() == null
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
      }
      if (total > GpxLimits.MAX_PLANNER_POINTS) {
        throw invalid();
      }
    }
    if (total < 2) {
      throw invalid();
    }
    return new Decoded(decodedSources, interiors);
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
