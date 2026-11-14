package fr.pedalons.service.route.generator;

/**
 * Local equirectangular projection around a reference point (design §1): x east, y north, in
 * metres. Good enough for short-range and angular maths over a team area; lengths never come from
 * here.
 */
final class LocalProjection {
  static final double EARTH_RADIUS_M = 6_371_008.8;

  private final double refLat;
  private final double refLon;
  private final double cosRef;

  LocalProjection(double refLat, double refLon) {
    this.refLat = refLat;
    this.refLon = refLon;
    this.cosRef = Math.cos(Math.toRadians(refLat));
  }

  double refLat() {
    return refLat;
  }

  double refLon() {
    return refLon;
  }

  double toX(double lat, double lon) {
    return EARTH_RADIUS_M * Math.toRadians(lon - refLon) * cosRef;
  }

  double toY(double lat, double lon) {
    return EARTH_RADIUS_M * Math.toRadians(lat - refLat);
  }

  LatLon toLatLon(double x, double y) {
    double lat = refLat + Math.toDegrees(y / EARTH_RADIUS_M);
    double lon = refLon + Math.toDegrees(x / (EARTH_RADIUS_M * cosRef));
    return new LatLon(lat, lon);
  }

  static double distance(double x1, double y1, double x2, double y2) {
    return Math.hypot(x2 - x1, y2 - y1);
  }
}
