package fr.pedalons.service.calendar;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.dto.calendar.response.CalendarEventDto;
import fr.pedalons.dto.calendar.response.CalendarEventType;
import fr.pedalons.enums.Status;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class IcsGenerationServiceTest extends AbstractBaseTest {

  @Inject IcsGenerationService icsGenerationService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;

  private Domain domain;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
  }

  @Test
  void generateIcs_shouldReturnValidIcsFormat() {
    CalendarEventDto event =
        new CalendarEventDto(
            "abc123",
            "Morning Ride",
            Instant.parse("2024-06-15T08:00:00Z"),
            null,
            false,
            CalendarEventType.RIDE,
            "cycling-team",
            "Cycling Team",
            "morning-ride",
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            false,
            null,
            Status.PUBLISHED,
            "Europe/Paris");

    String ics = icsGenerationService.generateIcs(List.of(event), "My Calendar", null);

    assertTrue(ics.startsWith("BEGIN:VCALENDAR\r\n"));
    assertTrue(ics.endsWith("END:VCALENDAR\r\n"));
    assertTrue(ics.contains("VERSION:2.0"));
    assertTrue(ics.contains("PRODID:-//Pedalons//Calendar//EN"));
    assertTrue(ics.contains("X-WR-CALNAME:My Calendar"));
  }

  @Test
  void generateIcs_shouldIncludeEventDetails() {
    CalendarEventDto event =
        new CalendarEventDto(
            "event123",
            "Test Ride",
            Instant.parse("2024-06-15T08:00:00Z"),
            null,
            false,
            CalendarEventType.RIDE,
            "team-slug",
            "Team Name",
            "test-ride",
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            false,
            null,
            Status.PUBLISHED,
            "Europe/Paris");

    String ics = icsGenerationService.generateIcs(List.of(event), "Calendar", null);

    assertTrue(ics.contains("BEGIN:VEVENT"));
    assertTrue(ics.contains("END:VEVENT"));
    assertTrue(ics.contains("UID:event123@pedalons.app"));
    assertTrue(ics.contains("SUMMARY:Test Ride"));
    assertTrue(ics.contains("DESCRIPTION:Team Name"));
    assertTrue(ics.contains("CATEGORIES:RIDE"));
  }

  @Test
  void generateIcs_shouldHandleAllDayEvents() {
    CalendarEventDto event =
        new CalendarEventDto(
            "allday123",
            "All Day Event",
            Instant.parse("2024-06-15T06:00:00Z"),
            Instant.parse("2024-06-15T15:00:00Z"),
            true,
            CalendarEventType.TRIP_STAGE,
            "team-slug",
            "Team Name",
            "stage-1",
            "trip-slug",
            null,
            null,
            null,
            null,
            null,
            null,
            false,
            null,
            Status.PUBLISHED,
            "Europe/Paris");

    String ics = icsGenerationService.generateIcs(List.of(event), "Calendar", null);

    assertTrue(ics.contains("DTSTART;VALUE=DATE:20240615"));
    assertTrue(ics.contains("DTEND;VALUE=DATE:20240616"));
    assertTrue(ics.contains("CATEGORIES:TRIP"));
  }

  @Test
  void generateIcs_shouldHandleTimedEvents() {
    CalendarEventDto event =
        new CalendarEventDto(
            "timed123",
            "Timed Ride",
            Instant.parse("2024-06-15T08:30:00Z"),
            Instant.parse("2024-06-15T12:30:00Z"),
            false,
            CalendarEventType.RIDE,
            "team-slug",
            "Team Name",
            "timed-ride",
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            false,
            null,
            Status.PUBLISHED,
            "Europe/Paris");

    String ics = icsGenerationService.generateIcs(List.of(event), "Calendar", null);

    assertTrue(ics.contains("DTSTART:20240615T083000Z"));
    assertTrue(ics.contains("DTEND:20240615T123000Z"));
  }

  @Test
  void generateIcs_shouldIncludeRideUrl() {
    CalendarEventDto event =
        new CalendarEventDto(
            "ride123",
            "Ride Event",
            Instant.parse("2024-06-15T08:00:00Z"),
            null,
            false,
            CalendarEventType.RIDE,
            "cycling-club",
            "Cycling Club",
            "sunday-ride",
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            false,
            null,
            Status.PUBLISHED,
            "Europe/Paris");

    String ics = icsGenerationService.generateIcs(List.of(event), "Calendar", null);

    assertTrue(ics.contains("URL:"));
    assertTrue(ics.contains("/teams/cycling-club/rides/sunday-ride"));
  }

  @Test
  void generateIcs_shouldIncludeTripStageUrl() {
    CalendarEventDto event =
        new CalendarEventDto(
            "stage123",
            "Stage Event",
            Instant.parse("2024-06-15T00:00:00Z"),
            null,
            true,
            CalendarEventType.TRIP_STAGE,
            "cycling-club",
            "Cycling Club",
            "stage-1",
            "summer-trip",
            null,
            null,
            null,
            null,
            null,
            null,
            false,
            null,
            Status.PUBLISHED,
            "Europe/Paris");

    String ics = icsGenerationService.generateIcs(List.of(event), "Calendar", null);

    assertTrue(ics.contains("URL:"));
    assertTrue(ics.contains("/teams/cycling-club/trips/summer-trip/stages/stage-1"));
  }

  @Test
  void generateIcs_shouldEscapeSpecialCharacters() {
    CalendarEventDto event =
        new CalendarEventDto(
            "special123",
            "Ride with, commas; and semicolons",
            Instant.parse("2024-06-15T08:00:00Z"),
            null,
            false,
            CalendarEventType.RIDE,
            "team",
            "Team, Name; Test",
            "ride",
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            false,
            null,
            Status.PUBLISHED,
            "Europe/Paris");

    String ics = icsGenerationService.generateIcs(List.of(event), "Calendar; Test, Name", null);

    assertTrue(ics.contains("SUMMARY:Ride with\\, commas\\; and semicolons"));
    assertTrue(ics.contains("DESCRIPTION:Team\\, Name\\; Test"));
    assertTrue(ics.contains("X-WR-CALNAME:Calendar\\; Test\\, Name"));
  }

  @Test
  void generateIcs_shouldHandleMultipleEvents() {
    CalendarEventDto event1 =
        new CalendarEventDto(
            "event1",
            "First Event",
            Instant.parse("2024-06-15T08:00:00Z"),
            null,
            false,
            CalendarEventType.RIDE,
            "team",
            "Team",
            "first",
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            false,
            null,
            Status.PUBLISHED,
            "Europe/Paris");

    CalendarEventDto event2 =
        new CalendarEventDto(
            "event2",
            "Second Event",
            Instant.parse("2024-06-16T09:00:00Z"),
            null,
            false,
            CalendarEventType.RIDE,
            "team",
            "Team",
            "second",
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            false,
            null,
            Status.PUBLISHED,
            "Europe/Paris");

    String ics = icsGenerationService.generateIcs(List.of(event1, event2), "Calendar", null);

    // Count VEVENT blocks
    int eventCount = ics.split("BEGIN:VEVENT").length - 1;
    assertEquals(2, eventCount);

    assertTrue(ics.contains("UID:event1@pedalons.app"));
    assertTrue(ics.contains("UID:event2@pedalons.app"));
  }

  @Test
  void generateIcs_shouldHandleEmptyEventList() {
    String ics = icsGenerationService.generateIcs(List.of(), "Empty Calendar", null);

    assertTrue(ics.contains("BEGIN:VCALENDAR"));
    assertTrue(ics.contains("END:VCALENDAR"));
    assertTrue(ics.contains("X-WR-CALNAME:Empty Calendar"));
    assertFalse(ics.contains("BEGIN:VEVENT"));
  }

  @Test
  void generateIcs_shouldIncludeRefreshInterval() {
    String ics =
        icsGenerationService.generateIcs(
            List.of(
                new CalendarEventDto(
                    "id",
                    "Event",
                    Instant.now(),
                    null,
                    false,
                    CalendarEventType.RIDE,
                    "team",
                    "Team",
                    "event",
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    false,
                    null,
                    Status.PUBLISHED,
                    "Europe/Paris")),
            "Calendar",
            null);

    assertTrue(ics.contains("REFRESH-INTERVAL;VALUE=DURATION:PT1H"));
  }

  /** An all-day event ends the day after its end falls on, exclusive (API-85). */
  @Test
  void allDayEnd_coversEveryDayUpToTheEnd() {
    Instant start = Instant.parse("2024-06-15T07:00:00Z");
    assertEquals(
        LocalDate.parse("2024-06-16"),
        IcsGenerationService.allDayEnd(start, Instant.parse("2024-06-15T17:00:00Z"), UTC));
    assertEquals(
        LocalDate.parse("2024-06-17"),
        IcsGenerationService.allDayEnd(start, Instant.parse("2024-06-16T01:00:00Z"), UTC));
    // Already a midnight: that day is the exclusive end.
    assertEquals(
        LocalDate.parse("2024-06-16"),
        IcsGenerationService.allDayEnd(start, Instant.parse("2024-06-16T00:00:00Z"), UTC));
    // Never before the day after the start.
    assertEquals(
        LocalDate.parse("2024-06-16"),
        IcsGenerationService.allDayEnd(start, Instant.parse("2024-06-14T00:00:00Z"), UTC));
  }

  /** Days and midnights are the stage's, not UTC's (API-90). */
  @Test
  void allDayEnd_countsDaysInTheStageZone() {
    // 23:30 in Paris (UTC+2) is still the 15th there: the stage occupies that one day.
    assertEquals(
        LocalDate.parse("2024-06-16"),
        IcsGenerationService.allDayEnd(
            Instant.parse("2024-06-15T06:00:00Z"), Instant.parse("2024-06-15T21:30:00Z"), PARIS));
    // Midnight in Paris is 22:00 UTC: already the exclusive end.
    assertEquals(
        LocalDate.parse("2024-06-16"),
        IcsGenerationService.allDayEnd(
            Instant.parse("2024-06-15T06:00:00Z"), Instant.parse("2024-06-15T22:00:00Z"), PARIS));
  }

  /**
   * A stage leaving at 00:30 and ending at 23:30, Paris time, is that one day — not the eve, and
   * not two days (API-90): its stored zone counts the days, not UTC's.
   */
  @Test
  void generateIcs_allDayStage_isDatedInItsStoredZone_Paris() {
    CalendarEventDto event =
        stage(
            "night",
            Instant.parse("2024-06-14T22:30:00Z"),
            Instant.parse("2024-06-15T21:30:00Z"),
            "Europe/Paris");

    String ics = icsGenerationService.generateIcs(List.of(event), "Calendar", null);

    assertTrue(ics.contains("DTSTART;VALUE=DATE:20240615"), ics);
    assertTrue(ics.contains("DTEND;VALUE=DATE:20240616"), ics);
  }

  /**
   * A stage abroad is dated in the zone its event carries — the stage's stored zone — whatever the
   * calendar's own zone (docs/LEDGER_*.md API-60).
   */
  @Test
  void generateIcs_allDayStage_isDatedInItsOwnZone() {
    // 00:30 to 23:30 in Tokyo (UTC+9): the 14th then the 15th in UTC and in Paris.
    CalendarEventDto event =
        stage(
            "tokyo",
            Instant.parse("2024-06-14T15:30:00Z"),
            Instant.parse("2024-06-15T14:30:00Z"),
            "Asia/Tokyo");

    String ics = icsGenerationService.generateIcs(List.of(event), "Calendar", PARIS);

    assertTrue(ics.contains("DTSTART;VALUE=DATE:20240615"), ics);
    assertTrue(ics.contains("DTEND;VALUE=DATE:20240616"), ics);
  }

  /** A feed mixing teams has no zone of its own: no X-WR-TIMEZONE (docs/LEDGER_*.md API-60). */
  @Test
  void generateIcs_withoutACalendarZone_announcesNone() {
    String ics = icsGenerationService.generateIcs(List.of(), "Mine", null);

    assertFalse(ics.contains("X-WR-TIMEZONE"), ics);
  }

  /** A team feed announces the team's zone, not Paris in hard (docs/LEDGER_*.md API-60). */
  @Test
  void generateIcs_withACalendarZone_announcesIt() {
    String ics = icsGenerationService.generateIcs(List.of(), "Team", ZoneId.of("Asia/Tokyo"));

    assertTrue(ics.contains("X-WR-TIMEZONE:Asia/Tokyo\r\n"), ics);
  }

  /**
   * The meeting place is the event's LOCATION, escaped as every text value (RFC 5545 §3.3.11);
   * an event without one has no LOCATION line (docs/LEDGER_*.md API-157).
   */
  @Test
  void generateIcs_writesTheStartPlaceAsAnEscapedLocation() {
    CalendarEventDto placed =
        new CalendarEventDto(
            "placed",
            "Ride",
            Instant.parse("2024-06-15T08:00:00Z"),
            null,
            false,
            CalendarEventType.RIDE,
            "team",
            "Team",
            "ride",
            null,
            "Parking, gare; quai \\ nord\nentrée B",
            null,
            null,
            null,
            null,
            null,
            false,
            null,
            Status.PUBLISHED,
            "Europe/Paris");
    CalendarEventDto unplaced =
        stage(
            "unplaced",
            Instant.parse("2024-06-16T08:00:00Z"),
            Instant.parse("2024-06-16T17:00:00Z"),
            "Europe/Paris");

    String ics = icsGenerationService.generateIcs(List.of(placed, unplaced), "Cal", null);

    assertTrue(ics.contains("LOCATION:Parking\\, gare\\; quai \\\\ nord\\nentrée B\r\n"), ics);
    assertEquals(1, ics.split("LOCATION:", -1).length - 1, ics);
  }

  private static final ZoneId UTC = ZoneId.of("UTC");
  private static final ZoneId PARIS = ZoneId.of("Europe/Paris");

  private static CalendarEventDto stage(String id, Instant start, Instant end, String timezone) {
    return new CalendarEventDto(
        id,
        "Stage",
        start,
        end,
        true,
        CalendarEventType.TRIP_STAGE,
        "team",
        "Team",
        id,
        "trip",
        null,
        null,
        null,
        null,
        null,
        null,
        false,
        null,
        Status.PUBLISHED,
        timezone);
  }
}
