package fr.pedalons.infrastructure.routedetails;

import fr.pedalons.common.GeoDistance;
import java.util.ArrayList;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The Google polylines of {@code edges[].geometry} (precision 6, {@code [lat, lon]} order, the
 * travel direction), for the stitching of sliced answers: cut an edge to a range of its traversed
 * length, join the two halves of an edge a slice boundary cut. Pure. A geometry that is not
 * stitched is never decoded, so the service's strings are stored byte for byte in the common case.
 */
final class EdgePolylines {

  private static final double PRECISION = 1e6;

  private EdgePolylines() {}

  /** The vertices as {@code [lat, lon]} pairs; empty for a null or empty string. */
  static List<double[]> decode(@Nullable String encoded) {
    List<double[]> out = new ArrayList<>();
    if (encoded == null || encoded.isEmpty()) {
      return out;
    }
    int index = 0;
    long lat = 0;
    long lon = 0;
    while (index < encoded.length()) {
      int shift = 0;
      long result = 0;
      int b;
      do {
        b = encoded.charAt(index++) - 63;
        result |= (long) (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length());
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      if (index >= encoded.length()) {
        break;
      }
      shift = 0;
      result = 0;
      do {
        b = encoded.charAt(index++) - 63;
        result |= (long) (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length());
      lon += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      out.add(new double[] {lat / PRECISION, lon / PRECISION});
    }
    return out;
  }

  /** The polyline of {@code latLon} pairs. */
  static String encode(List<double[]> latLon) {
    StringBuilder sb = new StringBuilder();
    long prevLat = 0;
    long prevLon = 0;
    for (double[] p : latLon) {
      long lat = Math.round(p[0] * PRECISION);
      long lon = Math.round(p[1] * PRECISION);
      value(sb, lat - prevLat);
      value(sb, lon - prevLon);
      prevLat = lat;
      prevLon = lon;
    }
    return sb.toString();
  }

  private static void value(StringBuilder sb, long delta) {
    long v = delta < 0 ? ~(delta << 1) : delta << 1;
    while (v >= 0x20) {
      sb.append((char) ((0x20 | (v & 0x1f)) + 63));
      v >>= 5;
    }
    sb.append((char) (v + 63));
  }

  /** The length of a line of {@code [lat, lon]} pairs in metres. */
  static double length(List<double[]> line) {
    double total = 0;
    for (int i = 1; i < line.size(); i++) {
      total +=
          GeoDistance.haversineMeters(
              line.get(i - 1)[0], line.get(i - 1)[1], line.get(i)[0], line.get(i)[1]);
    }
    return total;
  }

  /**
   * The part of {@code line} between {@code from} and {@code to} metres from its start, cut with
   * a linear interpolation inside a segment; at least two points when the line has two.
   */
  static List<double[]> slice(List<double[]> line, double from, double to) {
    List<double[]> out = new ArrayList<>();
    if (line.size() < 2) {
      out.addAll(line);
      return out;
    }
    double at = 0;
    for (int i = 1; i < line.size(); i++) {
      double[] a = line.get(i - 1);
      double[] b = line.get(i);
      double len = GeoDistance.haversineMeters(a[0], a[1], b[0], b[1]);
      double start = at;
      double end = at + len;
      at = end;
      if (end < from || start > to) {
        continue;
      }
      if (out.isEmpty()) {
        out.add(len == 0 ? a : interpolate(a, b, (Math.max(from, start) - start) / len));
      }
      double[] last = out.getLast();
      double[] next = end <= to || len == 0 ? b : interpolate(a, b, (to - start) / len);
      if (last[0] != next[0] || last[1] != next[1]) {
        out.add(next);
      }
    }
    if (out.size() < 2 && !out.isEmpty()) {
      out.add(out.getFirst());
    }
    if (out.isEmpty()) {
      out.add(line.getLast());
      out.add(line.getLast());
    }
    return out;
  }

  private static double[] interpolate(double[] a, double[] b, double t) {
    double f = Math.max(0, Math.min(1, t));
    return new double[] {a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f};
  }
}
