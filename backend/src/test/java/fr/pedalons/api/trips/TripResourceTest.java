package fr.pedalons.api.trips;

import static fr.pedalons.util.WallTimes.wall;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.common.request.SlugChangeRequest;
import fr.pedalons.dto.trips.request.StageRequest;
import fr.pedalons.dto.trips.request.TripRequest;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TripResourceTest extends AbstractResourceTest {

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private TripRequest createTripRequest(String name, Status status, Visibility visibility) {
    return new TripRequest(
        name,
        MediaDto.builder().markdown("Trip description").build(),
        wall(Instant.now().plus(30, ChronoUnit.DAYS)),
        status,
        visibility,
        null,
        null,
        List.of(
            StageRequest.builder()
                .name("Stage 1")
                .dateTime(wall(Instant.now().plus(30, ChronoUnit.DAYS)))
                .media(MediaDto.builder().build())
                .build()),
        null);
  }

  private TripRequest createTripRequest(String name) {
    return createTripRequest(name, Status.DRAFT, Visibility.PUBLIC);
  }

  private String createTestTrip(String name, Status status, Visibility visibility) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(createTripRequest(name, status, visibility))
        .when()
        .post("/api/teams/" + team1Slug + "/trips")
        .then()
        .statusCode(201)
        .extract()
        .path("slug");
  }

  private String createTestTrip(String name) {
    return createTestTrip(name, Status.DRAFT, Visibility.PUBLIC);
  }

  // ==================== Create Trip Tests ====================

  @Test
  void createTrip_asAdmin_shouldSucceed() {
    TripRequest request = createTripRequest("Admin Trip");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/trips")
        .then()
        .statusCode(201)
        .body("name", equalTo("Admin Trip"))
        .body("media.markdown", equalTo("Trip description"))
        .body("status", equalTo("DRAFT"))
        .body("visibility", equalTo("PUBLIC"));
  }

  @Test
  void createTrip_asOrganizer_shouldSucceed() {
    TripRequest request = createTripRequest("Organizer Trip");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/trips")
        .then()
        .statusCode(201)
        .body("name", equalTo("Organizer Trip"));
  }

  @Test
  void createTrip_asMember_shouldBeDenied() {
    TripRequest request = createTripRequest("Member Trip");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/trips")
        .then()
        .statusCode(403);
  }

  @Test
  void createTrip_withoutAuth_shouldReturn401() {
    TripRequest request = createTripRequest("Unauth Trip");

    given()
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/trips")
        .then()
        .statusCode(401);
  }

  @Test
  void createTrip_asNonMember_shouldReturn403() {
    TripRequest request = createTripRequest("NonMember Trip");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/trips")
        .then()
        .statusCode(403);
  }

  @Test
  void createTrip_toNonexistentTeam_shouldReturn404() {
    TripRequest request = createTripRequest("Test Trip");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/nonexistent-team/trips")
        .then()
        .statusCode(404);
  }

  @Test
  void createTrip_withStages_shouldCreateAllStages() {
    TripRequest request =
        new TripRequest(
            "Multi-Stage Trip",
            MediaDto.builder().markdown("Trip with stages").build(),
            wall(Instant.now().plus(30, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            List.of(
                StageRequest.builder()
                    .name("Day 1")
                    .dateTime(wall(Instant.now().plus(30, ChronoUnit.DAYS)))
                    .media(MediaDto.builder().build())
                    .build(),
                StageRequest.builder()
                    .name("Day 2")
                    .dateTime(wall(Instant.now().plus(31, ChronoUnit.DAYS)))
                    .media(MediaDto.builder().build())
                    .build(),
                StageRequest.builder()
                    .name("Day 3")
                    .dateTime(wall(Instant.now().plus(32, ChronoUnit.DAYS)))
                    .media(MediaDto.builder().build())
                    .build()),
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/trips")
        .then()
        .statusCode(201)
        .body("name", equalTo("Multi-Stage Trip"))
        .body("stages", hasSize(3));
  }

  @Test
  void createTrip_withPublishAt_shouldSucceed() {
    TripRequest request =
        new TripRequest(
            "Scheduled Trip",
            MediaDto.builder().markdown("Scheduled content").build(),
            wall(Instant.now().plus(30, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            wall(Instant.now().plus(7, ChronoUnit.DAYS)),
            List.of(
                StageRequest.builder()
                    .name("Stage 1")
                    .dateTime(wall(Instant.now().plus(30, ChronoUnit.DAYS)))
                    .media(MediaDto.builder().build())
                    .build()),
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .post("/api/teams/" + team1Slug + "/trips")
        .then()
        .statusCode(201)
        .body("name", equalTo("Scheduled Trip"))
        .body("publishAt", notNullValue());
  }

  // ==================== Get Trip Tests ====================

  @Test
  void getTrip_withoutAuth_shouldSucceed() {
    String tripSlug = createTestTrip("Public Trip", Status.PUBLISHED, Visibility.PUBLIC);

    given()
        .when()
        .get("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(200)
        .body("slug", equalTo(tripSlug))
        .body("name", equalTo("Public Trip"));
  }

  @Test
  void getTrip_asMember_shouldSucceed() {
    String tripSlug = createTestTrip("Member Get Trip", Status.PUBLISHED, Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Member Get Trip"));
  }

  @Test
  void getTrip_asNonMember_shouldSucceed() {
    String tripSlug = createTestTrip("NonMember Get Trip", Status.PUBLISHED, Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("NonMember Get Trip"));
  }

  @Test
  void getTrip_withoutAuth_whenTeamOnly_shouldReturn404() {
    String tripSlug = createTestTrip("Team Only Trip", Status.PUBLISHED, Visibility.TEAM);

    given().when().get("/api/teams/" + team1Slug + "/trips/" + tripSlug).then().statusCode(404);
  }

  @Test
  void getTrip_nonexistent_shouldReturn404() {
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/trips/nonexistent-trip")
        .then()
        .statusCode(404);
  }

  @Test
  void getTrip_toNonexistentTeam_shouldReturn404() {
    given().when().get("/api/teams/nonexistent-team/trips/some-trip").then().statusCode(404);
  }

  // ==================== Update Trip Tests ====================

  @Test
  void updateTrip_asAdmin_shouldSucceed() {
    String tripSlug = createTestTrip("Original Trip");

    TripRequest request =
        new TripRequest(
            "Updated Trip",
            MediaDto.builder().markdown("Updated description").build(),
            wall(Instant.now().plus(45, ChronoUnit.DAYS)),
            Status.PUBLISHED,
            Visibility.PUBLIC,
            null,
            null,
            List.of(
                StageRequest.builder()
                    .name("Updated Stage")
                    .dateTime(wall(Instant.now().plus(45, ChronoUnit.DAYS)))
                    .media(MediaDto.builder().build())
                    .build()),
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated Trip"))
        .body("media.markdown", equalTo("Updated description"))
        .body("status", equalTo("PUBLISHED"));
  }

  @Test
  void updateTrip_asOrganizer_shouldSucceed() {
    String tripSlug = createTestTrip("Organizer Update Trip");

    TripRequest request =
        new TripRequest(
            "Updated by Organizer",
            MediaDto.builder().markdown("Organizer updated").build(),
            wall(Instant.now().plus(45, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            List.of(
                StageRequest.builder()
                    .name("Stage")
                    .dateTime(wall(Instant.now().plus(45, ChronoUnit.DAYS)))
                    .media(MediaDto.builder().build())
                    .build()),
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated by Organizer"));
  }

  @Test
  void updateTrip_asMember_shouldBeDenied() {
    String tripSlug = createTestTrip("Member Update Trip");

    TripRequest request =
        new TripRequest(
            "Hacked by Member",
            MediaDto.builder().build(),
            wall(Instant.now().plus(45, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            List.of(
                StageRequest.builder()
                    .name("Stage")
                    .dateTime(wall(Instant.now().plus(45, ChronoUnit.DAYS)))
                    .media(MediaDto.builder().build())
                    .build()),
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(404);
  }

  @Test
  void updateTrip_withoutAuth_shouldReturn401() {
    String tripSlug = createTestTrip("Unauth Update Trip");

    TripRequest request =
        new TripRequest(
            "Unauthorized Update",
            MediaDto.builder().build(),
            wall(Instant.now().plus(45, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            List.of(
                StageRequest.builder()
                    .name("Stage")
                    .dateTime(wall(Instant.now().plus(45, ChronoUnit.DAYS)))
                    .media(MediaDto.builder().build())
                    .build()),
            null);

    given()
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(401);
  }

  @Test
  void updateTrip_asNonMember_shouldReturn403() {
    String tripSlug = createTestTrip("NonMember Update Trip");

    TripRequest request =
        new TripRequest(
            "Hacked by NonMember",
            MediaDto.builder().build(),
            wall(Instant.now().plus(45, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            List.of(
                StageRequest.builder()
                    .name("Stage")
                    .dateTime(wall(Instant.now().plus(45, ChronoUnit.DAYS)))
                    .media(MediaDto.builder().build())
                    .build()),
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(404);
  }

  @Test
  void updateTrip_nonexistent_shouldReturn404() {
    TripRequest request =
        new TripRequest(
            "Nonexistent",
            MediaDto.builder().build(),
            wall(Instant.now().plus(45, ChronoUnit.DAYS)),
            Status.DRAFT,
            Visibility.PUBLIC,
            null,
            null,
            List.of(
                StageRequest.builder()
                    .name("Stage")
                    .dateTime(wall(Instant.now().plus(45, ChronoUnit.DAYS)))
                    .media(MediaDto.builder().build())
                    .build()),
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(request)
        .when()
        .put("/api/teams/" + team1Slug + "/trips/nonexistent-trip")
        .then()
        .statusCode(404);
  }

  // ==================== Delete Trip Tests ====================

  @Test
  void deleteTrip_asAdmin_shouldSucceed() {
    String tripSlug = createTestTrip("To Delete");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(204);

    // Verify trip is no longer accessible (403 for security by obscurity)
    given().when().get("/api/teams/" + team1Slug + "/trips/" + tripSlug).then().statusCode(404);
  }

  @Test
  void deleteTrip_asOrganizer_shouldSucceed() {
    String tripSlug = createTestTrip("Organizer Delete");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .delete("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(204);
  }

  @Test
  void deleteTrip_asMember_shouldBeDenied() {
    String tripSlug = createTestTrip("Member Delete");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .delete("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(404);
  }

  @Test
  void deleteTrip_withoutAuth_shouldReturn401() {
    String tripSlug = createTestTrip("Unauth Delete");

    given().when().delete("/api/teams/" + team1Slug + "/trips/" + tripSlug).then().statusCode(401);
  }

  @Test
  void deleteTrip_asNonMember_shouldReturn403() {
    String tripSlug = createTestTrip("NonMember Delete");

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .delete("/api/teams/" + team1Slug + "/trips/" + tripSlug)
        .then()
        .statusCode(404);
  }

  @Test
  void deleteTrip_nonexistent_shouldReturn404() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/trips/nonexistent-trip")
        .then()
        .statusCode(404);
  }

  // ==================== Join Trip Tests ====================

  @Test
  void joinTrip_asMember_shouldSucceed() {
    String tripSlug = createTestTrip("Join Trip", Status.PUBLISHED, Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/join")
        .then()
        .statusCode(201);
  }

  @Test
  void joinTrip_asOrganizer_shouldSucceed() {
    String tripSlug = createTestTrip("Organizer Join Trip", Status.PUBLISHED, Visibility.PUBLIC);

    given()
        .contentType("application/json")
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/join")
        .then()
        .statusCode(201);
  }

  @Test
  void joinTrip_asNonMember_shouldReturn403() {
    String tripSlug = createTestTrip("NonMember Join Trip", Status.PUBLISHED, Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/join")
        .then()
        .statusCode(403);
  }

  @Test
  void joinTrip_withoutAuth_shouldReturn401() {
    String tripSlug = createTestTrip("Unauth Join Trip", Status.PUBLISHED, Visibility.PUBLIC);

    given()
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/join")
        .then()
        .statusCode(401);
  }

  @Test
  void joinTrip_whenNotPublished_shouldBeDenied() {
    String tripSlug = createTestTrip("Draft Trip", Status.DRAFT, Visibility.PUBLIC);

    given()
        .contentType("application/json")
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/join")
        .then()
        .statusCode(404);
  }

  /**
   * The platform admin's bypass gets them past the access check, not past the trip's status: a
   * draft or cancelled trip takes no one, as a ride does (docs/LEDGER_*.md API-176). Their
   * permissions block says {@code canRegister: false} for the same trips.
   */
  @Test
  void joinTrip_whenNotPublished_isRefused_evenToAPlatformAdmin() {
    dataService.createPlatformAdminUser("root@example.com", "Root");
    Instant soon = Instant.now().plus(30, ChronoUnit.DAYS);
    for (Status status : List.of(Status.DRAFT, Status.CANCELLED)) {
      String tripSlug =
          dataService
              .createTrip(
                  team1, user1, "Admin " + status + " Trip", soon, Visibility.PUBLIC, status, null)
              .getSlug();
      given()
          .auth()
          .oauth2(getAccessToken("root"))
          .when()
          .get("/api/teams/" + team1Slug + "/trips/" + tripSlug)
          .then()
          .statusCode(200)
          .body("permissions.canRegister", equalTo(false));
      given()
          .contentType("application/json")
          .auth()
          .oauth2(getAccessToken("root"))
          .when()
          .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/join")
          .then()
          .statusCode(403);
    }
  }

  @Test
  void joinTrip_whenAlreadyJoined_shouldReturnConflict() {
    String tripSlug = createTestTrip("Already Joined Trip", Status.PUBLISHED, Visibility.PUBLIC);

    // First join
    given()
        .contentType("application/json")
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/join")
        .then()
        .statusCode(201);

    // Second join should fail
    given()
        .contentType("application/json")
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/join")
        .then()
        .statusCode(409);
  }

  // ==================== Leave Trip Tests ====================

  @Test
  void leaveTrip_asParticipant_shouldSucceed() {
    String tripSlug = createTestTrip("Leave Trip", Status.PUBLISHED, Visibility.PUBLIC);

    // First join
    given()
        .contentType("application/json")
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/join")
        .then()
        .statusCode(201);

    // Then leave
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/leave")
        .then()
        .statusCode(204);
  }

  @Test
  void leaveTrip_withoutAuth_shouldReturn401() {
    String tripSlug = createTestTrip("Unauth Leave Trip", Status.PUBLISHED, Visibility.PUBLIC);

    given()
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/leave")
        .then()
        .statusCode(401);
  }

  @Test
  void leaveTrip_whenNotParticipant_shouldReturn404() {
    String tripSlug = createTestTrip("Not Participant Trip", Status.PUBLISHED, Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/leave")
        .then()
        .statusCode(400);
  }

  @Test
  void leaveTrip_andRejoin_shouldSucceed() {
    String tripSlug = createTestTrip("Rejoin Trip", Status.PUBLISHED, Visibility.PUBLIC);

    // Join
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/join")
        .then()
        .statusCode(201);

    // Leave
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/leave")
        .then()
        .statusCode(204);

    // Rejoin
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/join")
        .then()
        .statusCode(201);
  }

  // ==================== Change Slug Tests ====================

  @Test
  void changeSlug_asAdmin_shouldSucceed() {
    String tripSlug = createTestTrip("Slug Change Trip");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(new SlugChangeRequest("new-trip-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/slug")
        .then()
        .statusCode(200)
        .body("slug", equalTo("new-trip-slug"));
  }

  @Test
  void changeSlug_asOrganizer_shouldSucceed() {
    String tripSlug = createTestTrip("Organizer Slug Trip");

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(new SlugChangeRequest("organizer-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/slug")
        .then()
        .statusCode(200)
        .body("slug", equalTo("organizer-slug"));
  }

  @Test
  void changeSlug_asMember_shouldReturn404() {
    String tripSlug = createTestTrip("Member Slug Trip");

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(new SlugChangeRequest("hacked-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/slug")
        .then()
        .statusCode(404);
  }

  @Test
  void changeSlug_withoutAuth_shouldReturn401() {
    String tripSlug = createTestTrip("Unauth Slug Trip");

    given()
        .contentType("application/json")
        .body(new SlugChangeRequest("unauth-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/trips/" + tripSlug + "/slug")
        .then()
        .statusCode(401);
  }
}
