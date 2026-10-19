package fr.pedalons.service.route.planner;

import fr.pedalons.common.planner.PlannerJunction;
import fr.pedalons.common.planner.PlannerJunctionKind;
import fr.pedalons.common.planner.PlannerPiece;
import fr.pedalons.common.planner.PlannerPieceMode;
import fr.pedalons.common.planner.PlannerSource;
import fr.pedalons.common.planner.PlannerState;
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
        null);
  }

  public static PlannerPiece direct() {
    return new PlannerPiece(PlannerPieceMode.DIRECT, "", null, null, null, null, null);
  }

  public static PlannerPiece imported(int from, int to) {
    return new PlannerPiece(PlannerPieceMode.IMPORTED, null, null, null, 0, from, to);
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

  /** {@code state} with another profile, to tell two saves apart. */
  public static PlannerState withProfile(PlannerState state, RouterProfile profile) {
    return new PlannerState(
        state.version(), profile, state.sources(), state.junctions(), state.pieces());
  }
}
