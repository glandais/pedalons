package fr.pedalons.service.route.planner;

import fr.pedalons.common.planner.PlannerJunction;
import fr.pedalons.common.planner.PlannerJunctionKind;
import fr.pedalons.common.planner.PlannerPiece;
import fr.pedalons.common.planner.PlannerPieceMode;
import fr.pedalons.common.planner.PlannerSource;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.common.planner.UnpavedSpan;
import fr.pedalons.dto.router.request.RouterProfile;
import java.util.List;

/** Planner states for the tests of WEB-100 (C4a), small enough to run the whole GPX pipeline. */
public final class PlannerStateFixtures {

  public static final int SOURCE_POINTS = 20;

  private PlannerStateFixtures() {}

  /** A source track of {@link #SOURCE_POINTS} points about 120 m apart, around Lyon. */
  public static double[][] sourceCoords() {
    double[][] coords = new double[SOURCE_POINTS][];
    for (int i = 0; i < SOURCE_POINTS; i++) {
      coords[i] = new double[] {4.83 + 0.001 * i, 45.76 + 0.0005 * i};
    }
    return coords;
  }

  public static PlannerSource source() {
    double[][] coords = sourceCoords();
    double[] ele = new double[coords.length];
    for (int i = 0; i < ele.length; i++) {
      ele[i] = 170 + i;
    }
    return new PlannerSource(PolylineCodec.encode2(coords), PolylineCodec.encode1(ele), 1.0, null);
  }

  /** {@link #source()} with the server's accumulated ascent: 0.5 m a point, from 0. */
  public static PlannerSource sourceWithClimb() {
    PlannerSource plain = source();
    double[] climb = new double[SOURCE_POINTS];
    for (int i = 0; i < climb.length; i++) {
      climb[i] = 0.5 * i;
    }
    return new PlannerSource(plain.line(), plain.ele(), 1.0, PolylineCodec.encode1(climb));
  }

  /** {@link #example()} over {@link #sourceWithClimb()}. */
  public static PlannerState exampleWithClimb() {
    PlannerState e = example();
    return new PlannerState(
        e.version(), e.profile(), List.of(sourceWithClimb()), e.junctions(), e.pieces());
  }

  /**
   * {@link #example()} whose first routed piece (1 interior point, so 2 edges) is unpaved on its
   * second edge and whose second routed piece (2 interior points, 3 edges) on its first two.
   */
  public static PlannerState exampleWithUnpaved() {
    PlannerState e = example();
    List<PlannerPiece> pieces = new java.util.ArrayList<>(e.pieces());
    pieces.set(1, withUnpaved(pieces.get(1), List.of(new UnpavedSpan(1, 2))));
    pieces.set(2, withUnpaved(pieces.get(2), List.of(new UnpavedSpan(0, 2))));
    return new PlannerState(e.version(), e.profile(), e.sources(), e.junctions(), pieces);
  }

  private static PlannerPiece withUnpaved(PlannerPiece p, List<UnpavedSpan> spans) {
    return new PlannerPiece(
        p.mode(), p.line(), p.ele(), p.ascend(), p.source(), p.from(), p.to(), spans);
  }

  public static PlannerJunction control(double lng, double lat) {
    return new PlannerJunction(PlannerJunctionKind.CONTROL, lng, lat, null, null, null);
  }

  public static PlannerJunction fromSource(PlannerJunctionKind kind, int idx) {
    double[] c = sourceCoords()[idx];
    return new PlannerJunction(kind, c[0], c[1], 170.0 + idx, 0, idx);
  }

  public static PlannerPiece routed(double[][] interior) {
    return new PlannerPiece(
        PlannerPieceMode.ROUTED,
        PolylineCodec.encode2(interior),
        null,
        interior.length == 0 ? null : 3.5,
        null,
        null,
        null,
        null);
  }

  public static PlannerPiece direct() {
    return new PlannerPiece(PlannerPieceMode.DIRECT, "", null, null, null, null, null, null);
  }

  public static PlannerPiece imported(int from, int to) {
    return new PlannerPiece(PlannerPieceMode.IMPORTED, null, null, null, 0, from, to, null);
  }

  /**
   * The example of the plan: a file from A (idx 0) to B (idx 19), a point P dragged between the
   * anchors idx 5 and idx 8. Derived points: 2 + 4 + 2 + 1 + 1 + 10... see the tests.
   */
  public static PlannerState example() {
    double[] p = {4.8395, 45.7655};
    return new PlannerState(
        1,
        RouterProfile.GRAVEL,
        List.of(source()),
        List.of(
            fromSource(PlannerJunctionKind.CONTROL, 0),
            fromSource(PlannerJunctionKind.JOIN, 5),
            control(p[0], p[1]),
            fromSource(PlannerJunctionKind.JOIN, 8),
            fromSource(PlannerJunctionKind.CONTROL, SOURCE_POINTS - 1)),
        List.of(
            imported(0, 5),
            routed(new double[][] {{4.8372, 45.7644}}),
            routed(new double[][] {{4.8402, 45.7660}, {4.8410, 45.7664}}),
            imported(8, SOURCE_POINTS - 1)));
  }

  /** Number of points {@link #example()} derives: 5 junctions, 4 + 1 + 2 + 10 interior points. */
  public static final int EXAMPLE_DERIVED = 5 + 4 + 1 + 2 + 10;

  /** Three control points, two routed pieces and nothing imported. */
  public static PlannerState drawn() {
    return new PlannerState(
        1,
        RouterProfile.BIKE,
        List.of(),
        List.of(control(4.8300, 45.7600), control(4.8340, 45.7620), control(4.8400, 45.7650)),
        List.of(
            routed(new double[][] {{4.8320, 45.7610}}),
            routed(new double[][] {{4.8360, 45.7632}, {4.8380, 45.7641}})));
  }

  /** A file untouched: one imported piece from the first to the last point. */
  public static PlannerState importedOnly() {
    return new PlannerState(
        1,
        RouterProfile.BIKE,
        List.of(source()),
        List.of(
            fromSource(PlannerJunctionKind.CONTROL, 0),
            fromSource(PlannerJunctionKind.CONTROL, SOURCE_POINTS - 1)),
        List.of(imported(0, SOURCE_POINTS - 1)));
  }

  // ------------------------------------------------------------------ raw shapes (API-147, C)

  /**
   * {@code polyline} with {@code per - 1} points inserted evenly in each segment, its own points
   * kept: {@code (n - 1) * per + 1} points, the vertex {@code i} at index {@code i * per}.
   */
  public static double[][] densify(double[][] polyline, int per) {
    double[][] out = new double[(polyline.length - 1) * per + 1][];
    for (int i = 0; i < polyline.length - 1; i++) {
      for (int k = 0; k < per; k++) {
        double t = (double) k / per;
        out[i * per + k] =
            new double[] {
              polyline[i][0] + t * (polyline[i + 1][0] - polyline[i][0]),
              polyline[i][1] + t * (polyline[i + 1][1] - polyline[i][1])
            };
      }
    }
    out[out.length - 1] = polyline[polyline.length - 1];
    return out;
  }

  /** Points of the raw source between two of its line's: {@link #rawSourceCoords()}. */
  public static final int RAW_PER = 4;

  /** The raw track {@link #source()} stands for: its points, and three more in each segment. */
  public static double[][] rawSourceCoords() {
    return densify(sourceCoords(), RAW_PER);
  }

  /** {@link #source()} with its raw track. */
  public static PlannerSource sourceWithShape() {
    PlannerSource plain = source();
    return new PlannerSource(
        plain.line(), plain.ele(), 1.0, null, PolylineCodec.encode2(rawSourceCoords()));
  }

  /** {@link #example()} over {@link #sourceWithShape()}. */
  public static PlannerState exampleWithRawSource() {
    PlannerState e = example();
    return new PlannerState(
        e.version(), e.profile(), List.of(sourceWithShape()), e.junctions(), e.pieces());
  }

  /** Raw points of a routed piece of {@link #drawnWithShapes()} per segment of its line. */
  public static final int ROUTED_PER = 10;

  /**
   * {@link #drawn()} with the router's raw shape on both pieces, as the router answers it: the line
   * densified, both junctions included (the server drops them). Derives 3 junctions and 19 + 29
   * raw interior points.
   */
  public static PlannerState drawnWithShapes() {
    PlannerState d = drawn();
    List<PlannerPiece> pieces = new java.util.ArrayList<>();
    for (int k = 0; k < d.pieces().size(); k++) {
      PlannerPiece p = d.pieces().get(k);
      double[][] interior = PolylineCodec.decode2(p.line(), Integer.MAX_VALUE);
      double[][] full = new double[interior.length + 2][];
      full[0] = new double[] {d.junctions().get(k).lng(), d.junctions().get(k).lat()};
      System.arraycopy(interior, 0, full, 1, interior.length);
      full[full.length - 1] =
          new double[] {d.junctions().get(k + 1).lng(), d.junctions().get(k + 1).lat()};
      pieces.add(withShape(p, PolylineCodec.encode2(densify(full, ROUTED_PER))));
    }
    return new PlannerState(d.version(), d.profile(), d.sources(), d.junctions(), pieces);
  }

  /** Points {@link #drawnWithShapes()} derives. */
  public static final int DRAWN_WITH_SHAPES_DERIVED =
      3 + (2 * ROUTED_PER - 1) + (3 * ROUTED_PER - 1);

  public static PlannerPiece withShape(PlannerPiece p, String shape) {
    return new PlannerPiece(
        p.mode(), p.line(), p.ele(), p.ascend(), p.source(), p.from(), p.to(), p.unpaved(), shape);
  }

  /** {@code state} with another profile, to tell two saves apart. */
  public static PlannerState withProfile(PlannerState state, RouterProfile profile) {
    return new PlannerState(
        state.version(), profile, state.sources(), state.junctions(), state.pieces());
  }
}
