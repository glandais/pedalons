package fr.pedalons.domain.route;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import com.fasterxml.jackson.databind.JsonNode;
import fr.pedalons.domain.gpx.PreviewSurfacesDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.domain.route.TrackSurfaceDocument.WayRange;
import io.hypersistence.utils.hibernate.type.util.JsonConfiguration;
import io.hypersistence.utils.hibernate.type.util.ObjectMapperWrapper;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

/** The documents are read by the mapper {@code JsonBinaryType} hands to Hibernate. */
class TrackSurfaceDocumentTest {

  private static final ObjectMapperWrapper MAPPER =
      JsonConfiguration.INSTANCE.getObjectMapperWrapper();

  private static TrackSurfaceDocument document() {
    return new TrackSurfaceDocument(
        1,
        "ok",
        null,
        190674135L,
        Instant.parse("2026-10-20T08:00:00Z"),
        "bicycle",
        57012.3,
        List.of(new SurfaceRange(0, 1234.5, "paved"), new SurfaceRange(1234.5, 57012.3, "unknown")),
        List.of(
            new WayRange(0, 800, "road", "none"), new WayRange(800, 57012.3, "cycleway", null)));
  }

  @Test
  void rangesAreStoredAsArrays() {
    JsonNode json = MAPPER.toJsonNode(MAPPER.toString(document()));
    assertEquals(
        MAPPER.toJsonNode("[[0.0,1234.5,\"paved\"],[1234.5,57012.3,\"unknown\"]]"),
        json.get("surfaces"));
    assertEquals(
        MAPPER.toJsonNode("[[0.0,800.0,\"road\",\"none\"],[800.0,57012.3,\"cycleway\",null]]"),
        json.get("ways"));
    assertEquals("ok", json.get("status").asText());
    assertEquals(190674135L, json.get("osmChangeset").asLong());
  }

  @Test
  void aDocumentReadsBack() {
    TrackSurfaceDocument read =
        MAPPER.fromString(MAPPER.toString(document()), TrackSurfaceDocument.class);
    assertEquals(document(), read);
  }

  @Test
  void aDocumentOfALaterReleaseStillReads() {
    String json =
        """
        {"version":2,"status":"ok","reason":null,"osmChangeset":null,"computedAt":"2026-10-20T08:00:00Z",
         "costing":"bicycle","distance":100.0,"somethingNew":{"a":1},
         "surfaces":[[0,100,"paved","a fourth element",{"and":"a fifth"}]],
         "ways":[[0,100,"road","none","more"]]}
        """;
    TrackSurfaceDocument read = MAPPER.fromString(json, TrackSurfaceDocument.class);
    assertEquals(new SurfaceRange(0, 100, "paved"), read.surfaces().getFirst());
    assertEquals(new WayRange(0, 100, "road", "none"), read.ways().getFirst());
    assertNull(read.osmChangeset());
  }

  @Test
  void aStatusOfALaterReleaseIsNotOk() {
    String json =
        "{\"version\":1,\"status\":\"partial\",\"computedAt\":\"2026-10-20T08:00:00Z\","
            + "\"costing\":\"bicycle\",\"distance\":1.0,\"surfaces\":[],\"ways\":[]}";
    assertEquals(false, MAPPER.fromString(json, TrackSurfaceDocument.class).ok());
  }

  @Test
  void aPreviewDocumentReadsBackWithItsNulls() {
    PreviewSurfacesDocument preview =
        new PreviewSurfacesDocument(42L, java.util.Arrays.asList(document(), null));
    String json = MAPPER.toString(preview);
    PreviewSurfacesDocument read = MAPPER.fromString(json, PreviewSurfacesDocument.class);
    assertEquals(preview, read);
    PreviewSurfacesDocument later =
        MAPPER.fromString(
            "{\"trackRevision\":7,\"tracks\":[],\"extra\":true}", PreviewSurfacesDocument.class);
    assertEquals(7L, later.trackRevision());
  }
}
