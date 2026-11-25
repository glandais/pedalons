package fr.pedalons.infrastructure.hibernate;

import io.quarkus.hibernate.orm.JsonFormat;
import io.quarkus.hibernate.orm.PersistenceUnitExtension;
import java.lang.reflect.Type;
import org.hibernate.type.descriptor.WrapperOptions;
import org.hibernate.type.descriptor.java.JavaType;
import org.hibernate.type.format.FormatMapper;

/**
 * The persistence unit's JSON {@link FormatMapper}: every {@code @JdbcTypeCode(SqlTypes.JSON)}
 * column goes through {@link JsonbMapper}. Keep this class non-final and without an explicit scope
 * (the bean-defining annotation makes it {@code @ApplicationScoped}); {@code JsonbMappingTest}
 * guards that it is the mapper Hibernate actually uses.
 */
@JsonFormat
@PersistenceUnitExtension
public class JsonbFormatMapper implements FormatMapper {

  @Override
  @SuppressWarnings("unchecked")
  public <T> T fromString(CharSequence charSequence, JavaType<T> javaType, WrapperOptions options) {
    Type type = javaType.getJavaType();
    if (type == String.class) {
      return (T) charSequence.toString();
    }
    return JsonbMapper.INSTANCE.fromString(charSequence.toString(), type);
  }

  @Override
  public <T> String toString(T value, JavaType<T> javaType, WrapperOptions options) {
    return value instanceof String str ? str : JsonbMapper.INSTANCE.toString(value);
  }
}
