package fr.pedalons.service.route.planner;

import static fr.pedalons.service.route.planner.PlannerStateFixtures.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTimeoutPreemptively;
import static org.junit.jupiter.api.Assertions.assertTrue;

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
import fr.pedalons.dto.router.request.RouterProfile;
import fr.pedalons.service.route.GpxLimits;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

class PlannerStatesTest {

  private final PlannerStates states = new PlannerStates();

  // ------------------------------------------------------------------ derivation

  @Test
  void derivesTheExampleInOrder() {
    PlannerState state = example();
    List<GeoPoint> points = states.validateAndDerive(state);
    double[][] src = sourceCoords();

    assertEquals(EXAMPLE_DERIVED, points.size());
    assertTrue(state.drawn());
    // J0, source[1..4], J1
    assertEquals(new GeoPoint(src[0][0], src[0][1]), points.get(0));
    assertEquals(new GeoPoint(src[1][0], src[1][1]), points.get(1));
    assertEquals(new GeoPoint(src[4][0], src[4][1]), points.get(4));
    assertEquals(new GeoPoint(src[5][0], src[5][1]), points.get(5));
    // interior of the first routed piece, J2 (P)
    assertEquals(new GeoPoint(4.8372, 45.7644), points.get(6));
    assertEquals(new GeoPoint(4.8395, 45.7655), points.get(7));
    // interior of the second routed piece, J3
    assertEquals(new GeoPoint(4.8402, 45.766), points.get(8));
    assertEquals(new GeoPoint(4.841, 45.7664), points.get(9));
    assertEquals(new GeoPoint(src[8][0], src[8][1]), points.get(10));
    // source[9..18], J4
    assertEquals(new GeoPoint(src[9][0], src[9][1]), points.get(11));
    assertEquals(new GeoPoint(src[18][0], src[18][1]), points.get(20));
    assertEquals(new GeoPoint(src[19][0], src[19][1]), points.get(points.size() - 1));
  }

  @Test
  void anImportedOnlyStateIsNotDrawn() {
    PlannerState state = importedOnly();
    assertFalse(state.drawn());
    assertEquals(SOURCE_POINTS, states.validateAndDerive(state).size());
  }

  @Test
  void aDrawnStateIsDrawn() {
    assertTrue(drawn().drawn());
    assertEquals(3 + 1 + 2, states.validateAndDerive(drawn()).size());
  }

  @Test
  void anEmptyInteriorIsAccepted() {
    PlannerState state =
        new PlannerState(
            1,
            drawn().profile(),
            List.of(),
            List.of(control(4.83, 45.76), control(4.84, 45.77)),
            List.of(
                new PlannerPiece(PlannerPieceMode.ROUTED, "", null, null, null, null, null, null)));
    assertEquals(2, states.validateAndDerive(state).size());
  }

  // ------------------------------------------------------------------ refusals

  @Test
  void refusals() {
    PlannerState ok = example();
    PlannerState d = drawn();

    assertInvalid(null);
    assertInvalid(rebuild(ok, 2, ok.profile(), ok.sources(), ok.junctions(), ok.pieces()));
    assertInvalid(rebuild(ok, 1, null, ok.sources(), ok.junctions(), ok.pieces()));
    // junctions != pieces + 1
    assertInvalid(rebuild(d, 1, d.profile(), d.sources(), d.junctions().subList(0, 2), d.pieces()));
    // no piece
    assertInvalid(rebuild(d, 1, d.profile(), List.of(), List.of(control(4.83, 45.76)), List.of()));
    // too many sources
    List<PlannerSource> nine = new ArrayList<>();
    for (int i = 0; i < GpxLimits.MAX_PLANNER_SOURCES + 1; i++) {
      nine.add(source());
    }
    assertInvalid(rebuild(ok, 1, ok.profile(), nine, ok.junctions(), ok.pieces()));
  }

  @Test
  void tooManyPieces() {
    int n = GpxLimits.MAX_PLANNER_PIECES + 1;
    List<PlannerJunction> junctions = new ArrayList<>();
    List<PlannerPiece> pieces = new ArrayList<>();
    for (int i = 0; i < n; i++) {
      junctions.add(control(4.83 + i * 1e-5, 45.76));
      pieces.add(direct());
    }
    junctions.add(control(4.9, 45.76));
    assertInvalid(new PlannerState(1, drawn().profile(), List.of(), junctions, pieces));
    // The bound itself is accepted
    junctions.removeLast();
    junctions.removeLast();
    pieces.removeLast();
    junctions.add(control(4.9, 45.76));
    assertEquals(
        GpxLimits.MAX_PLANNER_PIECES + 1,
        states
            .validateAndDerive(new PlannerState(1, drawn().profile(), List.of(), junctions, pieces))
            .size());
  }

  @Test
  void tooManyCharacters() {
    String filler = "?".repeat(GpxLimits.MAX_PLANNER_STATE_CHARS);
    PlannerState d = drawn();
    List<PlannerPiece> pieces = new ArrayList<>(d.pieces());
    pieces.set(
        0, new PlannerPiece(PlannerPieceMode.ROUTED, filler, null, null, null, null, null, null));
    pieces.set(
        1, new PlannerPiece(PlannerPieceMode.ROUTED, "?", null, null, null, null, null, null));
    assertInvalid(rebuild(d, 1, d.profile(), d.sources(), d.junctions(), pieces));
  }

  @Test
  void sourceRefusals() {
    PlannerState ok = example();
    PlannerSource good = source();
    // a source of one point
    assertInvalid(
        withSource(
            ok,
            new PlannerSource(
                PolylineCodec.encode2(new double[][] {{4.8, 45.7}}), null, 1.0, null)));
    // ele of the wrong cardinality
    assertInvalid(
        withSource(
            ok,
            new PlannerSource(
                good.line(), PolylineCodec.encode1(new double[] {1, 2, 3}), 1.0, null)));
    // ascendScale 0, NaN, > 100
    assertInvalid(withSource(ok, new PlannerSource(good.line(), good.ele(), 0, null)));
    assertInvalid(withSource(ok, new PlannerSource(good.line(), good.ele(), Double.NaN, null)));
    assertInvalid(withSource(ok, new PlannerSource(good.line(), good.ele(), 100.5, null)));
    // a truncated line
    assertInvalid(
        withSource(
            ok,
            new PlannerSource(
                good.line().substring(0, good.line().length() - 1), null, 1.0, null)));
  }

  @Test
  void climbRefusals() {
    PlannerState ok = example();
    PlannerSource good = source();
    int n = SOURCE_POINTS;
    double[] rising = new double[n];
    for (int i = 0; i < n; i++) {
      rising[i] = i;
    }
    // absent climb is accepted (checked by every other test); a valid one too
    states.validateAndDerive(
        withSource(
            ok, new PlannerSource(good.line(), good.ele(), 1.0, PolylineCodec.encode1(rising))));
    // wrong cardinality
    assertInvalid(
        withSource(
            ok,
            new PlannerSource(
                good.line(), good.ele(), 1.0, PolylineCodec.encode1(new double[] {0, 1, 2}))));
    // a negative delta
    double[] falling = rising.clone();
    falling[3] = 0.5;
    assertInvalid(
        withSource(
            ok, new PlannerSource(good.line(), good.ele(), 1.0, PolylineCodec.encode1(falling))));
    // a negative value
    double[] negative = rising.clone();
    negative[0] = -1;
    assertInvalid(
        withSource(
            ok, new PlannerSource(good.line(), good.ele(), 1.0, PolylineCodec.encode1(negative))));
    // over 100 000 m
    double[] huge = rising.clone();
    huge[n - 1] = 100_000.1;
    assertInvalid(
        withSource(
            ok, new PlannerSource(good.line(), good.ele(), 1.0, PolylineCodec.encode1(huge))));
    // climb without ele
    assertInvalid(
        withSource(ok, new PlannerSource(good.line(), null, 1.0, PolylineCodec.encode1(rising))));
    // climb counts in the character budget
    assertInvalid(
        withSource(
            ok,
            new PlannerSource(
                good.line(), good.ele(), 1.0, "?".repeat(GpxLimits.MAX_PLANNER_STATE_CHARS + 1))));
  }

  @Test
  void junctionRefusals() {
    PlannerState ok = example();
    // first junction is a JOIN
    assertInvalid(withJunction(ok, 0, fromSource(PlannerJunctionKind.JOIN, 0)));
    // latitude 91
    assertInvalid(
        withJunction(
            ok, 2, new PlannerJunction(PlannerJunctionKind.CONTROL, 4.8, 91, null, null, null)));
    // source without idx
    assertInvalid(
        withJunction(
            ok, 2, new PlannerJunction(PlannerJunctionKind.CONTROL, 4.8, 45.7, null, 0, null)));
    // idx without source
    assertInvalid(
        withJunction(
            ok, 2, new PlannerJunction(PlannerJunctionKind.CONTROL, 4.8, 45.7, null, null, 3)));
    // idx out of the source
    assertInvalid(
        withJunction(
            ok,
            2,
            new PlannerJunction(PlannerJunctionKind.CONTROL, 4.8, 45.7, null, 0, SOURCE_POINTS)));
    // unknown source
    assertInvalid(
        withJunction(
            ok, 2, new PlannerJunction(PlannerJunctionKind.CONTROL, 4.8, 45.7, null, 1, 0)));
    // elevation out of bounds
    assertInvalid(
        withJunction(
            ok,
            2,
            new PlannerJunction(PlannerJunctionKind.CONTROL, 4.8, 45.7, 20_000.0, null, null)));
    // NaN
    assertInvalid(
        withJunction(
            ok,
            2,
            new PlannerJunction(PlannerJunctionKind.CONTROL, Double.NaN, 45.7, null, null, null)));
  }

  @Test
  void pieceRefusals() {
    PlannerState ok = example();
    // from == to
    assertInvalid(withPiece(ok, 0, imported(5, 5)));
    // to outside the source
    assertInvalid(withPiece(ok, 3, imported(8, SOURCE_POINTS)));
    // junction provenance != (source, from)
    assertInvalid(withPiece(ok, 0, imported(1, 5)));
    assertInvalid(withPiece(ok, 0, imported(0, 4)));
    // ROUTED without line
    assertInvalid(
        withPiece(
            ok,
            1,
            new PlannerPiece(PlannerPieceMode.ROUTED, null, null, null, null, null, null, null)));
    // ascend on a DIRECT piece
    assertInvalid(
        withPiece(
            ok,
            1,
            new PlannerPiece(PlannerPieceMode.DIRECT, "", null, 3.0, null, null, null, null)));
    // negative or NaN ascend
    assertInvalid(
        withPiece(
            ok,
            1,
            new PlannerPiece(PlannerPieceMode.ROUTED, "", null, -1.0, null, null, null, null)));
    assertInvalid(
        withPiece(
            ok,
            1,
            new PlannerPiece(
                PlannerPieceMode.ROUTED, "", null, Double.NaN, null, null, null, null)));
    // ele of the wrong cardinality
    assertInvalid(
        withPiece(
            ok,
            1,
            new PlannerPiece(
                PlannerPieceMode.ROUTED,
                PolylineCodec.encode2(new double[][] {{4.837, 45.764}}),
                PolylineCodec.encode1(new double[] {1, 2}),
                null,
                null,
                null,
                null,
                null)));
    // IMPORTED carrying a line
    assertInvalid(
        withPiece(
            ok, 0, new PlannerPiece(PlannerPieceMode.IMPORTED, "", null, null, 0, 0, 5, null)));
  }

  @Test
  void derivedPointsOverTheBoundAreRefusedBeforeAllocation() {
    // A single imported piece over a source that is itself at the bound, plus one routed point
    int n = GpxLimits.MAX_PLANNER_POINTS;
    double[][] big = new double[n][];
    for (int i = 0; i < n; i++) {
      big[i] = new double[] {4.0 + (i % 1000) * 1e-4, 45.0 + (i / 1000) * 1e-4};
    }
    PlannerSource source = new PlannerSource(PolylineCodec.encode2(big), null, 1.0, null);
    PlannerJunction first =
        new PlannerJunction(PlannerJunctionKind.CONTROL, big[0][0], big[0][1], null, 0, 0);
    PlannerJunction mid =
        new PlannerJunction(PlannerJunctionKind.JOIN, big[n - 1][0], big[n - 1][1], null, 0, n - 1);
    PlannerJunction last = control(4.5, 45.5);
    PlannerState state =
        new PlannerState(
            1,
            drawn().profile(),
            List.of(source),
            List.of(first, mid, last),
            List.of(
                imported(0, n - 1),
                new PlannerPiece(
                    PlannerPieceMode.ROUTED,
                    PolylineCodec.encode2(new double[][] {{4.4, 45.4}}),
                    null,
                    null,
                    null,
                    null,
                    null,
                    null)));
    // n + 1 junction-and-interior points from the first piece (n) + 1 junction + 1 interior + last
    assertInvalid(state);
  }

  // ------------------------------------------------------------------ helpers

  private void assertInvalid(PlannerState state) {
    BusinessException e =
        assertThrows(BusinessException.class, () -> states.validateAndDerive(state));
    assertEquals(ErrorCode.PLANNER_STATE_INVALID, e.getErrorCode());
  }

  private static PlannerState rebuild(
      PlannerState base,
      int version,
      fr.pedalons.dto.router.request.RouterProfile profile,
      List<PlannerSource> sources,
      List<PlannerJunction> junctions,
      List<PlannerPiece> pieces) {
    return new PlannerState(version, profile, sources, junctions, pieces);
  }

  private static PlannerState withSource(PlannerState s, PlannerSource source) {
    return new PlannerState(s.version(), s.profile(), List.of(source), s.junctions(), s.pieces());
  }

  // ------------------------------------------------------------------ unpaved runs (C1a)

  /** The second routed piece of {@link #example()} (index 2): 2 interior points, so 3 edges. */
  private static PlannerState withUnpaved(UnpavedSpan... spans) {
    PlannerPiece p = routed(new double[][] {{4.8402, 45.7660}, {4.8410, 45.7664}});
    return withPiece(
        example(),
        2,
        new PlannerPiece(
            p.mode(), p.line(), p.ele(), p.ascend(), null, null, null, List.of(spans)));
  }

  @Test
  void unpavedRunsOfARoutedPieceAreAccepted() {
    assertEquals(
        EXAMPLE_DERIVED,
        states.validateAndDerive(withUnpaved(new UnpavedSpan(0, 1), new UnpavedSpan(2, 3))).size());
    // The whole piece, and no run at all (all paved) are both valid.
    states.validateAndDerive(withUnpaved(new UnpavedSpan(0, 3)));
    states.validateAndDerive(withUnpaved());
  }

  @Test
  void unpavedRunsRefusals() {
    // beyond the 3 edges of the piece
    assertInvalid(withUnpaved(new UnpavedSpan(0, 4)));
    // empty, reversed, negative
    assertInvalid(withUnpaved(new UnpavedSpan(1, 1)));
    assertInvalid(withUnpaved(new UnpavedSpan(2, 1)));
    assertInvalid(withUnpaved(new UnpavedSpan(-1, 1)));
    // not ascending, overlapping, adjacent (one run in canonical form)
    assertInvalid(withUnpaved(new UnpavedSpan(2, 3), new UnpavedSpan(0, 1)));
    assertInvalid(withUnpaved(new UnpavedSpan(0, 2), new UnpavedSpan(1, 3)));
    assertInvalid(withUnpaved(new UnpavedSpan(0, 1), new UnpavedSpan(1, 3)));
    // too many runs
    List<UnpavedSpan> many = new ArrayList<>();
    for (int i = 0; i <= GpxLimits.MAX_PLANNER_UNPAVED_SPANS; i++) {
      many.add(new UnpavedSpan(2 * i, 2 * i + 1));
    }
    PlannerPiece p = routed(new double[][] {{4.8402, 45.7660}, {4.8410, 45.7664}});
    assertInvalid(
        withPiece(
            example(),
            2,
            new PlannerPiece(p.mode(), p.line(), p.ele(), p.ascend(), null, null, null, many)));
    // a null run
    List<UnpavedSpan> withNull = new ArrayList<>();
    withNull.add(null);
    assertInvalid(
        withPiece(
            example(),
            2,
            new PlannerPiece(p.mode(), p.line(), p.ele(), p.ascend(), null, null, null, withNull)));
  }

  @Test
  void unpavedRunsAreRefusedOnAnotherMode() {
    List<UnpavedSpan> spans = List.of(new UnpavedSpan(0, 1));
    assertInvalid(
        withPiece(
            example(),
            2,
            new PlannerPiece(PlannerPieceMode.DIRECT, "", null, null, null, null, null, spans)));
    PlannerPiece imported = imported(0, 5);
    assertInvalid(
        withPiece(
            example(),
            0,
            new PlannerPiece(
                imported.mode(),
                null,
                null,
                null,
                imported.source(),
                imported.from(),
                imported.to(),
                spans)));
  }

  private static PlannerState withJunction(PlannerState s, int i, PlannerJunction j) {
    List<PlannerJunction> list = new ArrayList<>(s.junctions());
    list.set(i, j);
    return new PlannerState(s.version(), s.profile(), s.sources(), list, s.pieces());
  }

  private static PlannerState withPiece(PlannerState s, int i, PlannerPiece p) {
    List<PlannerPiece> list = new ArrayList<>(s.pieces());
    list.set(i, p);
    return new PlannerState(s.version(), s.profile(), s.sources(), s.junctions(), list);
  }

  // ------------------------------------------------------------------ direct runs (C1b)

  @Test
  void directRunsLocateTheStraightPiecesAlongTheDerivedLine() {
    // Two routed pieces would be c0 - c1 - c2; here the second is a straight line
    PlannerState state =
        new PlannerState(
            1,
            fr.pedalons.dto.router.request.RouterProfile.BIKE,
            List.of(),
            List.of(control(4.8300, 45.7600), control(4.8340, 45.7620), control(4.8400, 45.7650)),
            List.of(routed(new double[][] {{4.8320, 45.7610}}), direct()));
    PlannerStates.DirectRuns runs = states.directRuns(state);
    List<GeoPoint> line = states.validateAndDerive(state);
    assertEquals(4, line.size());
    assertEquals(1, runs.runs().size());
    double toC1 = distance(line.subList(0, 3));
    double total = distance(line);
    assertEquals(total, runs.length(), 0.01);
    assertEquals(toC1, runs.runs().getFirst()[0], 0.01);
    assertEquals(total, runs.runs().getFirst()[1], 0.01);
  }

  @Test
  void directRunsCountTheImportedAndRoutedPointsBeforeThem() {
    // example() with its second routed piece (P to the JOIN at idx 8) drawn straight: imported
    // 0-5 (4 interiors), routed (1), then the straight piece between derived points 7 and 8
    PlannerState e = example();
    List<PlannerPiece> pieces = new ArrayList<>(e.pieces());
    pieces.set(2, direct());
    PlannerState state =
        new PlannerState(e.version(), e.profile(), e.sources(), e.junctions(), pieces);
    PlannerStates.DirectRuns runs = states.directRuns(state);
    List<GeoPoint> line = states.validateAndDerive(state);
    assertEquals(1, runs.runs().size());
    assertEquals(distance(line.subList(0, 8)), runs.runs().getFirst()[0], 0.01);
    assertEquals(distance(line.subList(0, 9)), runs.runs().getFirst()[1], 0.01);
    assertEquals(distance(line), runs.length(), 0.01);
  }

  @Test
  void directRunsOfAStateWithoutStraightPiecesAreEmptyButGiveTheLength() {
    PlannerStates.DirectRuns runs = states.directRuns(example());
    assertTrue(runs.runs().isEmpty());
    assertEquals(distance(states.validateAndDerive(example())), runs.length(), 0.01);
  }

  @Test
  void directRunsOfAnInvalidStateAreEmpty() {
    PlannerStates.DirectRuns runs = states.directRuns(null);
    assertEquals(0, runs.length(), 0);
    assertTrue(runs.runs().isEmpty());
  }

  // ------------------------------------------------------------------ raw shapes (API-147, C)

  @Test
  void aRoutedPieceIsDerivedFromItsShapeWithoutItsEnds() {
    PlannerState state = drawnWithShapes();
    List<GeoPoint> points = states.validateAndDerive(state);
    assertEquals(DRAWN_WITH_SHAPES_DERIVED, points.size());
    double[][] first = PolylineCodec.decode2(state.pieces().getFirst().shape(), Integer.MAX_VALUE);
    assertEquals(new GeoPoint(4.83, 45.76), points.getFirst());
    // The router's first point is the junction: dropped, the next one follows it
    assertEquals(new GeoPoint(first[1][0], first[1][1]), points.get(1));
    assertEquals(
        new GeoPoint(first[first.length - 2][0], first[first.length - 2][1]), points.get(19));
    assertEquals(new GeoPoint(4.834, 45.762), points.get(20));
    assertEquals(new GeoPoint(4.84, 45.765), points.getLast());
  }

  @Test
  void aStateWithoutShapeDerivesItsLinesAsBefore() {
    assertEquals(
        states.validateAndDerive(drawn()).size(),
        states.validateAndDerive(withoutShapes(drawnWithShapes())).size());
    assertEquals(EXAMPLE_DERIVED, states.validateAndDerive(example()).size());
  }

  @Test
  void anImportedPieceIsCutOutOfTheRawSourceAtItsJunctions() {
    List<GeoPoint> points = states.validateAndDerive(exampleWithRawSource());
    double[][] raw = rounded(rawSourceCoords());
    // imported 0-5: raw 1..19; routed 1 + 2 from their lines; imported 8-19: raw 33..75
    int first = 5 * RAW_PER - 1;
    int last = (SOURCE_POINTS - 1 - 8) * RAW_PER - 1;
    assertEquals(5 + first + 1 + 2 + last, points.size());
    assertEquals(new GeoPoint(raw[1][0], raw[1][1]), points.get(1));
    assertEquals(new GeoPoint(raw[19][0], raw[19][1]), points.get(19));
    double[] j1 = sourceCoords()[5];
    assertEquals(new GeoPoint(j1[0], j1[1]), points.get(20));
    assertEquals(new GeoPoint(raw[33][0], raw[33][1]), points.get(26));
    assertEquals(new GeoPoint(raw[75][0], raw[75][1]), points.get(points.size() - 2));
  }

  @Test
  void anOutAndBackSourceIsCutOnTheRightLeg() {
    // Out along a parallel and back on the very same points: idx 11 lies where idx 7 does
    int n = 19;
    double[][] line = new double[n][];
    for (int i = 0; i < n; i++) {
      line[i] = new double[] {4.83 + 0.001 * Math.min(i, n - 1 - i), 45.76};
    }
    double[][] raw = rounded(densify(line, RAW_PER));
    PlannerSource source =
        new PlannerSource(PolylineCodec.encode2(line), null, 1.0, null, PolylineCodec.encode2(raw));
    PlannerState state =
        new PlannerState(
            1,
            fr.pedalons.dto.router.request.RouterProfile.BIKE,
            List.of(source),
            List.of(
                junctionAt(line, PlannerJunctionKind.CONTROL, 0),
                junctionAt(line, PlannerJunctionKind.JOIN, 11),
                junctionAt(line, PlannerJunctionKind.CONTROL, n - 1)),
            List.of(imported(0, 11), imported(11, n - 1)));
    List<GeoPoint> points = states.validateAndDerive(state);
    // raw 1..43, the junction, raw 45..71
    assertEquals(3 + (11 * RAW_PER - 1) + (7 * RAW_PER - 1), points.size());
    assertEquals(new GeoPoint(raw[43][0], raw[43][1]), points.get(43));
    assertEquals(new GeoPoint(line[11][0], line[11][1]), points.get(44));
    assertEquals(new GeoPoint(raw[45][0], raw[45][1]), points.get(45));
    assertEquals(new GeoPoint(raw[71][0], raw[71][1]), points.get(points.size() - 2));
  }

  @Test
  void anInconsistentRoutedShapeIsIgnored() {
    int expected = states.validateAndDerive(drawn()).size();
    // A kilometre north of its piece
    double[][] away = {{4.832, 45.770}, {4.833, 45.771}};
    assertEquals(
        expected,
        states
            .validateAndDerive(
                withPiece(
                    drawn(),
                    0,
                    withShape(drawn().pieces().getFirst(), PolylineCodec.encode2(away))))
            .size());
    // Right ends, two kilometres of detour between them
    double[][] detour = {{4.8301, 45.7601}, {4.83, 45.78}, {4.8339, 45.7619}};
    assertEquals(
        expected,
        states
            .validateAndDerive(
                withPiece(
                    drawn(),
                    0,
                    withShape(drawn().pieces().getFirst(), PolylineCodec.encode2(detour))))
            .size());
  }

  @Test
  void anInconsistentRawSourceIsIgnored() {
    double[][] raw = rawSourceCoords();
    for (double[] p : raw) {
      p[1] += 0.01;
    }
    PlannerSource plain = source();
    PlannerSource shifted =
        new PlannerSource(plain.line(), plain.ele(), 1.0, null, PolylineCodec.encode2(raw));
    PlannerState e = example();
    assertEquals(
        EXAMPLE_DERIVED,
        states
            .validateAndDerive(
                new PlannerState(
                    e.version(), e.profile(), List.of(shifted), e.junctions(), e.pieces()))
            .size());
  }

  @Test
  void shapesPastTheirPointBudgetAreIgnoredNotRefused() {
    double[][] many = new double[GpxLimits.MAX_PLANNER_SHAPE_POINTS + 1][];
    for (int i = 0; i < many.length; i++) {
      many[i] = new double[] {4.832, 45.761};
    }
    PlannerState state =
        withPiece(drawn(), 0, withShape(drawn().pieces().getFirst(), PolylineCodec.encode2(many)));
    assertEquals(states.validateAndDerive(drawn()).size(), states.validateAndDerive(state).size());
  }

  @Test
  void shapeRefusals() {
    PlannerState ok = drawnWithShapes();
    // malformed
    assertInvalid(withPiece(ok, 0, withShape(ok.pieces().getFirst(), "not a polyline \u0001")));
    // on a straight piece, on an imported one
    assertInvalid(withPiece(ok, 0, withShape(direct(), ok.pieces().getFirst().shape())));
    PlannerState e = example();
    assertInvalid(
        withPiece(e, 0, withShape(e.pieces().getFirst(), ok.pieces().getFirst().shape())));
    // a source shape malformed, or of a single point
    PlannerSource plain = source();
    assertInvalid(withSource(e, new PlannerSource(plain.line(), plain.ele(), 1.0, null, "?")));
    assertInvalid(
        withSource(
            e,
            new PlannerSource(
                plain.line(),
                plain.ele(),
                1.0,
                null,
                PolylineCodec.encode2(new double[][] {{4.83, 45.76}}))));
    // counted with the other strings
    String filler = "?".repeat(GpxLimits.MAX_PLANNER_STATE_CHARS);
    assertInvalid(withPiece(ok, 0, withShape(ok.pieces().getFirst(), filler)));
  }

  @Test
  void directRunsFollowTheLinesNotTheRawShapes() {
    // A jittery raw source, about 300 m longer than its line, then a straight piece
    double[][] raw = rawSourceCoords();
    for (int i = 1; i < raw.length - 1; i += 2) {
      raw[i] = new double[] {raw[i][0], raw[i][1] + 0.00015};
    }
    PlannerSource plain = source();
    PlannerSource jittery =
        new PlannerSource(plain.line(), plain.ele(), 1.0, null, PolylineCodec.encode2(raw));
    List<PlannerJunction> junctions =
        List.of(
            fromSource(PlannerJunctionKind.CONTROL, 0),
            fromSource(PlannerJunctionKind.CONTROL, SOURCE_POINTS - 1),
            control(4.8600, 45.7800));
    List<PlannerPiece> pieces = List.of(imported(0, SOURCE_POINTS - 1), direct());
    PlannerState withRaw =
        new PlannerState(1, RouterProfile.BIKE, List.of(jittery), junctions, pieces);
    PlannerState lines = new PlannerState(1, RouterProfile.BIKE, List.of(plain), junctions, pieces);
    List<GeoPoint> derived = states.validateAndDerive(withRaw);
    // The track takes the raw source, 300 m longer than the line
    assertEquals(3 + (SOURCE_POINTS - 1) * RAW_PER - 1, derived.size());
    assertTrue(distance(derived) > distance(states.validateAndDerive(lines)) + 250);

    PlannerStates.DirectRuns runs = states.directRuns(withRaw);
    PlannerStates.DirectRuns expected = states.directRuns(lines);
    assertEquals(expected.length(), runs.length(), 0.01);
    assertEquals(1, runs.runs().size());
    assertEquals(expected.runs().getFirst()[0], runs.runs().getFirst()[0], 0.01);
    assertEquals(expected.runs().getFirst()[1], runs.runs().getFirst()[1], 0.01);
  }

  @Test
  void aRawSourceTooLongToWalkIsIgnoredBeforeTheWalk() {
    // Each segment half way round the globe: the walk would take a station every 20 m of it
    int n = 1001;
    double[][] line = new double[n][];
    for (int i = 0; i < n; i++) {
      line[i] = new double[] {i % 2 == 0 ? -89.9 : 89.9, 0.0};
    }
    String encoded = PolylineCodec.encode2(line);
    PlannerSource withShape = new PlannerSource(encoded, null, 1.0, null, encoded);
    PlannerSource plain = new PlannerSource(encoded, null, 1.0, null);
    List<PlannerJunction> junctions =
        List.of(
            junctionAt(line, PlannerJunctionKind.CONTROL, 0),
            junctionAt(line, PlannerJunctionKind.JOIN, n - 2),
            control(0.0, 1.0));
    List<PlannerPiece> pieces = List.of(imported(0, n - 2), direct());
    PlannerState state =
        new PlannerState(1, RouterProfile.BIKE, List.of(withShape), junctions, pieces);
    List<GeoPoint> derived =
        assertTimeoutPreemptively(Duration.ofSeconds(5), () -> states.validateAndDerive(state));
    assertEquals(
        states
            .validateAndDerive(
                new PlannerState(1, RouterProfile.BIKE, List.of(plain), junctions, pieces))
            .size(),
        derived.size());
  }

  /** {@code points} as a polyline carries them, to the microdegree. */
  private static double[][] rounded(double[][] points) {
    return PolylineCodec.decode2(PolylineCodec.encode2(points), Integer.MAX_VALUE);
  }

  private static PlannerState withoutShapes(PlannerState s) {
    return new PlannerState(
        s.version(),
        s.profile(),
        s.sources(),
        s.junctions(),
        s.pieces().stream().map(p -> withShape(p, null)).toList());
  }

  private static PlannerJunction junctionAt(double[][] line, PlannerJunctionKind kind, int idx) {
    return new PlannerJunction(kind, line[idx][0], line[idx][1], null, 0, idx);
  }

  private static double distance(List<GeoPoint> line) {
    double d = 0;
    for (int i = 1; i < line.size(); i++) {
      d +=
          fr.pedalons.common.GeoDistance.haversineMeters(
              line.get(i - 1).lat(), line.get(i - 1).lng(), line.get(i).lat(), line.get(i).lng());
    }
    return d;
  }
}
