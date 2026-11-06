package fr.pedalons.infrastructure.routedetails;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.infrastructure.routedetails.RouteDetailsResponse.OutputPoint;
import fr.pedalons.infrastructure.valhalla.Polyline6Decoder;
import fr.pedalons.infrastructure.valhalla.Polyline6Encoder;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

/**
 * The gateway on the test fake, off the network (plan §8): the profiles' flat terrains, a sliced
 * call stitched back to one answer on the caller's indices, and a failure classified.
 */
class FakeRouteDetailsGatewayTest {

  private final RouteDetailsGateway gateway = new FakeRouteDetailsGateway();

  @AfterEach
  void reset() {
    FakeRouteDetailsClient.reset();
  }

  @Test
  void eachProfile_hasItsOwnFlatTerrain() {
    double[][] line = RouteSlicerTest.meridian(30, 90);
    RouteDetailsResponse fast =
        gateway.details(line[0], line[1], RouteDetailsOptions.of(RouteDetailsProfile.FAST, false));
    RouteDetailsResponse full =
        gateway.details(line[0], line[1], RouteDetailsOptions.of(RouteDetailsProfile.FULL, false));
    assertEquals(FakeRouteDetailsClient.FAST_ELEVATION, fast.points().getFirst().ele());
    assertEquals(FakeRouteDetailsClient.FULL_ELEVATION, full.points().getLast().ele());
    assertEquals("fast", fast.meta().profile());
    assertEquals(2, FakeRouteDetailsClient.REQUESTS.size());
  }

  @Test
  void aLongRoute_goesOutInSlicesAndComesBackWhole() {
    FakeRouteDetailsClient.limits = new RouteDetailsCapabilities.Limits(200, 5_000);
    double[][] line = RouteSlicerTest.meridian(401, 50);
    RouteDetailsResponse r =
        gateway.details(line[0], line[1], RouteDetailsOptions.of(RouteDetailsProfile.FULL, false));
    assertTrue(FakeRouteDetailsClient.REQUESTS.size() > 1);
    assertEquals(401, r.points().size());
    // The fake measures the polyline6 it receives, rounded to 1e-6 degree (about 0.1 m): the
    // stitched distances must add up to that measure of the whole line, not to i * 50 m.
    double[] expected = polyline6Distances(line[0], line[1]);
    for (int i = 0; i < r.points().size(); i++) {
      OutputPoint p = r.points().get(i);
      assertEquals(i, p.index());
      assertEquals(expected[i], p.dM(), 1e-6, "point " + i);
      assertEquals(i * 50.0, p.dM(), 0.1, "point " + i);
    }
    assertEquals(1, r.segments().size());
    assertEquals(expected[400], r.summary().lengthM(), 1e-6);
  }

  /** The cumulative haversine of the line as the service sees it, through polyline6. */
  static double[] polyline6Distances(double[] lat, double[] lon) {
    List<double[]> lonLat =
        Polyline6Decoder.decode(Polyline6Encoder.encode(lat, lon, 0, lat.length - 1));
    double[] d = new double[lonLat.size()];
    for (int i = 1; i < d.length; i++) {
      double[] a = lonLat.get(i - 1);
      double[] b = lonLat.get(i);
      d[i] = d[i - 1] + GeoDistance.haversineMeters(a[1], a[0], b[1], b[0]);
    }
    return d;
  }

  @Test
  void aSlicedCall_forcesTheElevationSectionAndAnInputSampling() {
    FakeRouteDetailsClient.limits = new RouteDetailsCapabilities.Limits(200, 5_000);
    double[][] line = RouteSlicerTest.meridian(401, 50);
    RouteDetailsOptions options =
        new RouteDetailsOptions(
            RouteDetailsProfile.FULL,
            List.of(RouteDetailsSection.TYPOLOGY),
            new RouteDetailsOptions.Sampling("distance"),
            null,
            false);
    gateway.details(line[0], line[1], options);
    assertTrue(FakeRouteDetailsClient.REQUESTS.size() > 1);
    for (RouteDetailsRequest request : FakeRouteDetailsClient.REQUESTS) {
      assertTrue(request.options().sections().contains(RouteDetailsSection.ELEVATION));
      assertEquals(RouteDetailsOptions.INPUT_WITH_BREAKPOINTS, request.options().sampling().mode());
    }
  }

  @Test
  void aFullCallDuringAnOutage_isTransient() {
    FakeRouteDetailsClient.failFull = true;
    double[][] line = RouteSlicerTest.meridian(10, 90);
    RouteDetailsException e =
        assertThrows(
            RouteDetailsException.class,
            () ->
                gateway.details(
                    line[0], line[1], RouteDetailsOptions.of(RouteDetailsProfile.FULL, false)));
    assertTrue(e.isTransient());
    assertEquals(503, e.status());
    assertEquals(RouteDetailsErrors.DATA_UNAVAILABLE, e.code());
    assertEquals(Duration.ofSeconds(30), e.retryAfter());
  }

  @Test
  void aPartialAnswer_saysSo() {
    FakeRouteDetailsClient.partial = true;
    double[][] line = RouteSlicerTest.meridian(10, 90);
    RouteDetailsResponse r =
        gateway.details(line[0], line[1], RouteDetailsOptions.of(RouteDetailsProfile.FULL, true));
    assertTrue(r.isPartial());
    assertEquals(null, r.points().getLast().ele());
    assertEquals("elevation_missing", r.quality().warnings().getFirst().code());
  }
}
