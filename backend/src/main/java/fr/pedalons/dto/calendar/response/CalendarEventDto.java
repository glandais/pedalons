package fr.pedalons.dto.calendar.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Status;
import java.time.Instant;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;

/**
 * One row of an agenda: enough to draw a calendar cell and an agenda card without going back to the
 * server for the ride behind it.
 *
 * <p>The first ten components are the original event identity (who, when, where to navigate). The
 * ones after are the render payload — start place, distance, elevation, thumbnail, status — plus the
 * two "me" fields, {@code registered} and {@code groupName}. Every added component is nullable or
 * defaulted, so a client built against the ten-field shape keeps working.
 *
 * <p>The thumbnail is exposed three ways on purpose: the two themed variants, and {@code
 * thumbnailUrl}, which is one of them. The server cannot know the colour scheme the caller renders
 * in, so collapsing the pair here would hand a dark-mode calendar a light map tile — but a client
 * that shows one picture and has no theme (the ICS feed's consumers, a future widget) should not
 * have to implement the fallback itself.
 *
 * <p>Because {@code registered} and {@code groupName} answer "am <em>I</em> signed up?", any
 * response carrying this DTO is specific to the caller and must not be stored by a shared cache.
 */
@Schema(description = "Calendar event data")
@ValidateSchema
public record CalendarEventDto(
    @Schema(description = "Event ID (TSID)", required = true) String id,
    @Schema(description = "Event title", required = true) String title,
    @Schema(
            description =
                "Event start date/time. For a ride the caller is registered to, the start of"
                    + " their group (RideGroupDto.startAt), which may differ from the ride's own"
                    + " when the group leaves at its own time; the ride's start (RideDto.dateTime)"
                    + " otherwise. Same value as DTSTART in the iCalendar feeds.",
            required = true)
        Instant start,
    @Nullable
        @Schema(
            description =
                "Event end date/time: the end the server computes for a ride (its latest group"
                    + " at its pace, 3 hours when nothing tells) or for a trip stage (its route at"
                    + " its pace, likewise) — the same as RideDto.endDateTime. On an all-day stage"
                    + " it is still that instant: the stage occupies every day up to it. Always"
                    + " after start: 3 hours after it when the computed end is not.")
        Instant end,
    @Schema(description = "Is all-day event", required = true) boolean allDay,
    @Schema(description = "Event type", required = true) CalendarEventType type,
    @Schema(description = "Team slug", required = true) String teamSlug,
    @Schema(description = "Team name", required = true) String teamName,
    @Schema(description = "Entity slug (ride or stage)", required = true) String entitySlug,
    @Nullable @Schema(description = "Parent trip slug (for stages only)") String tripSlug,
    @Nullable
        @Schema(
            description =
                "Name of the meeting place, null when the ride or stage has no start place. The"
                    + " LOCATION of the iCalendar feeds.")
        String startPlaceName,
    @Nullable
        @Schema(
            description = "Distance in meters of the attached route, null when there is no route")
        Float distance,
    @Nullable
        @Schema(
            description =
                "Total elevation gain in meters of the attached route, null when there is no route")
        Float elevationGain,
    @Nullable
        @Schema(
            description =
                "Thumbnail image URL template (contains a {size} placeholder), light variant"
                    + " preferred. Falls back to the route's thumbnail when the ride or stage has"
                    + " none of its own. For a client that renders one picture and does not follow"
                    + " a colour scheme; prefer thumbnailLightUrl/thumbnailDarkUrl otherwise."
                    + " Opaque URL: may carry a query string; substitute {size} only.")
        String thumbnailUrl,
    @Nullable
        @Schema(
            description =
                "Light-scheme thumbnail image URL template (contains a {size} placeholder). Null"
                    + " when the event's picture exists only in a dark variant. Opaque URL: may"
                    + " carry a query string; substitute {size} only.")
        String thumbnailLightUrl,
    @Nullable
        @Schema(
            description =
                "Dark-scheme thumbnail image URL template (contains a {size} placeholder). Null"
                    + " when the event's picture exists only in a light variant. Opaque URL: may"
                    + " carry a query string; substitute {size} only.")
        String thumbnailDarkUrl,
    @Schema(
            description =
                "Whether the current user is registered to this ride, or to the trip this stage"
                    + " belongs to. False for an anonymous caller.",
            required = true)
        boolean registered,
    @Nullable
        @Schema(
            description =
                "Name of the ride group the current user joined. Null when not registered, and"
                    + " always null for trip stages, which have no groups.")
        String groupName,
    @Schema(description = "Publication status of the ride or stage", required = true) Status status,
    @Schema(
            description =
                "IANA zone of the ride or stage, as RideDto.timezone / TripStageDto.timezone: start"
                    + " and end are rendezvous in it. The calendar grid itself stays in the"
                    + " reader's zone.",
            examples = "Europe/Paris",
            required = true)
        String timezone,
    @Nullable
        @Schema(
            description =
                "The distance in meters an agenda card shows to the caller, as"
                    + " RideDto.displayDistance: for a ride, the route of the group they joined"
                    + " when registered, else the route every group rides, else null (groups on"
                    + " different routes, or no route); for a trip stage, the stage's route. Unlike"
                    + " distance, which is only the ride's own route.")
        Float displayDistance,
    @Nullable
        @Schema(
            description =
                "The elevation gain in meters an agenda card shows to the caller, from the same"
                    + " route as displayDistance. Null whenever displayDistance is.")
        Float displayElevationGain) {

  /**
   * An event without display figures — for the ICS writers, which never render a card. The agenda
   * endpoints go through the canonical constructor (docs/LEDGER_*.md API-178).
   */
  public CalendarEventDto(
      String id,
      String title,
      Instant start,
      @Nullable Instant end,
      boolean allDay,
      CalendarEventType type,
      String teamSlug,
      String teamName,
      String entitySlug,
      @Nullable String tripSlug,
      @Nullable String startPlaceName,
      @Nullable Float distance,
      @Nullable Float elevationGain,
      @Nullable String thumbnailUrl,
      @Nullable String thumbnailLightUrl,
      @Nullable String thumbnailDarkUrl,
      boolean registered,
      @Nullable String groupName,
      Status status,
      String timezone) {
    this(
        id,
        title,
        start,
        end,
        allDay,
        type,
        teamSlug,
        teamName,
        entitySlug,
        tripSlug,
        startPlaceName,
        distance,
        elevationGain,
        thumbnailUrl,
        thumbnailLightUrl,
        thumbnailDarkUrl,
        registered,
        groupName,
        status,
        timezone,
        null,
        null);
  }

  /**
   * Whether the ride or stage is over: its end, or its start when it has none, has passed. Derived
   * at serialisation rather than a
   * component, so that no caller has to compute it (docs/LEDGER_*.md API-16).
   */
  @JsonProperty("finished")
  @Schema(
      description =
          "Whether the ride or stage is over, computed by the server when the response is built:"
              + " its end (or its start, when it has no end) has passed. Independent of status.",
      required = true)
  public boolean finished() {
    return (end != null ? end : start).isBefore(Instant.now());
  }
}
