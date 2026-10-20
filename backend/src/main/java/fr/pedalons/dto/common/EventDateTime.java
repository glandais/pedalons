package fr.pedalons.dto.common;

import com.fasterxml.jackson.annotation.JsonValue;
import fr.pedalons.dto.validation.ValidateSchema;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Objects;
import org.eclipse.microprofile.openapi.annotations.enums.SchemaType;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.jspecify.annotations.Nullable;
import tools.jackson.core.JsonGenerator;
import tools.jackson.core.JsonParser;
import tools.jackson.core.JsonToken;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.SerializationContext;
import tools.jackson.databind.ValueDeserializer;
import tools.jackson.databind.ValueSerializer;
import tools.jackson.databind.annotation.JsonDeserialize;
import tools.jackson.databind.annotation.JsonSerialize;

/**
 * A rendezvous date as a request carries it: a wall time without offset ({@code
 * 2026-10-11T08:00:00}), read by the backend in the zone it resolves for the entity — the start
 * place's, else the route's, else the team's (docs/LEDGER_*.md API-60).
 *
 * <p>An instant with {@code Z} or an offset — what the SPA sent before — is refused with a 400
 * since version N+1 (docs/plans/archive/2026-10-06-event-timezones.md §8): the client never decides the
 * zone of a rendezvous.
 *
 * <p>Deliberately not a {@link LocalDateTime} field: Jackson's lenient {@code
 * LocalDateTimeDeserializer} silently drops a trailing {@code Z} (06:30Z would be read as 06:30
 * wall time) where this refuses it. And the schema is a plain string, without {@code format:
 * date-time}, which would announce an offset.
 */
@Schema(
    type = SchemaType.STRING,
    implementation = String.class,
    description =
        "Wall time without offset (2026-10-11T08:00:00), in the zone the backend resolves for the"
            + " entity. An instant with Z or an offset is refused with a 400.",
    examples = "2026-10-11T08:00:00")
@ValidateSchema
@JsonSerialize(using = EventDateTime.Serializer.class)
@JsonDeserialize(using = EventDateTime.Deserializer.class)
public final class EventDateTime {

  private final LocalDateTime local;

  private EventDateTime(LocalDateTime local) {
    this.local = local;
  }

  /** A wall time, read in the entity's zone. */
  public static EventDateTime local(LocalDateTime local) {
    return new EventDateTime(Objects.requireNonNull(local));
  }

  public static @Nullable EventDateTime localNullable(@Nullable LocalDateTime local) {
    return local == null ? null : local(local);
  }

  /**
   * Parses a wall time.
   *
   * @throws DateTimeException when the text is not one — an instant with {@code Z} or an offset
   *     included
   */
  public static EventDateTime parse(String text) {
    return local(LocalDateTime.parse(text.trim(), DateTimeFormatter.ISO_LOCAL_DATE_TIME));
  }

  /** The wall time itself. */
  public LocalDateTime wallTime() {
    return local;
  }

  /**
   * The instant this designates in {@code zone}, as {@link ZonedDateTime#of(LocalDateTime, ZoneId)}
   * resolves it — shifted by the length of the gap when it does not exist, at the earlier offset
   * when it exists twice (plan §6).
   */
  public Instant toInstant(ZoneId zone) {
    return local.atZone(zone).toInstant();
  }

  public static @Nullable Instant toInstant(@Nullable EventDateTime value, ZoneId zone) {
    return value == null ? null : value.toInstant(zone);
  }

  /**
   * The wire form. {@code @JsonValue} on top of the {@link Serializer}: it lives in
   * jackson-annotations, which every Jackson reads. RestAssured 6 picks Jackson 3 and does see the
   * databind annotations, so this is belt and braces for any other mapper that ignores them.
   */
  @JsonValue
  @Override
  public String toString() {
    return local.toString();
  }

  @Override
  public boolean equals(Object o) {
    return o instanceof EventDateTime other && local.equals(other.local);
  }

  @Override
  public int hashCode() {
    return local.hashCode();
  }

  static final class Serializer extends ValueSerializer<EventDateTime> {
    @Override
    public void serialize(EventDateTime value, JsonGenerator gen, SerializationContext provider) {
      gen.writeString(value.toString());
    }
  }

  static final class Deserializer extends ValueDeserializer<EventDateTime> {
    @Override
    public EventDateTime deserialize(JsonParser p, DeserializationContext ctxt) {
      if (p.currentToken() != JsonToken.VALUE_STRING) {
        return (EventDateTime) ctxt.handleUnexpectedToken(EventDateTime.class, p);
      }
      String text = p.getString();
      try {
        return parse(text);
      } catch (DateTimeException e) {
        // An InvalidFormatException, so a 400 like any other malformed body.
        throw ctxt.weirdStringException(
            text,
            EventDateTime.class,
            "expected a wall time without offset, such as 2026-10-11T08:00:00");
      }
    }
  }
}
