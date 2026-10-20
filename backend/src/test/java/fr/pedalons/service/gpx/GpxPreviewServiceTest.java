package fr.pedalons.service.gpx;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.gpx.GpxPreview;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.gpx.GpxPreviewRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.GpxPrivacyAssertions;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.File;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class GpxPreviewServiceTest extends AbstractBaseTest {

  @Inject GpxPreviewService gpxPreviewService;
  @Inject GpxPreviewRepository gpxPreviewRepository;
  @Inject StorageService storageService;
  @Inject PedalonsQueryContext context;
  @Inject DomainResolver domainResolver;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;

  private Domain domain;
  private User user;
  private User otherUser;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    user = dataService.createUser("owner@example.com", "Owner");
    otherUser = dataService.createUser("other@example.com", "Other");
    context.setUserForTest(user);
  }

  private Path exampleGpx() {
    return new File("src/test/resources/example.gpx").toPath();
  }

  /** A track file's key in the revision the preview is on (the flat layout when it has none). */
  private static String key(GpxPreview preview, String fileName) {
    return GpxPreviewService.trackKey(preview, fileName);
  }

  @Test
  void create_shouldAnalyseGpxAndStoreBothFiles() {
    GpxPreview preview = gpxPreviewService.create(exampleGpx(), "fallback.gpx");

    assertNotNull(preview.getId());
    assertNotNull(preview.getPublicId());
    assertEquals(domain.getId(), preview.getDomain().getId());
    assertEquals(user.getId(), preview.getCreatedBy().getId());
    assertTrue(preview.getDistance() > 0);
    assertFalse(preview.getTracks().isEmpty());
    assertFalse(preview.getTracks().getFirst().trackPoints().isEmpty());

    assertTrue(storageService.exists(key(preview, "original.gpx")));
    assertTrue(storageService.exists(key(preview, "filtered.gpx")));
  }

  /** docs/LEDGER_*.md API-44: nothing of an activity's clock or sensors reaches a stored file. */
  @Test
  void create_shouldStripTimestampsAndSensorsFromStoredFiles() throws Exception {
    GpxPreview preview =
        gpxPreviewService.create(GpxPrivacyAssertions.activityGpx(), "activity.gpx");

    for (String file : List.of("original.gpx", "filtered.gpx")) {
      try (InputStream is = storageService.retrieve(key(preview, file))) {
        GpxPrivacyAssertions.assertGpxHasNoPersonalData(
            new String(is.readAllBytes(), StandardCharsets.UTF_8));
      }
    }
    GpxPrivacyAssertions.assertFitHasNoPersonalData(gpxPreviewService.getFitContent(preview));
    assertEquals("Morning Ride", preview.getName());
  }

  @Test
  void create_shouldFallBackToTheFileNameWhenTheGpxHasNoName() {
    GpxPreview preview = gpxPreviewService.create(exampleGpx(), "fallback.gpx");

    assertNotNull(preview.getName());
    assertFalse(preview.getName().isBlank());
  }

  /** docs/LEDGER_*.md API-115: most exporters name the track, not the file. */
  @Test
  void create_shouldTakeTheTrackNameWhenTheGpxHasNoMetadataName() {
    Path gpx = new File("src/test/resources/track_name_only.gpx").toPath();

    GpxPreview preview = gpxPreviewService.create(gpx, "trace.gpx");

    assertEquals("Boucle du dimanche", preview.getName());
  }

  @Test
  void create_shouldFallBackToTheFileNameWhenTheTrackNameIsBlank() {
    Path gpx = new File("src/test/resources/blank_track_name.gpx").toPath();

    GpxPreview preview = gpxPreviewService.create(gpx, "trace.gpx");

    assertEquals("trace.gpx", preview.getName());
  }

  @Test
  void createMergedPreview_shouldNameEachFileByItsTrackThenItsFileName() {
    List<Path> gpx =
        List.of(
            new File("src/test/resources/track_name_only.gpx").toPath(),
            new File("src/test/resources/blank_track_name.gpx").toPath());

    var preview = gpxPreviewService.createMergedPreview(gpx, List.of("a.gpx", "sans-nom.gpx"));

    assertEquals("Boucle du dimanche + sans-nom", preview.name());
  }

  @Test
  void create_shouldThrowForEmptyGpx() {
    Path empty = new File("src/test/resources/empty.gpx").toPath();

    assertThrows(PedalonsException.class, () -> gpxPreviewService.create(empty, "empty.gpx"));
  }

  @Test
  void getByPublicId_shouldReturnPreviewOfCurrentDomain() {
    GpxPreview created = gpxPreviewService.create(exampleGpx(), "example.gpx");

    GpxPreview found = gpxPreviewService.getByPublicId(created.getPublicId().toString());

    assertEquals(created.getId(), found.getId());
  }

  @Test
  void getByPublicId_shouldNotLeakAcrossDomains() {
    GpxPreview created = gpxPreviewService.create(exampleGpx(), "example.gpx");
    String publicId = created.getPublicId().toString();

    Domain otherDomain = dataService.createDomain("other.example.com", "Other", "http://other");
    domainResolver.setDomainForTest(otherDomain);

    assertThrows(NotFoundException.class, () -> gpxPreviewService.getByPublicId(publicId));
  }

  @Test
  void getPreview_shouldBeReadableAnonymouslyAndReportItAsNotOwned() {
    GpxPreview created = gpxPreviewService.create(exampleGpx(), "example.gpx");
    context.setUserForTest(null);

    var dto = gpxPreviewService.getPreview(created.getPublicId().toString());

    assertEquals(created.getPublicId().toString(), dto.id());
    assertFalse(dto.owned());
    assertFalse(dto.tracks().isEmpty());
  }

  @Test
  void getPreview_shouldReportOwnershipForTheCreator() {
    GpxPreview created = gpxPreviewService.create(exampleGpx(), "example.gpx");

    assertTrue(gpxPreviewService.getPreview(created.getPublicId().toString()).owned());
  }

  @Test
  void getByPublicId_shouldThrowForUnknownOrMalformedId() {
    String unknown = UUID.randomUUID().toString();

    assertThrows(NotFoundException.class, () -> gpxPreviewService.getByPublicId(unknown));
    assertThrows(NotFoundException.class, () -> gpxPreviewService.getByPublicId("not-a-uuid"));
  }

  @Test
  void getFilteredGpxContent_shouldReturnStoredBytes() {
    GpxPreview preview = gpxPreviewService.create(exampleGpx(), "example.gpx");

    byte[] content = gpxPreviewService.getFilteredGpxContent(preview);

    assertTrue(content.length > 0);
  }

  @Test
  void downloadOriginalGpx_shouldWriteATempFileTheCallerOwns() throws Exception {
    GpxPreview preview = gpxPreviewService.create(exampleGpx(), "example.gpx");

    Path downloaded = gpxPreviewService.downloadOriginalGpx(preview);
    try {
      assertTrue(java.nio.file.Files.size(downloaded) > 0);
    } finally {
      java.nio.file.Files.deleteIfExists(downloaded);
    }
  }

  @Test
  void delete_shouldRemoveRowAndFilesForTheCreator() {
    GpxPreview preview = gpxPreviewService.create(exampleGpx(), "example.gpx");
    String publicId = preview.getPublicId().toString();

    gpxPreviewService.delete(publicId);

    assertThrows(NotFoundException.class, () -> gpxPreviewService.getByPublicId(publicId));
    assertFalse(storageService.exists(key(preview, "original.gpx")));
    assertFalse(storageService.exists(key(preview, "filtered.gpx")));
  }

  @Test
  void delete_shouldRejectANonCreator() {
    GpxPreview preview = gpxPreviewService.create(exampleGpx(), "example.gpx");
    String publicId = preview.getPublicId().toString();

    context.setUserForTest(otherUser);

    assertThrows(ForbiddenException.class, () -> gpxPreviewService.delete(publicId));
    assertTrue(storageService.exists(key(preview, "original.gpx")));
  }

  @Test
  void purgeExpired_shouldOnlyDeletePreviewsPastTheRetentionWindow() {
    GpxPreview fresh = gpxPreviewService.create(exampleGpx(), "fresh.gpx");
    GpxPreview old = gpxPreviewService.create(exampleGpx(), "old.gpx");
    dataService.backdateGpxPreview(old, GpxPreviewService.RETENTION_DAYS + 1);

    int deleted = gpxPreviewService.purgeExpired();

    assertEquals(1, deleted);
    assertTrue(
        gpxPreviewRepository.findByPublicId(domain.getId(), fresh.getPublicId()).isPresent());
    assertTrue(gpxPreviewRepository.findByPublicId(domain.getId(), old.getPublicId()).isEmpty());
    assertFalse(storageService.exists(key(old, "original.gpx")));
    assertTrue(storageService.exists(key(fresh, "original.gpx")));
  }

  // ==================== Waypoints (docs/LEDGER_*.md WEB-100, C3c) ====================

  private static GpxPreview previewWith(
      Long filesRevision,
      java.util.List<GpxPreview.PreviewWaypoint> old,
      fr.pedalons.domain.gpx.PreviewWaypointsDocument details) {
    GpxPreview preview = new GpxPreview();
    preview.setFilesRevision(filesRevision);
    preview.setWaypoints(old);
    preview.setWaypointDetails(details);
    return preview;
  }

  private static fr.pedalons.domain.gpx.PreviewWaypointDetail detail(String name) {
    return new fr.pedalons.domain.gpx.PreviewWaypointDetail(
        "0abc", name, 45.0, 6.0, "WATER", "desc", 120.0, "AUTHOR");
  }

  @Test
  void legacyPreviewWithoutDetails_readsTheOldColumn() {
    GpxPreview preview =
        previewWith(7L, List.of(new GpxPreview.PreviewWaypoint("Source", 45.0, 6.0)), null);

    var waypoints = preview.readableWaypoints();

    assertEquals(1, waypoints.size());
    assertEquals("Source", waypoints.getFirst().name());
    assertEquals("INFO", waypoints.getFirst().type());
    assertEquals("IMPORTED", waypoints.getFirst().origin());
    assertNull(waypoints.getFirst().distance());
    assertNull(waypoints.getFirst().id());
  }

  @Test
  void staleDetailsRevision_fallsBackToTheOldColumn() {
    // The previous release rewrote the track (new files_revision) and left the details behind
    GpxPreview preview =
        previewWith(
            8L,
            List.of(new GpxPreview.PreviewWaypoint("Nouveau", 45.0, 6.0)),
            new fr.pedalons.domain.gpx.PreviewWaypointsDocument(7L, List.of(detail("Périmé"))));

    assertEquals("Nouveau", preview.readableWaypoints().getFirst().name());

    GpxPreview current =
        previewWith(
            7L,
            List.of(new GpxPreview.PreviewWaypoint("Nouveau", 45.0, 6.0)),
            new fr.pedalons.domain.gpx.PreviewWaypointsDocument(7L, List.of(detail("Courant"))));

    assertEquals("Courant", current.readableWaypoints().getFirst().name());
    assertEquals("WATER", current.readableWaypoints().getFirst().type());
  }

  @Test
  void oldColumn_keepsItsThreeFieldShape() throws Exception {
    // The previous release reads this column with a reader that fails on unknown properties
    String json =
        new com.fasterxml.jackson.databind.ObjectMapper()
            .writeValueAsString(new GpxPreview.PreviewWaypoint("Source", 45.0, 6.0));

    var node = new com.fasterxml.jackson.databind.ObjectMapper().readTree(json);
    assertEquals(3, node.size());
    assertTrue(node.has("name"));
    assertTrue(node.has("lat"));
    assertTrue(node.has("lng"));
  }

  @Test
  void detailsDocument_ignoresUnknownProperties() throws Exception {
    var mapper = new com.fasterxml.jackson.databind.ObjectMapper();
    String json =
        "{\"trackRevision\":5,\"future\":true,\"waypoints\":[{\"id\":\"x\",\"name\":\"n\","
            + "\"lat\":1.0,\"lng\":2.0,\"type\":\"TELEPORTER\",\"origin\":\"AUTHOR\","
            + "\"later\":1}]}";

    var document = mapper.readValue(json, fr.pedalons.domain.gpx.PreviewWaypointsDocument.class);

    assertEquals(5L, document.trackRevision());
    assertEquals("n", document.waypoints().getFirst().name());
    assertEquals(
        fr.pedalons.enums.WaypointType.INFO,
        fr.pedalons.enums.WaypointType.parseOrInfo(document.waypoints().getFirst().type()),
        "a type this release does not know reads as INFO");
  }
}
