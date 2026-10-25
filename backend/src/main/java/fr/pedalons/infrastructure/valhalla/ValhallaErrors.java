package fr.pedalons.infrastructure.valhalla;

import jakarta.ws.rs.core.Response;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

/** Reading the errors of the Valhalla protocol, as served by Stadia Maps. */
public final class ValhallaErrors {

  // Jackson 3 refuses trailing content, Jackson 2 read past it (docs/LEDGER_*.md API-144).
  private static final ObjectMapper OBJECT_MAPPER =
      JsonMapper.builder().disable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS).build();

  private ValhallaErrors() {}

  /** The Valhalla {@code error_code} of an error body, or -1 when it is empty or not JSON. */
  public static int errorCode(Response response) {
    try {
      if (!response.hasEntity()) {
        return -1;
      }
      String body = response.readEntity(String.class);
      if (body == null || body.isBlank()) {
        return -1;
      }
      JsonNode code = OBJECT_MAPPER.readTree(body).path("error_code");
      return code.isInt() ? code.asInt() : -1;
    } catch (RuntimeException ex) {
      // Empty, truncated or HTML body: the status alone decides.
      return -1;
    }
  }
}
