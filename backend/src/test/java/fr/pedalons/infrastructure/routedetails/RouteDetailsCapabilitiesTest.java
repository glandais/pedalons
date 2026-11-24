package fr.pedalons.infrastructure.routedetails;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import org.junit.jupiter.api.Test;

/** What {@code GET /v1/capabilities} says of the edges (api 1.7, docs/LEDGER_*.md API-198). */
class RouteDetailsCapabilitiesTest {

  private static final RouteDetailsCapabilities.EdgesFeature EDGES =
      new RouteDetailsCapabilities.EdgesFeature("z14", 14, 4096, 6);

  private static RouteDetailsCapabilities caps(String api, boolean edges) {
    return new RouteDetailsCapabilities(
        api, null, null, new RouteDetailsCapabilities.Data(true, edges ? EDGES : null));
  }

  @Test
  void edges_needApi17_andTheDataEntry() {
    assertFalse(caps("1.6", false).supportsEdges());
    assertFalse(caps("1.6", true).supportsEdges(), "an entry without the version is not enough");
    assertFalse(caps("1.7", false).supportsEdges(), "1.7 without data.edges");
    assertTrue(caps("1.7", true).supportsEdges());
    assertTrue(caps("1.8", true).supportsEdges());
    assertTrue(caps("2.0", true).supportsEdges());
  }

  @Test
  void edges_areNotSupported_whenTheVersionIsUnreadable_orThereIsNoData() {
    assertFalse(caps("garbage", true).supportsEdges());
    assertFalse(caps(null, true).supportsEdges());
    assertFalse(new RouteDetailsCapabilities("1.7", null, null, null).supportsEdges());
  }

  @Test
  void theGeneratorSectionOfApi19_isRead() throws IOException {
    String json =
        """
        {"api_version":"1.9","data":{"surface_detail":true},
         "generator":{"enabled":true,"ride_types":["road","gravel","mtb"],"ascent":false,
           "graph":{"id":"graph-x","data_date":"2026-11-01","data_timestamp":1,"tool_version":"1"},
           "limits":{"distance_m_min":5000,"distance_m_max":200000,"budget_ms":8000,
             "deposit":{"max_document_bytes":16777216,"max_tracks":10000,"budget_s":900}},
           "overlay_ttl_days":14,"future_key":1}}
        """;
    RouteDetailsCapabilities c = new ObjectMapper().readValue(json, RouteDetailsCapabilities.class);
    assertTrue(c.generatorEnabled());
    assertEquals("graph-x", c.generator().graph().id());
    assertEquals(200_000, c.generator().limits().distanceMMax());
    assertEquals(16_777_216L, c.generator().limits().deposit().maxDocumentBytes());
    assertEquals(14L, c.generator().overlayTtlDays());
  }

  @Test
  void theGeneratorNeedsApi19_andItsOwnSwitch() {
    RouteDetailsCapabilities.GeneratorSection on =
        new RouteDetailsCapabilities.GeneratorSection(true, null, null, null, 14L, false);
    RouteDetailsCapabilities.GeneratorSection off =
        new RouteDetailsCapabilities.GeneratorSection(
            false, "not_configured", null, null, null, false);
    assertTrue(new RouteDetailsCapabilities("1.9", null, null, null, on).generatorEnabled());
    assertFalse(new RouteDetailsCapabilities("1.8", null, null, null, on).generatorEnabled());
    assertFalse(new RouteDetailsCapabilities("1.9", null, null, null, off).generatorEnabled());
    assertFalse(new RouteDetailsCapabilities("1.9", null, null, null, null).generatorEnabled());
  }

  @Test
  void theRouterNeedsApi115_andItsOwnSwitch() throws IOException {
    String json =
        """
        {"api_version":"1.15","router":{"enabled":true,"ride_types":["road","gravel","mtb"],
         "crow_m_max":100000,"snap_m":500}}
        """;
    RouteDetailsCapabilities c = new ObjectMapper().readValue(json, RouteDetailsCapabilities.class);
    assertTrue(c.routerEnabled());
    assertEquals(3, c.router().rideTypes().size());
    RouteDetailsCapabilities.RouterSection on =
        new RouteDetailsCapabilities.RouterSection(true, null, null, null);
    RouteDetailsCapabilities.RouterSection off =
        new RouteDetailsCapabilities.RouterSection(false, null, null, null);
    assertFalse(new RouteDetailsCapabilities("1.14", null, null, null, null, on).routerEnabled());
    assertFalse(new RouteDetailsCapabilities("1.15", null, null, null, null, off).routerEnabled());
    assertFalse(new RouteDetailsCapabilities("1.15", null, null, null, null, null).routerEnabled());
  }

  @Test
  void theRoutersUseRoads_isReadPresentAbsentOrFalse() throws IOException {
    ObjectMapper mapper = new ObjectMapper();
    assertTrue(
        mapper
            .readValue(
                "{\"api_version\":\"1.16\",\"router\":{\"enabled\":true,\"use_roads\":true}}",
                RouteDetailsCapabilities.class)
            .router()
            .useRoads());
    assertFalse(
        mapper
            .readValue(
                "{\"api_version\":\"1.15\",\"router\":{\"enabled\":true}}",
                RouteDetailsCapabilities.class)
            .router()
            .useRoads());
    assertFalse(
        mapper
            .readValue(
                "{\"api_version\":\"1.16\",\"router\":{\"enabled\":true,\"use_roads\":false}}",
                RouteDetailsCapabilities.class)
            .router()
            .useRoads());
  }

  @Test
  void theRoutersAvoidMainRoads_isReadPresentAbsentOrFalse() throws IOException {
    ObjectMapper mapper = new ObjectMapper();
    String head = "{\"api_version\":\"1.16\",\"router\":{\"enabled\":true";
    assertTrue(
        mapper
            .readValue(head + ",\"avoid_main_roads\":true}}", RouteDetailsCapabilities.class)
            .router()
            .avoidMainRoads());
    assertFalse(
        mapper.readValue(head + "}}", RouteDetailsCapabilities.class).router().avoidMainRoads());
    assertFalse(
        mapper
            .readValue(head + ",\"avoid_main_roads\":false}}", RouteDetailsCapabilities.class)
            .router()
            .avoidMainRoads());
  }

  @Test
  void theCapabilitiesOfApi17_areRead() throws IOException {
    String json =
        """
        {"api_version":"1.7","limits":{"max_points":16000,"max_length_m":200000},
         "enums":{"profiles":["fast","full"],"unmatched_reason":["no_data"]},
         "data":{"surface_detail":true,"edges":{"node_id_prefix":"z14","node_grid_zoom":14,
           "node_grid_extent":4096,"geometry":"polyline","polyline_precision":6,
           "way_id":false,"oneway_bicycle":false}}}
        """;
    RouteDetailsCapabilities c = new ObjectMapper().readValue(json, RouteDetailsCapabilities.class);
    assertTrue(c.supportsEdges());
    assertTrue(c.supportsSurfaceDetail());
    assertTrue(c.supportsFast());
  }

  @Test
  void theEditNeedsApi117_andItsOwnBlock() throws IOException {
    String json =
        """
        {"api_version":"1.17","generator":{"enabled":true,"ride_types":["road"],"ascent":false,
         "edit":{"operations":["resize","move_end"],"ride_types":["road","gravel"],
         "change_share_max":0.3,"change_m_min":1000,"tolerance":0.05,"end_snap_m":500,
         "proposals_max":3,"points_max":50000,"request_body_bytes":4194304,"future":1}}}
        """;
    RouteDetailsCapabilities c = new ObjectMapper().readValue(json, RouteDetailsCapabilities.class);
    assertTrue(c.editEnabled());
    RouteDetailsCapabilities.EditInfo edit = c.generator().edit();
    assertTrue(edit.offers("resize"));
    assertTrue(edit.offers("move_end"));
    assertFalse(edit.offers("rotate"));
    assertTrue(edit.accepts("gravel"));
    assertFalse(edit.accepts("mtb"));
    assertEquals(0.3, edit.changeShareMax(), 1e-9);
    assertEquals(50_000, edit.pointsMax());
    assertEquals(4_194_304L, edit.requestBodyBytes());
    // absent block (an engine that cannot edit), and an api below 1.17
    RouteDetailsCapabilities.GeneratorSection without =
        new RouteDetailsCapabilities.GeneratorSection(true, null, null, null, 14L, false);
    assertFalse(new RouteDetailsCapabilities("1.17", null, null, null, without).editEnabled());
    RouteDetailsCapabilities.GeneratorSection with =
        new RouteDetailsCapabilities.GeneratorSection(
            true, null, null, null, 14L, false, null, edit);
    assertTrue(new RouteDetailsCapabilities("1.17", null, null, null, with).editEnabled());
    assertFalse(new RouteDetailsCapabilities("1.16", null, null, null, with).editEnabled());
    RouteDetailsCapabilities.GeneratorSection off =
        new RouteDetailsCapabilities.GeneratorSection(
            false, "not_configured", null, null, null, false, null, edit);
    assertFalse(new RouteDetailsCapabilities("1.17", null, null, null, off).editEnabled());
  }
}
