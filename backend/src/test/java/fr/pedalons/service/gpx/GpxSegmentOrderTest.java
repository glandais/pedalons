package fr.pedalons.service.gpx;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.common.GeoDistance;
import fr.pedalons.service.route.GpxProcessingService;
import fr.pedalons.service.route.GpxProcessingService.RawTracks;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxModelJvm;
import io.github.glandais.engine.gpx.GpxParserJvm;
import io.github.glandais.engine.gpx.GpxPathKind;
import io.github.glandais.engine.gpx.GpxSegment;
import io.github.glandais.engine.gpx.GpxTrack;
import io.github.glandais.engine.gpx.GpxTrackPoint;
import io.github.glandais.engine.path.Path;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * The segments of a track written out of order or backwards are put back end to end — by vcyclist
 * ({@code GpxSegmentOrderJvm}) — on the two ways a GPX file comes in: the pipeline's {@code
 * rawTracks} and a merge of files (docs/LEDGER_*.md API-195).
 */
class GpxSegmentOrderTest {

  /** About 1.1 km of longitude at the equator. */
  private static final double STEP = 0.01;

  private static GpxDocument af3v() throws Exception {
    // AF3V « de Langogne à Le Puy-en-Velay » : one trk, nine trkseg in no order, four backwards.
    return GpxParserJvm.parse(
        Files.readString(
            java.nio.file.Path.of("src/test/resources/unordered_segments.gpx"),
            StandardCharsets.UTF_8));
  }

  private static double distance(double lat1, double lon1, double lat2, double lon2) {
    return GeoDistance.haversineMeters(lat1, lon1, lat2, lon2);
  }

  /** The longest step between consecutive points of {@code points}. */
  private static double longestStep(List<GpxTrackPoint> points) {
    double max = 0.0;
    for (int i = 1; i < points.size(); i++) {
      GpxTrackPoint a = points.get(i - 1);
      GpxTrackPoint b = points.get(i);
      max =
          Math.max(
              max,
              distance(
                  a.getLatitudeDeg(),
                  a.getLongitudeDeg(),
                  b.getLatitudeDeg(),
                  b.getLongitudeDeg()));
    }
    return max;
  }

  /** The longest step within any one segment of {@code track}: what the file itself spaces. */
  private static double longestStepWithinSegments(GpxTrack track) {
    return track.getSegments().stream()
        .mapToDouble(s -> longestStep(s.getPoints()))
        .max()
        .orElse(0.0);
  }

  @Test
  void rawTracks_af3vExport_isOneContinuousPath() throws Exception {
    GpxDocument doc = af3v();
    GpxTrack source = doc.getTracks().getFirst();
    double withinSegments = longestStepWithinSegments(source);
    // Read in file order, the track jumps kilometres across the map.
    assertTrue(longestStep(source.getPoints()) > 5_000.0);

    RawTracks raw = new GpxProcessingService().rawTracks(doc);

    assertEquals(1, raw.paths().size());
    Path path = raw.paths().getFirst();
    assertEquals(source.getPoints().size(), path.getSize(), "no point lost");
    double longest = 0.0;
    for (int i = 1; i < path.getSize(); i++) {
      longest =
          Math.max(
              longest,
              distance(
                  path.latitudeDeg(i - 1),
                  path.longitudeDeg(i - 1),
                  path.latitudeDeg(i),
                  path.longitudeDeg(i)));
    }
    // No step longer than the ones the file already has within a segment (~550 m).
    assertTrue(longest <= withinSegments + 1e-6, "longest step " + longest + " m");
    assertEquals(9, raw.doc().getTracks().getFirst().getSegments().size());
  }

  @Test
  void merge_trackWithShuffledSegments_isReorderedBeforeTheTracksAre() {
    GpxTrack track =
        new GpxTrack(
            "t",
            null,
            List.of(seg(0, STEP), seg(3 * STEP, 2 * STEP), seg(STEP, 2 * STEP)),
            GpxPathKind.TRACK,
            null,
            null);
    GpxDocument a = GpxModelJvm.document(List.of(track), "a", List.of());
    GpxDocument b =
        GpxModelJvm.document(
            List.of(
                new GpxTrack(
                    "u", null, List.of(seg(3 * STEP, 4 * STEP)), GpxPathKind.TRACK, null, null)),
            "b",
            List.of());

    GpxDocument merged = GpxTrackMerger.merge(List.of(a, b), "m");

    List<GpxTrackPoint> points = merged.getTracks().getFirst().getPoints();
    assertEquals(0.0, points.getFirst().getLongitudeDeg(), 1e-12);
    assertEquals(4 * STEP, points.getLast().getLongitudeDeg(), 1e-12);
    assertTrue(longestStep(points) < 1_000.0, "no jump back across the track");
  }

  private static GpxSegment seg(double from, double to) {
    return new GpxSegment(
        List.of(
            GpxModelJvm.trackPoint(0.0, from, 10.0),
            GpxModelJvm.trackPoint(0.0, (from + to) / 2, 20.0),
            GpxModelJvm.trackPoint(0.0, to, 30.0)));
  }
}
