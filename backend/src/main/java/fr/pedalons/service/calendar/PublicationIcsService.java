package fr.pedalons.service.calendar;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.dto.calendar.response.CalendarEventDto;
import fr.pedalons.dto.calendar.response.CalendarEventType;
import fr.pedalons.dto.publications.response.TeamPublicationDto;
import fr.pedalons.dto.rides.response.RideDto;
import fr.pedalons.dto.rides.response.RideGroupDto;
import fr.pedalons.dto.trips.response.TripDto;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Status;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.ride.RideService;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.trip.TripService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * One ride or one trip as a downloadable calendar — « ajouter au calendrier » on a card
 * (docs/LEDGER_DONE.md WEB-33).
 *
 * <p>Unlike the subscription feeds of {@link CalendarService}, this takes no token: the file is
 * built from the same DTO as the detail page, so whoever may read the ride or the trip — an
 * anonymous visitor on a public one included — gets its calendar, and nobody else does. The
 * {@code @CheckAccess(READ)} here is the same check {@code getDto} makes: it is the one the
 * architecture test requires on every service a resource calls.
 */
@ApplicationScoped
public class PublicationIcsService {

  @Inject RideService rideService;
  @Inject TripService tripService;
  @Inject IcsGenerationService icsGenerationService;
  @Inject PublicationEndCalculator publicationEndCalculator;

  /**
   * The ride as one event. A registered caller's starts when their group leaves, as in the
   * subscription feeds (docs/LEDGER_*.md API-157); anyone else's at the ride's start.
   */
  @CheckAccess(entityType = EntityType.RIDE, action = ActionType.READ)
  public String rideIcs(String teamSlug, String rideSlug) {
    RideDto ride = rideService.getDto(teamSlug, rideSlug);
    RideGroupDto joined = ride.getRegisteredGroup();
    Instant start = joined != null ? joined.startAt() : ride.getDateTime();
    Instant end = ride.getEndDateTime();
    CalendarEventDto event =
        event(
            ride.getTeam(),
            ride.getId(),
            ride.getName(),
            start,
            end != null ? CalendarService.endAfter(start, end) : null,
            false,
            CalendarEventType.RIDE,
            ride.getSlug(),
            null,
            ride.getStartPlace() != null ? ride.getStartPlace().name() : null,
            ride.getStatus(),
            ride.getTimezone());
    // A single publication's calendar reads in its own zone (docs/LEDGER_*.md API-60).
    return icsGenerationService.generateIcs(
        List.of(event), ride.getName(), ZoneId.of(ride.getTimezone()));
  }

  /** A trip is its stages: one all-day event each, as in the subscription feeds. */
  @CheckAccess(entityType = EntityType.TRIP, action = ActionType.READ)
  public String tripIcs(String teamSlug, String tripSlug) {
    TripDto trip = tripService.getDto(teamSlug, tripSlug);
    List<Long> stageIds =
        trip.getStages().stream().map(stage -> TsidUtils.toLong(stage.id())).toList();
    // Each stage up to its own end — one query for all of them (docs/LEDGER_*.md API-85).
    Map<Long, Instant> ends = publicationEndCalculator.effectiveEnds(stageIds);
    List<CalendarEventDto> events =
        trip.getStages().stream()
            .map(stage ->
                event(
                    trip.getTeam(),
                    stage.id(),
                    stage.name(),
                    stage.dateTime(),
                    ends.get(TsidUtils.toLong(stage.id())),
                    true,
                    CalendarEventType.TRIP_STAGE,
                    stage.slug(),
                    trip.getSlug(),
                    stage.startPlace() != null ? stage.startPlace().name() : null,
                    trip.getStatus(),
                    stage.timezone()))
            .toList();
    // Each stage's days are counted in its own zone, carried by the event; the calendar reads in
    // the trip's (docs/LEDGER_*.md API-60).
    return icsGenerationService.generateIcs(events, trip.getName(), ZoneId.of(trip.getTimezone()));
  }

  /** Only what the ICS writer reads is set; the card-only fields stay empty. */
  private static CalendarEventDto event(
      TeamPublicationDto team,
      String id,
      String title,
      Instant start,
      @Nullable Instant end,
      boolean allDay,
      CalendarEventType type,
      String entitySlug,
      @Nullable String tripSlug,
      @Nullable String startPlaceName,
      Status status,
      String timezone) {
    return new CalendarEventDto(
        id,
        title,
        start,
        end,
        allDay,
        type,
        team.slug(),
        team.name(),
        entitySlug,
        tripSlug,
        startPlaceName,
        null,
        null,
        null,
        null,
        null,
        false,
        null,
        status,
        timezone);
  }
}
