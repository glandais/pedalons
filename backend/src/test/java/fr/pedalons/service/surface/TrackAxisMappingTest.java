package fr.pedalons.service.surface;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** docs/LEDGER_*.md API-149: distances along the sent line, carried onto the stored points. */
class TrackAxisMappingTest {

  /** An out-and-back: {@code n} vertices north every {@code step} metres, then back south. */
  private static double[][] outAndBack(int n, double step, double eastM) {
    double dLat = Math.toDegrees(step / fr.pedalons.common.GeoDistance.EARTH_RADIUS_METERS);
    double dLng =
        Math.toDegrees(
            eastM
                / (fr.pedalons.common.GeoDistance.EARTH_RADIUS_METERS
                    * Math.cos(Math.toRadians(48))));
    int total = 2 * n - 1;
    double[][] out = new double[3][total];
    for (int i = 0; i < total; i++) {
      int k = i < n ? i : 2 * (n - 1) - i;
      out[0][i] = 48 + k * dLat;
      out[1][i] = 2 + (i < n ? 0 : dLng);
      if (i > 0) {
        out[2][i] =
            out[2][i - 1]
                + fr.pedalons.common.GeoDistance.haversineMeters(
                    out[0][i - 1], out[1][i - 1], out[0][i], out[1][i]);
      }
    }
    return out;
  }

  @Test
  void theMappingOfAnOutAndBack_followsTheLegItIsOn() {
    // Stored: 1 km north and back every 100 m; sent: the same every 10 m, 3 m east on the way back
    double[][] track = outAndBack(11, 100, 0);
    double[][] sent = outAndBack(101, 10, 3);
    double sentLength = sent[2][sent[2].length - 1];
    double back = sent[2][170]; // 300 m north, on the way back
    double[] mapped =
        TrackAxisMapping.map(
            sent[0],
            sent[1],
            sent[2],
            track[0],
            track[1],
            track[2],
            new double[] {0, back, sentLength});
    assertEquals(0, mapped[0], 0);
    assertEquals(1_700, mapped[1], 2);
    assertEquals(track[2][track[2].length - 1], mapped[2], 0);

    double out = sent[2][30]; // 300 m north, on the way out: the same spot, the other leg
    mapped =
        TrackAxisMapping.map(
            sent[0], sent[1], sent[2], track[0], track[1], track[2], new double[] {out, back});
    assertEquals(300, mapped[0], 2);
    assertEquals(1_700, mapped[1], 2);
  }

  /**
   * A line through the given {@code [east, north]} waypoints in metres from (lat 48, lng 2), a
   * vertex every {@code step} metres along each leg; between {@code zigFrom} and {@code zigTo}
   * metres along it every other vertex is {@code lateral} metres east, a GPS jitter that makes the
   * line longer there only. As {@code [lat[], lng[], dist[]]}.
   */
  private static double[][] path(
      double step, double zigFrom, double zigTo, double lateral, double[]... waypoints) {
    double r = fr.pedalons.common.GeoDistance.EARTH_RADIUS_METERS;
    double cos = Math.cos(Math.toRadians(48));
    List<double[]> en = new ArrayList<>();
    en.add(waypoints[0]);
    for (int w = 1; w < waypoints.length; w++) {
      double[] a = waypoints[w - 1];
      double[] b = waypoints[w];
      double leg = Math.hypot(b[0] - a[0], b[1] - a[1]);
      int steps = Math.max(1, (int) Math.round(leg / step));
      for (int i = 1; i <= steps; i++) {
        double f = (double) i / steps;
        en.add(new double[] {a[0] + f * (b[0] - a[0]), a[1] + f * (b[1] - a[1])});
      }
    }
    double[][] out = new double[3][en.size()];
    for (int i = 0; i < en.size(); i++) {
      boolean zig = i % 2 == 1 && i * step >= zigFrom && i * step < zigTo;
      double east = en.get(i)[0] + (zig ? lateral : 0);
      out[0][i] = 48 + Math.toDegrees(en.get(i)[1] / r);
      out[1][i] = 2 + Math.toDegrees(east / (r * cos));
      if (i > 0) {
        out[2][i] =
            out[2][i - 1]
                + fr.pedalons.common.GeoDistance.haversineMeters(
                    out[0][i - 1], out[1][i - 1], out[0][i], out[1][i]);
      }
    }
    return out;
  }

  /** The distance along {@code line} of its first vertex within a metre of {@code [east, north]}, from {@code after}. */
  private static double distAt(double[][] line, double east, double north, double after) {
    double r = fr.pedalons.common.GeoDistance.EARTH_RADIUS_METERS;
    double lat = 48 + Math.toDegrees(north / r);
    double lng = 2 + Math.toDegrees(east / (r * Math.cos(Math.toRadians(48))));
    for (int i = 0; i < line[2].length; i++) {
      if (line[2][i] >= after
          && fr.pedalons.common.GeoDistance.haversineMeters(line[0][i], line[1][i], lat, lng) < 1) {
        return line[2][i];
      }
    }
    throw new AssertionError("no vertex at " + east + ", " + north);
  }

  @Test
  void aSpurAfterAJitteryStretch_mapsOnThePassItIsOn() {
    // 20 km north, a 100 m spur east and back, 30 km north again. The raw line zigzags 10 m over
    // km 15-16, about 414 m more there only: rescaled by the length ratio of the whole line, the
    // base of the spur, passed first, is expected about 250 m on, nearer its second pass
    double[][] corners = {{0, 0}, {0, 20_000}, {100, 20_000}, {0, 20_000}, {0, 50_000}};
    double[][] track = path(100, 0, 0, 0, corners);
    double[][] sent = path(10, 15_000, 16_000, 10, corners);
    double first = distAt(sent, 0, 20_000, 0);
    double tip = distAt(sent, 100, 20_000, first);
    double second = distAt(sent, 0, 20_000, tip);
    assertTrue(first > 20_400, "first " + first);
    double[] mapped =
        TrackAxisMapping.map(
            sent[0],
            sent[1],
            sent[2],
            track[0],
            track[1],
            track[2],
            new double[] {first, tip, second});
    assertEquals(20_000, mapped[0], 3);
    assertEquals(20_100, mapped[1], 3);
    assertEquals(20_200, mapped[2], 3);
  }

  @Test
  void aBoundaryFarFromThePreviousOne_staysOnItsLeg() {
    // 25 km north and 5 km back, the way back 5 m east; the raw line zigzags only after the
    // boundary, which is 100 m after the U-turn, 25 km from the start: a length ratio of the
    // whole line would expect it about 340 m early, on the way out across the road
    double[][] track =
        path(
            100,
            0,
            0,
            0,
            new double[] {0, 0},
            new double[] {0, 25_000},
            new double[] {5, 25_000},
            new double[] {5, 20_000});
    double[][] sent =
        path(
            10,
            28_000,
            29_000,
            10,
            new double[] {0, 0},
            new double[] {0, 25_000},
            new double[] {5, 25_000},
            new double[] {5, 20_000});
    double turn = distAt(sent, 5, 25_000, 0);
    double back = distAt(sent, 5, 24_900, turn);
    double[] mapped =
        TrackAxisMapping.map(
            sent[0], sent[1], sent[2], track[0], track[1], track[2], new double[] {back});
    assertEquals(25_105, mapped[0], 3);
  }
}
