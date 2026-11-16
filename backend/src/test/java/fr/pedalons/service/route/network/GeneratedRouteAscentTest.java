package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.infrastructure.routedetails.RouteDetailsGateway;
import fr.pedalons.infrastructure.routedetails.RouteDetailsOptions;
import fr.pedalons.infrastructure.routedetails.RouteDetailsProfile;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse;
import fr.pedalons.infrastructure.routedetails.RouteDetailsSection;
import fr.pedalons.infrastructure.valhalla.Polyline6Encoder;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;

/** The gain of each proposal from the fast profile, null for a route whose call did not come back. */
class GeneratedRouteAscentTest {

  /** A polyline whose first latitude says what the fake service must do with it. */
  private static String polyline(double lat) {
    return Polyline6Encoder.encode(new double[] {lat, lat + 0.01}, new double[] {-1.5, -1.5}, 0, 1);
  }

  private static RouteDetailsResponse answer(double gain, double loss, String status) {
    return new RouteDetailsResponse(
        null,
        status,
        null,
        null,
        new RouteDetailsResponse.Summary(1000, gain, loss, null, null, null, null),
        null);
  }

  private static GeneratedRouteAscent ascent(RouteDetailsGateway gateway, Duration budget) {
    GeneratedRouteAscent a = new GeneratedRouteAscent();
    a.routeDetails = gateway;
    a.budget = budget;
    a.metrics = new RouteGeneratorMetrics();
    a.metrics.registry = new SimpleMeterRegistry();
    return a;
  }

  @Test
  void theGainOfEachRouteIsTakenFromTheFastProfile() {
    RouteDetailsOptions[] seen = new RouteDetailsOptions[1];
    RouteDetailsGateway gateway =
        new RouteDetailsGateway() {
          @Override
          public RouteDetailsResponse details(double[] lat, double[] lon, RouteDetailsOptions o) {
            seen[0] = o;
            return answer(lat[0] * 10, lat[0], "complete");
          }
        };
    List<GeneratedRouteAscent.Gain> gains =
        ascent(gateway, Duration.ofSeconds(2)).compute(List.of(polyline(47.0), polyline(48.0)));
    assertEquals(2, gains.size());
    assertEquals(470, gains.get(0).ascentM(), 1e-3);
    assertEquals(48, gains.get(1).descentM(), 1e-3);
    assertEquals(RouteDetailsProfile.FAST, seen[0].profile());
    assertEquals(List.of(RouteDetailsSection.SUMMARY), seen[0].sections());
  }

  @Test
  void aFailedOrPartialCallLeavesNullForThatRouteAlone() {
    RouteDetailsGateway gateway =
        new RouteDetailsGateway() {
          @Override
          public RouteDetailsResponse details(double[] lat, double[] lon, RouteDetailsOptions o) {
            if (lat[0] < 47.5) {
              throw new IllegalStateException("fast paused");
            }
            return answer(100, 90, lat[0] > 48.5 ? "partial" : "complete");
          }
        };
    List<GeneratedRouteAscent.Gain> gains =
        ascent(gateway, Duration.ofSeconds(2))
            .compute(List.of(polyline(47.0), polyline(48.0), polyline(49.0)));
    assertNull(gains.get(0));
    assertNotNull(gains.get(1));
    assertNull(gains.get(2));
  }

  @Test
  void aCallPastTheBudgetLeavesNullAndTheOthersAnswer() {
    RouteDetailsGateway gateway =
        new RouteDetailsGateway() {
          @Override
          public RouteDetailsResponse details(double[] lat, double[] lon, RouteDetailsOptions o) {
            if (lat[0] > 48.5) {
              try {
                Thread.sleep(5_000);
              } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
              }
            }
            return answer(100, 90, "complete");
          }
        };
    long start = System.nanoTime();
    List<GeneratedRouteAscent.Gain> gains =
        ascent(gateway, Duration.ofMillis(300)).compute(List.of(polyline(47.0), polyline(49.0)));
    long ms = Duration.ofNanos(System.nanoTime() - start).toMillis();
    assertNotNull(gains.get(0));
    assertNull(gains.get(1));
    assertTrue(ms < 3_000, "waited " + ms + " ms");
  }

  @Test
  void anUndecodablePolylineIsNull() {
    RouteDetailsGateway gateway =
        new RouteDetailsGateway() {
          @Override
          public RouteDetailsResponse details(double[] lat, double[] lon, RouteDetailsOptions o) {
            return answer(1, 1, "complete");
          }
        };
    assertNull(ascent(gateway, Duration.ofSeconds(1)).compute(List.of("?")).get(0));
  }
}
