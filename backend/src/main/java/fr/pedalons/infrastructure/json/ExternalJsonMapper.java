package fr.pedalons.infrastructure.json;

import jakarta.enterprise.inject.Produces;
import jakarta.inject.Singleton;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

/**
 * The mapper for JSON we do not write: the application's mapper, with Jackson 2's tolerant reading
 * back. Jackson 3 refuses an explicit {@code null} for a primitive and content after the document;
 * that strictness is kept for our own clients' requests ({@link PedalonsJacksonConfig}), not for a
 * third party, whose one {@code null} would otherwise fail a whole migration or generation.
 *
 * <p>See docs/LEDGER_*.md API-220.
 */
@Singleton
public class ExternalJsonMapper {

  /** For the pure error parsers, which only read trees. */
  public static final ObjectMapper TREES = lenient(new JsonMapper());

  @Produces
  @Singleton
  @ExternalJson
  ObjectMapper external(ObjectMapper application) {
    return lenient(application);
  }

  /** {@code mapper} reading like Jackson 2: null as the primitive's default, trailing ignored. */
  public static ObjectMapper lenient(ObjectMapper mapper) {
    return mapper
        .rebuild()
        .disable(
            DeserializationFeature.FAIL_ON_NULL_FOR_PRIMITIVES,
            DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
        .build();
  }
}
