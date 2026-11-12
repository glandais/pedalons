package fr.pedalons.infrastructure.gpx;

import static org.junit.jupiter.api.Assertions.*;

import com.garmin.fit.DecodeOptions;
import com.garmin.fit.FitDecoder;
import com.garmin.fit.RecordMesg;
import fr.pedalons.enums.WaypointType;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.github.glandais.engine.gpx.GpxToPathJvm;
import io.github.glandais.engine.gpx.GpxTrack;
import io.github.glandais.engine.gpx.GpxTrackPoint;
import io.github.glandais.engine.path.Path;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-181: a route has no clock, and its FIT course must still give every record
 * a timestamp of its own — a Garmin Edge draws records sharing one instant as a straight line from
 * the start to the finish.
 */
class FitExporterTest {

  /** About 111 m between two points, heading north. */
  private static final double STEP_DEG = 0.001;

  @Test
  void clocklessRoute_everyRecordIsLaterThanThePreviousOne() {
    List<Long> seconds = timestamps(FitExporter.toFitBytes(List.of(route(48.0, 50)), "x"));

    assertEquals(50, seconds.size());
    assertEquals(FitExporter.COURSE_START_MS / 1000, seconds.getFirst());
    assertStrictlyIncreasing(seconds);
    // 49 steps of ~111 m at 25 km/h
    double expected = 49 * 111.2 / FitExporter.COURSE_SPEED_MS;
    assertEquals(expected, seconds.getLast() - seconds.getFirst(), 5.0);
  }

  @Test
  void clocklessRoute_pointsCloserThanOneSecondOfRidingStillGetASecondEach() {
    // 1.1 m apart: a whole-second clock from the distance alone would repeat itself
    List<GpxTrackPoint> points = new ArrayList<>();
    for (int i = 0; i < 20; i++) {
      points.add(GpxModelJvm.trackPoint(48.0 + i * 0.00001, 2.0, 100.0));
    }
    List<Path> paths =
        GpxToPathJvm.tracksAsPaths(
            GpxModelJvm.document(List.of(GpxModelJvm.track(points, "t")), "x"));

    assertStrictlyIncreasing(timestamps(FitExporter.toFitBytes(paths, "x")));
  }

  @Test
  void clocklessRoute_severalTracks_timeKeepsMovingAcrossThem() {
    List<Path> paths =
        GpxToPathJvm.tracksAsPaths(
            GpxModelJvm.document(List.of(track(48.0, 10), track(48.5, 10)), "x"));

    List<Long> seconds = timestamps(FitExporter.toFitBytes(paths, "x"));

    assertEquals(20, seconds.size());
    assertStrictlyIncreasing(seconds);
  }

  @Test
  void clocklessRoute_aCoursePointTakesTheTimeOfItsRecord() {
    byte[] fit =
        FitExporter.toFitBytes(
            List.of(route(48.0, 50)),
            "x",
            List.of(new CoursePoint(2000.0, WaypointType.SUPPLY, "Eau")));

    var messages = new FitDecoder(fit).decode(new DecodeOptions()).getMessages();
    List<Long> records = timestamps(fit);
    long point =
        messages.getCoursePointMesgs().getFirst().getTimestamp().toEpochMilliseconds() / 1000;

    assertTrue(point > records.getFirst() && point < records.getLast());
    assertTrue(records.contains(point), "a course point sits on a record");
  }

  private static Path route(double lat, int size) {
    return GpxToPathJvm.tracksAsPaths(GpxModelJvm.document(List.of(track(lat, size)), "x"))
        .getFirst();
  }

  private static GpxTrack track(double lat, int size) {
    List<GpxTrackPoint> points = new ArrayList<>();
    for (int i = 0; i < size; i++) {
      points.add(GpxModelJvm.trackPoint(lat + i * STEP_DEG, 2.0, 100.0));
    }
    return GpxModelJvm.track(points, "t");
  }

  private static List<Long> timestamps(byte[] fit) {
    List<RecordMesg> records =
        new FitDecoder(fit).decode(new DecodeOptions()).getMessages().getRecordMesgs();
    return records.stream().map(r -> r.getTimestamp().toEpochMilliseconds() / 1000).toList();
  }

  private static void assertStrictlyIncreasing(List<Long> seconds) {
    for (int i = 1; i < seconds.size(); i++) {
      assertTrue(
          seconds.get(i) > seconds.get(i - 1),
          "record " + i + " shares its second with the previous one");
    }
  }
}
