package fr.pedalons.infrastructure.json;

import tools.jackson.core.json.JsonWriteFeature;
import tools.jackson.databind.MapperFeature;
import tools.jackson.databind.cfg.DateTimeFeature;
import tools.jackson.databind.cfg.EnumFeature;
import tools.jackson.databind.cfg.JsonNodeFeature;
import tools.jackson.databind.json.JsonMapper;

/**
 * The Jackson 2 defaults Jackson 3 changed and that both the REST mapper ({@link
 * PedalonsJacksonConfig}) and the JSONB mapper ({@code JsonbMapper}) restore, in one place so that
 * the two cannot drift when a later 3.x flips another default (docs/LEDGER_*.md API-220).
 */
public final class Jackson2Defaults {
  private Jackson2Defaults() {}

  public static JsonMapper.Builder apply(JsonMapper.Builder builder) {
    return builder
        // 3.x sorts non-creator properties: setter beans and @Getter DTO extras would reorder
        .disable(MapperFeature.SORT_PROPERTIES_ALPHABETICALLY)
        .disable(MapperFeature.FIX_FIELD_NAME_UPPER_CASE_PREFIX)
        .disable(MapperFeature.ALLOW_VOID_VALUED_PROPERTIES)
        // 3.x reads a java.time.Month index as one-based
        .disable(DateTimeFeature.ONE_BASED_MONTHS)
        // 3.x uses toString(); enums are written and read by name()
        .disable(EnumFeature.WRITE_ENUMS_USING_TO_STRING, EnumFeature.READ_ENUMS_USING_TO_STRING)
        // valueToTree(BigDecimal 1.50) was 1.5
        .enable(JsonNodeFeature.STRIP_TRAILING_BIGDECIMAL_ZEROES)
        // 2.x wrote characters outside the BMP as surrogate escapes in UTF-8 output
        .disable(JsonWriteFeature.COMBINE_UNICODE_SURROGATES_IN_UTF8);
  }
}
