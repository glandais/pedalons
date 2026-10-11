package fr.pedalons.service.route;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.route.response.TrackMetadata;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.GpxPrivacyAssertions;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.github.glandais.engine.gpx.GpxDocument;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.File;
import java.io.InputStream;
import java.nio.file.Path;
import java.util.List;
import java.util.Set;
import org.geolatte.geom.G2D;
import org.geolatte.geom.LineString;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class GpxProcessingServiceTest extends AbstractBaseTest {

  @Inject PedalonsQueryContext context;
  @Inject GpxProcessingService gpxProcessingService;
  @Inject AssetService assetService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;

  private Domain domain;
  private Team team;
  private User user;
  private Route route;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    user = dataService.createUser("admin@example.com", "Admin");
    team = dataService.createTeam(user, "Test Team", "test-team", Visibility.PUBLIC);
    route = dataService.createRoute(team, user, "route", Visibility.PUBLIC);
    route.getTracks().clear();
    dataService.updateRoute(route);
  }

  @AfterEach
  void cleanup() {
    gpxProcessingService.deleteRouteFiles(route);
  }

  // ==================== Create Tracks - Single Track ====================

  @Test
  void createTracks_shouldProcessValidGpx() {
    Path gpxPath = getExampleGpxPath();

    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    TrackMetadata result = gpxProcessingService.createTracks(route, gpx);

    assertNotNull(result);
    assertTrue(result.distance() > 0);
    assertTrue(result.elevationGain() >= 0);
    assertNotNull(result.start());
    assertNotNull(result.end());

    List<GpxTrack> tracks = route.getTracks();
    assertFalse(tracks.isEmpty());
    assertEquals(1, tracks.size());
  }

  @Test
  void createTracks_shouldExtractCorrectMetadata() {
    Path gpxPath = getExampleGpxPath();

    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    TrackMetadata result = gpxProcessingService.createTracks(route, gpx);

    assertNotNull(result);
    assertTrue(result.distance() > 0, "Distance should be positive");
    assertTrue(result.elevationGain() >= 0, "Elevation gain should be non-negative");
    assertTrue(result.elevationLoss() <= 0, "Elevation loss should be negative");

    // Verify coordinates are in valid ranges
    G2D start = result.start().getPosition();
    G2D end = result.end().getPosition();
    assertTrue(start.getLat() >= -90 && start.getLat() <= 90, "Start latitude should be valid");
    assertTrue(start.getLon() >= -180 && start.getLon() <= 180, "Start longitude should be valid");
    assertTrue(end.getLat() >= -90 && end.getLat() <= 90, "End latitude should be valid");
    assertTrue(end.getLon() >= -180 && end.getLon() <= 180, "End longitude should be valid");
  }

  @Test
  void createTracks_shouldGenerateValidGeometry() {
    Path gpxPath = getExampleGpxPath();

    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    gpxProcessingService.createTracks(route, gpx);

    GpxTrack track = route.getTracks().getFirst();
    LineString<G2D> lineString = track.getGeometry();
    assertNotNull(lineString);

    for (G2D point : lineString.getPositions()) {
      double lng = point.getLon();
      double lat = point.getLat();
      assertTrue(lng >= -180 && lng <= 180, "Longitude should be valid");
      assertTrue(lat >= -90 && lat <= 90, "Latitude should be valid");
    }
  }

  @Test
  void createTracks_shouldGenerateTrackPoints() {
    Path gpxPath = getExampleGpxPath();

    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    gpxProcessingService.createTracks(route, gpx);

    GpxTrack track = route.getTracks().getFirst();
    List<GpxTrack.TrackPoint> trackPoints = track.getTrackPoints();
    assertFalse(trackPoints.isEmpty(), "Track points should not be empty");

    trackPoints.forEach(
        tp -> {
          assertTrue(tp.lat() >= -90 && tp.lat() <= 90, "Latitude should be valid");
          assertTrue(tp.lng() >= -180 && tp.lng() <= 180, "Longitude should be valid");
          assertTrue(tp.dist() >= 0, "Distance should be non-negative");
        });
  }

  @Test
  void createTracks_shouldStoreTrackMetrics() {
    Path gpxPath = getExampleGpxPath();

    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    gpxProcessingService.createTracks(route, gpx);

    GpxTrack track = route.getTracks().getFirst();
    assertTrue(track.getDistance() > 0, "Track distance should be positive");
    assertTrue(track.getElevationGain() >= 0, "Track elevation gain should be non-negative");
    assertTrue(track.getElevationLoss() <= 0, "Track elevation loss should be negative");
    assertNotNull(track.getClimbs(), "Track climbs should not be null");
  }

  @Test
  void createTracks_shouldUploadFilesToS3() {
    Path gpxPath = getExampleGpxPath();

    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    gpxProcessingService.createTracks(route, gpx);

    Set<Asset> assets = route.getAssets();
    assertFalse(assets.isEmpty(), "Route should have assets");
    for (Asset asset : assets) {
      // Verify content is retrievable from S3
      try (InputStream content = assetService.getAssetContent(asset)) {
        assertNotNull(content, "Content should be retrievable from S3: " + asset.getType());
        assertTrue(content.available() > 0, "Content should not be empty: " + asset.getType());
      } catch (Exception e) {
        fail(
            "Failed to retrieve asset content from S3: "
                + asset.getType()
                + " - "
                + e.getMessage());
      }
    }
  }

  /**
   * docs/LEDGER_*.md API-44: an activity export (timestamps, heart rate, cadence, power,
   * temperature, author) leaves nothing of it in any stored file — original and filtered GPX
   * (the latter is what every download and GPS-service upload serves) nor the FIT course.
   */
  @Test
  void createTracks_shouldStripTimestampsAndSensorsFromEveryStoredFile() throws Exception {
    GpxDocument gpx = gpxProcessingService.parseGpx(GpxPrivacyAssertions.activityGpx());
    context.setUserForTest(user);
    TrackMetadata result = gpxProcessingService.createTracks(route, gpx);

    assertTrue(result.distance() > 5000, "the geometry must survive: " + result.distance());
    assertEquals(
        3,
        route.getAssets().stream()
            .filter(
                a ->
                    a.getType() == AssetType.ROUTE_ORIGINAL_GPX
                        || a.getType() == AssetType.ROUTE_FILTERED_GPX
                        || a.getType() == AssetType.ROUTE_FIT)
            .count(),
        "every stored GPX and FIT file must be checked");
    for (Asset asset : route.getAssets()) {
      byte[] content;
      try (InputStream is = assetService.getAssetContent(asset)) {
        content = is.readAllBytes();
      }
      switch (asset.getType()) {
        case ROUTE_ORIGINAL_GPX, ROUTE_FILTERED_GPX ->
            GpxPrivacyAssertions.assertGpxHasNoPersonalData(
                new String(content, java.nio.charset.StandardCharsets.UTF_8));
        case ROUTE_FIT -> GpxPrivacyAssertions.assertFitHasNoPersonalData(content);
        default -> {}
      }
    }
    try (InputStream is = gpxProcessingService.getFilteredGpxContent(route)) {
      String filtered = new String(is.readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
      // Read back rather than grepped: whether the writer escapes non-ASCII is not the point.
      assertEquals(
          List.of("Café stop"),
          io.github.glandais.engine.gpx.GpxParserJvm.parse(filtered).getWaypoints().stream()
              .map(io.github.glandais.engine.gpx.GpxWaypoint::getName)
              .toList(),
          "the waypoint's name must survive");
    }
  }

  // ==================== Create Tracks - Multiple Tracks ====================

  @Test
  void createTracks_shouldProcessMultipleTracks() {
    Path gpxPath = getTwoTracksGpxPath();

    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    TrackMetadata result = gpxProcessingService.createTracks(route, gpx);

    assertNotNull(result);
    List<GpxTrack> tracks = route.getTracks();
    assertEquals(2, tracks.size(), "Should have 2 tracks");

    // Check each track has valid data
    for (GpxTrack track : tracks) {
      assertNotNull(track.getName(), "Track should have a name");
      assertNotNull(track.getGeometry(), "Track should have geometry");
      assertFalse(track.getTrackPoints().isEmpty(), "Track should have track points");
      assertTrue(track.getDistance() > 0, "Track distance should be positive");
    }
  }

  @Test
  void createTracks_shouldAggregateMetadataFromMultipleTracks() {
    Path gpxPath = getTwoTracksGpxPath();

    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    TrackMetadata result = gpxProcessingService.createTracks(route, gpx);

    List<GpxTrack> tracks = route.getTracks();
    float totalDistance = (float) tracks.stream().mapToDouble(GpxTrack::getDistance).sum();
    float totalElevationGain =
        (float) tracks.stream().mapToDouble(GpxTrack::getElevationGain).sum();
    float totalElevationLoss =
        (float) tracks.stream().mapToDouble(GpxTrack::getElevationLoss).sum();

    assertEquals(totalDistance, result.distance(), "Distance should be sum of all tracks");
    assertEquals(
        totalElevationGain, result.elevationGain(), "Elevation gain should be sum of all tracks");
    assertEquals(
        totalElevationLoss, result.elevationLoss(), "Elevation loss should be sum of all tracks");
  }

  @Test
  void createTracks_shouldUseFirstTrackStartAndLastTrackEnd() {
    Path gpxPath = getTwoTracksGpxPath();

    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    TrackMetadata result = gpxProcessingService.createTracks(route, gpx);

    List<GpxTrack> tracks = route.getTracks();
    GpxTrack firstTrack = tracks.getFirst();
    GpxTrack lastTrack = tracks.getLast();

    // Start should be from first track's first point
    GpxTrack.TrackPoint firstPoint = firstTrack.getTrackPoints().getFirst();
    assertEquals(firstPoint.lat(), result.start().getPosition().getLat(), 0.0001);
    assertEquals(firstPoint.lng(), result.start().getPosition().getLon(), 0.0001);

    // End should be from last track's last point
    GpxTrack.TrackPoint lastPoint = lastTrack.getTrackPoints().getLast();
    assertEquals(lastPoint.lat(), result.end().getPosition().getLat(), 0.0001);
    assertEquals(lastPoint.lng(), result.end().getPosition().getLon(), 0.0001);
  }

  // ==================== computeGpx (pure pipeline) ====================

  @Test
  void computeGpx_shouldWriteOriginalAndFilteredGpxAndFit() throws Exception {
    Path gpxPath = getExampleGpxPath();
    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);

    try (GpxProcessingService.ComputedGpx computed = gpxProcessingService.computeGpx(gpx)) {
      assertTrue(computed.originalGpx().exists(), "Original GPX should be written");
      assertTrue(computed.filteredGpx().exists(), "Filtered GPX should be written");
      assertTrue(computed.filteredGpx().length() > 0);
      assertTrue(computed.fitFile().length() > 0, "FIT export should be written");

      byte[] original = java.nio.file.Files.readAllBytes(computed.originalGpx().toPath());
      byte[] filtered = java.nio.file.Files.readAllBytes(computed.filteredGpx().toPath());
      assertFalse(
          java.util.Arrays.equals(java.nio.file.Files.readAllBytes(gpxPath), original),
          "original.gpx must be the sanitized re-serialization, never the uploaded bytes"
              + " (docs/LEDGER_*.md API-44)");
      assertFalse(
          java.util.Arrays.equals(original, filtered),
          "Filtered GPX must differ from the original: it is written after resampling,"
              + " elevation fixing and Douglas-Peucker simplification");
    }
  }

  @Test
  void computeGpx_shouldSerializeTheOriginalOfPlannerPoints() throws Exception {
    // The planner path: points, no uploaded file, no elevation and no time.
    GpxDocument gpx =
        gpxProcessingService.fromPoints(
            "planner", List.of(new GeoPoint(6.0, 45.0), new GeoPoint(6.01, 45.01)));

    try (GpxProcessingService.ComputedGpx computed = gpxProcessingService.computeGpx(gpx)) {
      String original = java.nio.file.Files.readString(computed.originalGpx().toPath());
      assertTrue(original.contains("<gpx"), "Original GPX should be a serialized document");
      assertTrue(computed.filteredGpx().length() > 0);
      assertTrue(computed.fitFile().length() > 0);
      assertEquals(1, computed.tracks().size());
    }
  }

  @Test
  void computeGpx_shouldDeleteTempFilesOnClose() {
    Path gpxPath = getExampleGpxPath();
    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);

    File original;
    File filtered;
    File fit;
    try (GpxProcessingService.ComputedGpx computed = gpxProcessingService.computeGpx(gpx)) {
      original = computed.originalGpx();
      filtered = computed.filteredGpx();
      fit = computed.fitFile();
      assertTrue(fit.exists(), "FIT temp file should exist before close");
    }

    assertFalse(original.exists(), "Original temp file should be deleted on close");
    assertFalse(filtered.exists(), "Filtered temp file should be deleted on close");
    assertFalse(fit.exists(), "FIT temp file should be deleted on close");
  }

  @Test
  void computeGpx_shouldComputeTracksAndAggregateMetadata() {
    Path gpxPath = getTwoTracksGpxPath();
    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);

    try (GpxProcessingService.ComputedGpx computed = gpxProcessingService.computeGpx(gpx)) {
      assertEquals(2, computed.tracks().size());
      for (GpxProcessingService.ComputedTrack track : computed.tracks()) {
        assertNotNull(track.line());
        assertFalse(track.trackPoints().isEmpty());
        assertNotNull(track.climbs());
        assertTrue(track.metadata().distance() > 0);
      }

      TrackMetadata aggregated = computed.aggregated();
      float summed =
          (float) computed.tracks().stream().mapToDouble(t -> t.metadata().distance()).sum();
      assertEquals(summed, aggregated.distance(), "Distance should be the sum of all tracks");
      assertNotNull(aggregated.start());
      assertNotNull(aggregated.end());
    }
  }

  @Test
  void computeGpx_shouldNotRequireAUserOrTeam() {
    // No context.setUserForTest(...): the pure pipeline must not touch the security context.
    Path gpxPath = getExampleGpxPath();
    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);

    try (GpxProcessingService.ComputedGpx computed = gpxProcessingService.computeGpx(gpx)) {
      assertFalse(computed.tracks().isEmpty());
    }
  }

  @Test
  void computeGpx_shouldThrowForEmptyGpx() {
    Path gpxPath = new File("src/test/resources/empty.gpx").toPath();
    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);

    PedalonsException exception =
        assertThrows(PedalonsException.class, () -> gpxProcessingService.computeGpx(gpx));

    assertTrue(exception.getMessage().contains("GPX_EMPTY"));
  }

  // ==================== Error Cases ====================

  @Test
  void createTracks_shouldThrowForEmptyGpx() {
    Path gpxPath = new File("src/test/resources/empty.gpx").toPath();

    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    PedalonsException exception =
        assertThrows(PedalonsException.class, () -> gpxProcessingService.createTracks(route, gpx));

    assertTrue(exception.getMessage().contains("GPX_EMPTY"));
  }

  @Test
  void createTracks_shouldThrowForInvalidGpx() {
    Path gpxPath = new File("src/test/resources/invalid.gpx").toPath();
    assertThrows(PedalonsException.class, () -> gpxProcessingService.parseGpx(gpxPath));
  }

  // ==================== File Management ====================

  @Test
  void getFilteredGpxContent_shouldReturnStreamIfExists() {
    Path gpxPath = getExampleGpxPath();
    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    gpxProcessingService.createTracks(route, gpx);

    InputStream result = gpxProcessingService.getFilteredGpxContent(route);

    assertNotNull(result);
  }

  @Test
  void getFilteredGpxContent_shouldThrowIfNotExists() {
    assertThrows(PedalonsException.class, () -> gpxProcessingService.getFilteredGpxContent(route));
  }

  @Test
  void getFitContent_shouldReturnStreamIfExists() {
    Path gpxPath = getExampleGpxPath();
    GpxDocument gpx = gpxProcessingService.parseGpx(gpxPath);
    context.setUserForTest(user);
    gpxProcessingService.createTracks(route, gpx);

    InputStream result = gpxProcessingService.getFitContent(route);

    assertNotNull(result);
  }

  @Test
  void getFitContent_shouldThrowIfNotExists() {
    assertThrows(PedalonsException.class, () -> gpxProcessingService.getFitContent(route));
  }

  @Test
  void deleteRouteFiles_shouldNotThrowIfDirectoryNotExists() {
    assertDoesNotThrow(() -> gpxProcessingService.deleteRouteFiles(route));
  }

  // ==================== Helper Methods ====================

  private Path getExampleGpxPath() {
    return new File("src/test/resources/example.gpx").toPath();
  }

  private Path getTwoTracksGpxPath() {
    return new File("src/test/resources/two_tracks.gpx").toPath();
  }
}
