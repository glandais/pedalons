package fr.pedalons.infrastructure.valhalla;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.ws.rs.core.Response;
import java.io.IOException;

/** Reading the errors of the Valhalla protocol, as served by Stadia Maps and osm-surface. */
public final class ValhallaErrors {

  private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

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
    } catch (RuntimeException | IOException ex) {
      // Empty, truncated or HTML body: the status alone decides.
      return -1;
    }
  }
}
