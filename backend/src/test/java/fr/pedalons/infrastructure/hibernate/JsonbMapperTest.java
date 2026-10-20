package fr.pedalons.infrastructure.hibernate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.domain.route.TrackSurfaceDocument.WayRange;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import org.hibernate.HibernateException;
import org.junit.jupiter.api.Test;

/**
 * Pins what {@link JsonbMapper} writes: it must stay byte-identical to what hypersistence-utils
 * 3.16.0 wrote, because a rolling deploy makes the previous release read these documents.
 */
class JsonbMapperTest {

  private static final JsonbMapper MAPPER = JsonbMapper.INSTANCE;

  @Test
  void goldenDocumentWrittenByHypersistence() {
    TrackSurfaceDocument doc =
        new TrackSurfaceDocument(
            1,
            "ok",
            null,
            190674135L,
            Instant.parse("2026-10-20T08:00:00Z"),
            "bicycle",
            57012.3,
            List.of(
                new SurfaceRange(0, 1234.5, "paved"), new SurfaceRange(1234.5, 57012.3, "unknown")),
            List.of(
                new WayRange(0, 800, "road", "none"),
                new WayRange(800, 57012.3, "cycleway", null)));
    assertEquals(
        "{\"version\":1,\"status\":\"ok\",\"reason\":null,\"osmChangeset\":190674135,"
            + "\"computedAt\":1792483200.000000000,\"costing\":\"bicycle\",\"distance\":57012.3,"
            + "\"surfaces\":[[0.0,1234.5,\"paved\"],[1234.5,57012.3,\"unknown\"]],"
            + "\"ways\":[[0.0,800.0,\"road\",\"none\"],[800.0,57012.3,\"cycleway\",null]]}",
        MAPPER.toString(doc));
  }

  @Test
  void offsetDateTimeIsIsoWithOffset() {
    assertEquals(
        "\"2026-10-20T10:00:00+02:00\"",
        MAPPER.toString(OffsetDateTime.parse("2026-10-20T10:00:00+02:00")));
  }

  @Test
  void stringsPassThrough() {
    assertEquals("{\"a\":1}", MAPPER.toString("{\"a\":1}"));
  }

  @Test
  void malformedJsonIsAHibernateException() {
    assertThrows(
        HibernateException.class, () -> MAPPER.fromString("{not json", java.util.Map.class));
  }
}
