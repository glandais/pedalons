package fr.pedalons.infrastructure.routedetails;

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
}
