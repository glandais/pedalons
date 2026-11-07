package fr.pedalons.service.weather;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.gpx.GpxPreview.PreviewTrack;
import fr.pedalons.domain.route.GpxTrack.TrackPoint;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@link RouteSampleLookup#previewSamples}: the forecast points of a GPX preview are the ones the
 * static sampling gives for its tracks, cached by (preview, files revision) (docs/LEDGER_*.md
 * API-149).
 */
@QuarkusTest
class RouteSampleLookupPreviewTest extends AbstractResourceTest {

  @Inject RouteSampleLookup lookup;
  @Inject GpxPreviewRepository previewRepository;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private List<TrackPoint> north(double lat, double km) {
    return WeatherTestFixtures.northbound(lat, 4.0, km, 170);
  }

  private GpxPreview preview(List<TrackPoint> points, long revision) {
    return dataService.createGpxPreview(
        domain, user1, UUID.randomUUID(), points, revision, null, null, null);
  }

  private void replaceTracks(GpxPreview preview, List<List<TrackPoint>> tracks, long revision) {
    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              GpxPreview managed = previewRepository.findById(preview.getId());
              managed.setTracks(
                  tracks.stream()
                      .map(p -> new PreviewTrack("t", p, List.of(), 0f, 0f, 0f))
                      .toList());
              managed.setFilesRevision(revision);
            });
  }

  @Test
  void previewSamples_equalTheStaticSamplingOfTheStoredTrack() {
    List<TrackPoint> points = north(45.0, 40);
    GpxPreview preview = preview(points, 7L);

    RouteSamples samples = lookup.previewSamples(preview.getId(), 7L);

    assertEquals(RouteSampleLookup.sample(List.of(points), 15_000), samples);
  }

  @Test
  void previewSamples_chainTheTracksInTheOrderOfTheList() {
    List<TrackPoint> first = north(45.0, 20);
    List<TrackPoint> second = north(46.0, 20);
    GpxPreview preview = preview(first, 3L);
    replaceTracks(preview, List.of(first, second), 3L);

    RouteSamples samples = lookup.previewSamples(preview.getId(), 3L);

    assertEquals(RouteSampleLookup.sample(List.of(first, second), 15_000), samples);
    assertEquals(40_000, samples.totalDistance(), 0.001);
  }

  @Test
  void previewSamples_aNewRevisionIsANewGeometry() {
    GpxPreview preview = preview(north(45.0, 40), 1L);
    RouteSamples before = lookup.previewSamples(preview.getId(), 1L);

    replaceTracks(preview, List.of(north(47.0, 40)), 2L);
    RouteSamples after = lookup.previewSamples(preview.getId(), 2L);

    assertNotEquals(before.samples().getFirst().lat(), after.samples().getFirst().lat());
    assertEquals(47.0, after.samples().getFirst().lat(), 1e-6);
  }

  @Test
  void previewSamples_aKeyBehindTheRow_isEmptyAndNeverHoldsTheNewerGeometry() {
    GpxPreview preview = preview(north(45.0, 40), 1L);
    replaceTracks(preview, List.of(north(47.0, 40)), 2L);

    RouteSamples late = lookup.previewSamples(preview.getId(), 1L);

    assertTrue(late.isEmpty());
    // The row's own revision still reads its own geometry
    assertEquals(47.0, lookup.previewSamples(preview.getId(), 2L).samples().getFirst().lat(), 1e-6);
  }

  @Test
  void previewSamples_ofAnUnknownPreview_isEmpty() {
    assertTrue(lookup.previewSamples(1L, 0L).isEmpty());
  }

  @Test
  void previewSamples_aSecondCallCostsNoQuery() {
    GpxPreview preview = preview(north(45.0, 40), 5L);
    lookup.previewSamples(preview.getId(), 5L);

    long statements =
        queryStats.measure(
            "preview samples [cached]", () -> lookup.previewSamples(preview.getId(), 5L));

    assertEquals(0, statements);
  }
}
