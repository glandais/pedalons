package fr.pedalons.api.admin;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.lessThan;
import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.admin.ThumbnailRegenerationRequest;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import fr.pedalons.service.thumbnail.ThumbnailBackfill;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.awt.image.BufferedImage;
import java.io.File;
import java.time.Instant;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class AdminThumbnailResourceTest extends AbstractResourceTest {

  @InjectMock MapThumbnailRenderer renderer;

  @Inject AssetRepository assetRepository;
  @Inject AssetService assetService;
  @Inject StorageService storageService;
  @Inject EntityManager entityManager;
  @Inject ThumbnailBackfill thumbnailBackfill;

  private User platformAdmin;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    platformAdmin = dataService.createPlatformAdminUser("admin@example.com", "Platform Admin");
  }

  private String platformAdminToken() {
    return jwtService.generateAccessToken(platformAdmin);
  }

  @Test
  void regenerate_asNonAdmin_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(new ThumbnailRegenerationRequest(null, null, null, true, null, null, true, null))
        .when()
        .post("/api/admin/thumbnails/regenerate")
        .then()
        .statusCode(403);
  }

  @Test
  void regenerate_withoutCriterion_shouldReturn400() {
    given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .body(new ThumbnailRegenerationRequest(null, null, null, false, null, null, true, null))
        .when()
        .post("/api/admin/thumbnails/regenerate")
        .then()
        .statusCode(400);
  }

  @Test
  void regenerate_dryRun_listsARouteWithoutThumbnailAndDrawsNothing() {
    Route route = dataService.createRoute(team1, user1, "No Thumbnail Route");
    String routeId = TsidUtils.toString(route.getId());

    given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .body(new ThumbnailRegenerationRequest(null, null, null, true, null, null, true, null))
        .when()
        .post("/api/admin/thumbnails/regenerate")
        .then()
        .statusCode(200)
        .body("dryRun", equalTo(true))
        .body("entities.id", hasItem(routeId))
        .body("entities.find { it.id == '" + routeId + "' }.kind", equalTo("ROUTE"))
        .body("entities.find { it.id == '" + routeId + "' }.reasons", hasItem("MISSING"))
        .body("entities.find { it.id == '" + routeId + "' }.outcome", equalTo("PENDING"))
        .body("entities.find { it.id == '" + routeId + "' }.before", empty());
  }

  @Test
  void regenerate_withSizeThreshold_selectsOnlySmallThumbnails() {
    Route route = dataService.createRoute(team1, user1, "Tiny Thumbnail Route");
    // attachAsset stores a few dozen bytes of dummy content, far below any real map
    dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_LIGHT, "thumbnail-light.png");
    String routeId = TsidUtils.toString(route.getId());

    given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .body(new ThumbnailRegenerationRequest(null, null, 10_000, false, null, null, true, null))
        .when()
        .post("/api/admin/thumbnails/regenerate")
        .then()
        .statusCode(200)
        .body("entities.id", hasItem(routeId))
        .body("entities.find { it.id == '" + routeId + "' }.reasons", hasItem("SMALL_FILE"))
        .body("entities.find { it.id == '" + routeId + "' }.before[0].bytes", lessThan(10_000));
  }

  /**
   * docs/LEDGER_*.md API-128: the redraw gives the thumbnail rows new files, so the URLs already
   * published for them (asset id) go on working, and the previous files are deleted.
   */
  @Test
  void regenerate_keepsTheThumbnailAssetIds_andReplacesTheirFiles() throws Exception {
    doAnswer(
            invocation -> {
              File output = invocation.getArgument(0);
              ImageIO.write(new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB), "png", output);
              return null;
            })
        .when(renderer)
        .render(any(File.class), anyList(), anyString(), anyList());
    Route route = dataService.createRoute(team1, user1, "Tiny Thumbnails Route");
    Asset light =
        dataService.attachAsset(
            route, user1, AssetType.ROUTE_THUMBNAIL_LIGHT, "thumbnail-light.png");
    Asset dark =
        dataService.attachAsset(route, user1, AssetType.ROUTE_THUMBNAIL_DARK, "thumbnail-dark.png");
    String oldLightKey = assetService.getAssetKey(team1, light.getFileId());
    String oldDarkKey = assetService.getAssetKey(team1, dark.getFileId());

    given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .body(new ThumbnailRegenerationRequest(null, null, 10_000, false, null, null, false, null))
        .when()
        .post("/api/admin/thumbnails/regenerate")
        .then()
        .statusCode(200)
        .body(
            "entities.find { it.id == '" + TsidUtils.toString(route.getId()) + "' }.outcome",
            equalTo("REGENERATED"));

    Asset newLight =
        QuarkusTransaction.requiringNew().call(() -> assetRepository.findById(light.getId()));
    Asset newDark =
        QuarkusTransaction.requiringNew().call(() -> assetRepository.findById(dark.getId()));
    assertNotEquals(light.getFileId(), newLight.getFileId());
    assertNotEquals(dark.getFileId(), newDark.getFileId());
    // Re-rendered, not new content: nothing for GPS sync to notice
    assertNull(newLight.getContentRevision());
    assertNull(newDark.getContentRevision());
    assertTrue(storageService.exists(assetService.getAssetKey(team1, newLight.getFileId())));
    assertTrue(storageService.exists(assetService.getAssetKey(team1, newDark.getFileId())));
    assertFalse(storageService.exists(oldLightKey));
    assertFalse(storageService.exists(oldDarkKey));
  }

  private Route routeWithThumbnails(Team team, User owner, String name) {
    Route route = dataService.createRoute(team, owner, name);
    dataService.attachAsset(route, owner, AssetType.ROUTE_THUMBNAIL_LIGHT, "thumbnail-light.png");
    dataService.attachAsset(route, owner, AssetType.ROUTE_THUMBNAIL_DARK, "thumbnail-dark.png");
    return route;
  }

  /** The catch-up columns are not updatable through the entity: native update. */
  private void setCatchUp(Route route, Integer version, int attempts, Instant retryAt) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            entityManager
                .createNativeQuery(
                    "update team_entities set thumbnail_version = :v, thumbnail_attempts = :a,"
                        + " thumbnail_retry_at = :r where id = :id")
                .setParameter("v", version)
                .setParameter("a", attempts)
                .setParameter("r", retryAt == null ? null : java.sql.Timestamp.from(retryAt))
                .setParameter("id", route.getId())
                .executeUpdate());
  }

  private Object[] catchUpColumns(Route route) {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            (Object[])
                entityManager
                    .createNativeQuery(
                        "select thumbnail_version, thumbnail_attempts, thumbnail_retry_at"
                            + " from team_entities where id = :id")
                    .setParameter("id", route.getId())
                    .getSingleResult());
  }

  private io.restassured.response.ValidatableResponse dryRun(Boolean outdated, Boolean givenUp) {
    return given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .body(
            new ThumbnailRegenerationRequest(null, null, null, null, outdated, givenUp, true, null))
        .when()
        .post("/api/admin/thumbnails/regenerate")
        .then()
        .statusCode(200);
  }

  @Test
  void regenerate_outdated_selectsABehindEntityAndNotAStampedOne() {
    Route behind = routeWithThumbnails(team1, user1, "Behind Route");
    Route stamped = routeWithThumbnails(team1, user1, "Stamped Route");
    setCatchUp(stamped, MapThumbnailRenderer.VERSION, 0, null);
    String behindId = TsidUtils.toString(behind.getId());
    String stampedId = TsidUtils.toString(stamped.getId());

    dryRun(true, null)
        .body("entities.id", hasItem(behindId))
        .body("entities.id", not(hasItem(stampedId)))
        .body("entities.find { it.id == '" + behindId + "' }.reasons", hasItem("OUTDATED"));
  }

  @Test
  void regenerate_givenUp_selectsOnlyEntitiesAtTheAttemptCap() {
    Route gaveUp = routeWithThumbnails(team1, user1, "Given Up Route");
    Route failing = routeWithThumbnails(team1, user1, "Failing Route");
    setCatchUp(gaveUp, null, ThumbnailBackfill.MAX_ATTEMPTS, Instant.now());
    setCatchUp(failing, null, ThumbnailBackfill.MAX_ATTEMPTS - 1, Instant.now());
    String gaveUpId = TsidUtils.toString(gaveUp.getId());

    dryRun(null, true)
        .body("entities.id", hasItem(gaveUpId))
        .body("entities.id", not(hasItem(TsidUtils.toString(failing.getId()))))
        .body("entities.find { it.id == '" + gaveUpId + "' }.reasons", hasItem("GIVEN_UP"));
  }

  @Test
  void regenerate_ofAGivenUpEntity_stampsItAndClearsItsFailures() throws Exception {
    doAnswer(
            invocation -> {
              File output = invocation.getArgument(0);
              ImageIO.write(new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB), "png", output);
              return null;
            })
        .when(renderer)
        .render(any(File.class), anyList(), anyString(), anyList());
    Route route = routeWithThumbnails(team1, user1, "Given Up Redrawn Route");
    setCatchUp(route, null, ThumbnailBackfill.MAX_ATTEMPTS, Instant.now());

    given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .body(new ThumbnailRegenerationRequest(null, null, null, null, null, true, false, null))
        .when()
        .post("/api/admin/thumbnails/regenerate")
        .then()
        .statusCode(200)
        .body(
            "entities.find { it.id == '" + TsidUtils.toString(route.getId()) + "' }.outcome",
            equalTo("REGENERATED"));

    Object[] columns = catchUpColumns(route);
    assertEquals(MapThumbnailRenderer.VERSION, ((Number) columns[0]).intValue());
    assertEquals(0, ((Number) columns[1]).intValue());
    assertNull(columns[2]);
  }

  @Test
  void regenerate_outdatedOnly_keepsTheThumbnailsWhenTheRenderFails() throws Exception {
    doThrow(new java.io.IOException("tileserver down"))
        .when(renderer)
        .render(any(File.class), anyList(), anyString(), anyList());
    Route route = routeWithThumbnails(team1, user1, "Outdated Failing Route");

    given()
        .auth()
        .oauth2(platformAdminToken())
        .contentType("application/json")
        .body(new ThumbnailRegenerationRequest(null, null, null, null, true, null, false, null))
        .when()
        .post("/api/admin/thumbnails/regenerate")
        .then()
        .statusCode(200)
        .body(
            "entities.find { it.id == '" + TsidUtils.toString(route.getId()) + "' }.outcome",
            equalTo("FAILED"));

    // A restyle is no reason to lose them: both thumbnail rows are still there, version unchanged
    Number left =
        QuarkusTransaction.requiringNew()
            .call(() ->
                (Number)
                    entityManager
                        .createNativeQuery(
                            "select count(*) from assets where team_entity_id = :id"
                                + " and type like '%THUMBNAIL%'")
                        .setParameter("id", route.getId())
                        .getSingleResult());
    assertEquals(2, left.intValue());
    assertNull(catchUpColumns(route)[0]);
  }

  @Test
  void catchUp_countsBehindWaitingAndGivenUp_inTheTargetDomainOnly() {
    Route behind = routeWithThumbnails(team1, user1, "Behind Route");
    Route waiting = routeWithThumbnails(team1, user1, "Waiting Route");
    Route gaveUp = routeWithThumbnails(team1, user1, "Given Up Route");
    Route stamped = routeWithThumbnails(team1, user1, "Stamped Route");
    dataService.createRoute(team1, user1, "No Thumbnail Route");
    setCatchUp(waiting, null, 2, Instant.now().plusSeconds(3600));
    setCatchUp(gaveUp, null, ThumbnailBackfill.MAX_ATTEMPTS, Instant.now());
    setCatchUp(stamped, MapThumbnailRenderer.VERSION, 0, null);
    Domain other =
        dataService.createDomain("other.example.com", "Other", "https://other.example.com");
    User otherUser = dataService.createUser(other, "other@example.com", "Other");
    Team otherTeam =
        dataService.createTeam(other, otherUser, "Other Team", "other-team", Visibility.PUBLIC);
    routeWithThumbnails(otherTeam, otherUser, "Other Domain Route");
    assertNotNull(behind);

    given()
        .auth()
        .oauth2(platformAdminToken())
        .when()
        .get("/api/admin/thumbnails/catch-up")
        .then()
        .statusCode(200)
        .body("version", equalTo(MapThumbnailRenderer.VERSION))
        .body("behind", equalTo(2))
        .body("waiting", equalTo(1))
        .body("givenUp", equalTo(1))
        .body("enabled", equalTo(thumbnailBackfill.isEnabled()))
        .body("perHour", equalTo(thumbnailBackfill.getPerHour()));
  }

  @Test
  void catchUp_asNonAdmin_shouldReturn403() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/admin/thumbnails/catch-up")
        .then()
        .statusCode(403);
  }
}
