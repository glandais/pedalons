package fr.pedalons.service.weather;

import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.repository.route.GpxTrackRepository;
import io.quarkus.cache.CacheResult;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.util.ArrayList;
import java.util.List;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;

/**
 * The forecast points of a route, cached.
 *
 * <p>Its own bean, like {@code GeocodingLookup}, because {@code @CacheResult} is an interceptor: a
 * call from a sibling method of the same bean would bypass the proxy and never hit the cache. The
 * key is the route's <b>sorted track ids</b>: a GPX upload replaces the tracks with new rows rather
 * than editing them ({@code RouteService}), so an entry can never describe a geometry that changed
 * — a new upload is a new key.
 *
 * <p>A miss reads the tracks' {@code track_points} JSON, the only heavy read of the weather, and
 * never writes anything.
 */
@ApplicationScoped
public class RouteSampleLookup {

  /** A sample this close to the finish is dropped: the finish already says it. */
  static final double MIN_GAP_TO_FINISH_METERS = 5_000;

  @ConfigProperty(name = "pedalons.weather.sample-step-km", defaultValue = "15")
  double sampleStepKm;

  @Inject GpxTrackRepository gpxTrackRepository;

  /**
   * @param sortedTrackIds the route's track ids, ascending — the order they are chained in
   */
  @CacheResult(cacheName = "weather-route-samples")
  public RouteSamples samples(List<Long> sortedTrackIds) {
    if (sortedTrackIds.isEmpty()) {
      return RouteSamples.EMPTY;
    }
    List<List<TrackPoint>> tracks = new ArrayList<>();
    for (GpxTrack track : gpxTrackRepository.findTracksByIds(sortedTrackIds)) {
      tracks.add(track.getTrackPoints());
    }
    return sample(tracks, sampleStepKm * 1000);
  }

  /**
   * Samples chained tracks: the start, every {@code stepMeters} of cumulative distance, and the
   * finish, a sample within {@value #MIN_GAP_TO_FINISH_METERS} m of the finish left out (92 km at
   * 15 km: 0, 15, 30, 45, 60, 75, 92).
   *
   * <p>A sample is the first track point at or past its target, with that point's own cumulative
   * distance and altitude — no interpolation. Several tracks are chained in the order given with a
   * continuous distance; the jump between the end of one and the start of the next counts for no
   * distance and no bearing. A track whose altitudes are all zero is taken to have none.
   */
  static RouteSamples sample(List<List<TrackPoint>> tracks, double stepMeters) {
    List<Point> points = chain(tracks);
    if (points.isEmpty()) {
      return RouteSamples.EMPTY;
    }
    double total = points.getLast().distance;

    // Indexes of the sampled points.
    List<Integer> picked = new ArrayList<>();
    picked.add(0);
    int cursor = 0;
    for (int k = 1; k * stepMeters < total - MIN_GAP_TO_FINISH_METERS; k++) {
      double target = k * stepMeters;
      while (cursor < points.size() - 1 && points.get(cursor).distance < target) {
        cursor++;
      }
      if (cursor > picked.getLast() && cursor < points.size() - 1) {
        picked.add(cursor);
      }
    }
    if (points.size() > 1) {
      picked.add(points.size() - 1);
    }

    List<RouteSamples.Sample> samples = new ArrayList<>(picked.size());
    for (int s = 0; s < picked.size(); s++) {
      int from = picked.get(s);
      int to = s + 1 < picked.size() ? picked.get(s + 1) : from;
      double sumCos = 0;
      double sumSin = 0;
      double length = 0;
      for (int i = from; i < to; i++) {
        Point a = points.get(i);
        Point b = points.get(i + 1);
        double l = b.distance - a.distance;
        if (b.trackStart || l <= 0) {
          continue;
        }
        double bearing = Math.toRadians(bearing(a.lat, a.lon, b.lat, b.lon));
        sumCos += l * Math.cos(bearing);
        sumSin += l * Math.sin(bearing);
        length += l;
      }
      Point p = points.get(from);
      samples.add(
          new RouteSamples.Sample(
              s, p.distance, p.lat, p.lon, p.elevation, sumCos, sumSin, length));
    }
    return new RouteSamples(List.copyOf(samples), total);
  }

  /** Initial great-circle bearing from a to b, degrees clockwise from north. */
  static double bearing(double lat1, double lon1, double lat2, double lon2) {
    double phi1 = Math.toRadians(lat1);
    double phi2 = Math.toRadians(lat2);
    double dLambda = Math.toRadians(lon2 - lon1);
    double y = Math.sin(dLambda) * Math.cos(phi2);
    double x =
        Math.cos(phi1) * Math.sin(phi2) - Math.sin(phi1) * Math.cos(phi2) * Math.cos(dLambda);
    return (Math.toDegrees(Math.atan2(y, x)) + 360) % 360;
  }

  private record Point(
      double lat, double lon, @Nullable Double elevation, double distance, boolean trackStart) {}

  private static List<Point> chain(List<List<TrackPoint>> tracks) {
    List<Point> points = new ArrayList<>();
    double offset = 0;
    for (List<TrackPoint> track : tracks) {
      if (track == null || track.isEmpty()) {
        continue;
      }
      boolean hasElevation = track.stream().anyMatch(p -> p.ele() != 0);
      double first = track.getFirst().dist();
      double last = offset;
      for (int i = 0; i < track.size(); i++) {
        TrackPoint p = track.get(i);
        // Never backwards: a track's cumulative distance is monotonic, but a sanitised import is
        // not something to bet the sampling loop on.
        last = Math.max(last, offset + p.dist() - first);
        points.add(
            new Point(
                p.lat(),
                p.lng(),
                hasElevation ? p.ele() : null,
                last,
                i == 0 && !points.isEmpty()));
      }
      offset = last;
    }
    return points;
  }
}
