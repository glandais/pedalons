package fr.pedalons.service.surface;

import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.dto.routes.response.SurfaceSpanDto;
import fr.pedalons.enums.TrackSurface;
import fr.pedalons.service.surface.TraceSurfaceProjection.Range;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

class SurfaceRangesTest {

  private static Range<String> r(double from, double to, String v) {
    return new Range<>(from, to, v);
  }

  private static List<Range<String>> normalize(double length, Range<String>... ranges) {
    return SurfaceRanges.normalize(List.of(ranges), length, "unknown");
  }

  @SafeVarargs
  private static void assertCover(List<Range<String>> actual, Range<String>... expected) {
    assertEquals(List.of(expected), actual);
  }

  @Test
  @SuppressWarnings("unchecked")
  void gapsAndEndsAreUnknown() {
    assertCover(
        normalize(1000, r(100, 400, "paved"), r(600, 900, "gravel")),
        r(0, 100, "unknown"),
        r(100, 400, "paved"),
        r(400, 600, "unknown"),
        r(600, 900, "gravel"),
        r(900, 1000, "unknown"));
  }

  @Test
  @SuppressWarnings("unchecked")
  void nothingAtAllIsUnknown() {
    assertCover(normalize(500), r(0, 500, "unknown"));
  }

  @Test
  @SuppressWarnings("unchecked")
  void anOverlapGoesToTheLaterRange() {
    assertCover(
        normalize(1000, r(0, 600, "paved"), r(400, 1000, "gravel")),
        r(0, 400, "paved"),
        r(400, 1000, "gravel"));
  }

  @Test
  @SuppressWarnings("unchecked")
  void aRangeOverlappingSeveralEarlierOnesWinsOverEachAndKeepsTheOrder() {
    // dirt sits inside paved; gravel then reaches over dirt and over the rest of paved
    assertCover(
        normalize(1000, r(0, 1000, "paved"), r(100, 200, "dirt"), r(150, 300, "gravel")),
        r(0, 100, "paved"),
        r(100, 150, "dirt"),
        r(150, 300, "gravel"),
        r(300, 1000, "paved"));
  }

  @Test
  @SuppressWarnings("unchecked")
  void neighboursOfTheSameValueMerge() {
    assertCover(normalize(1000, r(0, 500, "paved"), r(500, 1000, "paved")), r(0, 1000, "paved"));
  }

  @Test
  @SuppressWarnings("unchecked")
  void aShortRangeGoesToTheLongerNeighbourAndTheNeighboursMerge() {
    assertCover(
        normalize(1000, r(0, 300, "paved"), r(300, 310, "gravel"), r(310, 1000, "paved")),
        r(0, 1000, "paved"));
    assertCover(
        normalize(1000, r(0, 300, "paved"), r(300, 310, "gravel"), r(310, 1000, "dirt")),
        r(0, 300, "paved"),
        r(300, 1000, "dirt"));
  }

  @Test
  @SuppressWarnings("unchecked")
  void theShortestGoesFirstAndTheEndsHaveOnlyOneNeighbour() {
    assertCover(
        normalize(
            1000, r(0, 5, "dirt"), r(5, 500, "paved"), r(500, 515, "gravel"), r(515, 1000, "path")),
        r(0, 515, "paved"),
        r(515, 1000, "path"));
    assertCover(normalize(1000, r(0, 990, "paved"), r(990, 1000, "gravel")), r(0, 1000, "paved"));
  }

  @Test
  @SuppressWarnings("unchecked")
  void boundariesAreRoundedToTheDecimetreAndCloseOnTheLength() {
    var out = normalize(1000.04, r(0, 400.0466, "paved"), r(400.0466, 1000.04, "gravel"));
    assertCover(out, r(0, 400.0, "paved"), r(400.0, 1000.0, "gravel"));
  }

  @Test
  void overlayCutsTheRangesThatOverflowARun() {
    var out =
        SurfaceRanges.overlay(
            List.of(r(0, 500, "paved"), r(500, 1000, "gravel")),
            List.<double[]>of(new double[] {400, 600}),
            "off_network");
    assertEquals(
        List.of(r(0, 400, "paved"), r(400, 600, "off_network"), r(600, 1000, "gravel")), out);
  }

  @Test
  void spansTakeTheClassesAndMergeThem() {
    TrackSurfaceDocument doc =
        new TrackSurfaceDocument(
            1,
            "ok",
            null,
            null,
            Instant.EPOCH,
            "bicycle",
            1000,
            List.of(
                new SurfaceRange(0, 200, "paved_smooth"),
                new SurfaceRange(200, 500, "paved"),
                new SurfaceRange(500, 800, "fine_gravel"),
                new SurfaceRange(800, 1000, "off_network")),
            List.of());
    List<SurfaceSpanDto> spans = SurfaceSpans.toDto(doc, 1000);
    assertEquals(
        List.of(
            new SurfaceSpanDto(0, 500, TrackSurface.PAVED),
            new SurfaceSpanDto(500, 800, TrackSurface.GRAVEL),
            new SurfaceSpanDto(800, 1000, TrackSurface.OFF_NETWORK)),
        spans);
  }

  @Test
  void spansRescaleToTheLengthTheTrackHasNow() {
    TrackSurfaceDocument doc =
        new TrackSurfaceDocument(
            1,
            "ok",
            null,
            null,
            Instant.EPOCH,
            "bicycle",
            1000,
            List.of(new SurfaceRange(0, 400, "paved"), new SurfaceRange(400, 1000, "dirt")),
            List.of());
    List<SurfaceSpanDto> longer = SurfaceSpans.toDto(doc, 1001);
    assertEquals(400.4, longer.get(0).to(), 0.001);
    assertEquals(1001.0, longer.getLast().to(), 0.0);
    List<SurfaceSpanDto> shorter = SurfaceSpans.toDto(doc, 999);
    assertEquals(399.6, shorter.get(0).to(), 0.001);
    assertEquals(shorter.get(0).to(), shorter.get(1).from(), 0.0);
    assertEquals(999.0, shorter.getLast().to(), 0.0);
    assertEquals(0.0, shorter.getFirst().from(), 0.0);
  }

  @Test
  void anUnknownCodeIsUnknown() {
    assertEquals(TrackSurface.UNKNOWN, TrackSurface.ofCode("cobblestone"));
    assertEquals(TrackSurface.UNKNOWN, TrackSurface.ofCode(null));
    assertEquals(TrackSurface.PATH, TrackSurface.ofCode("impassable"));
    assertEquals(TrackSurface.PAVED_ROUGH, TrackSurface.ofCode("paved_rough"));
  }
}
