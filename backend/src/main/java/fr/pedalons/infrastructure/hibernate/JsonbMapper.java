package fr.pedalons.infrastructure.hibernate;

import fr.pedalons.infrastructure.json.Jackson2Defaults;
import java.lang.reflect.Type;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import org.hibernate.HibernateException;
import tools.jackson.core.JacksonException;
import tools.jackson.core.JsonGenerator;
import tools.jackson.core.JsonParser;
import tools.jackson.core.JsonToken;
import tools.jackson.core.StreamReadConstraints;
import tools.jackson.core.StreamWriteConstraints;
import tools.jackson.core.json.JsonFactory;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.MapperFeature;
import tools.jackson.databind.SerializationContext;
import tools.jackson.databind.SerializationFeature;
import tools.jackson.databind.cfg.DateTimeFeature;
import tools.jackson.databind.deser.std.StdDeserializer;
import tools.jackson.databind.exc.InvalidFormatException;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.module.SimpleModule;
import tools.jackson.databind.ser.std.StdSerializer;

/**
 * The only {@link JsonMapper} of the JSONB columns. It reproduces, byte for byte, the mapper that
 * hypersistence-utils used for {@code JsonBinaryType}: Jackson 2 defaults (as hypersistence-utils
 * wrote them), restored on Jackson 3 one feature at a time — dates as timestamps, nulls written,
 * unknown properties refused, nesting up to 1000 — because a rolling deploy makes the previous
 * release read what this one writes (docs/LEDGER_*.md API-220). Never the Quarkus/REST mapper
 * ({@code PedalonsJacksonConfig} adds NON_NULL and disables timestamps). No module is discovered
 * from the classpath, so that a jar added later cannot silently change what is stored. {@code
 * JsonbMapperTest} is the gate for any change here.
 */
public final class JsonbMapper {

  public static final JsonbMapper INSTANCE = new JsonbMapper();

  private final JsonMapper mapper =
      // Jackson 2 defaults that Jackson 3 changed, restored one by one: what is stored must not
      // move. Those shared with the REST mapper first, then the JSONB-only ones.
      Jackson2Defaults.apply(
              JsonMapper.builder(
                  JsonFactory.builder()
                      .streamReadConstraints(
                          StreamReadConstraints.builder().maxNestingDepth(1000).build())
                      .streamWriteConstraints(
                          StreamWriteConstraints.builder().maxNestingDepth(1000).build())
                      .build()))
          .enable(DateTimeFeature.WRITE_DATES_AS_TIMESTAMPS)
          .enable(DateTimeFeature.WRITE_DURATIONS_AS_TIMESTAMPS)
          .enable(MapperFeature.USE_GETTERS_AS_SETTERS)
          .enable(MapperFeature.ALLOW_FINAL_FIELDS_AS_MUTATORS)
          .enable(MapperFeature.DEFAULT_VIEW_INCLUSION)
          .enable(SerializationFeature.FAIL_ON_EMPTY_BEANS)
          // 3.x default is false: stored records keep @JsonIgnoreProperties(ignoreUnknown = true)
          .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
          .disable(DeserializationFeature.FAIL_ON_NULL_FOR_PRIMITIVES)
          .disable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
          .addModule(
              new SimpleModule("jsonb-offset-date-time")
                  .addSerializer(OffsetDateTime.class, new OffsetDateTimeSerializer())
                  .addDeserializer(OffsetDateTime.class, new OffsetDateTimeDeserializer()))
          .build();

  private JsonbMapper() {}

  public String toString(Object value) {
    if (value instanceof String str) {
      return str;
    }
    try {
      return mapper.writeValueAsString(value);
    } catch (JacksonException e) {
      throw new HibernateException(
          new IllegalArgumentException(
              "The given Json object value cannot be transformed to a String", e));
    }
  }

  public <T> T fromString(String string, Class<T> clazz) {
    try {
      return mapper.readValue(string, clazz);
    } catch (JacksonException e) {
      throw new HibernateException(
          new IllegalArgumentException(
              "The given string value cannot be transformed to Json object", e));
    }
  }

  @SuppressWarnings("unchecked")
  public <T> T fromString(String string, Type type) {
    try {
      return (T) mapper.readValue(string, mapper.getTypeFactory().constructType(type));
    } catch (JacksonException e) {
      throw new HibernateException(
          new IllegalArgumentException(
              // never the document itself: megabytes of track, or a user's feedback, would reach
              // the logs and the error capture
              "A stored document of "
                  + string.length()
                  + " chars cannot be transformed to "
                  + type.getTypeName(),
              e));
    }
  }

  public JsonNode toJsonNode(String value) {
    try {
      return mapper.readTree(value);
    } catch (JacksonException e) {
      throw new HibernateException(new IllegalArgumentException(e));
    }
  }

  private static final class OffsetDateTimeSerializer extends StdSerializer<OffsetDateTime> {
    OffsetDateTimeSerializer() {
      super(OffsetDateTime.class);
    }

    @Override
    public void serialize(OffsetDateTime value, JsonGenerator gen, SerializationContext provider) {
      gen.writeString(DateTimeFormatter.ISO_OFFSET_DATE_TIME.format(value));
    }
  }

  private static final class OffsetDateTimeDeserializer extends StdDeserializer<OffsetDateTime> {
    OffsetDateTimeDeserializer() {
      super(OffsetDateTime.class);
    }

    /**
     * What the serializer writes (an ISO string), or seconds since the epoch as hypersistence also
     * accepted, milliseconds kept. A malformed string fails with its own parse error.
     */
    @Override
    public OffsetDateTime deserialize(JsonParser p, DeserializationContext ctxt) {
      if (p.hasToken(JsonToken.VALUE_STRING)) {
        String text = p.getString();
        try {
          return OffsetDateTime.parse(text, DateTimeFormatter.ISO_OFFSET_DATE_TIME);
        } catch (DateTimeParseException e) {
          InvalidFormatException failure =
              InvalidFormatException.from(
                  p, "Not an ISO offset date-time: " + e.getMessage(), text, OffsetDateTime.class);
          failure.initCause(e);
          throw failure;
        }
      }
      if (p.hasToken(JsonToken.VALUE_NUMBER_INT) || p.hasToken(JsonToken.VALUE_NUMBER_FLOAT)) {
        long millis = p.getDecimalValue().movePointRight(3).longValue();
        return OffsetDateTime.ofInstant(Instant.ofEpochMilli(millis), ZoneOffset.UTC);
      }
      return (OffsetDateTime) ctxt.handleUnexpectedToken(OffsetDateTime.class, p);
    }
  }
}
