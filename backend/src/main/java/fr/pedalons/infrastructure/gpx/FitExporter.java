package fr.pedalons.infrastructure.gpx;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import io.github.glandais.engine.path.Path;
import io.github.glandais.fit.FitCourse;
import io.github.glandais.fit.FitCoursePointSpec;
import io.github.glandais.fit.FitEncoder;
import io.github.glandais.fit.FitLap;
import io.github.glandais.fit.FitSegment;
import io.github.glandais.fit.FitSport;
import io.github.glandais.fit.FitUnits;
import io.github.glandais.fit.PathToFitJvm;
import java.util.ArrayList;
import java.util.List;
import org.jboss.logging.Logger;

/**
 * The single place where a FIT course is built from vcyclist paths.
 *
 * <p>Two callers need it and neither may diverge from the other: route import writes the FIT next to
 * the two GPX serializations, and the Wahoo upload builds one on the fly because Wahoo's {@code POST
 * /v1/routes} takes a FIT payload and nothing else.
 *
 * <p>{@code startTime} is mandatory (FIT has no relative clock): the first point's own timestamp,
 * but never before {@link #COURSE_START_MS}. A route carries no time — every stored track is
 * stripped of it (docs/LEDGER_*.md API-44) — so its first point sits at Unix epoch 0, which FIT
 * cannot represent: the unsigned field wraps and the course comes out dated 2106. Nor can it start
 * at the FIT epoch (1989-12-31), as it did until docs/LEDGER_*.md API-181: a FIT {@code date_time}
 * below {@code 0x10000000} is by specification a <em>system</em> time — seconds since the device
 * was switched on — not a date, and the SDK's decoder hands such a record back with no timestamp
 * at all. The course therefore starts at the first instant FIT reads as a date, in 1998. The
 * library rebases each path onto that start itself; rebasing here too would overwrite every
 * timestamp.
 *
 * <p><b>Every record still needs a timestamp of its own</b> (docs/LEDGER_*.md API-181). A course
 * whose records all carry the same instant is valid FIT, and a Garmin Edge draws it as one
 * straight line from the start to the finish: it orders and deduplicates the records by time. A
 * path without a clock is therefore given one, from its distances at {@link #COURSE_SPEED_MS} —
 * what every course planner does. It is a ride nobody made, starting in 1998: nothing of a
 * recording comes back through it.
 */
public final class FitExporter {

  private static final Logger LOG = Logger.getLogger(FitExporter.class);

  /**
   * The speed a clockless course is ridden at, 25 km/h. A head unit only uses it for its virtual
   * partner and its first time estimate; what matters is that time moves along the track.
   */
  static final double COURSE_SPEED_MS = 25 / 3.6;

  /**
   * Where a course without a clock starts: FIT timestamp {@code 0x10000000}, 1998-07-04T21:24:16Z,
   * the lowest one that is a date and not a system time.
   */
  static final long COURSE_START_MS = FitUnits.FIT_EPOCH_OFFSET_MS + 0x10000000L * 1000;

  /** Between two tracks of one file, so the second does not start on the first one's last second. */
  private static final long SEGMENT_GAP_MS = 1000;

  private FitExporter() {}

  /**
   * FIT bytes for {@code paths}, under the course name {@code name}.
   *
   * <p>Empty paths are filtered out because the writer rejects them outright.
   *
   * @throws BusinessException {@code GPX_EMPTY} when nothing is left to write, {@code GPX_FAILURE}
   *     when the writer refuses the geometry
   */
  public static byte[] toFitBytes(List<Path> paths, String name) {
    return toFitBytes(paths, name, List.of());
  }

  /**
   * As {@link #toFitBytes(List, String)}, with the course points of the route's waypoints
   * (docs/LEDGER_*.md WEB-100, C3c). The library puts each on the record nearest to its distance;
   * the names must already be cut ({@link WaypointFormats#fitName}). Without a point the bytes are
   * those of the call without them.
   */
  public static byte[] toFitBytes(List<Path> paths, String name, List<CoursePoint> points) {
    List<Path> sources = paths.stream().filter(p -> p.getSize() > 0).toList();
    if (sources.isEmpty()) {
      throw new BusinessException(ErrorCode.GPX_EMPTY);
    }
    List<Path> clocked = sources.stream().map(FitExporter::clocked).toList();
    long startMillis = Math.max((long) clocked.getFirst().time(0), COURSE_START_MS);
    try {
      List<FitCoursePointSpec> specs =
          points.stream()
              .map(p ->
                  new FitCoursePointSpec(
                      p.distanceM(), WaypointFormats.fitType(p.type()), p.name()))
              .toList();
      FitCourse course =
          PathToFitJvm.toFitCourse(
              clocked, name, startMillis, specs, FitSport.CYCLING, SEGMENT_GAP_MS);
      return FitEncoder.INSTANCE.encode(withReportedClimb(course, sources));
    } catch (Exception e) {
      throw new BusinessException(ErrorCode.GPX_FAILURE, e);
    }
  }

  /**
   * The same path when it has a usable clock, otherwise the same geometry riding at {@link
   * #COURSE_SPEED_MS}: each point at the second its distance falls in, and at least one second
   * after the previous one, since a FIT timestamp is a whole number of seconds and two points
   * closer than seven metres would share theirs.
   *
   * <p>No usable clock means no clock at all — a route, every point at the same instant — or one
   * that goes backwards: the writer requires monotonic time, which gpx2web never checked, and a
   * recording whose clock resynchronised mid-ride used to import fine. Rather than reject the
   * file, such a path is exported as a course, which is what these files are used for anyway.
   */
  private static Path clocked(Path path) {
    int size = path.getSize();
    boolean monotonic = true;
    for (int i = 1; i < size && monotonic; i++) {
      monotonic = path.time(i) >= path.time(i - 1);
    }
    if (monotonic && path.time(size - 1) > path.time(0)) {
      return path;
    }
    if (!monotonic) {
      LOG.warn("Path has non-monotonic timestamps, exporting it to FIT at the course speed");
    }
    Path out = path.copy();
    double millis = 0;
    out.setTime(0, millis);
    for (int i = 1; i < size; i++) {
      millis = Math.max(millis + 1000, Math.floor(path.distance(i) / COURSE_SPEED_MS) * 1000);
      out.setTime(i, millis);
    }
    // Speeds and the duration follow the new clock; this also drops the filtered climb, which
    // withReportedClimb puts back.
    out.computeDerivedData();
    return out;
  }

  /**
   * {@code course} with each lap's ascent and descent read from the path it was given for, rather
   * than from the re-clocked copy: recomputing a path's derived data forgets its filtered climb
   * (the figure shown everywhere else) and leaves the raw sum, which grows with the sampling.
   */
  private static FitCourse withReportedClimb(FitCourse course, List<Path> sources) {
    List<FitSegment> segments = new ArrayList<>(sources.size());
    for (int i = 0; i < sources.size(); i++) {
      FitSegment segment = course.getSegments().get(i);
      FitLap lap = segment.getLap();
      Path source = sources.get(i);
      segments.add(
          new FitSegment(
              segment.getRecords(),
              new FitLap(
                  lap.getStartTime(),
                  lap.getTotalElapsedTimeS(),
                  lap.getTotalTimerTimeS(),
                  lap.getTotalDistanceM(),
                  (int) Math.round(source.getReportedElevationGain()),
                  (int) Math.round(-source.getReportedElevationLoss()),
                  lap.getMaxSpeedMs(),
                  lap.getMinAltitudeM(),
                  lap.getMaxAltitudeM(),
                  lap.getStartLatitudeDeg(),
                  lap.getStartLongitudeDeg(),
                  lap.getEndLatitudeDeg(),
                  lap.getEndLongitudeDeg())));
    }
    return new FitCourse(
        course.getName(),
        course.getStartTime(),
        segments,
        course.getSport(),
        course.getCoursePoints());
  }
}
