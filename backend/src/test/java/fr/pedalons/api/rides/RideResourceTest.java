package fr.pedalons.api.rides;

import static fr.pedalons.util.WallTimes.wall;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.common.request.SlugChangeRequest;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.dto.rides.response.RideDto;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.ride.RideGroupRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class RideResourceTest extends AbstractResourceTest {

  @Inject RideGroupRepository rideGroupRepository;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  @Test
  void createRide_asAdmin_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new RideRequest(
                "Sunday Morning Ride",
                MediaDto.builder().build(),
                wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                Status.DRAFT,
                Visibility.PUBLIC,
                null,
                null,
                null,
                null,
                List.of(new GroupRequest(null, "G1", null, null, null, null)),
                null))
        .when()
        .post("/api/teams/" + team1Slug + "/rides")
        .then()
        .statusCode(201)
        .body("name", equalTo("Sunday Morning Ride"))
        .body("dateTime", equalTo("2025-01-20T00:00:00Z"))
        .body("status", equalTo("DRAFT"))
        .body("groupCount", equalTo(1));
  }

  @Test
  void createRide_asMember_shouldBeDenied() {
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(
            new RideRequest(
                "Sunday Morning Ride",
                MediaDto.builder().build(),
                wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                Status.DRAFT,
                Visibility.PUBLIC,
                null,
                null,
                null,
                null,
                List.of(new GroupRequest(null, "G1", null, null, null, null)),
                null))
        .when()
        .post("/api/teams/" + team1Slug + "/rides")
        .then()
        .statusCode(403);
  }

  @Test
  void createRide_withoutAuth_shouldReturn401() {
    given()
        .contentType("application/json")
        .body(
            new RideRequest(
                "Sunday Morning Ride",
                MediaDto.builder().build(),
                wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                Status.DRAFT,
                Visibility.PUBLIC,
                null,
                null,
                null,
                null,
                List.of(new GroupRequest(null, "G1", null, null, null, null)),
                null))
        .when()
        .post("/api/teams/" + team1Slug + "/rides")
        .then()
        .statusCode(401);
  }

  @Test
  void createRide_withGroups_shouldCreateAllGroups() {
    var body =
        new RideRequest(
            "Multi-Group Ride",
            MediaDto.builder().build(),
            wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            null,
            null,
            List.of(
                new GroupRequest(null, "Fast", null, 32.0f, 10, null),
                new GroupRequest(null, "Fase", null, 28.0f, 15, null),
                new GroupRequest(null, "Social", null, 25.0f, null, null)),
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(body)
        .when()
        .post("/api/teams/" + team1Slug + "/rides")
        .then()
        .statusCode(201)
        .body("name", equalTo("Multi-Group Ride"))
        .body("groupCount", equalTo(3));
  }

  /** docs/LEDGER_*.md API-28: an incomplete media is normalised to empty, not a 500. */
  @Test
  void createRide_withEmptyAssetsObject_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            """
            {
              "name": "Sparse Media Ride",
              "media": {"markdown": "Hello", "assets": {}},
              "dateTime": "2025-01-20T00:00:00",
              "status": "DRAFT",
              "visibility": "PUBLIC",
              "groups": [{"name": "G1"}]
            }
            """)
        .when()
        .post("/api/teams/" + team1Slug + "/rides")
        .then()
        .statusCode(201)
        .body("media.markdown", equalTo("Hello"))
        .body("media.assets.images", empty())
        .body("media.assets.attachments", empty());
  }

  /** docs/LEDGER_*.md API-28: neither markdown nor assets — an empty media. */
  @Test
  void createRide_withEmptyMediaObject_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            """
            {
              "name": "No Media Ride",
              "media": {},
              "dateTime": "2025-01-20T00:00:00",
              "status": "DRAFT",
              "visibility": "PUBLIC",
              "groups": [{"name": "G1"}]
            }
            """)
        .when()
        .post("/api/teams/" + team1Slug + "/rides")
        .then()
        .statusCode(201)
        .body("media.markdown", equalTo(""))
        .body("media.assets.images", empty());
  }

  @Test
  void getRide_shouldReturnRideDetails() {
    String rideSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER2))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Get Test Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-22").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.DRAFT,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/" + rideSlug)
        .then()
        .statusCode(200)
        .body("slug", equalTo(rideSlug))
        .body("name", equalTo("Get Test Ride"))
        .body("groups", hasSize(1));
  }

  /**
   * docs/LEDGER_*.md API-16: « terminée » is computed by the server from the start time, and is
   * independent of the status — the clients no longer derive it each on their own.
   */
  @Test
  void getRide_finished_followsTheStartTime() {
    dataService.createRide(
        team1, user1, "Passée", "passee", Instant.now().minus(2, ChronoUnit.HOURS));
    dataService.createRide(
        team1, user1, "À venir", "a-venir", Instant.now().plus(2, ChronoUnit.DAYS));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/passee")
        .then()
        .statusCode(200)
        .body("finished", equalTo(true));
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/a-venir")
        .then()
        .statusCode(200)
        .body("finished", equalTo(false));
  }

  @Test
  void getRide_withoutAuth_shouldReturn404() {
    String rideSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER2))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Get Test Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-22").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.PUBLISHED,
                    Visibility.TEAM,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given().when().get("/api/teams/" + team1Slug + "/rides/" + rideSlug).then().statusCode(404);
  }

  @Test
  void updateRide_asAdmin_shouldSucceed() {
    RideDto ride =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Sunday Morning Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.DRAFT,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(
                        new GroupRequest(null, "G1", null, null, null, null),
                        new GroupRequest(null, "G0", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .as(RideDto.class);
    String rideSlug = ride.getSlug();
    String groupId = ride.getGroups().getFirst().id();

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new RideRequest(
                "Updated Title",
                MediaDto.builder().build(),
                wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                Status.PUBLISHED,
                Visibility.PUBLIC,
                null,
                null,
                null,
                null,
                List.of(
                    new GroupRequest(groupId, "G1 modified", null, null, null, null),
                    new GroupRequest(null, "G2", null, null, null, null)),
                null))
        .when()
        .put("/api/teams/" + team1Slug + "/rides/" + rideSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated Title"))
        .body("status", equalTo("PUBLISHED"));
  }

  @Test
  void updateRide_withoutAuth_shouldReturn401() {
    String rideSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Sunday Morning Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.DRAFT,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(
                        new GroupRequest(null, "G1", null, null, null, null),
                        new GroupRequest(null, "G0", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .as(RideDto.class)
            .getSlug();

    given()
        .contentType("application/json")
        .body("{\"name\": \"Updated Ride\"}")
        .when()
        .put("/api/teams/" + team1Slug + "/rides/" + rideSlug)
        .then()
        .statusCode(401);
  }

  @Test
  void deleteRide_asAdmin_shouldSucceed() {
    String rideSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "To be deleted",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.PUBLISHED,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/rides/" + rideSlug)
        .then()
        .statusCode(204);

    // Verify it's gone
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/" + rideSlug)
        .then()
        .statusCode(404);
  }

  @Test
  void deleteRide_withoutAuth_shouldReturn401() {
    String rideSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "To be deleted",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.PUBLISHED,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given().when().delete("/api/teams/" + team1Slug + "/rides/" + rideSlug).then().statusCode(401);
  }

  @Test
  void joinRide_shouldAddParticipant() {
    // Create and publish ride
    RideDto ride =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.now().plusDays(7).atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.PUBLISHED,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .as(RideDto.class);
    String rideSlug = ride.getSlug();
    String groupId = ride.getGroups().getFirst().id();

    // Member joins the ride
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/rides/" + rideSlug + "/groups/" + groupId + "/join")
        .then()
        .statusCode(201);
  }

  @Test
  void joinRide_whenNotPublished_shouldBeDenied() {
    // Create ride (stays in DRAFT)
    RideDto ride =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.DRAFT,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .as(RideDto.class);
    String rideSlug = ride.getSlug();
    String groupId = ride.getGroups().getFirst().id();

    // Member tries to join (should fail - ride not published)
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/rides/" + rideSlug + "/groups/" + groupId + "/join")
        .then()
        .statusCode(404);
  }

  @Test
  void leaveRide_shouldRemoveParticipant() {
    // Create and publish ride
    RideDto ride =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.now().plusDays(7).atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.PUBLISHED,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .as(RideDto.class);
    String rideSlug = ride.getSlug();
    String groupId = ride.getGroups().getFirst().id();

    // Member joins
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/rides/" + rideSlug + "/groups/" + groupId + "/join")
        .then()
        .statusCode(201);

    // Member leaves
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/rides/" + rideSlug + "/groups/" + groupId + "/leave")
        .then()
        .statusCode(204);
  }

  @Test
  void leaveRideGroup_withoutAuth_shouldReturn401() {
    // Create and publish ride
    RideDto ride =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.PUBLISHED,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .as(RideDto.class);
    String rideSlug = ride.getSlug();
    String groupId = ride.getGroups().getFirst().id();

    given()
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/rides/" + rideSlug + "/groups/" + groupId + "/leave")
        .then()
        .statusCode(401);
  }

  // ==================== Change Slug Tests ====================

  @Test
  void changeSlug_asAdmin_shouldSucceed() {
    String rideSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Slug Change Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.DRAFT,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(new SlugChangeRequest("new-ride-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/rides/" + rideSlug + "/slug")
        .then()
        .statusCode(200)
        .body("slug", equalTo("new-ride-slug"));
  }

  @Test
  void changeSlug_asOrganizer_shouldSucceed() {
    String rideSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Organizer Slug Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.DRAFT,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(new SlugChangeRequest("organizer-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/rides/" + rideSlug + "/slug")
        .then()
        .statusCode(200)
        .body("slug", equalTo("organizer-slug"));
  }

  @Test
  void changeSlug_asMember_shouldReturn404() {
    String rideSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Member Slug Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.DRAFT,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(new SlugChangeRequest("hacked-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/rides/" + rideSlug + "/slug")
        .then()
        .statusCode(404);
  }

  @Test
  void changeSlug_withoutAuth_shouldReturn401() {
    String rideSlug =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new RideRequest(
                    "Unauth Slug Ride",
                    MediaDto.builder().build(),
                    wall(LocalDate.parse("2025-01-20").atTime(0, 0).toInstant(ZoneOffset.UTC)),
                    Status.DRAFT,
                    Visibility.PUBLIC,
                    null,
                    null,
                    null,
                    null,
                    List.of(new GroupRequest(null, "G1", null, null, null, null)),
                    null))
            .when()
            .post("/api/teams/" + team1Slug + "/rides")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    given()
        .contentType("application/json")
        .body(new SlugChangeRequest("unauth-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/rides/" + rideSlug + "/slug")
        .then()
        .statusCode(401);
  }

  /**
   * Each group carries its own route's thumbnail, so two groups on two routes no longer share the
   * ride's picture; a group without a route gets none rather than the ride's (the client falls back
   * on the ride's thumbnail itself).
   */
  @Test
  void getRide_groupsCarryTheirOwnRouteThumbnail() {
    Ride ride =
        dataService.createRide(
            team1,
            user1,
            "Sortie à deux parcours",
            "deux-parcours",
            Instant.now().plusSeconds(3600));
    Route longRoute = dataService.createRoute(team1, user1, "Grande boucle");
    Route shortRoute = dataService.createRoute(team1, user1, "Petite boucle");
    dataService.setRideRoute(ride, longRoute);
    var longLight =
        dataService.attachAsset(longRoute, user1, AssetType.ROUTE_THUMBNAIL_LIGHT, "long-l.png");
    var longDark =
        dataService.attachAsset(longRoute, user1, AssetType.ROUTE_THUMBNAIL_DARK, "long-d.png");
    var shortDark =
        dataService.attachAsset(shortRoute, user1, AssetType.ROUTE_THUMBNAIL_DARK, "short-d.png");
    dataService.setRideGroupRoute(dataService.createRideGroup(user1, ride, "Rapide", 0), longRoute);
    dataService.setRideGroupRoute(dataService.createRideGroup(user1, ride, "Cool", 1), shortRoute);
    dataService.createRideGroup(user1, ride, "Sans parcours", 2);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/deux-parcours")
        .then()
        .statusCode(200)
        .body("groups[0].thumbnailLightUrl", containsString(TsidUtils.toString(longLight.getId())))
        .body("groups[0].thumbnailDarkUrl", containsString(TsidUtils.toString(longDark.getId())))
        .body("groups[0].thumbnailUrl", containsString(TsidUtils.toString(longLight.getId())))
        .body("groups[0].thumbnailUrl", containsString("/{size}?v="))
        // Only a dark variant: the light one is absent and the collapsed one falls to dark.
        .body("groups[1]", not(hasKey("thumbnailLightUrl")))
        .body("groups[1].thumbnailUrl", containsString(TsidUtils.toString(shortDark.getId())))
        // No route, no thumbnail — never the ride's, which the client already holds.
        .body("groups[2]", not(hasKey("thumbnailUrl")))
        .body("thumbnailUrl", containsString(TsidUtils.toString(longLight.getId())));
  }

  // --- switch (docs/LEDGER_*.md API-171)
  // ----------------------------------------------------------

  private String switchUrl(String rideSlug, RideGroup group) {
    return "/api/teams/"
        + team1Slug
        + "/rides/"
        + rideSlug
        + "/groups/"
        + TsidUtils.toString(group.getId())
        + "/switch";
  }

  @Test
  void switchGroup_shouldMoveTheRegistration_in201() {
    Ride ride =
        dataService.createRide(
            team1, user1, "Switch", "switch-http", Instant.now().plus(1, ChronoUnit.DAYS));
    RideGroup a = dataService.createRideGroup(user1, ride, "A", 0);
    RideGroup b = dataService.createRideGroup(user1, ride, "B", 1);
    dataService.createParticipation(a, user2);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post(switchUrl("switch-http", b))
        .then()
        .statusCode(201)
        .body("userId", equalTo(TsidUtils.toString(user2.getId())));

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/switch-http")
        .then()
        .statusCode(200)
        .body("registeredGroupId", equalTo(TsidUtils.toString(b.getId())))
        .body("groups[0].countParticipants", equalTo(0))
        .body("groups[1].countParticipants", equalTo(1));

    // Already there: nothing to do, 200.
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post(switchUrl("switch-http", b))
        .then()
        .statusCode(200);
  }

  @Test
  void switchGroup_refusals_shouldLeaveTheRegistrationWhereItWas() {
    Ride ride =
        dataService.createRide(
            team1, user1, "Switch", "switch-refused", Instant.now().plus(1, ChronoUnit.DAYS));
    RideGroup a = dataService.createRideGroup(user1, ride, "A", 0);
    RideGroup full = dataService.createRideGroupWithMaxParticipants(user1, ride, "Full", 1);
    dataService.createParticipation(full, user1);
    Ride other =
        dataService.createRide(
            team1, user1, "Other", "switch-other", Instant.now().plus(1, ChronoUnit.DAYS));
    RideGroup elsewhere = dataService.createRideGroup(user1, other, "Elsewhere", 0);

    // Not registered yet: join instead.
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post(switchUrl("switch-refused", a))
        .then()
        .statusCode(400)
        .body("code", equalTo("NOT_REGISTERED"));

    dataService.createParticipation(a, user2);
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post(switchUrl("switch-refused", full))
        .then()
        .statusCode(409)
        .body("code", equalTo("GROUP_FULL"));
    // A group of another ride, through this ride's URL.
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .when()
        .post(switchUrl("switch-refused", elsewhere))
        .then()
        .statusCode(404);
    given()
        .contentType("application/json")
        .when()
        .post(switchUrl("switch-refused", full))
        .then()
        .statusCode(401);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/switch-refused")
        .then()
        .statusCode(200)
        .body("registeredGroupId", equalTo(TsidUtils.toString(a.getId())));
  }

  // --- estimated arrival (docs/LEDGER_*.md API-172)
  // -------------------------------------------------

  @Test
  void getRide_groupsCarryTheirEstimatedArrival_onlyWithADistanceAndASpeed() {
    Instant departure = Instant.now().plus(1, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    Ride ride = dataService.createRide(team1, user1, "Estimée", "estimee", departure);
    Route route = dataService.createRoute(team1, user1, "Boucle 50");
    dataService.setRouteMetrics(route, 50_000f, 300f);
    dataService.setRideRoute(ride, route);
    RideGroup timed = dataService.createRideGroup(user1, ride, "Allure", 0);
    dataService.createRideGroup(user1, ride, "Sans allure", 1);
    QuarkusTransaction.requiringNew()
        .run(() -> rideGroupRepository.findById(timed.getId()).setAverageSpeed(25f));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/estimee")
        .then()
        .statusCode(200)
        // No route of its own: it rides the ride's 50 km, at 25 km/h — two hours.
        .body("groups[0].estimatedArrival", equalTo(departure.plus(2, ChronoUnit.HOURS).toString()))
        .body("groups[0].estimatedDurationMinutes", equalTo(120))
        // No speed: nothing, no 25 km/h default.
        .body("groups[1]", not(hasKey("estimatedArrival")))
        .body("groups[1]", not(hasKey("estimatedDurationMinutes")));
  }
}
