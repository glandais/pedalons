package fr.pedalons.service.route;

import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.github.glandais.engine.gpx.GpxSegment;
import io.github.glandais.engine.gpx.GpxTrack;
import io.github.glandais.engine.gpx.GpxTrackPoint;
import io.github.glandais.engine.gpx.GpxWaypoint;
import java.util.List;

/**
 * Reduces a parsed {@link GpxDocument} to what a route is: the geometry (latitude, longitude,
 * altitude) of its tracks, and its waypoints (position and name). Everything an activity recorder
 * adds on top is dropped — per-point timestamps, heart rate, cadence, power, temperature
 * (docs/LEDGER_*.md API-44).
 *
 * <p>An activity export is health data (heart rate) and a movement log (when the member rode,
 * how fast, where they stopped). Pédalons never uses any of it: distance, elevation, climbs, wind
 * and the track itself are pure geometry, and no client reads a {@code <time>} from a served file.
 *
 * <p><b>Timestamps become absent, not the epoch.</b> vcyclist reads a missing {@code <time>} as a
 * {@code 0} clock and writes a {@code 0} clock as no {@code <time>} at all, and absent sensors as
 * {@code NaN} that no writer emits: a sanitized document is indistinguishable from a route that
 * never had times — which is exactly what {@link GpxProcessingService#fromPoints} builds for a
 * drawn one. The FIT course then starts at the epoch, which FIT cannot represent and decodes as
 * absent.
 *
 * <p>Document metadata needs no work here: the parser keeps only its name (the route's name), so
 * author, e-mail, link, creator and {@code <metadata><time>} never survive parsing. What the model
 * does carry beyond geometry — a waypoint's time, description, symbol and type, a track's type, a
 * road width or OSM class — is dropped with the rest: none of it is read downstream.
 */
public final class GpxSanitizer {

  private GpxSanitizer() {}

  /**
   * A copy of {@code doc} with only names, track kinds and segment boundaries, point positions and
   * elevations, and waypoint positions and names. Idempotent. The model is immutable, so the
   * caller must go on with the returned document — the one it passed in is still raw.
   */
  public static GpxDocument sanitize(GpxDocument doc) {
    List<GpxTrack> tracks =
        doc.getTracks().stream()
            .map(
                track ->
                    new GpxTrack(
                        track.getName(),
                        null,
                        track.getSegments().stream()
                            .map(
                                s ->
                                    new GpxSegment(
                                        s.getPoints().stream().map(GpxSanitizer::point).toList()))
                            .toList(),
                        track.getKind(),
                        null,
                        null))
            .toList();
    List<GpxWaypoint> waypoints =
        doc.getWaypoints().stream()
            .map(
                w ->
                    GpxModelJvm.waypoint(
                        w.getLatitudeDeg(), w.getLongitudeDeg(), null, w.getName()))
            .toList();
    return GpxModelJvm.document(tracks, doc.getName(), waypoints);
  }

  private static GpxTrackPoint point(GpxTrackPoint source) {
    return GpxModelJvm.trackPoint(
        source.getLatitudeDeg(), source.getLongitudeDeg(), source.getElevationM());
  }
}
