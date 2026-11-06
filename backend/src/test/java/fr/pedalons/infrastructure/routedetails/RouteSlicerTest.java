package fr.pedalons.infrastructure.routedetails;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.infrastructure.routedetails.RouteSlicer.Bounds;
import fr.pedalons.infrastructure.routedetails.RouteSlicer.Plan;
import fr.pedalons.infrastructure.routedetails.RouteSlicer.Slice;
import java.util.List;
import org.junit.jupiter.api.Test;

/** The slicing of plan §3.1 (docs/LEDGER_*.md API-150): bounds, cores, overlaps, thinning. */
class RouteSlicerTest {

  /** Metres per degree of latitude along a meridian, the haversine's radius. */
  static final double M_PER_DEG = GeoDistance.EARTH_RADIUS_METERS * Math.PI / 180;

  /** A line due north from Nantes, one point every {@code stepM}. */
  static double[][] meridian(int n, double stepM) {
    double[] lat = new double[n];
    double[] lon = new double[n];
    for (int i = 0; i < n; i++) {
      lat[i] = 47.2 + i * stepM / M_PER_DEG;
      lon[i] = -1.55;
    }
    return new double[][] {lat, lon};
  }

  @Test
  void boundsOfThePublishedLimits_keepTheMargins() {
    Bounds bounds = Bounds.of(RouteDetailsCapabilities.FALLBACK_LIMITS);
    assertEquals(190_000, bounds.maxRequestM(), 1e-6);
    assertEquals(15_000, bounds.maxPoints());
    assertEquals(500, bounds.overlapM(), 1e-6);
    assertEquals(188_000, bounds.coreM(), 1e-6);
  }

  @Test
  void aRouteUnderTheBounds_isOneSliceOfEveryPoint() {
    double[][] line = meridian(500, 90);
    Plan plan = RouteSlicer.plan(line[0], line[1], RouteDetailsCapabilities.FALLBACK_LIMITS);
    assertFalse(plan.isSliced());
    assertEquals(List.of(new Slice(0, 499, 0, 499)), plan.slices());
    assertEquals(500, plan.sent().length);
    assertEquals(499, plan.sent()[499]);
  }

  @Test
  void aLongRoute_isCutIntoCoresThatMeetOnASharedPoint() {
    // 20 km under bounds of 5 km: cores of about 3.2 km, 500 m of overlap
    RouteDetailsCapabilities.Limits limits = new RouteDetailsCapabilities.Limits(200, 5_000);
    Bounds bounds = Bounds.of(limits);
    double[][] line = meridian(401, 50);
    Plan plan = RouteSlicer.plan(line[0], line[1], limits);
    double[] dist = RouteSlicer.cumulative(plan.lat(), plan.lon());
    List<Slice> slices = plan.slices();
    assertTrue(slices.size() > 1);
    assertEquals(0, slices.getFirst().coreFrom());
    assertEquals(0, slices.getFirst().from());
    assertEquals(400, slices.getLast().coreTo());
    assertEquals(400, slices.getLast().to());
    for (int k = 0; k < slices.size(); k++) {
      Slice s = slices.get(k);
      assertTrue(s.from() <= s.coreFrom() && s.coreFrom() < s.coreTo() && s.coreTo() <= s.to());
      assertTrue(s.to() - s.from() + 1 <= bounds.maxPoints());
      assertTrue(dist[s.to()] - dist[s.from()] <= bounds.maxRequestM());
      if (k > 0) {
        assertEquals(slices.get(k - 1).coreTo(), s.coreFrom());
        assertTrue(dist[s.coreFrom()] - dist[s.from()] >= bounds.overlapM() - 1e-6);
      }
      if (k < slices.size() - 1) {
        assertTrue(dist[s.to()] - dist[s.coreTo()] >= bounds.overlapM() - 1e-6);
      }
    }
  }

  @Test
  void aDenseRoute_isCutOnItsPointCount() {
    double[] dist = new double[1_000];
    for (int i = 0; i < dist.length; i++) {
      dist[i] = i;
    }
    Bounds bounds = new Bounds(1e9, 50, 10, 1e8);
    List<Slice> slices = RouteSlicer.slice(dist, bounds);
    assertTrue(slices.size() > 1);
    assertEquals(999, slices.getLast().coreTo());
    for (int k = 0; k < slices.size(); k++) {
      Slice s = slices.get(k);
      assertTrue(s.to() - s.from() + 1 <= 50, s.toString());
      assertTrue(s.coreTo() > s.coreFrom());
      if (k > 0) {
        assertEquals(slices.get(k - 1).coreTo(), s.coreFrom());
      }
    }
  }

  @Test
  void thinning_dropsPointsCloserThanTheSpacing_andKeepsBothEnds() {
    double[][] line = meridian(13, 2);
    int[] kept = RouteSlicer.thin(line[0], line[1], 5);
    // 2 m apart: 0, 6, 12, 18 m kept, the first at 5 m or more from the last kept, and the end
    assertArrayEquals(new int[] {0, 3, 6, 9, 12}, kept);
  }

  @Test
  void aRecordingAt1Hz_isThinnedToFiveMetres() {
    // 1.2 m apart: every fifth point is the first at 5 m or more (6 m) from the last kept
    double[][] line = meridian(1_001, 1.2);
    Plan plan = RouteSlicer.plan(line[0], line[1], RouteDetailsCapabilities.FALLBACK_LIMITS);
    assertEquals(0, plan.sent()[0]);
    assertEquals(1_000, plan.sent()[plan.sent().length - 1]);
    assertEquals(201, plan.sent().length);
  }

  @Test
  void aSinglePoint_isRefused() {
    assertThrows(
        IllegalArgumentException.class,
        () ->
            RouteSlicer.plan(
                new double[] {47.2},
                new double[] {-1.55},
                RouteDetailsCapabilities.FALLBACK_LIMITS));
  }
}
