package fr.pedalons.domain.route;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.fasterxml.jackson.databind.deser.std.StdDeserializer;
import fr.pedalons.domain.gpx.PreviewSurfacesDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.domain.route.TrackSurfaceDocument.WayRange;
import io.hypersistence.utils.hibernate.type.util.JsonConfiguration;
import io.hypersistence.utils.hibernate.type.util.ObjectMapperWrapper;
import java.io.IOException;
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
        {"version":3,"status":"ok","reason":null,"osmChangeset":null,"computedAt":"2026-10-20T08:00:00Z",
         "costing":"bicycle","distance":100.0,"somethingNew":{"a":1},
         "surfaces":[[0,100,"paved","a fourth element",{"and":"a fifth"}]],
         "ways":[[0,100,"road","none",null,null,null,null,"more"]]}
        """;
    TrackSurfaceDocument read = MAPPER.fromString(json, TrackSurfaceDocument.class);
    assertEquals(new SurfaceRange(0, 100, "paved"), read.surfaces().getFirst());
    assertEquals(new WayRange(0, 100, "road", "none"), read.ways().getFirst());
    assertNull(read.osmChangeset());
  }

  private static TrackSurfaceDocument version2() {
    return new TrackSurfaceDocument(
        TrackSurfaceDocument.VERSION_ROUTE_DETAILS,
        "ok",
        null,
        null,
        Instant.parse("2026-11-06T08:00:00Z"),
        "bicycle",
        1000.0,
        List.of(new SurfaceRange(0, 600, "gravel"), new SurfaceRange(600, 1000, "unknown")),
        List.of(
            new WayRange(0, 600, "track", null, "bridge", true, "unpaved", "fine_gravel"),
            new WayRange(600, 900, "track", null, null, false, "unknown", null),
            new WayRange(900, 1000, "path", null, "tunnel", null, null, null)),
        MAPPER.toJsonNode("{\"versatiles\":\"2026-10-27\"}"));
  }

  @Test
  void aVersion2Way_stopsAtItsLastKnownElement() {
    JsonNode json = MAPPER.toJsonNode(MAPPER.toString(version2()));
    assertEquals(
        MAPPER.toJsonNode(
            """
            [[0.0,600.0,"track",null,"bridge",true,"unpaved","fine_gravel"],
             [600.0,900.0,"track",null,null,false,"unknown"],
             [900.0,1000.0,"path",null,"tunnel"]]
            """),
        json.get("ways"));
    assertEquals("2026-10-27", json.get("dataVersions").get("versatiles").asText());
  }

  @Test
  void aVersion2Document_readsBack() {
    TrackSurfaceDocument read =
        MAPPER.fromString(MAPPER.toString(version2()), TrackSurfaceDocument.class);
    assertEquals(version2(), read);
    assertEquals(new SurfaceRange(0, 600, "gravel"), read.surfaces().getFirst());
  }

  @Test
  void aVersion1Document_doesNotChangeOnDisk() {
    JsonNode json = MAPPER.toJsonNode(MAPPER.toString(document()));
    assertFalse(json.has("dataVersions"));
  }

  /** The shape of this record before version 2, as the previous release reads a document. */
  @JsonIgnoreProperties(ignoreUnknown = true)
  record PreviousRelease(int version, String status, List<PreviousWay> ways) {

    @JsonDeserialize(using = PreviousWay.Reader.class)
    record PreviousWay(String use, String cycleLane) {

      static final class Reader extends StdDeserializer<PreviousWay> {
        Reader() {
          super(PreviousWay.class);
        }

        @Override
        public PreviousWay deserialize(JsonParser p, DeserializationContext c) throws IOException {
          JsonNode n = c.readTree(p);
          return new PreviousWay(
              n.path(2).isNull() ? null : n.path(2).asText(),
              n.path(3).isNull() ? null : n.path(3).asText());
        }
      }
    }
  }

  @Test
  void theReaderOfThePreviousRelease_seesTheWayKindAsAUse() {
    PreviousRelease read = MAPPER.fromString(MAPPER.toString(version2()), PreviousRelease.class);
    assertEquals(2, read.version());
    assertEquals("track", read.ways().getFirst().use());
    assertNull(read.ways().getFirst().cycleLane());
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
