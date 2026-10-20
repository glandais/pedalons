package fr.pedalons.infrastructure.hibernate;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.deser.std.StdDeserializer;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.databind.ser.std.StdSerializer;
import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.fasterxml.jackson.module.paramnames.ParameterNamesModule;
import java.io.IOException;
import java.lang.reflect.Type;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Date;
import org.hibernate.HibernateException;

/**
 * The only {@link ObjectMapper} of the JSONB columns. It reproduces, byte for byte, the mapper that
 * hypersistence-utils used for {@code JsonBinaryType} (Jackson 2 defaults: dates as timestamps,
 * nulls written, unknown properties refused), because a rolling deploy makes the previous release
 * read what this one writes. Never the Quarkus/REST mapper ({@code PedalonsJacksonConfig} adds
 * NON_NULL and disables timestamps). Modules are registered explicitly so that a jar added later
 * cannot silently change what is stored. {@code JsonbMapperTest} is the gate for any change here,
 * including a move to Jackson 3.
 */
public final class JsonbMapper {

  public static final JsonbMapper INSTANCE = new JsonbMapper();

  private final ObjectMapper mapper =
      new ObjectMapper()
          .registerModule(new JavaTimeModule())
          .registerModule(new Jdk8Module())
          .registerModule(new ParameterNamesModule())
          .registerModule(
              new SimpleModule()
                  .addSerializer(OffsetDateTime.class, new OffsetDateTimeSerializer())
                  .addDeserializer(OffsetDateTime.class, new OffsetDateTimeDeserializer()));

  private JsonbMapper() {}

  public String toString(Object value) {
    if (value instanceof String str) {
      return str;
    }
    try {
      return mapper.writeValueAsString(value);
    } catch (JsonProcessingException e) {
      throw new HibernateException(
          new IllegalArgumentException(
              "The given Json object value cannot be transformed to a String", e));
    }
  }

  public <T> T fromString(String string, Class<T> clazz) {
    try {
      return mapper.readValue(string, clazz);
    } catch (JsonProcessingException e) {
      throw new HibernateException(
          new IllegalArgumentException(
              "The given string value cannot be transformed to Json object", e));
    }
  }

  @SuppressWarnings("unchecked")
  public <T> T fromString(String string, Type type) {
    try {
      return (T) mapper.readValue(string, mapper.getTypeFactory().constructType(type));
    } catch (JsonProcessingException e) {
      throw new HibernateException(
          new IllegalArgumentException(
              "The given string value: " + string + " cannot be transformed to Json object", e));
    }
  }

  public JsonNode toJsonNode(String value) {
    try {
      return mapper.readTree(value);
    } catch (IOException e) {
      throw new HibernateException(new IllegalArgumentException(e));
    }
  }

  private static final class OffsetDateTimeSerializer extends StdSerializer<OffsetDateTime> {
    OffsetDateTimeSerializer() {
      super(OffsetDateTime.class);
    }

    @Override
    public void serialize(
        OffsetDateTime value,
        com.fasterxml.jackson.core.JsonGenerator gen,
        com.fasterxml.jackson.databind.SerializerProvider provider)
        throws IOException {
      gen.writeString(DateTimeFormatter.ISO_OFFSET_DATE_TIME.format(value));
    }
  }

  private static final class OffsetDateTimeDeserializer extends StdDeserializer<OffsetDateTime> {
    OffsetDateTimeDeserializer() {
      super(OffsetDateTime.class);
    }

    @Override
    public OffsetDateTime deserialize(JsonParser jsonParser, DeserializationContext ctxt)
        throws IOException {
      try {
        return OffsetDateTime.parse(jsonParser.getText(), DateTimeFormatter.ISO_OFFSET_DATE_TIME);
      } catch (Exception e) {
        return OffsetDateTime.ofInstant(
            new Date((long) jsonParser.getDoubleValue() * 1000).toInstant(), ZoneOffset.UTC);
      }
    }
  }
}
