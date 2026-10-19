package fr.pedalons.service.router;

import fr.pedalons.dto.router.response.GpxImportTrack;
import fr.pedalons.service.route.planner.PolylineCodec;
import io.github.glandais.engine.path.Path;

/** Encodes a processed path the way the route editor reads it (docs/LEDGER_*.md WEB-100). */
final class PlannerTracks {

  private PlannerTracks() {}

  /**
   * The polylines of a processed path, with the ascent accumulated up to each point. {@code ele}
   * and {@code climb} are absent when a value is not finite.
   */
  static GpxImportTrack toTrack(Path path, double[] climb) {
    int n = path.getSize();
    double[][] lngLat = new double[n][];
    double[] ele = new double[n];
    boolean finite = true;
    for (int i = 0; i < n; i++) {
      lngLat[i] = new double[] {path.longitudeDeg(i), path.latitudeDeg(i)};
      ele[i] = path.elevation(i);
      finite &= Double.isFinite(ele[i]) && Double.isFinite(climb[i]);
    }
    return new GpxImportTrack(
        PolylineCodec.encode2(lngLat),
        finite ? PolylineCodec.encode1(ele) : null,
        finite ? PolylineCodec.encode1(climb) : null,
        path.getTotalDistance(),
        path.getReportedElevationGain());
  }
}
