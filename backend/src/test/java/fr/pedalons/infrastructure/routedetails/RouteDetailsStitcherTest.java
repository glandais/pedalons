package fr.pedalons.infrastructure.routedetails;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.common.GeoDistance;
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
}
