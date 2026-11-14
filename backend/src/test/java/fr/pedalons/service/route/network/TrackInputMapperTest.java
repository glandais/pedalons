package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.domain.route.NetworkEdgesDocument.Edge;
import fr.pedalons.service.route.generator.Access;
import fr.pedalons.service.route.generator.Oneway;
import fr.pedalons.service.route.generator.OsmTrackType;
import fr.pedalons.service.route.generator.SurfaceClass;
import fr.pedalons.service.route.generator.SurfaceSource;
import fr.pedalons.service.route.generator.TrackEdge;
import fr.pedalons.service.route.generator.TrackInput;
import fr.pedalons.service.route.generator.TrackKind;
import fr.pedalons.service.route.generator.WayKind;
import fr.pedalons.util.NetworkEdgesFixtures;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** The mapping of a stored street edges document to the engine's input (API-198, lot 3 plan §1). */
class TrackInputMapperTest {

  private static final long REV = 42;

  private static TrackInputMapper mapper() {
    return new TrackInputMapper(20_000);
  }

  private static NetworkEdgesDocument withEdges(NetworkEdgesDocument base, Edge... edges) {
    return new NetworkEdgesDocument(
        base.v(),
        base.rev(),
        base.at(),
        base.status(),
        base.api(),
        base.rules(),
        base.profile(),
        null,
        base.len(),
        base.nodes(),
        List.of(edges),
        Map.of(),
        base.covered());
  }

  private static Edge with(
      Edge e,
      String ow,
      String sc,
      String sd,
      String ss,
      String wk,
      String tt,
      String bi,
      String ft) {
    return new Edge(
        e.fm(), e.tm(), e.fn(), e.tn(), e.p(), e.len(), e.trv(), e.fo(), e.to(), ow, e.g(), e.fg(),
        e.tg(), e.fl(), e.tl(), e.st(), sc, sd, ss, wk, tt, bi, ft);
  }

  private static Edge first(NetworkEdgesDocument d) {
    return d.edges().getFirst();
  }

  @Test
  void aCompleteEdge_isMappedAsIs() {
    NetworkEdgesDocument d = NetworkEdgesFixtures.walk(REV, new int[] {0, 0}, new int[] {1, 0});
    TrackInput in = mapper().map(7, false, TrackKind.GRAVEL, d);
    assertEquals(7, in.trackId());
    assertEquals(TrackKind.GRAVEL, in.kind());
    assertEquals(1, in.edges().size());
    TrackEdge e = in.edges().getFirst();
    assertEquals("z14:0:0", e.from().key());
    assertEquals("z14:1:0", e.to().key());
    assertEquals(4, e.from().streetDegree());
    assertEquals(1000.0, e.lengthM(), 1e-9);
    assertEquals(1000.0, e.traversedM(), 1e-9);
    assertEquals(0.0, e.fromOffsetM());
    assertEquals(1000.0, e.toOffsetM());
    assertEquals(Oneway.BOTH, e.oneway());
    assertEquals(2, e.geometry().size());
    assertEquals(NetworkEdgesFixtures.lat(0), e.geometry().getFirst().lat(), 1e-6);
    assertEquals(NetworkEdgesFixtures.lon(1), e.geometry().getLast().lon(), 1e-6);
    assertEquals(SurfaceClass.PAVED, e.surface().surfaceClass());
    assertEquals("asphalt", e.surface().detail());
    assertEquals(SurfaceSource.TAGGED, e.surface().source());
    assertEquals(WayKind.MINOR_ROAD, e.wayKind());
    assertNull(e.trackType());
    assertNull(e.bicycle());
    assertNull(e.foot());
  }

  @Test
  void excludedTracksArePassedWithTheirFlag() {
    NetworkEdgesDocument d = NetworkEdgesFixtures.walk(REV, new int[] {0, 0}, new int[] {1, 0});
    assertTrue(mapper().map(1, true, TrackKind.ROAD, d).excluded());
  }

  @Test
  void gainsAreDifferencesOfTheCumulativeValues() {
    NetworkEdgesDocument d = NetworkEdgesFixtures.walk(REV, new int[] {0, 0}, new int[] {1, 0});
    Edge e = first(d);
    Edge climbing =
        new Edge(
            e.fm(), e.tm(), e.fn(), e.tn(), e.p(), e.len(), e.trv(), e.fo(), e.to(), e.ow(), e.g(),
            10, 35, 4, 9, null, e.sc(), e.sd(), e.ss(), e.wk(), null, null, null);
    TrackEdge out =
        mapper().map(1, false, TrackKind.ROAD, withEdges(d, climbing)).edges().getFirst();
    assertEquals(25, out.gainM(), 1e-9);
    assertEquals(5, out.lossM(), 1e-9);
  }

  @Test
  void anEndWithoutNodeOrOutsideTheNodes_isUnknown() {
    NetworkEdgesDocument d = NetworkEdgesFixtures.walk(REV, new int[] {0, 0}, new int[] {1, 0});
    Edge e = first(d);
    Edge partial =
        new Edge(
            e.fm(), e.tm(), null, 99, true, null, 300.0, null, null, "both", e.g(), 0, 0, 0, 0,
            null, null, null, null, null, null, null, null);
    TrackEdge out =
        mapper().map(1, false, TrackKind.ROAD, withEdges(d, partial)).edges().getFirst();
    assertNull(out.from());
    assertNull(out.to());
    assertTrue(out.partial());
    assertNull(out.lengthM());
    assertNull(out.surface());
    assertNull(out.wayKind());
  }

  @Test
  void onewayAbsentOrUnknown_isForward() {
    NetworkEdgesDocument d = NetworkEdgesFixtures.walk(REV, new int[] {0, 0}, new int[] {1, 0});
    Edge e = first(d);
    assertEquals(
        Oneway.FORWARD, oneway(d, with(e, null, null, null, null, null, null, null, null)));
    assertEquals(
        Oneway.FORWARD, oneway(d, with(e, "sideways", null, null, null, null, null, null, null)));
    assertEquals(
        Oneway.FORWARD, oneway(d, with(e, "forward", null, null, null, null, null, null, null)));
    assertEquals(
        Oneway.AGAINST, oneway(d, with(e, "against", null, null, null, null, null, null, null)));
    assertEquals(Oneway.BOTH, oneway(d, with(e, "both", null, null, null, null, null, null, null)));
  }

  private static Oneway oneway(NetworkEdgesDocument d, Edge e) {
    return mapper().map(1, false, TrackKind.ROAD, withEdges(d, e)).edges().getFirst().oneway();
  }

  @Test
  void unknownValues_neverThrow() {
    NetworkEdgesDocument d = NetworkEdgesFixtures.walk(REV, new int[] {0, 0}, new int[] {1, 0});
    Edge odd =
        with(
            first(d),
            "both",
            "glittery",
            "Asphalt-X",
            "guessed",
            "hyperloop",
            "grade9",
            "maybe",
            "perhaps");
    TrackEdge out = mapper().map(1, false, TrackKind.ROAD, withEdges(d, odd)).edges().getFirst();
    assertEquals(SurfaceClass.UNKNOWN, out.surface().surfaceClass());
    assertEquals("asphalt-x", out.surface().detail());
    assertEquals(SurfaceSource.NONE, out.surface().source());
    assertEquals(WayKind.UNKNOWN, out.wayKind());
    assertNull(out.trackType());
    assertNull(out.bicycle());
    assertNull(out.foot());
  }

  @Test
  void knownApi18Values_areMapped() {
    NetworkEdgesDocument d = NetworkEdgesFixtures.walk(REV, new int[] {0, 0}, new int[] {1, 0});
    Edge e =
        with(
            first(d),
            "both",
            "unpaved",
            "gravel",
            "inferred_tracktype",
            "track",
            "grade3",
            "limited",
            "no");
    TrackEdge out = mapper().map(1, false, TrackKind.ROAD, withEdges(d, e)).edges().getFirst();
    assertEquals(SurfaceClass.UNPAVED, out.surface().surfaceClass());
    assertEquals(SurfaceSource.INFERRED_TRACKTYPE, out.surface().source());
    assertEquals(WayKind.TRACK, out.wayKind());
    assertEquals(OsmTrackType.GRADE3, out.trackType());
    assertEquals(Access.LIMITED, out.bicycle());
    assertEquals(Access.NO, out.foot());
  }

  @Test
  void aNegativeTraversedLength_andAnUndecodableGeometry_areDroppedAndCounted() {
    NetworkEdgesDocument d = NetworkEdgesFixtures.walk(REV, new int[] {0, 0}, new int[] {1, 0});
    Edge e = first(d);
    Edge negative =
        new Edge(
            e.fm(), e.tm(), e.fn(), e.tn(), false, e.len(), -1.0, e.fo(), e.to(), e.ow(), e.g(), 0,
            0, 0, 0, null, null, null, null, null, null, null, null);
    Edge garbage =
        new Edge(
            e.fm(),
            e.tm(),
            e.fn(),
            e.tn(),
            false,
            e.len(),
            e.trv(),
            e.fo(),
            e.to(),
            e.ow(),
            "!!not a polyline!!",
            0,
            0,
            0,
            0,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null);
    Edge noGeometry =
        new Edge(
            e.fm(), e.tm(), e.fn(), e.tn(), false, e.len(), e.trv(), e.fo(), e.to(), e.ow(), null,
            0, 0, 0, 0, null, null, null, null, null, null, null, null);
    TrackInputMapper mapper = mapper();
    TrackInput out =
        mapper.map(1, false, TrackKind.ROAD, withEdges(d, negative, e, garbage, noGeometry));
    assertEquals(1, out.edges().size());
    assertEquals(3, mapper.droppedEdges());
  }

  @Test
  void aTooShortDocument_hasNoEdge() {
    NetworkEdgesDocument d = NetworkEdgesDocument.tooShort(REV, Instant.now(), 30);
    TrackInput out = mapper().map(1, false, TrackKind.ROAD, d);
    assertTrue(out.edges().isEmpty());
  }

  @Test
  void twoDocumentsRidingTheSameStreet_shareGeometryAndNodes() {
    TrackInputMapper mapper = mapper();
    NetworkEdgesDocument a = NetworkEdgesFixtures.walk(1, new int[] {0, 0}, new int[] {1, 0});
    NetworkEdgesDocument b = NetworkEdgesFixtures.walk(2, new int[] {0, 0}, new int[] {1, 0});
    TrackEdge ea = mapper.map(1, false, TrackKind.ROAD, a).edges().getFirst();
    TrackEdge eb = mapper.map(2, false, TrackKind.ROAD, b).edges().getFirst();
    assertSame(ea.geometry(), eb.geometry());
    assertSame(ea.from(), eb.from());
    assertSame(ea.to(), eb.to());
    assertEquals(2, mapper.distinctPoints());
  }

  @Test
  void aNullSurfaceType_isMixed() {
    assertEquals(TrackKind.MIXED, TrackInputMapper.kindOf(null));
    assertEquals(TrackKind.MIXED, TrackInputMapper.kindOf("SOMETHING_NEW"));
    assertEquals(TrackKind.MTB, TrackInputMapper.kindOf("MTB"));
    assertNotNull(TrackInputMapper.kindOf("ROAD"));
  }
}
