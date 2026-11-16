package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.repository.route.GeneratorSourceRepository.TrackRow;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;

class OverlayNdjsonWriterTest {

  private static final ObjectMapper JSON = new ObjectMapper();

  private static String document(long rev) {
    return "{\"v\": "
        + NetworkEdgesDocument.VERSION
        + ", \"rev\": "
        + rev
        + ", \"edges\": [], \"nodes\": [], \"status\": \"ok\"}";
  }

  private static String[] lines(ByteArrayOutputStream out) {
    return out.toString(StandardCharsets.UTF_8).split("\n");
  }

  @Test
  void oneLinePerTrackThenTheEndLine() throws IOException {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    OverlayNdjsonWriter w = new OverlayNdjsonWriter(out, 1_000_000);
    w.track(new TrackRow(1, 10, "ROAD", false, 7L, document(7)));
    w.track(new TrackRow(2, 11, "GRAVEL", true, 8L, document(8)));
    w.finish();
    String[] lines = lines(out);
    assertEquals(3, lines.length);
    JsonNode first = JSON.readTree(lines[0]);
    assertEquals("ROAD", first.get("type").asText());
    assertEquals(false, first.get("excluded").asBoolean());
    assertEquals(7, first.get("network_edges").get("rev").asInt());
    JsonNode second = JSON.readTree(lines[1]);
    assertEquals("GRAVEL", second.get("type").asText());
    assertEquals(true, second.get("excluded").asBoolean());
    assertEquals(2, JSON.readTree(lines[2]).get("end").get("tracks").asInt());
  }

  @Test
  void theStoredTextGoesInAsItIs() throws IOException {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    OverlayNdjsonWriter w = new OverlayNdjsonWriter(out, 1_000_000);
    String doc = document(7);
    w.track(new TrackRow(1, 10, "ROAD", false, 7L, doc));
    assertTrue(out.toString(StandardCharsets.UTF_8).contains("\"network_edges\":" + doc + "}"));
  }

  @Test
  void aDocumentThatIsNotCurrentGoesAsNull() throws IOException {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    OverlayNdjsonWriter w = new OverlayNdjsonWriter(out, 1_000_000);
    w.track(new TrackRow(1, 10, "ROAD", false, 9L, document(7))); // another revision
    w.track(new TrackRow(2, 10, "ROAD", false, 7L, null)); // never computed
    w.track(new TrackRow(3, 10, "ROAD", false, null, document(7))); // no original
    w.finish();
    String[] lines = lines(out);
    for (int i = 0; i < 3; i++) {
      assertTrue(JSON.readTree(lines[i]).get("network_edges").isNull(), lines[i]);
    }
    assertEquals(3, w.stats().notCurrent());
  }

  @Test
  void aDocumentAboveTheLimitGoesAsNull() throws IOException {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    OverlayNdjsonWriter w = new OverlayNdjsonWriter(out, 20);
    w.track(new TrackRow(1, 10, "ROAD", false, 7L, document(7)));
    assertTrue(JSON.readTree(lines(out)[0]).get("network_edges").isNull());
  }

  @Test
  void anUnknownOrMissingSurfaceTypeIsMixed() throws IOException {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    OverlayNdjsonWriter w = new OverlayNdjsonWriter(out, 1_000_000);
    w.track(new TrackRow(1, 10, null, false, 7L, document(7)));
    w.track(new TrackRow(2, 10, "MIXED", false, 7L, document(7)));
    w.track(new TrackRow(3, 10, "GRAVELISH", false, 7L, document(7)));
    for (String line : lines(out)) {
      assertEquals("MIXED", JSON.readTree(line).get("type").asText());
    }
  }

  @Test
  void anEmptyTeamIsJustTheEndLine() throws IOException {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    OverlayNdjsonWriter w = new OverlayNdjsonWriter(out, 1_000_000);
    w.finish();
    assertEquals("{\"end\":{\"tracks\":0}}\n", out.toString(StandardCharsets.UTF_8));
  }
}
