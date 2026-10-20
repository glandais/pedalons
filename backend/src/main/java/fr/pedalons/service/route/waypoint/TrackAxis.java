package fr.pedalons.service.route.waypoint;

import fr.pedalons.domain.route.GpxTrack;
import io.github.glandais.engine.path.Path;
import java.util.ArrayList;
import java.util.List;

/**
 * The tracks of a route as arrays, on the axis of distances every client and the FIT export read:
 * the cumulative distance of each point, continued from one track to the next (docs/LEDGER_*.md
 * WEB-100, C3c). A waypoint's distance is a position on this axis.
 */
public final class TrackAxis {

  /** One track: its points, and the distance the tracks before it add. */
  record Segmented(double[] lat, double[] lng, double[] dist, double offset) {}

  private final List<Segmented> tracks;
  private final double total;

  private TrackAxis(List<Segmented> tracks, double total) {
    this.tracks = tracks;
    this.total = total;
  }

  List<Segmented> tracks() {
    return tracks;
  }

  /** The length of all the tracks. */
  public double total() {
    return total;
  }

  /** The processed paths a computation just produced, in order. */
  public static TrackAxis ofPaths(List<Path> paths) {
    List<Segmented> tracks = new ArrayList<>(paths.size());
    double offset = 0;
    for (Path path : paths) {
      int n = path.getSize();
      if (n == 0) {
        continue;
      }
      double[] lat = new double[n];
      double[] lng = new double[n];
      double[] dist = new double[n];
      for (int i = 0; i < n; i++) {
        lat[i] = path.latitudeDeg(i);
        lng[i] = path.longitudeDeg(i);
        dist[i] = path.distance(i);
      }
      tracks.add(new Segmented(lat, lng, dist, offset));
      offset += dist[n - 1];
    }
    return new TrackAxis(tracks, offset);
  }

  /** The stored tracks, already sorted by id (the order the distances are cumulated in). */
  public static TrackAxis ofTracks(List<GpxTrack> sortedById) {
    return ofPointLists(sortedById.stream().map(GpxTrack::getTrackPoints).toList());
  }

  /** The stored track points of each track, in order. */
  public static TrackAxis ofPointLists(List<List<GpxTrack.TrackPoint>> trackPoints) {
    List<Segmented> tracks = new ArrayList<>(trackPoints.size());
    double offset = 0;
    for (List<GpxTrack.TrackPoint> points : trackPoints) {
      int n = points.size();
      if (n == 0) {
        continue;
      }
      double[] lat = new double[n];
      double[] lng = new double[n];
      double[] dist = new double[n];
      for (int i = 0; i < n; i++) {
        GpxTrack.TrackPoint p = points.get(i);
        lat[i] = p.lat();
        lng[i] = p.lng();
        dist[i] = p.dist();
      }
      tracks.add(new Segmented(lat, lng, dist, offset));
      offset += dist[n - 1];
    }
    return new TrackAxis(tracks, offset);
  }
}
