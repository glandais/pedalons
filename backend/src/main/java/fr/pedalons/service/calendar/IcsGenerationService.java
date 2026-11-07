package fr.pedalons.service.calendar;

import fr.pedalons.dto.calendar.response.CalendarEventDto;
import fr.pedalons.service.security.DomainResolver;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class IcsGenerationService {

  private static final DateTimeFormatter ICS_DATETIME_FORMAT =
      DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'").withZone(ZoneId.of("UTC"));

  private static final DateTimeFormatter ICS_DATE_FORMAT = DateTimeFormatter.ofPattern("yyyyMMdd");

  @Inject DomainResolver domainResolver;

  /**
   * A calendar of {@code events}. Timed events are written in UTC and need no zone; an all-day
   * event's dates are counted in its own {@link CalendarEventDto#timezone()} — the stage's stored
   * zone, else its team's (docs/LEDGER_*.md API-60).
   *
   * @param calendarZone the zone announced as {@code X-WR-TIMEZONE}: the team's for a team feed,
   *     the publication's for a single one, {@code null} — no header — for a feed mixing teams,
   *     which has no zone of its own.
   */
  public String generateIcs(
      List<CalendarEventDto> events, String calendarName, @Nullable ZoneId calendarZone) {
    StringBuilder ics = new StringBuilder();

    // VCALENDAR header with Apple/Google compatibility
    ics.append("BEGIN:VCALENDAR\r\n");
    ics.append("VERSION:2.0\r\n");
    ics.append("PRODID:-//Pedalons//Calendar//EN\r\n");
    ics.append("CALSCALE:GREGORIAN\r\n");
    ics.append("METHOD:PUBLISH\r\n");
    ics.append("X-WR-CALNAME:").append(escapeIcs(calendarName)).append("\r\n");
    if (calendarZone != null) {
      ics.append("X-WR-TIMEZONE:").append(calendarZone.getId()).append("\r\n");
    }
    ics.append("REFRESH-INTERVAL;VALUE=DURATION:PT1H\r\n");

    // Add each event
    for (CalendarEventDto event : events) {
      appendEvent(ics, event, ZoneId.of(event.timezone()));
    }

    ics.append("END:VCALENDAR\r\n");
    return ics.toString();
  }

  private void appendEvent(StringBuilder ics, CalendarEventDto event, ZoneId allDayZone) {
    ics.append("BEGIN:VEVENT\r\n");

    // UID must be globally unique and stable
    ics.append("UID:").append(event.id()).append("@pedalons.app\r\n");

    // DTSTAMP is required - when the event was created/modified
    ics.append("DTSTAMP:").append(ICS_DATETIME_FORMAT.format(Instant.now())).append("\r\n");

    // Start date/time
    if (event.allDay()) {
      ics.append("DTSTART;VALUE=DATE:")
          .append(ICS_DATE_FORMAT.format(LocalDate.ofInstant(event.start(), allDayZone)))
          .append("\r\n");
    } else {
      ics.append("DTSTART:").append(ICS_DATETIME_FORMAT.format(event.start())).append("\r\n");
    }

    // End date/time (optional)
    if (event.end() != null) {
      if (event.allDay()) {
        ics.append("DTEND;VALUE=DATE:")
            .append(ICS_DATE_FORMAT.format(allDayEnd(event.start(), event.end(), allDayZone)))
            .append("\r\n");
      } else {
        ics.append("DTEND:").append(ICS_DATETIME_FORMAT.format(event.end())).append("\r\n");
      }
    }

    // Summary (title)
    ics.append("SUMMARY:").append(escapeIcs(event.title())).append("\r\n");

    // Description with team name
    ics.append("DESCRIPTION:").append(escapeIcs(event.teamName())).append("\r\n");

    // The meeting place, by name, when the ride or stage has one (docs/LEDGER_*.md API-157)
    String location = event.startPlaceName();
    if (location != null && !location.isBlank()) {
      ics.append("LOCATION:").append(escapeIcs(location.strip())).append("\r\n");
    }

    // URL to the event
    String url = buildEventUrl(event);
    ics.append("URL:").append(url).append("\r\n");

    // Categories
    switch (event.type()) {
      case RIDE -> ics.append("CATEGORIES:RIDE\r\n");
      case TRIP_STAGE -> ics.append("CATEGORIES:TRIP\r\n");
    }

    ics.append("END:VEVENT\r\n");
  }

  /**
   * The exclusive end date of an all-day event (RFC 5545): the day after the one its end falls on,
   * unless that end is already a midnight — so a stage ending at 17:00 occupies its own day, one
   * ending the next morning both days (docs/LEDGER_*.md API-85). Never before the day after the
   * start. Days and midnights are those of {@code zone}, the stage's (docs/LEDGER_*.md API-90,
   * API-60).
   */
  static LocalDate allDayEnd(Instant start, Instant end, ZoneId zone) {
    ZonedDateTime local = end.atZone(zone);
    LocalDate endDay = local.toLocalDate();
    boolean midnight = local.toLocalTime().equals(LocalTime.MIDNIGHT);
    LocalDate exclusive = midnight ? endDay : endDay.plusDays(1);
    LocalDate minimum = LocalDate.ofInstant(start, zone).plusDays(1);
    return exclusive.isBefore(minimum) ? minimum : exclusive;
  }

  private String buildEventUrl(CalendarEventDto event) {
    String baseUrl = domainResolver.getEffectiveBaseUrl();
    return switch (event.type()) {
      case RIDE -> baseUrl + "/teams/" + event.teamSlug() + "/rides/" + event.entitySlug();
      case TRIP_STAGE -> {
        if (event.tripSlug() != null) {
          yield baseUrl
              + "/teams/"
              + event.teamSlug()
              + "/trips/"
              + event.tripSlug()
              + "/stages/"
              + event.entitySlug();
        }
        yield baseUrl;
      }
    };
  }

  /**
   * Escape special characters in iCalendar text values per RFC 5545. Backslash, semicolon, and
   * comma must be escaped. Newlines must be escaped as \n.
   */
  static String escapeIcs(@Nullable String text) {
    if (text == null) {
      return "";
    }
    return text.replace("\\", "\\\\")
        .replace(";", "\\;")
        .replace(",", "\\,")
        .replace("\r\n", "\\n")
        .replace("\n", "\\n")
        .replace("\r", "\\n");
  }
}
