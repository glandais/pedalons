package fr.pedalons.infrastructure.json;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.quarkus.jackson.JsonMapperBuilderCustomizer;
import jakarta.inject.Singleton;
import org.geolatte.geom.json.jackson3.GeolatteGeomModule;
import tools.jackson.core.json.JsonWriteFeature;
import tools.jackson.databind.MapperFeature;
import tools.jackson.databind.cfg.DateTimeFeature;
import tools.jackson.databind.cfg.EnumFeature;
import tools.jackson.databind.cfg.JsonNodeFeature;
import tools.jackson.databind.json.JsonMapper;

/**
 * The REST mapper. Jackson 3 changed some defaults; those with a {@code quarkus.jackson.*}
 * property are set in application.properties, the others are restored here.
 *
 * <p>See docs/LEDGER_*.md API-134.
 */
@Singleton
public class PedalonsJacksonConfig implements JsonMapperBuilderCustomizer {
  @Override
  public void customize(JsonMapper.Builder builder) {
    builder.addModule(new GeolatteGeomModule());
    // Jackson 2's setDefaultPropertyInclusion(NON_NULL) set value AND content inclusion: null map
    // values were dropped too.
    builder.changeDefaultPropertyInclusion(
        v ->
            v.withValueInclusion(JsonInclude.Include.NON_NULL)
                .withContentInclusion(JsonInclude.Include.NON_NULL));
    // Jackson 3 defaults with no quarkus.jackson.* property, back to Jackson 2's.
    // 3.x sorts non-creator properties: setter beans and @Getter DTO extras would reorder.
    builder.disable(MapperFeature.SORT_PROPERTIES_ALPHABETICALLY);
    builder.disable(MapperFeature.FIX_FIELD_NAME_UPPER_CASE_PREFIX);
    builder.disable(MapperFeature.ALLOW_VOID_VALUED_PROPERTIES);
    // 3.x reads a java.time.Month index as one-based; none of our DTOs carries a Month today.
    builder.disable(DateTimeFeature.ONE_BASED_MONTHS);
    // 3.x uses toString(); none of our enums overrides it today.
    builder.disable(
        EnumFeature.WRITE_ENUMS_USING_TO_STRING, EnumFeature.READ_ENUMS_USING_TO_STRING);
    // valueToTree(BigDecimal 1.50) was 1.5; it feeds JSONB JsonNode columns.
    builder.enable(JsonNodeFeature.STRIP_TRAILING_BIGDECIMAL_ZEROES);
    // 2.x wrote emoji as surrogate escapes in UTF-8 bodies; also keeps WeatherEtag bytes stable.
    builder.disable(JsonWriteFeature.COMBINE_UNICODE_SURROGATES_IN_UTF8);
  }
}
