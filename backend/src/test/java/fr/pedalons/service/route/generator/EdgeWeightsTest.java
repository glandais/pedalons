package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.BitSet;
import org.junit.jupiter.api.Test;

class EdgeWeightsTest {
  private static final GeneratorParameters P = GeneratorParameters.defaults();

  /** Three 4 km edges from A: a popular one (support 10), a rare one, and an unpaved one. */
  private static TestNetwork star() {
    TestNetwork n =
        new TestNetwork(45, 5)
            .node("A", 0, 0)
            .node("P", 4000, 0)
            .node("R", 0, 4000)
            .node("U", -4000, 0);
    for (int i = 0; i < 10; i++) {
      n.track(1 + i).wayKind(WayKind.MINOR_ROAD).unpaved(false).path("A", "P");
    }
    n.track(20).wayKind(WayKind.MINOR_ROAD).unpaved(false).path("A", "R");
    n.track(21).wayKind(WayKind.MINOR_ROAD).unpaved(true).path("A", "U");
    return n;
  }

  @Test
  void theFamiliaritySliderMakesPopularEdgesCheaperOrDearer() {
    TestNetwork n = star();
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int popular = n.state(g, "A", "P");
    int rare = n.state(g, "A", "R");

    double[] often = EdgeWeights.build(qg, P, 1.0, RideType.ROAD, ZSource.ROAD);
    assertTrue(often[popular] < often[rare]);
    double[] seldom = EdgeWeights.build(qg, P, 0.0, RideType.ROAD, ZSource.ROAD);
    assertTrue(seldom[popular] > seldom[rare]);
    double[] neutral = EdgeWeights.build(qg, P, 0.5, RideType.ROAD, ZSource.ROAD);
    assertEquals(neutral[popular], neutral[rare], 5);
    // both directions of an edge weigh the same
    assertEquals(often[popular], often[popular ^ 1], 0);
  }

  @Test
  void aShortEdgeCostsMoreThanItsLengthAndALongOneBarelyDoes() {
    TestNetwork n = star();
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    double[] w = EdgeWeights.build(qg, P, 0.5, RideType.ROAD, ZSource.ROAD);
    int rare = n.state(g, "A", "R");
    double len = qg.length(rare >>> 1);
    // 4 km is longer than the 500 m reference: junction penalty = 0.1 * 500 / 4000
    assertEquals(len * (1 + 0.1 * 500 / len), w[rare], 1e-6);
  }

  @Test
  void roadBansTheUnpavedEdgesAndGravelKeepsThem() {
    TestNetwork n = star();
    NetworkGraph g = n.build();
    QueryGraph qg = QueryGraph.of(g);
    int unpaved = n.edgeBetween(g, "A", "U");
    BitSet road = EdgeWeights.banned(qg, RideType.ROAD);
    assertTrue(road.get(unpaved));
    assertEquals(1, road.cardinality());
    assertFalse(EdgeWeights.banned(qg, RideType.GRAVEL).get(unpaved));
    assertFalse(EdgeWeights.banned(qg, RideType.MTB).get(unpaved));
  }

  /** One edge A-B ridden by one track of {@code ridden}, admitted for the type? */
  private static boolean admitted(
      RideType type,
      TrackKind ridden,
      WayKind way,
      SurfaceClass sc,
      String detail,
      Access bicycle) {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 2000, 0);
    TestNetwork.Track t = n.track(1, ridden).wayKind(way).bicycle(bicycle);
    if (sc != null) {
      t.surface(sc, detail, detail == null ? SurfaceSource.INFERRED_HIGHWAY : SurfaceSource.TAGGED);
    }
    t.path("A", "B");
    QueryGraph qg = QueryGraph.of(n.build());
    return EdgeWeights.admitted(qg, 0, type);
  }

  @Test
  void theAdmissionTableRowByRow() {
    TrackKind road = TrackKind.ROAD;
    // paved roads and cycleways: every type
    for (RideType t : RideType.values()) {
      assertTrue(
          admitted(t, road, WayKind.MAJOR_ROAD, SurfaceClass.PAVED, "asphalt", null), "" + t);
    }
    assertTrue(admitted(RideType.ROAD, road, WayKind.CYCLEWAY, SurfaceClass.PAVED, null, null));
    // unpaved: never for road, rolling for gravel and mtb
    assertFalse(
        admitted(
            RideType.ROAD,
            TrackKind.GRAVEL,
            WayKind.MINOR_ROAD,
            SurfaceClass.UNPAVED,
            "gravel",
            null));
    assertTrue(
        admitted(RideType.GRAVEL, road, WayKind.MINOR_ROAD, SurfaceClass.UNPAVED, "gravel", null));
    assertTrue(
        admitted(RideType.MTB, road, WayKind.TRACK, SurfaceClass.UNPAVED, "compacted", null));
    // rough or a path: gravel needs a gravel or mixed track
    assertFalse(
        admitted(RideType.GRAVEL, road, WayKind.MINOR_ROAD, SurfaceClass.UNPAVED, "dirt", null));
    assertTrue(
        admitted(
            RideType.GRAVEL,
            TrackKind.GRAVEL,
            WayKind.MINOR_ROAD,
            SurfaceClass.UNPAVED,
            "dirt",
            null));
    assertFalse(admitted(RideType.GRAVEL, road, WayKind.PATH, null, null, null));
    assertTrue(admitted(RideType.GRAVEL, TrackKind.MIXED, WayKind.PATH, null, null, null));
    assertFalse(admitted(RideType.ROAD, road, WayKind.PATH, null, null, null));
    assertTrue(admitted(RideType.MTB, road, WayKind.PATH, null, null, null));
    // steps: never for road and gravel, only mtb tracks for mtb
    assertFalse(admitted(RideType.ROAD, road, WayKind.STEPS, null, null, null));
    assertFalse(admitted(RideType.GRAVEL, TrackKind.GRAVEL, WayKind.STEPS, null, null, null));
    assertFalse(admitted(RideType.MTB, road, WayKind.STEPS, null, null, null));
    assertTrue(admitted(RideType.MTB, TrackKind.MTB, WayKind.STEPS, null, null, null));
    // unknown kind and surface: road only when a road track rode it
    assertTrue(admitted(RideType.ROAD, road, WayKind.UNKNOWN, null, null, null));
    assertFalse(admitted(RideType.ROAD, TrackKind.GRAVEL, WayKind.UNKNOWN, null, null, null));
    assertTrue(admitted(RideType.GRAVEL, TrackKind.GRAVEL, WayKind.UNKNOWN, null, null, null));
    // api 1.8: a path that bicycles may use is a cycleway; a bicycle ban needs a track of the kind
    assertTrue(
        admitted(RideType.ROAD, road, WayKind.PATH, SurfaceClass.PAVED, "asphalt", Access.YES));
    assertFalse(
        admitted(
            RideType.ROAD, road, WayKind.MINOR_ROAD, SurfaceClass.PAVED, "asphalt", Access.NO));
    assertFalse(
        admitted(RideType.MTB, road, WayKind.MINOR_ROAD, SurfaceClass.PAVED, "asphalt", Access.NO));
    assertTrue(
        admitted(
            RideType.MTB,
            TrackKind.MTB,
            WayKind.MINOR_ROAD,
            SurfaceClass.PAVED,
            "asphalt",
            Access.NO));
  }

  @Test
  void theFamiliarityOfATypeCountsItsOwnKindsFirst() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 2000, 0).node("C", 0, 2000);
    for (int i = 0; i < 5; i++) {
      n.track(1 + i, TrackKind.ROAD).path("A", "B");
    }
    n.track(10, TrackKind.GRAVEL).path("A", "C");
    n.track(11, TrackKind.GRAVEL).path("A", "C");
    NetworkGraph g = n.build();
    int ab = n.edgeBetween(g, "A", "B");
    int ac = n.edgeBetween(g, "A", "C");
    assertTrue(g.z(ab, ZSource.ROAD) > g.z(ac, ZSource.ROAD));
    assertTrue(g.z(ac, ZSource.GRAVEL) > 0);
    // road is a secondary kind of gravel: the road edge still has a non-zero gravel familiarity
    assertTrue(g.z(ab, ZSource.GRAVEL) > 0);
    assertEquals(0, g.z(ab, ZSource.MTB), 1e-9);
    assertTrue(g.z(ab, ZSource.ALL) > g.z(ac, ZSource.ALL));
  }
}
