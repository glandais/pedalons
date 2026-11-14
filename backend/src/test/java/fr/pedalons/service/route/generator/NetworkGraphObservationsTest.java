package fr.pedalons.service.route.generator;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * Observations of complete street edges (design §12.3): partial observations attached by node pair
 * and offsets, stitched when they cover an edge together, stubs where they do not, and a builder
 * that never invents geometry (review B2, M2).
 */
class NetworkGraphObservationsTest {

  /** U-V with a hairpin: 300 m north, 412 m east, 300 m south. Length about 1012, chord 412. */
  private static TestNetwork hairpin() {
    return new TestNetwork(45, 5)
        .node("U", 0, 0)
        .node("V", 412, 0)
        .edge("U", "V", 0, 300, 412, 300);
  }

  /** No segment of a built geometry longer than the coverage gap may be missing from the inputs. */
  static void assertNoInventedGeometry(NetworkGraph g, List<TrackInput> tracks) {
    LocalProjection proj = g.projection();
    List<double[][]> live = new ArrayList<>();
    for (TrackInput t : tracks) {
      if (t.excluded()) {
        continue;
      }
      for (TrackEdge e : t.edges()) {
        double[][] xy = new double[2][e.geometry().size()];
        for (int i = 0; i < xy[0].length; i++) {
          xy[0][i] = proj.toX(e.geometry().get(i).lat(), e.geometry().get(i).lon());
          xy[1][i] = proj.toY(e.geometry().get(i).lat(), e.geometry().get(i).lon());
        }
        live.add(xy);
      }
    }
    double gap = g.parameters().coverageGapM();
    for (int e = 0; e < g.edgeCount(); e++) {
      double[] xs = g.geometryX(e);
      double[] ys = g.geometryY(e);
      for (int i = 1; i < xs.length; i++) {
        double len = Math.hypot(xs[i] - xs[i - 1], ys[i] - ys[i - 1]);
        if (len <= gap) {
          continue;
        }
        for (double t : new double[] {0, 0.25, 0.5, 0.75, 1}) {
          double px = xs[i - 1] + t * (xs[i] - xs[i - 1]);
          double py = ys[i - 1] + t * (ys[i] - ys[i - 1]);
          double best = Double.POSITIVE_INFINITY;
          for (double[][] xy : live) {
            best = Math.min(best, Geo.distanceToPolyline(px, py, xy[0], xy[1]));
          }
          assertTrue(
              best < 1.5,
              "edge "
                  + e
                  + " has a segment of "
                  + (int) len
                  + " m that is "
                  + best
                  + " m from every input geometry");
        }
      }
    }
  }

  /** Every point of the only edge lies within 1 m of the true hairpin (0,0) (0,300) (412,300) (412,0). */
  private static void assertOnHairpin(NetworkGraph g, TestNetwork n) {
    double[][] truth = {{0, 0}, {0, 300}, {412, 300}, {412, 0}};
    double[] txs = new double[truth.length];
    double[] tys = new double[truth.length];
    for (int i = 0; i < truth.length; i++) {
      LatLon q = n.latLon(truth[i][0], truth[i][1]);
      txs[i] = g.projection().toX(q.lat(), q.lon());
      tys[i] = g.projection().toY(q.lat(), q.lon());
    }
    double[] xs = g.geometryX(0);
    double[] ys = g.geometryY(0);
    for (int i = 0; i < xs.length; i++) {
      assertTrue(Geo.distanceToPolyline(xs[i], ys[i], txs, tys) < 1, "point " + i);
    }
  }

  // ---- B2 ----------------------------------------------------------------------------------

  @Test
  void aPartialObservationOfAKnownEdgeNeverMakesAPhantomEdge() {
    TestNetwork n = hairpin();
    n.track(1).path("U", "V");
    n.track(2).startAt("U", "V", 300);
    n.track(3).uTurnAt("U", "V", 600);
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    assertEquals(3, g.support(0));
    double len = TestNetwork.haversine(n.latLon(0, 0), n.latLon(0, 300)) + 412 + 300;
    assertEquals(len, g.length(0), 3);
    assertOnHairpin(g, n);
    assertNoInventedGeometry(g, n.inputs());
  }

  @Test
  void withoutACompleteObservationThePiecesAreStitchedIntoOneEdgeOnTheTruth() {
    TestNetwork n = hairpin();
    n.track(2).startAt("U", "V", 300);
    n.track(3).uTurnAt("U", "V", 600);
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    assertEquals(1, g.stats().stitchedEdges());
    assertEquals(0, g.stats().danglingStubCount());
    double len = TestNetwork.haversine(n.latLon(0, 0), n.latLon(0, 300)) + 412 + 300;
    assertEquals(len, g.length(0), 3);
    assertOnHairpin(g, n);
    assertNoInventedGeometry(g, n.inputs());
  }

  @Test
  void aPartialObservationAloneIsAStubFromItsKnownEndWithNothingOnTheOtherSide() {
    TestNetwork n = hairpin();
    n.track(2).startAt("U", "V", 300);
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    assertEquals(1, g.stats().danglingStubCount());
    assertEquals(-1, n.nodeId(g, "U"), "no piece on the U side");
    assertNotEquals(-1, n.nodeId(g, "V"));
    double len = TestNetwork.haversine(n.latLon(0, 0), n.latLon(0, 300)) + 412 + 300;
    assertEquals(len - 300, g.length(0), 3);
  }

  @Test
  void aGapWiderThanTheCoverageGapMakesTwoStubs() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 1000, 0);
    n.track(1).endAt("A", "B", 400);
    n.track(2).startAt("A", "B", 420);
    NetworkGraph g = n.build();
    assertEquals(2, g.edgeCount());
    assertEquals(2, g.stats().danglingStubCount());
    assertEquals(0, g.stats().stitchedEdges());
    assertNoInventedGeometry(g, n.inputs());
  }

  @Test
  void aPartialObservationIsAttachedWhicheverWayRoundItWasRidden() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 1000, 0);
    n.track(1).path("A", "B");
    n.track(2).startAt("B", "A", 300); // from B, 300 m along, to A
    n.track(3).uTurnAt("B", "A", 500);
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    assertEquals(3, g.support(0));
    assertTrue(g.allowed(n.state(g, "A", "B")) && g.allowed(n.state(g, "B", "A")));
  }

  // ---- order and excluded tracks ------------------------------------------------------------

  @Test
  void anExcludedCompleteObservationWithAnOddGeometryNeverSplitsTwoLiveOnes() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 1000, 0);
    // the excluded track has the smallest id and a geometry 40 m off the road
    n.track(1).excluded().via("A", "B", 500, 40);
    n.track(2).path("A", "B");
    n.track(3).path("B", "A");
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    assertEquals(2, g.support(0));
  }

  @Test
  void liveObservationsComeBeforeExcludedOnesWhateverTheTrackIds() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 1000, 0);
    n.track(1).excluded().via("A", "B", 500, 40);
    n.track(2).via("A", "B", 500, -40);
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    // the geometry is the live track's (bending to the other side), not the excluded one's
    double[] ys = g.geometryY(0);
    double mid = ys[ys.length / 2];
    double endY = ys[0];
    assertTrue(mid < endY - 20, "the live geometry bends south: " + (mid - endY));
  }

  // ---- floating, dropped ---------------------------------------------------------------------

  @Test
  void aFloatingObservationIsAttachedByProjectionOrDropped() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 2000, 0).node("C", 2000, 3000);
    n.track(1).path("A", "B");
    n.track(2).path("B", "C");
    NodeRef b = n.track(9).ref("B");
    // arrives at B from an unknown start, but its geometry stops 400 m before B: on the road A-B
    TrackEdge onTheRoad = floating(n, b, new double[][] {{1000, 0}, {1600, 0}}, 600);
    TrackEdge elsewhere = floating(n, b, new double[][] {{800, 900}, {1400, 900}}, 600);
    n.track(3).raw(onTheRoad);
    n.track(4).raw(elsewhere);
    NetworkGraph g = n.build();
    assertEquals(1, g.stats().floatingObservations());
    assertEquals(2, g.edgeCount());
    assertEquals(2, g.support(n.edgeBetween(g, "A", "B")));
  }

  private static TrackEdge floating(TestNetwork n, NodeRef to, double[][] pts, double traversed) {
    List<LatLon> geometry = new ArrayList<>();
    for (double[] p : pts) {
      geometry.add(n.latLon(p[0], p[1]));
    }
    return new TrackEdge(
        null,
        to,
        true,
        null,
        traversed,
        null,
        null,
        Oneway.BOTH,
        geometry,
        0,
        0,
        null,
        null,
        null,
        null,
        null);
  }

  @Test
  void inconsistentInputEdgesAreCountedAndNeverThrown() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 1000, 0);
    n.track(1).path("A", "B");
    NodeRef a = n.track(9).ref("A");
    NodeRef b = n.track(9).ref("B");
    List<LatLon> one = List.of(n.latLon(0, 0));
    List<LatLon> two = List.of(n.latLon(0, 0), n.latLon(1000, 0));
    // both ends null, one-point geometry, offsets outside the edge, a complete edge without length
    n.track(2)
        .raw(
            new TrackEdge(
                null,
                null,
                true,
                null,
                100,
                null,
                null,
                Oneway.BOTH,
                two,
                0,
                0,
                null,
                null,
                null,
                null,
                null));
    n.track(3)
        .raw(
            new TrackEdge(
                a,
                b,
                false,
                1000.0,
                0,
                0.0,
                1000.0,
                Oneway.BOTH,
                one,
                0,
                0,
                null,
                null,
                null,
                null,
                null));
    n.track(4)
        .raw(
            new TrackEdge(
                a,
                b,
                true,
                1000.0,
                400,
                2000.0,
                2400.0,
                Oneway.BOTH,
                two,
                0,
                0,
                null,
                null,
                null,
                null,
                null));
    n.track(5)
        .raw(
            new TrackEdge(
                a,
                b,
                false,
                null,
                1000,
                0.0,
                1000.0,
                Oneway.BOTH,
                two,
                0,
                0,
                null,
                null,
                null,
                null,
                null));
    NetworkGraph g = n.build();
    assertEquals(4, g.stats().droppedInputEdges());
    assertEquals(1, g.edgeCount());
  }

  // ---- contraction ---------------------------------------------------------------------------

  @Test
  void contractionNeedsIdenticalTrackSetsNotJustEqualCounts() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("M", 1000, 0).node("B", 2000, 0);
    n.track(1).path("A", "M");
    n.track(2).path("M", "B");
    NetworkGraph g = n.build();
    assertEquals(2, g.edgeCount(), "one track on each half: equal counts, different tracks");
    TestNetwork same = new TestNetwork(45, 5).node("A", 0, 0).node("M", 1000, 0).node("B", 2000, 0);
    same.track(1).path("A", "M", "B");
    assertEquals(1, same.build().edgeCount());
  }

  @Test
  void contractionIsRefusedWhereTheMeasuredTurnIsAHairpin() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("M", 1000, 0).node("B", 0, 20);
    n.track(1).path("A", "M", "B");
    NetworkGraph g = n.build();
    assertNotEquals(-1, n.nodeId(g, "M"));
    assertEquals(2, g.edgeCount());
  }

  // ---- attributes and per-kind support -------------------------------------------------------

  @Test
  void supportIsCountedPerKindAndTheCategoricalAttributesFollowTheMajority() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 1000, 0);
    n.track(1, TrackKind.ROAD).wayKind(WayKind.MINOR_ROAD).unpaved(false).path("A", "B");
    n.track(2, TrackKind.ROAD).wayKind(WayKind.MINOR_ROAD).unpaved(false).path("A", "B");
    n.track(3, TrackKind.GRAVEL).wayKind(WayKind.TRACK).unpaved(true).path("A", "B");
    n.track(4, TrackKind.MTB).wayKind(WayKind.MINOR_ROAD).unpaved(false).path("B", "A");
    NetworkGraph g = n.build();
    assertEquals(4, g.support(0));
    assertEquals(2, g.supportByKind(0, TrackKind.ROAD));
    assertEquals(1, g.supportByKind(0, TrackKind.GRAVEL));
    assertEquals(1, g.supportByKind(0, TrackKind.MTB));
    assertEquals(0, g.supportByKind(0, TrackKind.MIXED));
    assertEquals(WayKind.MINOR_ROAD, g.wayKind(0));
    assertEquals(SurfaceClass.PAVED, g.surfaceClass(0));
    assertEquals("asphalt", g.surfaceDetail(0));
  }

  @Test
  void aTieGoesToTheMostRestrictiveValue() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 1000, 0);
    n.track(1).wayKind(WayKind.MINOR_ROAD).unpaved(false).path("A", "B");
    n.track(2).wayKind(WayKind.TRACK).unpaved(true).path("A", "B");
    NetworkGraph g = n.build();
    assertEquals(WayKind.TRACK, g.wayKind(0));
    assertEquals(SurfaceClass.UNPAVED, g.surfaceClass(0));
    TestNetwork all = new TestNetwork(45, 5).node("A", 0, 0).node("B", 1000, 0);
    all.track(1).path("A", "B");
    NetworkGraph h = all.build();
    assertEquals(WayKind.UNKNOWN, h.wayKind(0));
    assertEquals(SurfaceClass.UNKNOWN, h.surfaceClass(0));
    assertNull(h.surfaceDetail(0));
    assertNull(h.bicycle(0));
    assertNull(h.trackType(0));
  }

  @Test
  void api18FieldsAreAbsentTodayAndTheRestrictiveValueWinsWhenPresent() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 1000, 0);
    n.track(1).trackType(OsmTrackType.GRADE2).bicycle(Access.YES).path("A", "B");
    n.track(2).trackType(OsmTrackType.GRADE4).bicycle(Access.LIMITED).path("A", "B");
    NetworkGraph g = n.build();
    assertEquals(OsmTrackType.GRADE4, g.trackType(0));
    assertEquals(Access.LIMITED, g.bicycle(0));
  }

  @Test
  void theAStarScaleIsBelowOneFarFromTheReferenceLatitudeAndTheFixedFactorWasNot() {
    // a 44-50 degrees north span: the projection around 47 over-estimates the east-west distances
    // at 50 degrees by about 6 %, which a fixed 0.97 did not cover
    List<TrackInput> tracks = GridNetwork.tracks(12, 4, 60_000, 0, 0, 0, 47, 5, 1);
    NetworkGraph g = NetworkGraphBuilder.build(tracks, NetworkParameters.defaults());
    assertTrue(g.aStarScale() <= 0.999);
    assertTrue(g.aStarScale() > 0.5);
  }

  @Test
  void aBuildNeverInventsGeometryOnARandomNetwork() {
    RandomNetworks.Generated net = RandomNetworks.generate(new java.util.Random(7));
    NetworkGraph g = NetworkGraphBuilder.build(net.tracks(), NetworkParameters.defaults());
    assertNoInventedGeometry(g, net.tracks());
  }

  // ---- review of lot 2: contraflow, restrictive partials, two streets between two nodes -------

  @Test
  void aFewMetresAgainstAOneWayDoNotOpenTheWholeEdgeInContraflow() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 1000, 0);
    for (long id = 1; id <= 3; id++) {
      n.track(id).oneway(Oneway.FORWARD).path("A", "B");
    }
    n.track(4).oneway(Oneway.AGAINST).endAt("B", "A", 10);
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    int ab = n.state(g, "A", "B");
    int ba = n.state(g, "B", "A");
    assertTrue(ab >= 0 && g.allowed(ab));
    assertTrue(ba < 0 || !g.allowed(ba), "10 m of wrong-way entry must not open the street");
  }

  @Test
  void aShortRestrictivePartialLosesAgainstLongCompleteObservations() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 1000, 0);
    for (long id = 1; id <= 3; id++) {
      n.track(id).path("A", "B");
    }
    n.track(4).bicycle(Access.NO).trackType(OsmTrackType.GRADE5).endAt("A", "B", 30);
    NetworkGraph g = n.build();
    assertEquals(1, g.edgeCount());
    assertNull(g.bicycle(0));
    assertNull(g.trackType(0));
  }

  @Test
  void twoStreetsBetweenTheSameNodesAreNeverJoinedByAnInventedSegment() {
    TestNetwork n = new TestNetwork(45, 5).node("U", 0, 0).node("V", 400, 0);
    // street N via (200, 60) and street S via (200, -60), each 417.6 m; N ridden over [0, 250],
    // S over [254, 417.6]: neither is complete, and the pieces do not belong together
    double len = 2 * Math.hypot(200, 60);
    double[] northEnd = {200 + 41.2 * 200 / len * 2, 60 - 41.2 * 60 / len * 2};
    double[] southStart = {200 + 45.2 * 200 / len * 2, -60 + 45.2 * 60 / len * 2};
    TestNetwork.Track t1 = n.track(1);
    TestNetwork.Track t2 = n.track(2);
    t1.raw(
        new TrackEdge(
            t1.ref("U"),
            t1.ref("V"),
            true,
            len,
            250.0,
            0.0,
            250.0,
            Oneway.BOTH,
            List.of(n.latLon(0, 0), n.latLon(200, 60), n.latLon(northEnd[0], northEnd[1])),
            0,
            0,
            null,
            null,
            null,
            null,
            null));
    t2.raw(
        new TrackEdge(
            t2.ref("U"),
            t2.ref("V"),
            true,
            len,
            len - 254,
            254.0,
            len,
            Oneway.BOTH,
            List.of(n.latLon(southStart[0], southStart[1]), n.latLon(400, 0)),
            0,
            0,
            null,
            null,
            null,
            null,
            null));
    NetworkGraph g = n.build();
    assertNoInventedGeometry(g, n.inputs());
  }

  @Test
  void aDegreeTwoNodeIsRiddenThroughOnlyWhenOneTrackRidesBothEdges() {
    TestNetwork n = new TestNetwork(45, 5).node("A", 0, 0).node("B", 500, 0).node("C", 500, 500);
    n.track(1).wayKind(WayKind.MINOR_ROAD).path("A", "B").wayKind(WayKind.TRACK).path("B", "C");
    NetworkGraph g = n.build();
    assertEquals(3, g.nodeCount());
    assertTrue(g.riddenThrough(n.nodeId(g, "B")));
    assertTrue(!g.riddenThrough(n.nodeId(g, "A")));

    TestNetwork m = new TestNetwork(45, 5).node("A", 0, 0).node("B", 500, 0).node("C", 500, 500);
    m.track(1).wayKind(WayKind.MINOR_ROAD).path("A", "B");
    m.track(2).wayKind(WayKind.TRACK).path("B", "C");
    NetworkGraph h = m.build();
    assertTrue(!h.riddenThrough(m.nodeId(h, "B")));
  }
}
