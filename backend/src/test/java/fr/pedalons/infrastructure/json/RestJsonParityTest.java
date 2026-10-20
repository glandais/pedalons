package fr.pedalons.infrastructure.json;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/** Pins the REST mapper to the Jackson 2 / Quarkus 3.40 output (ledger API-134). */
@QuarkusTest
class RestJsonParityTest {

  @Inject ObjectMapper mapper;

  public record Prim(int count, boolean flag, String name) {}

  public static class Bean {
    private String b;
    private final List<String> items = new ArrayList<>();
    private String a;

    public String getB() {
      return b;
    }

    public void setB(String b) {
      this.b = b;
    }

    public List<String> getItems() {
      return items;
    }

    public String getA() {
      return a;
    }

    public void setA(String a) {
      this.a = a;
    }
  }

  @Test
  void mapIsWrittenLikeJackson2() {
    Map<String, Object> map = new LinkedHashMap<>();
    map.put("dropped", null);
    map.put("instant", Instant.parse("2026-10-20T08:00:00Z"));
    map.put("duration", Duration.ofSeconds(90, 5));
    map.put("text", "vélo 🚴");
    String json = new String(mapper.writeValueAsBytes(map), StandardCharsets.UTF_8);
    assertEquals(
        "{\"instant\":\"2026-10-20T08:00:00Z\",\"duration\":90.000000005,\"text\":\"vélo"
            + " \\uD83D\\uDEB4\"}",
        json);
  }

  @Test
  void beanKeepsDeclarationOrder() {
    Bean bean = new Bean();
    bean.setB("B");
    bean.getItems().add("i");
    bean.setA("A");
    assertEquals("{\"b\":\"B\",\"items\":[\"i\"],\"a\":\"A\"}", mapper.writeValueAsString(bean));
  }

  @Test
  void bigDecimalTreeStripsTrailingZeroes() {
    assertEquals("{\"x\":1.5}", mapper.valueToTree(Map.of("x", new BigDecimal("1.50"))).toString());
  }

  @Test
  void lenientReads() {
    assertEquals(
        new Prim(0, false, "x"),
        mapper.readValue(
            "{\"count\":null,\"flag\":null,\"name\":\"x\",\"unknown\":1} {}", Prim.class));
    assertEquals(List.of("i"), mapper.readValue("{\"items\":[\"i\"]}", Bean.class).getItems());
  }

  @Test
  void nestingUpTo1000IsAccepted() {
    assertTrue(mapper.readTree("[".repeat(800) + "]".repeat(800)).isArray());
  }
}
