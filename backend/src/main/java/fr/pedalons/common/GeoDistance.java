package fr.pedalons.common;

/** Great-circle distance between two WGS84 positions. */
public final class GeoDistance {

  /** Mean Earth radius, the one a haversine distance is usually computed with. */
  public static final double EARTH_RADIUS_METERS = 6_371_000.0;

  private GeoDistance() {}

  /** Haversine distance in metres between two positions given in degrees. */
  public static double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    double dLat = Math.toRadians(lat2 - lat1);
    double dLng = Math.toRadians(lng2 - lng1);
    double a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2)
            + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2)
                * Math.sin(dLng / 2);
    return 2 * EARTH_RADIUS_METERS * Math.asin(Math.min(1.0, Math.sqrt(a)));
  }
}
