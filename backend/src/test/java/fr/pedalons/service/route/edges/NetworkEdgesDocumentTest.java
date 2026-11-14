package fr.pedalons.service.route.edges;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.Segment;
import io.hypersistence.utils.hibernate.type.util.JsonConfiguration;
import io.hypersistence.utils.hibernate.type.util.ObjectMapperWrapper;
import java.io.IOException;
import java.io.InputStream;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * The stored document of the street edges (docs/LEDGER_*.md API-198, lot 1), built from the real
 * answer recorded in {@code nantes-edges-fast.json}: 12 edges, 8 distinct junctions, a U-turn.
 */
class NetworkEdgesDocumentTest {

  private static final ObjectMapperWrapper MAPPER =
      JsonConfiguration.INSTANCE.getObjectMapperWrapper();
  private static final Instant NOW = Instant.parse("2026-11-13T21:04:00Z");
  private static final long REV = 7351234567890123L;

  private static RouteDetailsResponse fixture() throws IOException {
    try (InputStream in =
        NetworkEdgesDocumentTest.class.getResourceAsStream(
            "/routedetails/nantes-edges-fast.json")) {
      assertNotNull(in);
      return new com.fasterxml.jackson.databind.ObjectMapper()
          .readValue(in, RouteDetailsResponse.class);
    }
  }

  private static NetworkEdgesDocument document() throws IOException {
    return NetworkEdgesDocuments.from(NetworkEdgesAnswer.of(fixture()), REV, NOW);
  }

  @Test
  void theRealAnswer_becomesADocument() throws IOException {
    NetworkEdgesDocument d = document();
    assertEquals(NetworkEdgesDocument.VERSION, d.v());
    assertEquals(REV, d.rev());
    assertEquals("ok", d.status());
    assertEquals("1.7", d.api());
    assertEquals("2026.11.13", d.rules());
    assertEquals("fast", d.profile());
    assertEquals(12, d.edges().size());
    // The U-turn reuses the junctions: 8 distinct ones for 12 edges
    assertEquals(8, d.nodes().size());
    assertEquals("z14:33260341:23548731", d.nodes().getFirst().id());
    assertEquals(4, d.nodes().getFirst().degree());

    NetworkEdgesDocument.Edge first = d.edges().getFirst();
    assertEquals(0, first.fn());
    assertEquals(1, first.tn());
    assertEquals("wt}_yAthh_BiSz^", first.g(), "polyline kept byte for byte");
    assertEquals("paved", first.sc());
    assertEquals("asphalt", first.sd());
    assertEquals("tagged", first.ss());
    assertEquals("ground", first.st());
    assertEquals("minor_road", first.wk());
    assertEquals(2.74, first.tg());
    assertNull(first.tt());

    // Edges 5 and 6: the same partial edge in both directions
    NetworkEdgesDocument.Edge out = d.edges().get(5);
    NetworkEdgesDocument.Edge back = d.edges().get(6);
    assertTrue(out.p() && back.p());
    assertEquals(out.fn(), back.tn());
    assertEquals(out.tn(), back.fn());
    assertEquals(21.01, back.fo());

    assertEquals(668.93, d.covered(), 1e-6);
    assertEquals(668.93, d.len(), 1e-6, "no summary: the end of the last edge");
    assertTrue(d.unmatched().isEmpty());
    assertNotNull(d.dv().get("typology"));
    assertEquals("versatiles-shortbread", d.dv().get("typology").get("source").asText());
    assertTrue(d.streetsVersion().contains("versatiles-shortbread"));
  }

  @Test
  void anUnknownEnd_hasNoNodeIndexAndNoOffsets() {
    RouteDetailsResponse.Edge e =
        new RouteDetailsResponse.Edge(
            0,
            10,
            0,
            1,
            null,
            new RouteDetailsResponse.EdgeNode("z14:1:1", 47, -1, 2),
            true,
            null,
            10,
            null,
            null,
            "both",
            "g",
            0,
            1,
            0,
            0,
            null,
            null,
            null,
            "grade3",
            "yes",
            "no");
    RouteDetailsResponse response =
        new RouteDetailsResponse(null, "complete", null, null, null, null, List.of(e));
    NetworkEdgesDocument d = NetworkEdgesDocuments.from(NetworkEdgesAnswer.of(response), REV, NOW);
    NetworkEdgesDocument.Edge stored = d.edges().getFirst();
    assertNull(stored.fn());
    assertEquals(0, stored.tn());
    assertNull(stored.len());
    assertNull(stored.fo());
    assertEquals("grade3", stored.tt());
    assertEquals("yes", stored.bi());
    assertEquals("no", stored.ft());
    assertEquals(1, d.nodes().size());
  }

  @Test
  void theUnmatchedMetres_areSummedPerReason_aNewReasonKept() {
    List<Segment> segments =
        List.of(
            new Segment(0, 100, 0, 1, null, null, null, null, true, null),
            new Segment(100, 220.5, 1, 2, null, null, null, null, false, "closed_to_bicycles"),
            new Segment(220.5, 250.5, 2, 3, null, null, null, null, false, "off_network"),
            new Segment(250.5, 280.5, 3, 4, null, null, null, null, false, "off_network"),
            new Segment(280.5, 300, 4, 5, null, null, null, null, false, "a_reason_of_api_2"),
            new Segment(300, 310, 5, 6, null, null, null, null, false, null));
    var unmatched = NetworkEdgesDocuments.unmatched(segments);
    assertEquals(120.5, unmatched.get("closed_to_bicycles"), 1e-9);
    assertEquals(60.0, unmatched.get("off_network"), 1e-9);
    assertEquals(19.5, unmatched.get("a_reason_of_api_2"), 1e-9);
    assertEquals(10.0, unmatched.get("unknown"), 1e-9);
    assertNull(unmatched.get("no_data"));
  }

  @Test
  void theDocument_roundTripsThroughTheJsonbMapper() throws IOException {
    NetworkEdgesDocument d = document();
    String json = MAPPER.toString(d);
    NetworkEdgesDocument read = MAPPER.fromString(json, NetworkEdgesDocument.class);
    assertEquals(d, read);
    JsonNode tree = MAPPER.toJsonNode(json);
    assertEquals(1, tree.get("v").asInt());
    // A node is an array, a null stays out of an edge
    assertTrue(tree.get("nodes").get(0).isArray());
    assertEquals(4, tree.get("nodes").get(0).size());
    assertTrue(tree.get("edges").get(0).has("sc"));
    assertTrue(!tree.get("edges").get(0).has("tt"));
  }

  @Test
  void aLaterRelease_isRead() throws IOException {
    JsonNode tree = MAPPER.toJsonNode(MAPPER.toString(document()));
    ((com.fasterxml.jackson.databind.node.ObjectNode) tree).put("added_by_v2", true);
    ((com.fasterxml.jackson.databind.node.ObjectNode) tree.get("edges").get(0)).put("zz", 1);
    ((com.fasterxml.jackson.databind.node.ArrayNode) tree.get("nodes").get(0)).add("extra");
    NetworkEdgesDocument read = MAPPER.fromString(tree.toString(), NetworkEdgesDocument.class);
    assertEquals(document(), read);
  }

  @Test
  void aTrackTooShort_hasADocumentWithoutEdges() {
    NetworkEdgesDocument d = NetworkEdgesDocuments.from(NetworkEdgesAnswer.tooShort(0.4), REV, NOW);
    assertEquals(NetworkEdgesDocument.STATUS_TOO_SHORT, d.status());
    assertTrue(d.edges().isEmpty());
    assertTrue(d.nodes().isEmpty());
    assertEquals(REV, d.rev());
    assertEquals(NetworkEdgesDocument.VERSION, d.v());
    assertEquals(d, MAPPER.fromString(MAPPER.toString(d), NetworkEdgesDocument.class));
  }

  @Test
  void anAnswerWithoutEdges_givesNoAnswer() throws IOException {
    assertNull(NetworkEdgesAnswer.of(RouteDetailsFixtureHolder.withoutEdges()));
  }

  /** The recorded {@code full} answer of 1.6, which has no {@code edges}. */
  private static final class RouteDetailsFixtureHolder {
    static RouteDetailsResponse withoutEdges() throws IOException {
      try (InputStream in =
          NetworkEdgesDocumentTest.class.getResourceAsStream(
              "/routedetails/nantes-reze-pirmil-full.json")) {
        return new com.fasterxml.jackson.databind.ObjectMapper()
            .readValue(in, RouteDetailsResponse.class);
      }
    }
  }
}
