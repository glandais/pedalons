package fr.pedalons.service.route.waypoint;

import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.infrastructure.gpx.CoursePoint;
import fr.pedalons.infrastructure.gpx.WaypointFormats;
import java.util.Comparator;
import java.util.List;

/**
 * What the placed waypoints become in the files and the calls that carry them (docs/LEDGER_*.md
 * WEB-100, C3c). One selection for {@code route.fit}, Wahoo and Garmin, so they never disagree on
 * which points a device gets.
 */
public final class WaypointExports {

  /** A device holds few course points: past this the author's win over the imported ones. */
  public static final int MAX_COURSE_POINTS = 200;

  private WaypointExports() {}

  private static final Comparator<AnchoredWaypoint> BY_DISTANCE =
      Comparator.comparing(
          AnchoredWaypoint::distance, Comparator.nullsLast(Comparator.<Double>naturalOrder()));

  /**
   * The course points of a FIT file or a device: the points on the track (W5: one off the track is
   * kept and exported in the GPX only), the author's before the imported ones, at most {@value
   * #MAX_COURSE_POINTS}, in order of distance.
   */
  public static List<CoursePoint> coursePoints(List<AnchoredWaypoint> waypoints) {
    return waypoints.stream()
        .filter(w -> !w.offTrack())
        .sorted(
            Comparator.comparing(
                    (AnchoredWaypoint w) -> w.origin() == WaypointOrigin.AUTHOR ? 0 : 1)
                .thenComparing(BY_DISTANCE))
        .limit(MAX_COURSE_POINTS)
        .sorted(BY_DISTANCE)
        .map(
            w ->
                new CoursePoint(
                    w.distance(), w.type(), WaypointFormats.fitName(w.name(), w.type())))
        .toList();
  }

  /**
   * The {@code <wpt>} of the filtered GPX: all the points, those off the track last, with the
   * Garmin {@code sym}, the FIT name as {@code type} and the description.
   */
  public static List<io.github.glandais.engine.gpx.GpxWaypoint> gpx(
      List<AnchoredWaypoint> waypoints) {
    return waypoints.stream()
        .sorted(BY_DISTANCE)
        .map(
            w ->
                new io.github.glandais.engine.gpx.GpxWaypoint(
                    w.lat(),
                    w.lng(),
                    null,
                    w.name().isEmpty() ? null : w.name(),
                    w.description(),
                    WaypointFormats.garminSymbol(w.type()),
                    WaypointFormats.gpxType(w.type()),
                    null))
        .toList();
  }
}
