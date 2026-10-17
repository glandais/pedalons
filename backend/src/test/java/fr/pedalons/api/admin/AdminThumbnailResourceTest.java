package fr.pedalons.api.admin;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.lessThan;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.admin.ThumbnailRegenerationRequest;
import fr.pedalons.enums.AssetType;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.thumbnail.MapThumbnailRenderer;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.awt.image.BufferedImage;
import java.io.File;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class AdminThumbnailResourceTest extends AbstractResourceTest {

  @InjectMock MapThumbnailRenderer renderer;

  @Inject AssetRepository assetRepository;
  @Inject AssetService assetService;
  @Inject StorageService storageService;

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
        .body(new ThumbnailRegenerationRequest(null, null, null, true, true, null))
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
        .body(new ThumbnailRegenerationRequest(null, null, null, false, true, null))
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
        .body(new ThumbnailRegenerationRequest(null, null, null, true, true, null))
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
        .body(new ThumbnailRegenerationRequest(null, null, 10_000, false, true, null))
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
        .body(new ThumbnailRegenerationRequest(null, null, 10_000, false, false, null))
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
}
