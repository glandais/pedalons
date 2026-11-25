package fr.pedalons.infrastructure.gps;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

class GpsJsonTest {

  private static JsonNode json(String text) {
    return new JsonMapper().readTree(text);
  }

  @Test
  void string_isNullWhenAbsentNullOrAContainer() {
    JsonNode root = json("{\"a\":\"x\",\"n\":12,\"z\":null,\"o\":{},\"l\":[]}");

    assertEquals("x", GpsJson.string(root, "a"));
    assertEquals("12", GpsJson.string(root, "n"));
    assertNull(GpsJson.string(root, "z"));
    assertNull(GpsJson.string(root, "o"));
    assertNull(GpsJson.string(root, "l"));
    assertNull(GpsJson.string(root, "missing"));
  }

  @Test
  void longValue_readsNumbersFractionsAndNumericStrings() {
    JsonNode root =
        json("{\"i\":3600,\"f\":3.7,\"s\":\" 3600 \",\"bad\":\"soon\",\"z\":null,\"o\":{}}");

    assertEquals(3600L, GpsJson.longValue(root, "i"));
    assertEquals(3L, GpsJson.longValue(root, "f"));
    assertEquals(3600L, GpsJson.longValue(root, "s"));
    assertNull(GpsJson.longValue(root, "bad"));
    assertNull(GpsJson.longValue(root, "z"));
    assertNull(GpsJson.longValue(root, "o"));
    assertNull(GpsJson.longValue(root, "missing"));
  }
}
