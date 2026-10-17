package fr.pedalons.service.thumbnail;

import static fr.pedalons.util.WallTimes.wall;
import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.dto.rides.response.RideDto;
import fr.pedalons.dto.trips.request.TripRequest;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.asset.AssetRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.awt.image.BufferedImage;
import java.io.File;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import javax.imageio.ImageIO;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * docs/LEDGER_*.md MIG-4: {@code updateRide}/{@code updateTrip} redraw the thumbnails only when the
 * routes they are drawn from changed — a migration replay rewrites every ride with the same ones.
 * The renderer is replaced by one that writes a real 1×1 PNG, so the thumbnails exist and each draw
 * is one counted {@code render} call (light, then dark).
 */
@QuarkusTest
class ThumbnailRefreshTest extends AbstractResourceTest {

  @InjectMock MapThumbnailRenderer renderer;

  @Inject AssetRepository assetRepository;

  private final Instant nextWeek = Instant.now().plus(7, ChronoUnit.DAYS);

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
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

  private void verifyDraws(int count) throws Exception {
    verify(renderer, times(count)).render(any(File.class), anyList(), anyString(), anyList());
  }

  private RideRequest ride(String name, @Nullable String routeSlug) {
    return new RideRequest(
        name,
        MediaDto.builder().build(),
        wall(nextWeek),
        Status.PUBLISHED,
        Visibility.PUBLIC,
        routeSlug,
        null,
        null,
        null,
        List.of(new GroupRequest(null, "G1", null, null, null, null)),
        null);
  }

  private TripRequest trip(String name, @Nullable String routeSlug) {
    return new TripRequest(
        name,
        MediaDto.builder().build(),
        wall(nextWeek),
        Status.PUBLISHED,
        Visibility.PUBLIC,
        routeSlug,
        null,
        List.of(),
        null);
  }

  @Test
  void updateRide_redrawsTheThumbnails_onlyWhenItsRouteChanged() throws Exception {
    Route first = dataService.createRoute(team1, user1, "Premier parcours");
    Route second = dataService.createRoute(team1, user1, "Second parcours");

    RideDto created =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(ride("Sortie", first.getSlug()))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .as(RideDto.class);
    verifyDraws(2);
    clearInvocations(renderer);

    // Same route, new name and group id kept: a replay. Nothing to draw.
    RideRequest same =
        new RideRequest(
            "Sortie renommée",
            MediaDto.builder().build(),
            wall(nextWeek),
            Status.PUBLISHED,
            Visibility.PUBLIC,
            first.getSlug(),
            null,
            null,
            null,
            List.of(
                new GroupRequest(
                    created.getGroups().getFirst().id(), "G1", null, null, null, null)),
            null);
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(same)
        .when()
        .put("/api/teams/" + team1Slug + "/rides/" + created.getSlug())
        .then()
        .statusCode(200);
    verify(renderer, never()).render(any(File.class), anyList(), anyString(), anyList());

    // Another route: drawn again.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(ride("Sortie renommée", second.getSlug()))
        .when()
        .put("/api/teams/" + team1Slug + "/rides/" + created.getSlug())
        .then()
        .statusCode(200);
    verifyDraws(2);
  }

  @Test
  void updateTrip_redrawsTheThumbnails_onlyWhenItsRouteChanged() throws Exception {
    Route first = dataService.createRoute(team1, user1, "Premier parcours");
    Route second = dataService.createRoute(team1, user1, "Second parcours");

    String slug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(trip("Voyage", first.getSlug()))
            .when()
            .post("/api/teams/" + team1Slug + "/trips")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");
    verifyDraws(2);
    clearInvocations(renderer);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(trip("Voyage renommé", first.getSlug()))
        .when()
        .put("/api/teams/" + team1Slug + "/trips/" + slug)
        .then()
        .statusCode(200);
    verify(renderer, never()).render(any(File.class), anyList(), anyString(), anyList());

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(trip("Voyage renommé", second.getSlug()))
        .when()
        .put("/api/teams/" + team1Slug + "/trips/" + slug)
        .then()
        .statusCode(200);
    verifyDraws(2);
  }

  /** Asset id → file id of the thumbnails the ride and trip rows of team1 have. */
  private Map<Long, Long> thumbnailFiles() {
    return QuarkusTransaction.requiringNew()
        .call(
            () ->
                assetRepository
                    .list(
                        "team.id = ?1 and type in ?2",
                        team1.getId(),
                        List.of(
                            AssetType.RIDE_THUMBNAIL_LIGHT,
                            AssetType.RIDE_THUMBNAIL_DARK,
                            AssetType.TRIP_THUMBNAIL_LIGHT,
                            AssetType.TRIP_THUMBNAIL_DARK))
                    .stream()
                    .collect(Collectors.toMap(Asset::getId, Asset::getFileId)));
  }

  /**
   * docs/LEDGER_*.md API-128: a redraw gives the thumbnail rows new files — the ids, and so the
   * URLs clients and caches hold, stay.
   */
  @Test
  void updateRide_withAnotherRoute_keepsTheThumbnailRowsAndChangesTheirFiles() {
    Route first = dataService.createRoute(team1, user1, "Premier parcours");
    Route second = dataService.createRoute(team1, user1, "Second parcours");
    RideDto created =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(ride("Sortie", first.getSlug()))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .as(RideDto.class);
    Map<Long, Long> before = thumbnailFiles();
    assertEquals(2, before.size());

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(ride("Sortie", second.getSlug()))
        .when()
        .put("/api/teams/" + team1Slug + "/rides/" + created.getSlug())
        .then()
        .statusCode(200);

    Map<Long, Long> after = thumbnailFiles();
    assertEquals(before.keySet(), after.keySet(), "same asset rows");
    before.forEach((id, fileId) -> assertNotEquals(fileId, after.get(id), "new file for " + id));
    assertTrue(after.values().stream().noneMatch(before.values()::contains));
  }

  @Test
  void updateTrip_withAnotherRoute_keepsTheThumbnailRows() {
    Route first = dataService.createRoute(team1, user1, "Premier parcours");
    Route second = dataService.createRoute(team1, user1, "Second parcours");
    String slug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(trip("Voyage", first.getSlug()))
            .when()
            .post("/api/teams/" + team1Slug + "/trips")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");
    Map<Long, Long> before = thumbnailFiles();
    assertEquals(2, before.size());

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(trip("Voyage", second.getSlug()))
        .when()
        .put("/api/teams/" + team1Slug + "/trips/" + slug)
        .then()
        .statusCode(200);

    Map<Long, Long> after = thumbnailFiles();
    assertEquals(before.keySet(), after.keySet(), "same asset rows");
    before.forEach((id, fileId) -> assertNotEquals(fileId, after.get(id), "new file for " + id));
  }
}
