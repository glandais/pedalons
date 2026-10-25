package fr.pedalons.dto.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.time.DateTimeException;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.exc.InvalidFormatException;

/**
 * The date of a request (docs/LEDGER_*.md API-60, plan §5): a wall time read in the entity's zone.
 * An instant with Z or an offset, which version N still tolerated, is refused since N+1 (plan §8).
 */
class EventDateTimeTest {

  private static final ZoneId PARIS = ZoneId.of("Europe/Paris");
  private static final ZoneId TOKYO = ZoneId.of("Asia/Tokyo");

  private final ObjectMapper mapper = new ObjectMapper();

  @Test
  void aWallTime_isReadInTheGivenZone() {
    EventDateTime value = EventDateTime.parse("2030-06-02T08:00:00");
    assertEquals(Instant.parse("2030-06-02T06:00:00Z"), value.toInstant(PARIS));
    assertEquals(Instant.parse("2030-06-01T23:00:00Z"), value.toInstant(TOKYO));
  }

  @Test
  void aWallTime_withoutSeconds_isAccepted() {
    assertEquals(
        EventDateTime.local(LocalDateTime.parse("2030-06-02T08:00")),
        EventDateTime.parse("2030-06-02T08:00"));
  }

  /** The old format: the client never decides the zone of a rendezvous. */
  @Test
  void anInstantWithZ_isRefused() {
    assertThrows(DateTimeException.class, () -> EventDateTime.parse("2030-06-02T06:00:00Z"));
  }

  @Test
  void anInstantWithAnOffset_isRefused() {
    assertThrows(DateTimeException.class, () -> EventDateTime.parse("2030-06-02T08:00:00+02:00"));
    assertThrows(
        DateTimeException.class,
        () -> EventDateTime.parse("2030-06-02T08:00:00+02:00[Europe/Paris]"));
  }

  /** Paris springs forward on 2030-03-31: a wall time in the gap is shifted by the gap. */
  @Test
  void aWallTimeInTheSpringGap_isShiftedByTheGap() {
    assertEquals(
        Instant.parse("2030-03-31T01:30:00Z"),
        EventDateTime.parse("2030-03-31T02:30:00").toInstant(PARIS));
  }

  /** Paris falls back on 2030-10-27: a wall time that exists twice takes the earlier offset. */
  @Test
  void aWallTimeInTheAutumnOverlap_takesTheEarlierOffset() {
    assertEquals(
        Instant.parse("2030-10-27T00:30:00Z"),
        EventDateTime.parse("2030-10-27T02:30:00").toInstant(PARIS));
  }

  @Test
  void garbage_isRefused() {
    assertThrows(DateTimeException.class, () -> EventDateTime.parse("next saturday"));
    assertThrows(DateTimeException.class, () -> EventDateTime.parse("2030-06-02"));
  }

  @Test
  void aNullValue_givesNoInstant() {
    assertNull(EventDateTime.toInstant(null, PARIS));
  }

  // ─── JSON ─────────────────────────────────────────────────────────────────

  record Body(EventDateTime dateTime) {}

  @Test
  void json_readsAWallTime() throws Exception {
    assertEquals(
        EventDateTime.local(LocalDateTime.parse("2030-06-02T08:00:00")),
        mapper.readValue("{\"dateTime\":\"2030-06-02T08:00:00\"}", Body.class).dateTime());
  }

  /**
   * An InvalidFormatException, so a 400 — never Jackson's lenient LocalDateTime reading, which would
   * drop the Z and take 06:00 UTC for 06:00 wall time.
   */
  @Test
  void json_anInstant_isAnInvalidFormat() {
    assertThrows(
        InvalidFormatException.class,
        () -> mapper.readValue("{\"dateTime\":\"2030-06-02T06:00:00Z\"}", Body.class));
  }

  /** An InvalidFormatException: the resource layer answers 400, as for any malformed body. */
  @Test
  void json_garbage_isAnInvalidFormat() {
    assertThrows(
        InvalidFormatException.class,
        () -> mapper.readValue("{\"dateTime\":\"tomorrow\"}", Body.class));
  }

  @Test
  void json_writesTheWallTime() throws Exception {
    assertEquals(
        "{\"dateTime\":\"2030-06-02T08:00\"}",
        mapper.writeValueAsString(
            new Body(EventDateTime.local(LocalDateTime.parse("2030-06-02T08:00:00")))));
  }
}
