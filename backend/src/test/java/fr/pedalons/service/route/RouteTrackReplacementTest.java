package fr.pedalons.service.route;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doCallRealMethod;
import static org.mockito.Mockito.doThrow;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.common.asset.AssetDto;
import fr.pedalons.dto.common.asset.AssetsDto;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.response.RouteDto;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.publication.PublicationEndCalculator;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import fr.pedalons.util.StoredObjects;
import fr.pedalons.util.TestDataService;
import io.github.glandais.engine.gpx.GpxDocument;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.mockito.InjectSpy;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.MediaType;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.InputStream;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import javax.imageio.ImageIO;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md API-128: editing a route's track gives its asset rows new files instead of new
 * rows, so the URLs published for them keep working — and a failed edit leaves neither a changed
 * row nor a file behind. The renderer is replaced by one that writes a real 1×1 PNG (or fails on
 * demand), so every route has its five assets.
 */
@QuarkusTest
class RouteTrackReplacementTest extends AbstractResourceTest {

  @Inject DomainResolver domainResolver;

  private static final Path EXAMPLE = new File("src/test/resources/example.gpx").toPath();
  private static final Path TWO_TRACKS = new File("src/test/resources/two_tracks.gpx").toPath();

  @InjectMock MapThumbnailRenderer renderer;
  @InjectSpy AssetService assetService;
  @InjectSpy PublicationEndCalculator publicationEndCalculator;

  @Inject RouteService routeService;
  @Inject GpxProcessingService gpxProcessingService;
  @Inject AssetRepository assetRepository;
  @Inject PedalonsQueryContext queryContext;
  @Inject StoredObjects stored;
  @Inject StorageService storageService;

  /** An asset row as the tests compare it before and after an edit. */
  private record Snap(
      Long id, AssetType type, long fileId, @Nullable Long revision, String key, String url) {}

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);
    rendererDraws();
  }

  private void rendererDraws() {
    try {
      doAnswer(
              invocation -> {
                File output = invocation.getArgument(0);
                ImageIO.write(new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB), "png", output);
                return null;
              })
          .when(renderer)
          .render(any(File.class), anyList(), anyString(), anyList());
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  private void rendererFails() {
    try {
      doThrow(new IllegalStateException("tiles down"))
          .when(renderer)
          .render(any(File.class), anyList(), anyString(), anyList());
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  private static RouteRequest request(String name) {
    return new RouteRequest(
        name,
        MediaDto.builder().markdown("Parcours").build(),
        SurfaceType.ROAD,
        Visibility.PUBLIC,
        null);
  }

  private RouteDto createRoute(Path gpx) {
    queryContext.setUserForTest(user1);
    return routeService.createRoute(team1Slug, request("Boucle"), gpx);
  }

  private void updateOverHttp(String slug, Path gpx) {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", request("Boucle"), MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", gpx.toFile(), "application/gpx+xml")
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + slug)
        .then()
        .statusCode(200);
  }

  private List<Snap> snaps(String routeId) {
    return QuarkusTransaction.requiringNew()
        .call(
            () -> {
              Long id = TsidUtils.toLong(routeId);
              // The URLs as the API publishes them
              AssetsDto dto =
                  assetService.getAssetsDto(
                      assetRepository.getEntityManager().find(TeamEntity.class, id));
              Map<String, String> urls = new HashMap<>();
              for (AssetDto asset :
                  Stream.of(
                          dto.originalGpx(),
                          dto.gpx(),
                          dto.fit(),
                          dto.thumbnailLight(),
                          dto.thumbnailDark())
                      .filter(Objects::nonNull)
                      .toList()) {
                urls.put(asset.id(), asset.url());
              }
              return assetRepository.list("teamEntity.id = ?1", id).stream()
                  .map(
                      a ->
                          new Snap(
                              a.getId(),
                              a.getType(),
                              a.getFileId(),
                              a.getContentRevision(),
                              assetService.getAssetKey(a.getTeam(), a.getFileId()),
                              urls.getOrDefault(TsidUtils.toString(a.getId()), "")))
                  .sorted(Comparator.comparing(Snap::type))
                  .toList();
            });
  }

  private static Map<AssetType, Snap> byType(List<Snap> snaps) {
    return snaps.stream().collect(Collectors.toMap(Snap::type, Function.identity()));
  }

  private byte[] read(String key) throws Exception {
    try (InputStream in = storageService.retrieve(key)) {
      return in.readAllBytes();
    }
  }

  private static Set<String> keys(List<Snap> snaps) {
    return snaps.stream().map(Snap::key).collect(Collectors.toSet());
  }

  // ==================== 1. The URLs survive an edit ====================

  @Test
  void editingTheTrack_keepsTheFiveAssetRows_andTheOldUrlServesTheNewContent() throws Exception {
    RouteDto created = createRoute(EXAMPLE);
    List<Snap> before = snaps(created.id());
    assertEquals(5, before.size(), before.toString());
    Set<String> bucketBefore = stored.assetKeys(team1);
    Snap oldFiltered = byType(before).get(AssetType.ROUTE_FILTERED_GPX);
    byte[] oldContent = read(oldFiltered.key());

    updateOverHttp(created.slug(), TWO_TRACKS);

    List<Snap> after = snaps(created.id());
    assertEquals(5, after.size(), after.toString());
    Map<AssetType, Snap> afterByType = byType(after);
    for (Snap old : before) {
      Snap now = afterByType.get(old.type());
      assertEquals(old.id(), now.id(), "same row: " + old.type());
      assertNotEquals(old.fileId(), now.fileId(), "new file: " + old.type());
      assertNotEquals(old.url(), now.url(), "new version: " + old.type());
      assertTrue(old.url().endsWith("?v=" + TsidUtils.toString(old.fileId())), old.url());
      assertTrue(now.url().endsWith("?v=" + TsidUtils.toString(now.fileId())), now.url());
      assertTrue(now.url().contains("/" + TsidUtils.toString(old.id()) + "/"), now.url());
      boolean content =
          old.type() == AssetType.ROUTE_ORIGINAL_GPX
              || old.type() == AssetType.ROUTE_FILTERED_GPX
              || old.type() == AssetType.ROUTE_FIT;
      if (content) {
        assertEquals(now.fileId(), now.revision(), "content revision: " + old.type());
      } else {
        assertNull(now.revision(), "a re-rendered thumbnail is not new content: " + old.type());
      }
    }

    // The URL published before the edit (old ?v included) answers with the new track.
    byte[] served =
        given()
            .urlEncodingEnabled(false)
            .when()
            .get(oldFiltered.url())
            .then()
            .statusCode(200)
            .extract()
            .asByteArray();
    assertArrayEquals(read(afterByType.get(AssetType.ROUTE_FILTERED_GPX).key()), served);
    assertFalse(Arrays.equals(oldContent, served), "the content is the new track's");

    // Old keys deleted once committed, new ones present, nothing else moved.
    Set<String> expected = new HashSet<>(bucketBefore);
    expected.removeAll(keys(before));
    expected.addAll(keys(after));
    assertEquals(expected, stored.assetKeys(team1));
  }

  // ==================== 1b. The raw track (API-147) ====================

  /** The number of points of every sanitized source track, as the pipeline receives them. */
  private List<Integer> sourceSizes(Path gpx) {
    return gpxProcessingService.rawTracks(gpxProcessingService.parseGpx(gpx)).paths().stream()
        .map(io.github.glandais.engine.path.Path::getSize)
        .toList();
  }

  private static void assertRawOf(List<Integer> expected, List<TestDataService.RawGeometry> raw) {
    assertEquals(expected.size(), raw.size(), "one raw geometry per track");
    for (int i = 0; i < raw.size(); i++) {
      assertEquals(expected.get(i), raw.get(i).points(), "every source point, track " + i);
      assertEquals(2, raw.get(i).dims(), "2D, no elevation, track " + i);
    }
  }

  @Test
  void anUploadedTrack_keepsItsRawGeometry_andEditingTheTrackReplacesIt() {
    RouteDto created = createRoute(EXAMPLE);
    Long id = TsidUtils.toLong(created.id());

    assertRawOf(sourceSizes(EXAMPLE), dataService.rawGeometries(id));

    updateOverHttp(created.slug(), TWO_TRACKS);

    assertRawOf(sourceSizes(TWO_TRACKS), dataService.rawGeometries(id));
  }

  // ==================== 2. A failed edit changes nothing ====================

  @Test
  void aFailureAfterPersistGpxData_rollsBack_andLeavesNoNewObject() {
    RouteDto created = createRoute(EXAMPLE);
    List<Snap> before = snaps(created.id());
    Set<String> bucketBefore = stored.assetKeys(team1);
    doThrow(new IllegalStateException("boom"))
        .when(publicationEndCalculator)
        .refreshUsersOf(any(Route.class));

    queryContext.setUserForTest(user1);
    assertThrows(
        RuntimeException.class,
        () -> routeService.updateRoute(team1Slug, created.slug(), request("Boucle"), TWO_TRACKS));

    // Same ids, same files (so same URLs); old keys still there, the uploads of the edit removed.
    assertEquals(before, snaps(created.id()));
    assertEquals(bucketBefore, stored.assetKeys(team1));
  }

  // ==================== 3. Thumbnails ====================

  @Test
  void aThumbnailThatCannotBeRendered_isRemoved_theOthersKeepTheirRows() {
    RouteDto created = createRoute(EXAMPLE);
    List<Snap> before = snaps(created.id());
    Set<String> bucketBefore = stored.assetKeys(team1);
    rendererFails();

    updateOverHttp(created.slug(), TWO_TRACKS);

    List<Snap> after = snaps(created.id());
    Map<AssetType, Snap> beforeByType = byType(before);
    assertEquals(
        Set.of(AssetType.ROUTE_ORIGINAL_GPX, AssetType.ROUTE_FILTERED_GPX, AssetType.ROUTE_FIT),
        byType(after).keySet(),
        "a missing thumbnail beats the previous track's");
    for (Snap now : after) {
      assertEquals(beforeByType.get(now.type()).id(), now.id());
    }
    Set<String> expected = new HashSet<>(bucketBefore);
    expected.removeAll(keys(before));
    expected.addAll(keys(after));
    assertEquals(expected, stored.assetKeys(team1));
  }

  @Test
  void legacyDuplicateRowsOfAType_collapseToTheNewest() {
    Route route = dataService.createRoute(team1, user1, "Héritage", Visibility.PUBLIC);
    var first =
        dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_LIGHT, "thumbnail.png");
    var second =
        dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_LIGHT, "thumbnail.png");
    long newest = Math.max(first.getId(), second.getId());
    String routeId = TsidUtils.toString(route.getId());
    List<Snap> before = snaps(routeId);
    assertEquals(2, before.size());

    queryContext.setUserForTest(user1);
    routeService.updateRoute(team1Slug, route.getSlug(), request("Héritage"), EXAMPLE);

    List<Snap> after = snaps(routeId);
    List<Snap> lights =
        after.stream().filter(s -> s.type() == AssetType.ROUTE_THUMBNAIL_LIGHT).toList();
    assertEquals(1, lights.size(), after.toString());
    assertEquals(newest, lights.getFirst().id());
    Snap newestBefore = before.stream().filter(s -> s.id() == newest).findFirst().orElseThrow();
    assertNotEquals(newestBefore.fileId(), lights.getFirst().fileId());
    // The dark variant did not exist: created. Both legacy files are gone.
    assertEquals(1, after.stream().filter(s -> s.type() == AssetType.ROUTE_THUMBNAIL_DARK).count());
    Set<String> bucket = stored.assetKeys(team1);
    for (Snap old : before) {
      assertFalse(bucket.contains(old.key()), "old file deleted: " + old.key());
    }
    assertTrue(bucket.containsAll(keys(after)));
  }

  // ==================== 4. processGpxData cleans its partial uploads ====================

  @Test
  void processGpxData_failingMidway_deletesWhatItAlreadyUploaded() throws Exception {
    Route route = dataService.createRoute(team1, user1, "Partiel", Visibility.PUBLIC);
    Set<String> bucketBefore = stored.assetKeys(team1);
    // Original and filtered GPX go through, the FIT upload fails.
    doCallRealMethod()
        .doCallRealMethod()
        .doThrow(new java.io.IOException("s3 down"))
        .when(assetService)
        .uploadTempFileToS3(any(), any(), anyLong(), anyString());
    GpxDocument gpx = gpxProcessingService.parseGpx(EXAMPLE);

    queryContext.setUserForTest(user1);
    assertThrows(BusinessException.class, () -> gpxProcessingService.processGpxData(route, gpx));

    assertEquals(bucketBefore, stored.assetKeys(team1));
  }

  // ==================== 5. waypoints survive a new track (WEB-100, C3c) ====================

  @Test
  void editingTheTrack_keepsWaypointRows_noOrphanRemovalLoss() {
    Path waypointsGpx = new File("src/test/resources/waypoints.gpx").toPath();
    RouteDto created = createRoute(waypointsGpx);
    // An author's waypoint, which must outlive the replacement of the track
    queryContext.setUserForTest(user1);
    routeService.updateRoute(
        team1Slug,
        created.slug(),
        new RouteRequest(
            "Boucle",
            MediaDto.builder().markdown("Parcours").build(),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null,
            null,
            null,
            List.of(
                new fr.pedalons.dto.routes.request.WaypointRequest(
                    null,
                    new fr.pedalons.common.GeoPoint(-1.5456685, 47.2024271),
                    fr.pedalons.enums.WaypointType.BIKE_SHOP,
                    "Atelier",
                    null,
                    null,
                    null))),
        null);
    String authorId = waypointNamed(created.slug(), "Atelier").id();

    updateOverHttp(created.slug(), waypointsGpx);

    var after =
        QuarkusTransaction.requiringNew()
            .call(() -> routeService.getDto(team1Slug, created.slug()));
    assertEquals(1, after.tracks().size());
    assertEquals(
        1, after.waypoints().stream().filter(w -> "AUTHOR".equals(w.origin().name())).count());
    assertEquals(authorId, waypointNamed(created.slug(), "Atelier").id(), "the same row");
    assertEquals(
        3,
        after.waypoints().stream().filter(w -> "IMPORTED".equals(w.origin().name())).count(),
        "the file's own, in place of the old ones");
  }

  private fr.pedalons.dto.routes.response.WaypointDto waypointNamed(String slug, String name) {
    return QuarkusTransaction.requiringNew()
        .call(() -> routeService.getDto(team1Slug, slug))
        .waypoints()
        .stream()
        .filter(w -> name.equals(w.name()))
        .findFirst()
        .orElseThrow();
  }
}
