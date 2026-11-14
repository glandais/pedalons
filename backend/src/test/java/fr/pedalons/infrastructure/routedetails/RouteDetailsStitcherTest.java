package fr.pedalons.infrastructure.routedetails;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.common.GeoDistance;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Edge;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.EdgeNode;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.OutputPoint;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Quality;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Segment;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Structure;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Summary;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Surface;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.TerrainRange;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Warning;
import fr.pedalons.infrastructure.routedetails.RouteSlicer.Plan;
import fr.pedalons.infrastructure.routedetails.RouteSlicer.Slice;
import fr.pedalons.service.route.edges.NetworkEdgesAnswer;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * The stitching of plan §3.1 (docs/LEDGER_*.md API-150), against a synthetic service whose answers
 * depend only on the position along the route: the stitched answer of the slices must then be the
 * answer of one call, distances shifted, gain continuous, segments and bridges cut by a boundary
 * merged back.
 */
class RouteDetailsStitcherTest {

  /** The paved stretch ends there, the bridge spans the second range: both cross a boundary. */
  static final double SURFACE_CHANGE_M = 6_325;

  static final double BRIDGE_FROM_M = 3_100;
  static final double BRIDGE_TO_M = 3_400;

  /** A hilly route: the gain of a sub-range is not that of its ends. */
  static double ele(double d) {
    return 50 + 20 * Math.sin(d / 700);
  }

  /**
   * What the synthetic service answers for the points {@code from..to} of a meridian line: it reads
   * the route's position from the latitude, so a slice answers like the whole route on its range.
   * The gain is the sum of the rises between points, additive over any split.
   */
  static RouteDetailsResponse answer(double[] lat, int from, int to) {
    double d0 = (lat[from] - lat[0]) * RouteSlicerTest.M_PER_DEG;
    List<OutputPoint> points = new ArrayList<>();
    double gain = 0;
    double loss = 0;
    double previous = Double.NaN;
    for (int i = from; i <= to; i++) {
      double global = (lat[i] - lat[0]) * RouteSlicerTest.M_PER_DEG;
      double e = ele(global);
      if (!Double.isNaN(previous)) {
        gain += Math.max(0, e - previous);
        loss += Math.max(0, previous - e);
      }
      previous = e;
      points.add(
          new OutputPoint(
              global - d0, i - from, "input", null, null, null, e, e, "dem", gain, loss));
      // A breakpoint inserted after every tenth point, with the index of the input point before it
      if (i < to && i % 10 == 0) {
        double next = (lat[i + 1] - lat[0]) * RouteSlicerTest.M_PER_DEG;
        double mid = (global + next) / 2;
        double em = ele(mid);
        double g = gain + Math.max(0, em - e);
        double l = loss + Math.max(0, e - em);
        points.add(
            new OutputPoint(
                mid - d0,
                i - from,
                "inserted",
                List.of("local_max"),
                0.0,
                0.0,
                em,
                em,
                "dem",
                g,
                l));
        gain = g;
        loss = l;
        previous = em;
      }
    }
    double length = points.getLast().dM();
    double[] cuts = {0, BRIDGE_FROM_M - d0, BRIDGE_TO_M - d0, SURFACE_CHANGE_M - d0, length};
    List<Segment> segments = new ArrayList<>();
    for (int c = 0; c + 1 < cuts.length; c++) {
      double a = Math.max(0, cuts[c]);
      double b = Math.min(length, cuts[c + 1]);
      if (b <= a) {
        continue;
      }
      boolean bridge = c == 1;
      boolean paved = c < 3;
      segments.add(
          new Segment(
              a,
              b,
              0,
              to - from,
              bridge ? "bridge" : "ground",
              bridge ? "osm" : null,
              new Surface(paved ? "paved" : "unpaved", paved ? "asphalt" : "gravel", "tagged"),
              "minor_road",
              true));
    }
    List<Structure> structures = new ArrayList<>();
    double a = Math.max(0, BRIDGE_FROM_M - d0);
    double b = Math.min(length, BRIDGE_TO_M - d0);
    if (b > a) {
      structures.add(new Structure("bridge", a, b, b - a, "osm", "dsm_deck"));
    }
    return new RouteDetailsResponse(
        new RouteDetailsResponse.Meta("1.6", "test", "full", null),
        "complete",
        points,
        segments,
        new Summary(length, gain, loss, null, null, structures, Map.of("ign_lidar_hd", length)),
        new Quality(
            List.of(new TerrainRange(0, length, "ign_lidar_hd", true, false)), List.of(), null));
  }

  @Test
  void slicedAnswers_stitchToTheAnswerOfOneCall() {
    RouteDetailsCapabilities.Limits limits = new RouteDetailsCapabilities.Limits(200, 5_000);
    double[][] line = RouteSlicerTest.meridian(401, 50);
    Plan plan = RouteSlicer.plan(line[0], line[1], limits);
    assertTrue(plan.slices().size() > 2);
    List<RouteDetailsResponse> answers = new ArrayList<>();
    for (Slice s : plan.slices()) {
      answers.add(answer(plan.lat(), s.from(), s.to()));
    }
    RouteDetailsResponse stitched = RouteDetailsStitcher.stitch(plan.slices(), answers);
    RouteDetailsResponse single = answer(plan.lat(), 0, 400);

    assertEquals(single.points().size(), stitched.points().size());
    for (int i = 0; i < single.points().size(); i++) {
      OutputPoint expected = single.points().get(i);
      OutputPoint actual = stitched.points().get(i);
      assertEquals(expected.index(), actual.index(), "point " + i);
      assertEquals(expected.origin(), actual.origin(), "point " + i);
      assertEquals(expected.dM(), actual.dM(), 1e-6, "point " + i);
      assertEquals(expected.ele(), actual.ele(), 1e-9, "point " + i);
      assertEquals(expected.gainCumM(), actual.gainCumM(), 1e-6, "point " + i);
      assertEquals(expected.lossCumM(), actual.lossCumM(), 1e-6, "point " + i);
    }

    assertEquals(single.segments().size(), stitched.segments().size());
    for (int i = 0; i < single.segments().size(); i++) {
      Segment expected = single.segments().get(i);
      Segment actual = stitched.segments().get(i);
      assertEquals(expected.fromM(), actual.fromM(), 1e-6);
      assertEquals(expected.toM(), actual.toM(), 1e-6);
      assertEquals(expected.structure(), actual.structure());
      assertEquals(expected.surface(), actual.surface());
    }
    assertEquals(0, stitched.segments().getFirst().fromIndex());
    assertEquals(400, stitched.segments().getLast().toIndex());

    Summary summary = stitched.summary();
    assertNotNull(summary);
    assertEquals(single.summary().lengthM(), summary.lengthM(), 1e-6);
    assertEquals(single.summary().gainM(), summary.gainM(), 1e-6);
    assertEquals(single.summary().lossM(), summary.lossM(), 1e-6);
    assertEquals(1, summary.structures().size());
    assertEquals(BRIDGE_FROM_M, summary.structures().getFirst().fromM(), 1e-6);
    assertEquals(BRIDGE_TO_M, summary.structures().getFirst().toM(), 1e-6);
    assertEquals(summary.lengthM(), summary.terrainM().get("ign_lidar_hd"), 1e-6);
    assertEquals(1, stitched.quality().terrain().size());
    assertEquals("complete", stitched.status());
  }

  @Test
  void aSingleSlice_isReturnedAsIs() {
    double[][] line = RouteSlicerTest.meridian(20, 50);
    RouteDetailsResponse answer = answer(line[0], 0, 19);
    assertSame(
        answer, RouteDetailsStitcher.stitch(List.of(new Slice(0, 19, 0, 19)), List.of(answer)));
  }

  @Test
  void aPartialSlice_makesThePartialWhole() {
    double[][] line = RouteSlicerTest.meridian(41, 50);
    List<Slice> slices = List.of(new Slice(0, 25, 0, 20), new Slice(15, 40, 20, 40));
    RouteDetailsResponse first = answer(line[0], 0, 25);
    RouteDetailsResponse second = answer(line[0], 15, 40);
    RouteDetailsResponse partial =
        new RouteDetailsResponse(
            second.meta(),
            "partial",
            second.points(),
            second.segments(),
            second.summary(),
            second.quality());
    RouteDetailsResponse stitched = RouteDetailsStitcher.stitch(slices, List.of(first, partial));
    assertTrue(stitched.isPartial());
    // The shared point is kept once: 41 input points, plus a breakpoint after every tenth
    assertEquals(41, stitched.points().stream().filter(p -> !p.isInserted()).count());
  }

  /** {@code r} with its warnings and structure correction replaced. */
  static RouteDetailsResponse withQuality(
      RouteDetailsResponse r, List<Warning> warnings, JsonNode structureCorrection) {
    return new RouteDetailsResponse(
        r.meta(),
        r.status(),
        r.points(),
        r.segments(),
        r.summary(),
        new Quality(r.quality().terrain(), warnings, structureCorrection));
  }

  @Test
  void warningsAcrossABoundary_comeOutWhole() {
    double[][] line = RouteSlicerTest.meridian(41, 50);
    List<Slice> slices = List.of(new Slice(0, 25, 0, 20), new Slice(15, 40, 20, 40));
    RouteDetailsResponse first = answer(line[0], 0, 25);
    RouteDetailsResponse second = answer(line[0], 15, 40);
    double firstLength = first.points().getLast().dM();
    double secondLength = second.points().getLast().dM();
    // Seam at point 20 (1 000 m): 750 m into the second slice, which starts at point 15
    double seamInSecond =
        second.points().stream().filter(p -> p.index() == 5).findFirst().get().dM();
    RouteDetailsResponse a =
        withQuality(
            first,
            List.of(
                new Warning("terrain_fallback", "IGN failed", 0.0, firstLength),
                new Warning("unmatched_range", "off the graph", 950.0, firstLength),
                new Warning("structure_uncorrected", "bridge", 1_000.0, 1_000.0),
                new Warning("slow_source", "whole slice", null, null)),
            null);
    RouteDetailsResponse b =
        withQuality(
            second,
            List.of(
                new Warning("terrain_fallback", "IGN failed", 0.0, secondLength),
                new Warning("unmatched_range", "off the graph", 0.0, seamInSecond + 30),
                new Warning("structure_uncorrected", "bridge", seamInSecond, seamInSecond),
                new Warning("slow_source", "whole slice", null, null)),
            null);
    RouteDetailsResponse stitched = RouteDetailsStitcher.stitch(slices, List.of(a, b));
    List<Warning> warnings = stitched.quality().warnings();
    assertEquals(4, warnings.size(), warnings.toString());
    Warning fallback = warnings.get(0);
    assertEquals("terrain_fallback", fallback.code());
    assertEquals(0, fallback.fromM(), 1e-6);
    assertEquals(stitched.summary().lengthM(), fallback.toM(), 1e-6);
    Warning unmatched = warnings.get(1);
    assertEquals(950, unmatched.fromM(), 1e-6);
    assertEquals(1_030, unmatched.toM(), 1e-6);
    Warning point = warnings.get(2);
    assertEquals(1_000, point.fromM(), 1e-6);
    assertEquals(1_000, point.toM(), 1e-6);
    assertEquals("slow_source", warnings.get(3).code());
  }

  @Test
  void structureCorrection_takesTheMostTellingStatusAndCountsTheStitchedStructures()
      throws Exception {
    ObjectMapper mapper = new ObjectMapper();
    JsonNode none =
        mapper.readTree(
            "{\"bridges\":\"none_found\",\"tunnels\":\"none_found\",\"counts\":{},"
                + "\"counts_by_source\":{}}");
    JsonNode partial =
        mapper.readTree(
            "{\"bridges\":\"partial\",\"tunnels\":\"none_found\","
                + "\"counts\":{\"uncorrected\":1,\"dsm_deck\":1},"
                + "\"counts_by_source\":{\"osm\":2}}");
    List<Structure> stitched =
        List.of(
            new Structure("bridge", 0, 10, 10, "osm", "uncorrected"),
            new Structure("bridge", 20, 30, 10, "osm", "dsm_deck"));
    JsonNode combined =
        RouteDetailsStitcher.combineStructureCorrection(List.of(none, partial), stitched);
    assertEquals("partial", combined.get("bridges").asText());
    assertEquals("none_found", combined.get("tunnels").asText());
    assertEquals(1, combined.get("counts").get("uncorrected").asLong());
    assertEquals(1, combined.get("counts").get("dsm_deck").asLong());
    assertEquals(2, combined.get("counts_by_source").get("osm").asLong());

    JsonNode unavailable = mapper.readTree("{\"bridges\":\"unavailable\"}");
    assertEquals(
        "unavailable",
        RouteDetailsStitcher.combineStructureCorrection(List.of(partial, unavailable), stitched)
            .get("bridges")
            .asText());
    // Without the summary, the slices' counts are summed: 2 + 2
    assertEquals(
        4,
        RouteDetailsStitcher.combineStructureCorrection(List.of(partial, partial), null)
            .get("counts_by_source")
            .get("osm")
            .asLong());
  }

  @Test
  void aSlicedAnswerWithoutPoints_cannotBeStitched() {
    double[][] line = RouteSlicerTest.meridian(41, 50);
    RouteDetailsResponse first = answer(line[0], 0, 25);
    RouteDetailsResponse empty =
        new RouteDetailsResponse(first.meta(), "complete", null, null, null, null);
    assertThrows(
        IllegalStateException.class,
        () ->
            RouteDetailsStitcher.stitch(
                List.of(new Slice(0, 25, 0, 20), new Slice(15, 40, 20, 40)),
                List.of(first, empty)));
  }

  @Test
  void reindex_carriesTheSentIndicesBackToTheCallers() {
    double[] lat = {47.2, 47.2001, 47.2002};
    double[] lon = {-1.55, -1.55, -1.55};
    double d = GeoDistance.haversineMeters(lat[0], lon[0], lat[2], lon[2]);
    RouteDetailsResponse sentAnswer =
        new RouteDetailsResponse(
            null,
            "complete",
            List.of(
                new OutputPoint(0, 0, "input", null, null, null, 1.0, null, "dem", 0, 0),
                new OutputPoint(d / 2, 0, "inserted", null, 0.0, 0.0, 2.0, null, "dem", 1, 0),
                new OutputPoint(d, 1, "input", null, null, null, 1.0, null, "dem", 1, 1)),
            List.of(new Segment(0, d, 0, 1, "ground", null, null, "path", true)),
            null,
            null);
    RouteDetailsResponse mapped = RouteDetailsStitcher.reindex(sentAnswer, new int[] {0, 7});
    assertEquals(List.of(0, 0, 7), mapped.points().stream().map(OutputPoint::index).toList());
    assertEquals(7, mapped.segments().getFirst().toIndex());
    assertSame(sentAnswer, RouteDetailsStitcher.reindex(sentAnswer, new int[] {0, 1}));
  }

  // ------------------------------------------------------------------ edges (api 1.7)

  /** The synthetic street graph: consecutive edges of this length along the meridian. */
  static final double EDGE_M = 400;

  static EdgeNode node(int k) {
    return new EdgeNode("z14:" + k + ":0", 47.2 + k * EDGE_M / RouteSlicerTest.M_PER_DEG, -1.55, 3);
  }

  static double latAt(double[] lat, double global) {
    return lat[0] + global / RouteSlicerTest.M_PER_DEG;
  }

  /** The cumulative of {@code points} at {@code x}, by linear interpolation between them. */
  static double interpolate(List<OutputPoint> points, double x, boolean gain) {
    for (int i = 1; i < points.size(); i++) {
      OutputPoint a = points.get(i - 1);
      OutputPoint b = points.get(i);
      if (x <= b.dM() || i == points.size() - 1) {
        double span = b.dM() - a.dM();
        double t = span == 0 ? 0 : (x - a.dM()) / span;
        double va = gain ? a.gainCumM() : a.lossCumM();
        double vb = gain ? b.gainCumM() : b.lossCumM();
        return va + (vb - va) * t;
      }
    }
    return 0;
  }

  /**
   * {@code r} as the service would answer it with {@code options.edges}: one complete edge of
   * {@link #EDGE_M} per stretch of the meridian, cut (and so partial) where the slice starts or ends,
   * with offsets along the complete edge, a two-vertex geometry and the gains of the points.
   */
  static RouteDetailsResponse withEdges(RouteDetailsResponse r, double[] lat, int from) {
    double d0 = (lat[from] - lat[0]) * RouteSlicerTest.M_PER_DEG;
    double length = r.points().getLast().dM();
    List<Edge> edges = new ArrayList<>();
    for (int k = (int) Math.floor(d0 / EDGE_M); k * EDGE_M < d0 + length - 1e-6; k++) {
      double g0 = k * EDGE_M;
      double g1 = g0 + EDGE_M;
      double startG = Math.max(g0, d0);
      double endG = Math.min(g1, d0 + length);
      if (endG - startG < 1e-6) {
        continue;
      }
      double a = startG - d0;
      double b = endG - d0;
      boolean clipped = startG > g0 + 1e-6 || endG < g1 - 1e-6;
      String geometry =
          EdgePolylines.encode(
              List.of(
                  new double[] {latAt(lat, startG), -1.55},
                  new double[] {latAt(lat, endG), -1.55}));
      edges.add(
          new Edge(
              a,
              b,
              0,
              r.points().getLast().index(),
              node(k),
              node(k + 1),
              clipped,
              EDGE_M,
              b - a,
              startG - g0,
              endG - g0,
              "both",
              geometry,
              interpolate(r.points(), a, true),
              interpolate(r.points(), b, true),
              interpolate(r.points(), a, false),
              interpolate(r.points(), b, false),
              "ground",
              new Surface("paved", "asphalt", "tagged"),
              "minor_road",
              null,
              null,
              null));
    }
    return new RouteDetailsResponse(
        r.meta(), r.status(), r.points(), r.segments(), r.summary(), r.quality(), edges);
  }

  @Test
  void slicedEdges_stitchToTheEdgesOfOneCall_theCutOnesJoinedBack() {
    RouteDetailsCapabilities.Limits limits = new RouteDetailsCapabilities.Limits(200, 5_000);
    double[][] line = RouteSlicerTest.meridian(401, 50);
    Plan plan = RouteSlicer.plan(line[0], line[1], limits);
    assertTrue(plan.slices().size() > 2);
    List<RouteDetailsResponse> answers = new ArrayList<>();
    for (Slice s : plan.slices()) {
      answers.add(withEdges(answer(plan.lat(), s.from(), s.to()), plan.lat(), s.from()));
    }
    RouteDetailsResponse stitched = RouteDetailsStitcher.stitch(plan.slices(), answers);
    RouteDetailsResponse single = withEdges(answer(plan.lat(), 0, 400), plan.lat(), 0);

    assertEquals(single.edges().size(), stitched.edges().size());
    for (int i = 0; i < single.edges().size(); i++) {
      Edge expected = single.edges().get(i);
      Edge actual = stitched.edges().get(i);
      assertEquals(expected.fromM(), actual.fromM(), 1e-6, "edge " + i);
      assertEquals(expected.toM(), actual.toM(), 1e-6, "edge " + i);
      assertEquals(expected.fromNode().id(), actual.fromNode().id(), "edge " + i);
      assertEquals(expected.toNode().id(), actual.toNode().id(), "edge " + i);
      assertEquals(expected.partial(), actual.partial(), "edge " + i);
      assertEquals(expected.traversedM(), actual.traversedM(), 1e-6, "edge " + i);
      assertEquals(expected.fromOffsetM(), actual.fromOffsetM(), 1e-6, "edge " + i);
      assertEquals(expected.toOffsetM(), actual.toOffsetM(), 1e-6, "edge " + i);
      assertEquals(expected.fromGainCumM(), actual.fromGainCumM(), 1e-6, "edge " + i);
      assertEquals(expected.toGainCumM(), actual.toGainCumM(), 1e-6, "edge " + i);
      assertEquals(expected.toLossCumM(), actual.toLossCumM(), 1e-6, "edge " + i);
      assertEquals(expected.surface(), actual.surface(), "edge " + i);
    }
  }

  @Test
  void anEdgeCutByABoundary_comesOutOnce_withOneGeometry() {
    RouteDetailsCapabilities.Limits limits = new RouteDetailsCapabilities.Limits(200, 5_000);
    double[][] line = RouteSlicerTest.meridian(401, 50);
    Plan plan = RouteSlicer.plan(line[0], line[1], limits);
    List<RouteDetailsResponse> answers = new ArrayList<>();
    for (Slice s : plan.slices()) {
      answers.add(withEdges(answer(plan.lat(), s.from(), s.to()), plan.lat(), s.from()));
    }
    RouteDetailsResponse stitched = RouteDetailsStitcher.stitch(plan.slices(), answers);
    // Every edge once, contiguous, and its geometry as long as the edge, whole
    for (int i = 0; i < stitched.edges().size(); i++) {
      Edge e = stitched.edges().get(i);
      assertEquals(i * EDGE_M, e.fromM(), 1e-6);
      List<double[]> g = EdgePolylines.decode(e.geometry());
      assertEquals(latAt(plan.lat(), i * EDGE_M), g.getFirst()[0], 1e-6, "edge " + i);
      assertEquals(latAt(plan.lat(), (i + 1) * EDGE_M), g.getLast()[0], 1e-6, "edge " + i);
      assertEquals(EDGE_M, EdgePolylines.length(g), 0.5, "edge " + i);
      if (i > 0) {
        assertEquals(
            stitched.edges().get(i - 1).toGainCumM(), e.fromGainCumM(), 1e-6, "gain, edge " + i);
      }
    }
    // At least one geometry was rebuilt from the two halves: more than its two vertices
    assertTrue(
        stitched.edges().stream().anyMatch(e -> EdgePolylines.decode(e.geometry()).size() > 2));
  }

  @Test
  void anEdgeOfTheOverlapOnly_isDropped_andAnEdgeStraddlingTheCoreIsCutAndFlaggedPartial() {
    double[][] line = RouteSlicerTest.meridian(41, 50);
    // Cores 0-1000 m and 1000-2000 m; each slice also reads 250 m past its core
    List<Slice> slices = List.of(new Slice(0, 25, 0, 20), new Slice(15, 40, 20, 40));
    RouteDetailsResponse first = answer(line[0], 0, 25);
    RouteDetailsResponse second = answer(line[0], 15, 40);
    // A: an edge only in the overlap (1050-1200) must not be taken from the first answer;
    // B: one from 900 to 1300 crosses the boundary and is partial on each side
    Edge overlapOnly = edge(1050, 1200, 0, 1, node(10), node(11), false, 150, 0, 150);
    Edge straddling = edge(900, 1250, 0, 1, node(5), node(6), true, 350, 0, 350);
    RouteDetailsResponse a = withEdgeList(first, List.of(straddling, overlapOnly));
    RouteDetailsResponse b = withEdgeList(second, List.of());
    RouteDetailsResponse stitched = RouteDetailsStitcher.stitch(slices, List.of(a, b));
    assertEquals(1, stitched.edges().size(), "the overlap edge is gone");
    Edge cut = stitched.edges().getFirst();
    assertEquals(900, cut.fromM(), 1e-6);
    assertEquals(1000, cut.toM(), 1e-6, "cut at the end of the core");
    assertTrue(cut.partial());
    assertEquals(100, cut.traversedM(), 1e-6);
    assertEquals(0, cut.fromOffsetM(), 1e-6);
    assertEquals(100, cut.toOffsetM(), 1e-6);
    assertEquals(node(5).id(), cut.fromNode().id(), "the ends of the complete edge stay");
    assertEquals(node(6).id(), cut.toNode().id());
  }

  @Test
  void edgesWithDifferentNodes_areNotJoined() {
    double[][] line = RouteSlicerTest.meridian(41, 50);
    List<Slice> slices = List.of(new Slice(0, 25, 0, 20), new Slice(15, 40, 20, 40));
    RouteDetailsResponse first = answer(line[0], 0, 25);
    RouteDetailsResponse second = answer(line[0], 15, 40);
    // Both end/start on the boundary, but at different junctions
    Edge left = edge(800, 1000, 0, 1, node(1), node(2), true, 400, 200, 400);
    // The second slice starts at 750 m: its own axis puts the boundary at 250
    Edge right = edge(250, 450, 0, 1, node(3), node(4), true, 400, 0, 200);
    RouteDetailsResponse stitched =
        RouteDetailsStitcher.stitch(
            slices,
            List.of(withEdgeList(first, List.of(left)), withEdgeList(second, List.of(right))));
    assertEquals(2, stitched.edges().size());
  }

  @Test
  void edgesAcrossABoundary_keepTheTypologyOnlyWhereBothHalvesAgree() {
    double[][] line = RouteSlicerTest.meridian(41, 50);
    List<Slice> slices = List.of(new Slice(0, 25, 0, 20), new Slice(15, 40, 20, 40));
    RouteDetailsResponse first = answer(line[0], 0, 25);
    RouteDetailsResponse second = answer(line[0], 15, 40);
    Edge left = edge(800, 1000, 0, 1, node(1), node(2), true, 400, 0, 200);
    // The second slice starts at 750 m: its own axis puts the boundary at 250
    Edge right = edge(250, 450, 0, 1, node(1), node(2), true, 400, 200, 400);
    right =
        new Edge(
            right.fromM(),
            right.toM(),
            right.fromIndex(),
            right.toIndex(),
            right.fromNode(),
            right.toNode(),
            right.partial(),
            right.lengthM(),
            right.traversedM(),
            right.fromOffsetM(),
            right.toOffsetM(),
            right.oneway(),
            right.geometry(),
            right.fromGainCumM(),
            right.toGainCumM(),
            right.fromLossCumM(),
            right.toLossCumM(),
            right.structure(),
            new Surface("unpaved", "gravel", "tagged"),
            right.wayKind(),
            null,
            null,
            null);
    RouteDetailsResponse stitched =
        RouteDetailsStitcher.stitch(
            slices,
            List.of(withEdgeList(first, List.of(left)), withEdgeList(second, List.of(right))));
    assertEquals(1, stitched.edges().size());
    Edge joined = stitched.edges().getFirst();
    assertNull(joined.surface(), "paved on one side, unpaved on the other");
    assertEquals("ground", joined.structure());
    assertEquals("minor_road", joined.wayKind());
    assertEquals(400, joined.traversedM(), 1e-6);
    assertFalse(joined.partial(), "from 0 to the length of the complete edge");
  }

  @Test
  void reindex_carriesTheIndicesOfTheEdges() {
    Edge e = edge(0, 10, 0, 1, node(1), node(2), false, 10, 0, 10);
    RouteDetailsResponse r =
        new RouteDetailsResponse(null, "complete", null, null, null, null, List.of(e));
    RouteDetailsResponse mapped = RouteDetailsStitcher.reindex(r, new int[] {0, 7});
    assertEquals(7, mapped.edges().getFirst().toIndex());
  }

  @Test
  void slicedAnswerWithANullEdge_dropsTheEdgesOnly_profileStitched() {
    assertEdgesDropped(null);
  }

  @Test
  void slicedAnswerWithABadPolyline_isTolerated_edgesAndProfileStitched() {
    RouteDetailsResponse stitched = stitchWithBroken("?");
    assertNotNull(stitched.edges());
    assertFalse(stitched.edgesDropped());
    assertNotNull(stitched.points());
    assertNotNull(stitched.segments());
  }

  /** {@code geometry} null: a null edge is appended; else the geometry of the first slice's last edge. */
  private void assertEdgesDropped(String badGeometry) {
    RouteDetailsResponse stitched = stitchWithBroken(badGeometry);
    assertNull(stitched.edges());
    assertTrue(stitched.edgesDropped());
    assertNotNull(stitched.points());
    assertFalse(stitched.points().isEmpty());
    assertNotNull(stitched.segments());
    assertTrue(NetworkEdgesAnswer.of(stitched).dropped());
  }

  private RouteDetailsResponse stitchWithBroken(String badGeometry) {
    RouteDetailsCapabilities.Limits limits = new RouteDetailsCapabilities.Limits(200, 5_000);
    double[][] line = RouteSlicerTest.meridian(401, 50);
    Plan plan = RouteSlicer.plan(line[0], line[1], limits);
    List<RouteDetailsResponse> answers = new ArrayList<>();
    for (Slice sl : plan.slices()) {
      RouteDetailsResponse a =
          withEdges(answer(plan.lat(), sl.from(), sl.to()), plan.lat(), sl.from());
      answers.add(a);
    }
    RouteDetailsResponse first = answers.getFirst();
    List<Edge> broke = new ArrayList<>(first.edges());
    if (badGeometry == null) {
      broke.add(null);
    } else {
      Edge last = broke.getLast();
      broke.set(
          broke.size() - 1,
          new Edge(
              last.fromM(),
              last.toM(),
              last.fromIndex(),
              last.toIndex(),
              last.fromNode(),
              last.toNode(),
              last.partial(),
              last.lengthM(),
              last.traversedM(),
              last.fromOffsetM(),
              last.toOffsetM(),
              last.oneway(),
              badGeometry,
              last.fromGainCumM(),
              last.toGainCumM(),
              last.fromLossCumM(),
              last.toLossCumM(),
              last.structure(),
              last.surface(),
              last.wayKind(),
              last.tracktype(),
              last.bicycle(),
              last.foot()));
    }
    answers.set(0, withEdgeList(first, broke));
    return RouteDetailsStitcher.stitch(plan.slices(), answers);
  }

  @Test
  void reindexWithANullEdge_dropsTheEdges_keepsPointsAndSegments() {
    double[] lat = {47.2, 47.2001, 47.2002};
    double[] lon = {-1.55, -1.55, -1.55};
    double d = GeoDistance.haversineMeters(lat[0], lon[0], lat[2], lon[2]);
    Edge e = edge(0, 10, 0, 1, node(1), node(2), false, 10, 0, 10);
    List<Edge> withNull = new ArrayList<>();
    withNull.add(e);
    withNull.add(null);
    RouteDetailsResponse r =
        new RouteDetailsResponse(
            null,
            "complete",
            List.of(
                new OutputPoint(0, 0, "input", null, null, null, 1.0, null, "dem", 0, 0),
                new OutputPoint(d, 1, "input", null, null, null, 1.0, null, "dem", 1, 1)),
            List.of(new Segment(0, d, 0, 1, "ground", null, null, "path", true)),
            null,
            null,
            withNull);
    RouteDetailsResponse mapped = RouteDetailsStitcher.reindex(r, new int[] {0, 7});
    assertNull(mapped.edges());
    assertTrue(mapped.edgesDropped());
    assertEquals(7, mapped.segments().getFirst().toIndex());
    assertEquals(7, mapped.points().getLast().index());
  }

  @Test
  void networkEdgesAnswer_skipsNullEdges() {
    Edge e = edge(0, 10, 0, 1, node(1), node(2), false, 10, 0, 10);
    List<Edge> withNull = new ArrayList<>();
    withNull.add(e);
    withNull.add(null);
    NetworkEdgesAnswer a =
        NetworkEdgesAnswer.of(
            new RouteDetailsResponse(null, "complete", null, null, null, null, withNull));
    assertEquals(1, a.edges().size());
    assertEquals(10, a.lengthM(), 1e-9);
  }

  static RouteDetailsResponse withEdgeList(RouteDetailsResponse r, List<Edge> edges) {
    return new RouteDetailsResponse(
        r.meta(), r.status(), r.points(), r.segments(), r.summary(), r.quality(), edges);
  }

  /** A paved edge on a straight line of two vertices, gains rising 1 m per 100 m. */
  static Edge edge(
      double fromM,
      double toM,
      int fromIndex,
      int toIndex,
      EdgeNode from,
      EdgeNode to,
      boolean partial,
      double length,
      double fromOffset,
      double toOffset) {
    String geometry =
        EdgePolylines.encode(
            List.of(
                new double[] {47.2 + fromM / RouteSlicerTest.M_PER_DEG, -1.55},
                new double[] {47.2 + toM / RouteSlicerTest.M_PER_DEG, -1.55}));
    return new Edge(
        fromM,
        toM,
        fromIndex,
        toIndex,
        from,
        to,
        partial,
        length,
        toM - fromM,
        fromOffset,
        toOffset,
        "both",
        geometry,
        fromM / 100,
        toM / 100,
        0,
        0,
        "ground",
        new Surface("paved", "asphalt", "tagged"),
        "minor_road",
        null,
        null,
        null);
  }
}
