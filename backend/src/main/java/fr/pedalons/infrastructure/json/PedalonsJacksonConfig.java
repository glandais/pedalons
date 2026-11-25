package fr.pedalons.infrastructure.json;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.quarkus.jackson.JsonMapperBuilderCustomizer;
import jakarta.inject.Singleton;
import org.geolatte.geom.json.jackson3.GeolatteGeomModule;
import tools.jackson.databind.json.JsonMapper;

/**
 * The REST mapper. Jackson 3 changed some defaults; those that change what a client receives are
 * restored here. Jackson 3's stricter reading (null for a primitive, trailing tokens) is kept;
 * third-party JSON is read by {@link ExternalJsonMapper}.
 *
 * <p>See docs/LEDGER_*.md API-220.
 */
@Singleton
public class PedalonsJacksonConfig implements JsonMapperBuilderCustomizer {
  @Override
  public void customize(JsonMapper.Builder builder) {
    builder.addModule(new GeolatteGeomModule());
    // Jackson 2's setDefaultPropertyInclusion(NON_NULL) set value AND content inclusion: null map
    // values were dropped too.
    builder.changeDefaultPropertyInclusion(v ->
        v.withValueInclusion(JsonInclude.Include.NON_NULL)
            .withContentInclusion(JsonInclude.Include.NON_NULL));
    // Jackson 3 output defaults, back to Jackson 2's. The surrogate escapes also keep WeatherEtag
    // bytes stable; valueToTree feeds JSONB JsonNode columns.
    Jackson2Defaults.apply(builder);
  }
}
