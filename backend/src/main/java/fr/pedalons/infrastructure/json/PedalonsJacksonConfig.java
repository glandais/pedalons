package fr.pedalons.infrastructure.json;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.quarkus.jackson.JsonMapperBuilderCustomizer;
import jakarta.inject.Singleton;
import org.geolatte.geom.json.jackson3.GeolatteGeomModule;
import tools.jackson.databind.json.JsonMapper;

@Singleton
public class PedalonsJacksonConfig implements JsonMapperBuilderCustomizer {
  @Override
  public void customize(JsonMapper.Builder builder) {
    builder.addModule(new GeolatteGeomModule());
    builder.changeDefaultPropertyInclusion(v -> v.withValueInclusion(JsonInclude.Include.NON_NULL));
  }
}
