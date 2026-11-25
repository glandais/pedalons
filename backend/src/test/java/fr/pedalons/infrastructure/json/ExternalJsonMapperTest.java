package fr.pedalons.infrastructure.json;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.exc.MismatchedInputException;
import tools.jackson.databind.json.JsonMapper;

/** Third-party JSON is read like Jackson 2 did (docs/LEDGER_*.md API-220). */
class ExternalJsonMapperTest {

  record Map(double length, int count) {}

  private static final ObjectMapper STRICT = new JsonMapper();
  private static final ObjectMapper LENIENT = ExternalJsonMapper.lenient(STRICT);

  @Test
  void nullForPrimitive_isTheDefault() {
    Map map = LENIENT.readValue("{\"length\":null,\"count\":null}", Map.class);

    assertEquals(0.0, map.length());
    assertEquals(0, map.count());
  }

  @Test
  void nullForPrimitive_stillFailsOnTheStrictMapper() {
    assertThrows(
        MismatchedInputException.class,
        () -> STRICT.readValue("{\"length\":null,\"count\":1}", Map.class));
  }

  @Test
  void trailingContent_isIgnored() {
    assertEquals("x", LENIENT.readTree("{\"code\":\"x\"} trailing").get("code").asString());
    assertEquals(
        "x", ExternalJsonMapper.TREES.readTree("{\"code\":\"x\"}\n{}").get("code").asString());
  }
}
