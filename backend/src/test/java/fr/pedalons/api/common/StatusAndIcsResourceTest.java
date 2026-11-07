package fr.pedalons.api.common;

import static fr.pedalons.util.WallTimes.wall;
import static io.restassured.RestAssured.given;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.arrayWithSize;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.hamcrest.Matchers.startsWith;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.dto.ads.request.AdRequest;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.common.request.StatusChangeRequest;
import fr.pedalons.dto.posts.request.PostRequest;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.dto.trips.request.StageRequest;
import fr.pedalons.dto.trips.request.TripRequest;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The card actions of docs/LEDGER_DONE.md WEB-33: {@code PATCH …/status} on rides, trips, posts and
 * ads, and the single-publication {@code GET …/ics} of rides and trips.
 *
 * <p>Kept apart from the per-resource test classes on purpose: the status endpoint exists so a
 * list row — which lacks a ride's groups and a trip's stages — can publish without dropping them,
 * and that is what these tests pin.
 */
@QuarkusTest
class StatusAndIcsResourceTest extends AbstractResourceTest {

  @Inject EntityManager entityManager;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  // ── Rides ────────────────────────────────────────────────────────────────────────────────────

  @Test
  void rideStatus_asOrganizer_publishesDraft_keepsGroups_andDropsSchedule() {
    String slug =
        createRide(
            "Status Ride", Status.DRAFT, Visibility.PUBLIC, Instant.now().plus(3, ChronoUnit.DAYS));

    patchStatus(USER2, "/rides/" + slug, Status.PUBLISHED)
        .statusCode(200)
        .body("status", equalTo("PUBLISHED"))
        .body("groupCount", equalTo(2));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/" + slug)
        .then()
        .statusCode(200)
        .body("groups", hasSize(2))
        .body("publishAt", nullValue());
  }

  @Test
  void rideStatus_asMember_isForbidden() {
    String slug = createRide("Member Ride", Status.PUBLISHED, Visibility.PUBLIC, null);

    patchStatus(USER3, "/rides/" + slug, Status.CANCELLED).statusCode(403);
  }

  @Test
  void rideStatus_withoutAuth_returns401() {
    String slug = createRide("Anonymous Ride", Status.PUBLISHED, Visibility.PUBLIC, null);

    given()
        .contentType("application/json")
        .body(new StatusChangeRequest(Status.DRAFT))
        .when()
        .patch("/api/teams/" + team1Slug + "/rides/" + slug + "/status")
        .then()
        .statusCode(401);
  }

  @Test
  void rideStatus_withoutStatus_returns400() {
    String slug = createRide("No Status Ride", Status.DRAFT, Visibility.PUBLIC, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body("{}")
        .when()
        .patch("/api/teams/" + team1Slug + "/rides/" + slug + "/status")
        .then()
        .statusCode(400);
  }

  // ── Trips ────────────────────────────────────────────────────────────────────────────────────

  @Test
  void tripStatus_publishesDraft_keepsStages_andTheStagesFollow() {
    String slug = createTrip("Status Trip", Status.DRAFT, Visibility.PUBLIC);

    patchStatus(USER2, "/trips/" + slug, Status.PUBLISHED)
        .statusCode(200)
        .body("status", equalTo("PUBLISHED"))
        .body("stages", hasSize(2));

    // The calendar and its feeds read a stage's own status, not its trip's.
    List<Status> stageStatuses =
        QuarkusTransaction.requiringNew()
            .call(
                () ->
                    entityManager
                        .createQuery(
                            "select s.status from TripStage s"
                                + " where s.trip.slug = :slug and s.deleted = false",
                            Status.class)
                        .setParameter("slug", slug)
                        .getResultList());
    assertThat(stageStatuses, contains(Status.PUBLISHED, Status.PUBLISHED));
  }

  @Test
  void tripStatus_asMember_isForbidden() {
    String slug = createTrip("Member Trip", Status.PUBLISHED, Visibility.PUBLIC);

    patchStatus(USER3, "/trips/" + slug, Status.CANCELLED).statusCode(403);
  }

  // ── Posts ────────────────────────────────────────────────────────────────────────────────────

  @Test
  void postStatus_asOrganizer_unpublishes() {
    String slug = createPost("Status Post");

    patchStatus(USER2, "/posts/" + slug, Status.DRAFT)
        .statusCode(200)
        .body("status", equalTo("DRAFT"));
  }

  @Test
  void postStatus_asMember_isForbidden() {
    String slug = createPost("Member Post");

    patchStatus(USER3, "/posts/" + slug, Status.DRAFT).statusCode(403);
  }

  // ── Ads ──────────────────────────────────────────────────────────────────────────────────────

  @Test
  void adStatus_asAuthor_unpublishes() {
    String slug = createAd("Status Ad");

    patchStatus(USER1, "/classifieds/" + slug, Status.DRAFT)
        .statusCode(200)
        .body("status", equalTo("DRAFT"));
  }

  @Test
  void adStatus_cancelled_isRejected() {
    String slug = createAd("Cancelled Ad");

    patchStatus(USER1, "/classifieds/" + slug, Status.CANCELLED).statusCode(400);
  }

  @Test
  void adStatus_asOrganizerWhoIsNotTheAuthor_isForbidden() {
    String slug = createAd("Organizer Ad");

    patchStatus(USER2, "/classifieds/" + slug, Status.DRAFT).statusCode(403);
  }

  // ── ICS ──────────────────────────────────────────────────────────────────────────────────────

  @Test
  void rideIcs_ofAPublicRide_isOneEvent_forAnAnonymousVisitor() {
    String slug = createRide("Ics Ride", Status.PUBLISHED, Visibility.PUBLIC, null);

    String body =
        given()
            .when()
            .get("/api/teams/" + team1Slug + "/rides/" + slug + "/ics")
            .then()
            .statusCode(200)
            .contentType(startsWith("text/calendar"))
            .header("Content-Disposition", containsString("attachment"))
            .header("Content-Disposition", containsString(slug + ".ics"))
            .body(containsString("SUMMARY:Ics Ride"))
            .extract()
            .asString();
    assertThat(body.split("BEGIN:VEVENT", -1), arrayWithSize(2));
  }

  /**
   * A registered member's file starts when their group leaves; an anonymous visitor's at the
   * ride's start. Both name the meeting place (docs/LEDGER_*.md API-157).
   */
  @Test
  void rideIcs_startsAtTheCallersGroup_andNamesTheStartPlace() {
    Instant rideStart = Instant.now().plus(3, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    Instant groupStart = rideStart.plus(90, ChronoUnit.MINUTES);
    Ride ride = dataService.createRide(team1, user1, "Grouped Ics", "grouped-ics", rideStart);
    RideGroup group = dataService.createRideGroup(user1, ride, "Later");
    dataService.setRideGroupStart(group, groupStart);
    dataService.createParticipation(group, user3);
    dataService.setRidePlaces(ride, dataService.createPlace(team1, user1, "Église; parvis"), null);
    DateTimeFormatter utc =
        DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'").withZone(ZoneOffset.UTC);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/grouped-ics/ics")
        .then()
        .statusCode(200)
        .header("Cache-Control", containsString("private"))
        .body(containsString("DTSTART:" + utc.format(groupStart) + "\r\n"))
        .body(containsString("LOCATION:Église\\; parvis\r\n"));
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/rides/grouped-ics/ics")
        .then()
        .statusCode(200)
        .body(containsString("DTSTART:" + utc.format(rideStart) + "\r\n"))
        .body(containsString("LOCATION:Église\\; parvis\r\n"));
  }

  @Test
  void rideIcs_ofADraft_isNotFound_forAnAnonymousVisitor() {
    String slug = createRide("Draft Ics Ride", Status.DRAFT, Visibility.PUBLIC, null);

    given()
        .when()
        .get("/api/teams/" + team1Slug + "/rides/" + slug + "/ics")
        .then()
        .statusCode(404);
  }

  @Test
  void rideIcs_ofATeamOnlyRide_isNotFound_forAnAnonymousVisitor_butServedToAMember() {
    String slug = createRide("Team Ics Ride", Status.PUBLISHED, Visibility.TEAM, null);

    given()
        .when()
        .get("/api/teams/" + team1Slug + "/rides/" + slug + "/ics")
        .then()
        .statusCode(404);
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/rides/" + slug + "/ics")
        .then()
        .statusCode(200);
  }

  @Test
  void tripIcs_isOneAllDayEventPerStage() {
    String slug = createTrip("Ics Trip", Status.PUBLISHED, Visibility.PUBLIC);

    String body =
        given()
            .when()
            .get("/api/teams/" + team1Slug + "/trips/" + slug + "/ics")
            .then()
            .statusCode(200)
            .contentType(startsWith("text/calendar"))
            .extract()
            .asString();
    assertThat(body.split("BEGIN:VEVENT", -1), arrayWithSize(3));
    assertThat(body, containsString("DTSTART;VALUE=DATE:"));
  }

  // ── Fixtures ─────────────────────────────────────────────────────────────────────────────────

  private io.restassured.response.ValidatableResponse patchStatus(
      String user, String path, Status status) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType("application/json")
        .body(new StatusChangeRequest(status))
        .when()
        .patch("/api/teams/" + team1Slug + path + "/status")
        .then();
  }

  private String createRide(String name, Status status, Visibility visibility, Instant publishAt) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new RideRequest(
                name,
                MediaDto.builder().build(),
                wall(Instant.now().plus(10, ChronoUnit.DAYS)),
                status,
                visibility,
                null,
                null,
                null,
                wall(publishAt),
                List.of(
                    new GroupRequest(null, "G1", null, null, null, null),
                    new GroupRequest(null, "G2", null, null, null, null)),
                null))
        .when()
        .post("/api/teams/" + team1Slug + "/rides")
        .then()
        .statusCode(201)
        .extract()
        .path("slug");
  }

  private String createTrip(String name, Status status, Visibility visibility) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new TripRequest(
                name,
                MediaDto.builder().build(),
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
                        .build(),
                    StageRequest.builder()
                        .name("Stage 2")
                        .dateTime(wall(Instant.now().plus(31, ChronoUnit.DAYS)))
                        .media(MediaDto.builder().build())
                        .build()),
                null))
        .when()
        .post("/api/teams/" + team1Slug + "/trips")
        .then()
        .statusCode(201)
        .extract()
        .path("slug");
  }

  private String createPost(String name) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new PostRequest(
                name,
                MediaDto.builder().markdown("Post content").build(),
                wall(Instant.now().plus(7, ChronoUnit.DAYS)),
                Status.PUBLISHED,
                Visibility.PUBLIC,
                null,
                null,
                null))
        .when()
        .post("/api/teams/" + team1Slug + "/posts")
        .then()
        .statusCode(201)
        .extract()
        .path("slug");
  }

  private String createAd(String name) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new AdRequest(
                name,
                MediaDto.builder().markdown("Ad content").build(),
                Status.PUBLISHED,
                AdType.SALE,
                BigDecimal.valueOf(100),
                null,
                null,
                null))
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds")
        .then()
        .statusCode(201)
        .extract()
        .path("slug");
  }
}
