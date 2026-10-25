package fr.pedalons.infrastructure.json;

import io.quarkus.jackson.JsonFactoryBuilderCustomizer;
import jakarta.inject.Singleton;
import tools.jackson.core.StreamReadConstraints;
import tools.jackson.core.StreamWriteConstraints;
import tools.jackson.core.json.JsonFactoryBuilder;

/**
 * Jackson 2.22 allowed 1000 levels of nesting, Jackson 3 allows 500: without this, a feedback
 * context between 501 and 1000 levels deep would start being refused (docs/LEDGER_*.md API-144).
 */
@Singleton
public class PedalonsJsonFactoryConfig implements JsonFactoryBuilderCustomizer {
  @Override
  public void customize(JsonFactoryBuilder builder) {
    builder.streamReadConstraints(StreamReadConstraints.builder().maxNestingDepth(1000).build());
    builder.streamWriteConstraints(StreamWriteConstraints.builder().maxNestingDepth(1000).build());
  }
}
