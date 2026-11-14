package fr.pedalons.infrastructure.routedetails;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.ws.rs.ProcessingException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

/**
 * The one place that decides whether {@code options.edges} is sent (docs/LEDGER_*.md API-198, lot
 * 1): the gateway, from its cached capabilities. A real (caching) gateway on the fake client.
 */
class RouteDetailsGatewayEdgesTest {

  private static final ObjectMapper MAPPER = new ObjectMapper();

  private static final RouteDetailsOptions HD_WITH_EDGES =
      RouteDetailsOptions.of(RouteDetailsProfile.FULL, false).withEdges(true);

  /** Caches its capabilities like production does, the answers coming from the fake. */
  private static RouteDetailsGateway gateway(boolean capabilitiesUnreachable) {
    FakeRouteDetailsClient fake = new FakeRouteDetailsClient();
    RouteDetailsClient client =
        new RouteDetailsClient() {
          @Override
          public RouteDetailsResponse routeDetails(RouteDetailsRequest request) {
            return fake.routeDetails(request);
          }

          @Override
          public RouteDetailsCapabilities capabilities() {
            if (capabilitiesUnreachable) {
              throw new ProcessingException("connection refused");
            }
            return fake.capabilities();
          }
        };
    return new RouteDetailsGateway() {
      @Override
      RouteDetailsClient client(RouteDetailsProfile profile) {
        return client;
      }
    };
  }

  @AfterEach
  void reset() {
    FakeRouteDetailsClient.reset();
  }

  private static void call(RouteDetailsGateway gateway, RouteDetailsOptions options) {
    double[][] line = RouteSlicerTest.meridian(30, 90);
    gateway.details(line[0], line[1], options);
  }

  private static JsonNode sentOptions() {
    return MAPPER.valueToTree(FakeRouteDetailsClient.lastOptions);
  }

  @Test
  void withoutTheOption_noEdgesKeyIsSent() {
    call(gateway(false), RouteDetailsOptions.of(RouteDetailsProfile.FULL, false));
    assertFalse(sentOptions().has("edges"));
  }

  @Test
  void asked_atApi17_theOptionIsSent_andEdgesComeBack() {
    RouteDetailsGateway gateway = gateway(false);
    double[][] line = RouteSlicerTest.meridian(30, 90);
    RouteDetailsResponse r = gateway.details(line[0], line[1], HD_WITH_EDGES);
    assertTrue(sentOptions().get("edges").asBoolean());
    assertNotNull(r.edges());
    assertFalse(r.edges().isEmpty());
    assertTrue(gateway.supportsEdges());
  }

  @Test
  void asked_atApi16_theOptionIsLeftOut_noMatterWhat() {
    FakeRouteDetailsClient.apiVersion = "1.6";
    RouteDetailsGateway gateway = gateway(false);
    double[][] line = RouteSlicerTest.meridian(30, 90);
    RouteDetailsResponse r = gateway.details(line[0], line[1], HD_WITH_EDGES);
    assertFalse(sentOptions().has("edges"), "an unknown key would be a 400");
    assertNull(r.edges());
    assertFalse(gateway.supportsEdges());
  }

  @Test
  void asked_whileTheServiceCannotBeReached_theOptionIsLeftOut() {
    RouteDetailsGateway gateway = gateway(true);
    assertFalse(gateway.supportsEdges());
    call(gateway, HD_WITH_EDGES);
    assertFalse(sentOptions().has("edges"));
  }

  @Test
  void aSlicedCall_keepsTheOption() {
    FakeRouteDetailsClient.limits = new RouteDetailsCapabilities.Limits(200, 5_000);
    RouteDetailsGateway gateway = gateway(false);
    double[][] line = RouteSlicerTest.meridian(401, 50);
    gateway.details(line[0], line[1], HD_WITH_EDGES);
    assertTrue(FakeRouteDetailsClient.REQUESTS.size() > 1);
    assertTrue(FakeRouteDetailsClient.REQUESTS.stream().allMatch(r -> r.options().wantsEdges()));
  }

  @Test
  void a400OnARequestWithEdges_dropsTheCachedCapabilities() {
    RouteDetailsGateway gateway = gateway(false);
    call(gateway, HD_WITH_EDGES);
    assertTrue(gateway.supportsEdges(), "1.7 cached");

    // The image behind the service is rolled back within the cache hour
    FakeRouteDetailsClient.apiVersion = "1.6";
    assertTrue(gateway.supportsEdges(), "still cached: the call below is sent with edges");
    RouteDetailsException e =
        assertThrows(RouteDetailsException.class, () -> call(gateway, HD_WITH_EDGES));
    assertEquals(400, e.status());

    assertFalse(gateway.supportsEdges(), "fetched again, and no longer asked");
    call(gateway, HD_WITH_EDGES);
    assertFalse(sentOptions().has("edges"));
  }
}
