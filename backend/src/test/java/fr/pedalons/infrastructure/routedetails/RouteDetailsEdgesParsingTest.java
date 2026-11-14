package fr.pedalons.infrastructure.routedetails;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Edge;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * Freezes the parsing of a real answer with {@code options.edges} (docs/LEDGER_*.md API-198): {@code
 * fast}, api 1.7, rules 2026.11.13, 12 edges over 669 m of Nantes, with a U-turn (edges 5 and 6 are
 * the same partial edge, ridden in both directions) and 8 distinct junctions.
 */
class RouteDetailsEdgesParsingTest {

  private static final ObjectMapper MAPPER = new ObjectMapper();

  static RouteDetailsResponse fixture() throws IOException {
    try (InputStream in =
        RouteDetailsEdgesParsingTest.class.getResourceAsStream(
            "/routedetails/nantes-edges-fast.json")) {
      assertNotNull(in);
      return MAPPER.readValue(in, RouteDetailsResponse.class);
    }
  }

  @Test
  void aRecordedAnswerWithEdges_isRead() throws IOException {
    RouteDetailsResponse r = fixture();
    assertEquals("1.7", r.meta().apiVersion());
    assertEquals("fast", r.meta().profile());
    assertNull(r.points());
    List<Edge> edges = r.edges();
    assertEquals(12, edges.size());

    Edge first = edges.getFirst();
    assertEquals(0.0, first.fromM());
    assertEquals(52.78, first.toM());
    assertEquals("z14:33260341:23548731", first.fromNode().id());
    assertEquals(4, first.fromNode().degree());
    assertEquals(47.201628, first.fromNode().lat(), 1e-9);
    assertEquals("z14:33260246:23548642", first.toNode().id());
    assertFalse(first.partial());
    assertEquals(52.76, first.lengthM());
    assertEquals(0.0, first.fromOffsetM());
    assertEquals(52.76, first.toOffsetM());
    assertEquals("wt}_yAthh_BiSz^", first.geometry());
    assertEquals(2.74, first.toGainCumM());
    assertEquals("ground", first.structure());
    assertEquals("paved", first.surface().surfaceClass());
    assertEquals("asphalt", first.surface().detail());
    assertEquals("tagged", first.surface().source());
    assertEquals("minor_road", first.wayKind());

    assertEquals(2, edges.stream().filter(Edge::partial).count());
    assertEquals(8, edges.stream().filter(e -> "both".equals(e.oneway())).count());
    assertEquals(4, edges.stream().filter(e -> "forward".equals(e.oneway())).count());
    // Api 1.8 fields: absent today
    assertTrue(edges.stream().allMatch(e -> e.tracktype() == null));
    assertTrue(edges.stream().allMatch(e -> e.bicycle() == null && e.foot() == null));
  }

  @Test
  void anEdgeOfApi18_andUnknownKeys_areRead() throws IOException {
    String json =
        """
        {"meta":{"api_version":"1.8"},"status":"complete","something_new":1,
         "edges":[{"from_m":0,"to_m":10,"from_index":0,"to_index":1,
          "from_node":null,"to_node":{"id":"z14:1:2","lat":47.0,"lon":-1.0,"degree":3,"x":1},
          "partial":true,"length_m":null,"traversed_m":10,"from_offset_m":null,"to_offset_m":null,
          "oneway":"against","geometry":"_p~iF~ps|U","from_gain_cum_m":0,"to_gain_cum_m":1,
          "from_loss_cum_m":0,"to_loss_cum_m":0,"tracktype":"grade2","bicycle":"yes",
          "foot":"no","future":{"a":1}}],
         "segments":[{"from_m":0,"to_m":5,"from_index":0,"to_index":1,"matched":false,
          "unmatched_reason":"closed_to_bicycles"}]}
        """;
    RouteDetailsResponse r = MAPPER.readValue(json, RouteDetailsResponse.class);
    Edge e = r.edges().getFirst();
    assertEquals("grade2", e.tracktype());
    assertEquals("yes", e.bicycle());
    assertEquals("no", e.foot());
    assertEquals("against", e.oneway());
    assertNull(e.fromNode());
    assertNull(e.lengthM());
    assertNull(e.fromOffsetM());
    assertNull(e.toOffsetM());
    assertTrue(e.partial());
    assertEquals("z14:1:2", e.toNode().id());
    assertEquals("closed_to_bicycles", r.segments().getFirst().unmatchedReason());
    assertFalse(r.segments().getFirst().matched());
  }

  @Test
  void anAnswerWithoutEdges_hasNone() throws IOException {
    assertNull(RouteDetailsFixtureTest.fixture().edges());
  }
}
