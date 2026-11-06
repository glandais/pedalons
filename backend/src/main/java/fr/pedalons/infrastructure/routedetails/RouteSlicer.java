package fr.pedalons.infrastructure.routedetails;

import fr.pedalons.common.GeoDistance;
import java.util.ArrayList;
import java.util.List;

/**
 * Cuts a line into the requests osm-route-details accepts (plan §3.1, docs/LEDGER_*.md API-150):
 * the service answers a 413 beyond the bounds of {@code /v1/capabilities} (200 km, 16 000 points
 * as of api 1.6), and a longer route is the client's to slice. Pure: no call, no clock.
 *
 * <p>The rules are those of {@code TraceSurfaceComputer}, which slices for osm-surface under the
 * same bounds: the line is first thinned ({@link #MIN_SPACING_M}, more on a long line, {@link
 * #spacingFor}), then cut into cores of about 188 km, each sent with 500 m of overlap on both sides
 * so that a structure cut by a slice boundary is still corrected (contract §5.3). The copy there
 * stays until phase E removes osm-surface; this one is derived from the published bounds instead of
 * constants.
 *
 * <p>One difference, for the stitching ({@link RouteDetailsStitcher}): a core starts and ends on a
 * <b>sent point</b>, not at an arbitrary distance. The point that closes a core is an input point of
 * both neighbouring slices, so both answers carry it ({@code input_with_breakpoints} keeps every
 * input point) and the next slice's distances and cumulated gain are anchored on it, without any
 * interpolation.
 */
public final class RouteSlicer {

  /** Sent on each side of a core: what the matching and the structure correction settle in. */
  static final double OVERLAP_M = 500;

  /** Room left in a request for the spacing of the points that close it. */
  static final double SPACING_ROOM_M = 1_000;

  /**
   * A point closer than this to the previous one kept is never sent. Well under the spacing of two
   * junctions and under the 25 m of the service's own stations: an elevation there adds nothing.
   */
  static final double MIN_SPACING_M = 5;

  /** Points a request may hold on top of one every spacing: its ends, and the last point kept. */
  private static final int SPACING_MARGIN_POINTS = 8;

  private RouteSlicer() {}

  /**
   * The bounds a request is kept under, from the published ones: 95 % of the length (190 km of
   * 200, haversine on both sides but on rounded coordinates there) and 15/16 of the points (15 000
   * of 16 000, the margin {@code TraceSurfaceComputer} measured). The overlap and the spacing room
   * shrink on tiny bounds (tests) so that a core always has a length.
   */
  record Bounds(double maxRequestM, int maxPoints, double overlapM, double coreM) {

    static Bounds of(RouteDetailsCapabilities.Limits limits) {
      double maxRequest = limits.maxLengthM() * 0.95;
      int maxPoints = Math.max(4, limits.maxPoints() - limits.maxPoints() / 16);
      double overlap = Math.min(OVERLAP_M, maxRequest / 8);
      double room = Math.min(SPACING_ROOM_M, maxRequest / 8);
      return new Bounds(maxRequest, maxPoints, overlap, maxRequest - 2 * overlap - room);
    }
  }

  /**
   * One request: the sent points {@code from..to} (inclusive), of which it answers for the core
   * {@code coreFrom..coreTo}. Consecutive slices share their boundary point: {@code coreTo} of one
   * is {@code coreFrom} of the next.
   */
  public record Slice(int from, int to, int coreFrom, int coreTo) {}

  /**
   * The line to send and how to cut it.
   *
   * @param sent the caller's index of each sent point, increasing; the answers' indices count the
   *     sent points and are carried back through it ({@link RouteDetailsStitcher#reindex})
   * @param lat the sent points' latitudes
   * @param lon the sent points' longitudes
   */
  public record Plan(int[] sent, double[] lat, double[] lon, List<Slice> slices) {

    public boolean isSliced() {
      return slices.size() > 1;
    }
  }

  /**
   * The plan for a line, thinned then sliced.
   *
   * @throws IllegalArgumentException with fewer than two points, or arrays of different lengths
   */
  public static Plan plan(double[] lat, double[] lon, RouteDetailsCapabilities.Limits limits) {
    if (lat.length != lon.length) {
      throw new IllegalArgumentException("lat and lon differ in length");
    }
    if (lat.length < 2) {
      throw new IllegalArgumentException("a route needs two points");
    }
    Bounds bounds = Bounds.of(limits);
    int[] sent = thin(lat, lon, spacingFor(lat, lon, bounds));
    double[] sentLat = new double[sent.length];
    double[] sentLon = new double[sent.length];
    for (int k = 0; k < sent.length; k++) {
      sentLat[k] = lat[sent[k]];
      sentLon[k] = lon[sent[k]];
    }
    return new Plan(sent, sentLat, sentLon, slice(cumulative(sentLat, sentLon), bounds));
  }

  /**
   * The slices of a line given its cumulative distances. One slice when the whole line fits in a
   * request; otherwise cores of {@link Bounds#coreM()} closed on the last point at or before their
   * end, each widened by the overlap on both sides, and shortened when its points exceed the bound.
   * A single leg longer than a core makes a core of its own (and the service a 413: a bug of the
   * track, not of the slicing).
   */
  static List<Slice> slice(double[] dist, Bounds bounds) {
    int n = dist.length;
    double length = dist[n - 1];
    if (n <= bounds.maxPoints() && length <= bounds.maxRequestM()) {
      return List.of(new Slice(0, n - 1, 0, n - 1));
    }
    // Points an overlap may take, so that a core always keeps some on tiny bounds
    int overlapPoints = Math.max(1, bounds.maxPoints() / 4);
    List<Slice> slices = new ArrayList<>();
    int c0 = 0;
    while (c0 < n - 1) {
      double start = dist[c0];
      int c1 =
          start + bounds.coreM() >= length
              ? n - 1
              : Math.max(c0 + 1, lastAtOrBefore(dist, start + bounds.coreM()));
      int i0 =
          Math.max(
              c0 - overlapPoints, lastAtOrBefore(dist, Math.max(0, start - bounds.overlapM())));
      int i1 =
          Math.min(
              c1 + overlapPoints,
              firstAtOrAfter(dist, Math.min(length, dist[c1] + bounds.overlapM())));
      if (i1 - i0 + 1 > bounds.maxPoints()) {
        // The request holds i0..last at most; the core ends an overlap before its last point
        int last = i0 + bounds.maxPoints() - 1;
        c1 = Math.max(c0 + 1, Math.min(last, lastAtOrBefore(dist, dist[last] - bounds.overlapM())));
        i1 = Math.max(c1, Math.min(last, firstAtOrAfter(dist, dist[c1] + bounds.overlapM())));
      }
      slices.add(new Slice(i0, i1, c0, c1));
      c0 = c1;
    }
    return slices;
  }

  /**
   * The spacing the line is thinned to: {@link #MIN_SPACING_M}, or more when a request would hold
   * more points than the bound at that spacing, so that a slice stays bounded by its length and not
   * by its point count (the rule of {@code TraceSurfaceComputer.spacingFor}).
   */
  static double spacingFor(double[] lat, double[] lon, Bounds bounds) {
    double length = 0;
    for (int i = 1; i < lat.length; i++) {
      length += GeoDistance.haversineMeters(lat[i - 1], lon[i - 1], lat[i], lon[i]);
    }
    // The thinned line is no longer than the given one, so neither is any request of it
    double request = Math.min(length, bounds.coreM() + 2 * bounds.overlapM());
    return Math.max(
        MIN_SPACING_M, request / Math.max(1, bounds.maxPoints() - SPACING_MARGIN_POINTS));
  }

  /**
   * The indices of the points kept: every point closer than {@code minSpacing} to the previous one
   * kept is dropped, the first and the last are always kept, so the sent line ends where the given
   * one does.
   */
  static int[] thin(double[] lat, double[] lon, double minSpacing) {
    int n = lat.length;
    int[] kept = new int[n];
    int count = 0;
    for (int i = 0; i < n; i++) {
      if (count == 0 || i == n - 1) {
        kept[count++] = i;
        continue;
      }
      int last = kept[count - 1];
      if (GeoDistance.haversineMeters(lat[last], lon[last], lat[i], lon[i]) >= minSpacing) {
        kept[count++] = i;
      }
    }
    int[] out = new int[count];
    System.arraycopy(kept, 0, out, 0, count);
    return out;
  }

  /** The cumulative haversine distance of each point, the service's measure (contract §4.2). */
  static double[] cumulative(double[] lat, double[] lon) {
    double[] dist = new double[lat.length];
    for (int i = 1; i < lat.length; i++) {
      dist[i] = dist[i - 1] + GeoDistance.haversineMeters(lat[i - 1], lon[i - 1], lat[i], lon[i]);
    }
    return dist;
  }

  /** The last index whose distance is at most {@code d} (the first when none is). */
  private static int lastAtOrBefore(double[] dist, double d) {
    int lo = 0;
    int hi = dist.length - 1;
    int found = 0;
    while (lo <= hi) {
      int mid = (lo + hi) >>> 1;
      if (dist[mid] <= d) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }

  /** The first index whose distance is at least {@code d} (the last when none is). */
  private static int firstAtOrAfter(double[] dist, double d) {
    int lo = 0;
    int hi = dist.length - 1;
    int found = dist.length - 1;
    while (lo <= hi) {
      int mid = (lo + hi) >>> 1;
      if (dist[mid] >= d) {
        found = mid;
        hi = mid - 1;
      } else {
        lo = mid + 1;
      }
    }
    return found;
  }
}
