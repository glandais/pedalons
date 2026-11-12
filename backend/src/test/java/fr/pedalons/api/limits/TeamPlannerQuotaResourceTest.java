package fr.pedalons.api.limits;

import static fr.pedalons.service.route.planner.PlannerStateFixtures.drawn;
import static fr.pedalons.service.route.planner.PlannerStateFixtures.importedOnly;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TeamTier;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.valhalla.StadiaMapsClient;
import fr.pedalons.infrastructure.valhalla.ValhallaRequest;
import fr.pedalons.infrastructure.valhalla.ValhallaResponse;
import fr.pedalons.service.limits.LimitsClock;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.MediaType;
import java.io.File;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

/**
 * The route planner quota of a team on the free plan (docs/LEDGER_*.md BILL-10, design §3.2 and §6):
 * 20 saves of a drawn track per calendar month in the team's zone, each save counting one, the
 * imports never; the route calculation refused once the quota is spent. The clock is injected, the
 * journal is filled directly up to the edge so that only the saves under test run the pipeline.
 * Stadia Maps is mocked.
 */
@QuarkusTest
class TeamPlannerQuotaResourceTest extends AbstractResourceTest {

  private static final File EXAMPLE_GPX = new File("src/test/resources/example.gpx");

  /** Mid-November 2026, UTC. */
  private static final Instant NOW = Instant.parse("2026-11-15T10:00:00Z");

  private static final int TEAM_QUOTA = 20;

  @Inject LimitsClock limitsClock;

  @InjectMock @RestClient StadiaMapsClient stadiaMapsClient;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    Mockito.reset(stadiaMapsClient);
    limitsClock.setForTest(Clock.fixed(NOW, ZoneOffset.UTC));
    dataService.setTeamTier(team1, TeamTier.FREE);
    dataService.setTeamEnableRoutePlanner(team1, true);
    dataService.setTeamTimezone(team1, "Europe/Paris");
  }

  @AfterEach
  void resetClock() {
    limitsClock.setForTest(null);
  }

  // ==================== helpers ====================

  private static List<GeoPoint> points() {
    return List.of(new GeoPoint(4.8357, 45.7640), new GeoPoint(4.8500, 45.7700));
  }

  private static RouteRequest drawnRequest(String name) {
    return new RouteRequest(
        name, MediaDto.builder().build(), SurfaceType.ROAD, Visibility.PUBLIC, points());
  }

  private static RouteRequest stateRequest(String name, PlannerState state) {
    return new RouteRequest(
        name, MediaDto.builder().build(), SurfaceType.ROAD, Visibility.PUBLIC, null, null, state);
  }

  private static RouteRequest metadataRequest(String name) {
    return new RouteRequest(
        name, MediaDto.builder().build(), SurfaceType.ROAD, Visibility.PUBLIC, null);
  }

  private ValidatableResponse create(String user, RouteRequest route, File gpx) {
    var spec =
        given()
            .auth()
            .oauth2(getAccessToken(user))
            .multiPart("route", route, MediaType.APPLICATION_JSON);
    if (gpx != null) {
      spec = spec.multiPart("gpxFile", gpx, "application/gpx+xml");
    }
    return spec.when().post("/api/teams/" + team1Slug + "/routes").then();
  }

  private ValidatableResponse update(String slug, RouteRequest route, File gpx) {
    var spec =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("route", route, MediaType.APPLICATION_JSON);
    if (gpx != null) {
      spec = spec.multiPart("gpxFile", gpx, "application/gpx+xml");
    }
    return spec.when().put("/api/teams/" + team1Slug + "/routes/" + slug).then();
  }

  private ValidatableResponse route(String user, String teamSlug) {
    String team = teamSlug == null ? "" : ", \"teamSlug\": \"" + teamSlug + "\"";
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(
            "{\"from\": {\"lng\": 4.8357, \"lat\": 45.7640},"
                + " \"to\": {\"lng\": 4.8500, \"lat\": 45.7700}, \"profile\": \"BIKE\""
                + team
                + "}")
        .when()
        .post("/api/router")
        .then();
  }

  private void fill(int saves) {
    dataService.addPlannerSaves(user1, team1, saves, NOW);
  }

  private long saves() {
    return dataService.countPlannerSaves(team1, user1);
  }

  private static void assertTeamQuotaReached(ValidatableResponse response, long current) {
    response
        .statusCode(403)
        .body("code", equalTo("PLANNER_QUOTA_REACHED"))
        .body("errorDetails.type", equalTo("PLANNER_QUOTA_REACHED"))
        .body("errorDetails.scope", equalTo("TEAM"))
        .body("errorDetails.limit", equalTo(TEAM_QUOTA))
        .body("errorDetails.current", equalTo((int) current))
        .body("errorDetails.resetsOn", equalTo("2026-12-01"))
        .body("errorDetails.teamName", equalTo("Team 1"));
  }

  // ==================== the count ====================

  @Test
  void theTwentiethSavePasses_theTwentyFirstIsRefused() {
    fill(TEAM_QUOTA - 1);

    create(USER1, drawnRequest("Vingtième"), null).statusCode(201);
    assertEquals(TEAM_QUOTA, saves());

    assertTeamQuotaReached(create(USER1, drawnRequest("Vingt-et-unième"), null), TEAM_QUOTA);
    // A refused save counts nothing
    assertEquals(TEAM_QUOTA, saves());
  }

  @Test
  void threeRedrawsOfTheSameRoute_countThree() {
    Route existing = dataService.createRoute(team1, user1, "Boucle");

    update(existing.getSlug(), drawnRequest("Boucle"), null).statusCode(200);
    update(existing.getSlug(), drawnRequest("Boucle"), null).statusCode(200);
    update(existing.getSlug(), stateRequest("Boucle", drawn()), null).statusCode(200);

    assertEquals(3, saves());
  }

  @Test
  void aRedraw_isRefusedAtTheQuota_andTheRouteIsLeftAsItWas() {
    Route existing = dataService.createRoute(team1, user1, "Boucle");
    fill(TEAM_QUOTA);

    assertTeamQuotaReached(
        update(existing.getSlug(), drawnRequest("Redessinée"), null), TEAM_QUOTA);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + existing.getSlug())
        .then()
        .statusCode(200)
        .body("name", equalTo("Boucle"));
  }

  @Test
  void anImport_aRename_andAStateOfImportedPieces_countNothing() {
    String slug =
        create(USER1, metadataRequest("Importée"), EXAMPLE_GPX)
            .statusCode(201)
            .extract()
            .path("slug");
    update(slug, metadataRequest("Renommée"), null).statusCode(200);
    update(slug, metadataRequest("Remplacée"), EXAMPLE_GPX).statusCode(200);
    create(USER1, stateRequest("Morceaux importés", importedOnly()), null).statusCode(201);

    assertEquals(0, saves());
  }

  @Test
  void atTheQuota_theGpxImportAndTheRenameStayOpen() {
    Route existing = dataService.createRoute(team1, user1, "Boucle");
    fill(TEAM_QUOTA);

    create(USER1, metadataRequest("Importée"), EXAMPLE_GPX).statusCode(201);
    update(existing.getSlug(), metadataRequest("Renommée"), null).statusCode(200);
    create(USER1, stateRequest("Morceaux importés", importedOnly()), null).statusCode(201);
  }

  @Test
  void deletingARoute_givesNothingBack() {
    fill(TEAM_QUOTA - 1);
    String slug =
        create(USER1, drawnRequest("Éphémère"), null).statusCode(201).extract().path("slug");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/routes/" + slug)
        .then()
        .statusCode(204);

    assertTeamQuotaReached(create(USER1, drawnRequest("Encore"), null), TEAM_QUOTA);
  }

  // ==================== the month, in the team's zone ====================

  @Test
  void theCountStartsAgain_onTheFirstOfTheMonth_inTheTeamZone() {
    fill(TEAM_QUOTA);

    // 23:30 in Paris on 30 November: still November for the team
    limitsClock.setForTest(Clock.fixed(Instant.parse("2026-11-30T22:30:00Z"), ZoneOffset.UTC));
    create(USER1, drawnRequest("Fin novembre"), null).statusCode(403);

    // 00:30 in Paris on 1 December, still 30 November in UTC: a new month for the team
    limitsClock.setForTest(Clock.fixed(Instant.parse("2026-11-30T23:30:00Z"), ZoneOffset.UTC));
    create(USER1, drawnRequest("Début décembre"), null).statusCode(201);
  }

  @Test
  void savesOfLastMonth_doNotCount() {
    dataService.addPlannerSaves(user1, team1, TEAM_QUOTA, Instant.parse("2026-10-20T10:00:00Z"));

    create(USER1, drawnRequest("Novembre"), null).statusCode(201);
  }

  // ==================== the route calculation ====================

  @Test
  void routing_forTheTeam_isRefusedOnceTheQuotaIsSpent_beforeCallingStadia() {
    fill(TEAM_QUOTA);

    assertTeamQuotaReached(route(USER1, team1Slug), TEAM_QUOTA);

    verify(stadiaMapsClient, never()).route(any());
  }

  @Test
  void routing_forTheTeam_staysOpenBelowTheQuota() {
    fill(TEAM_QUOTA - 1);
    when(stadiaMapsClient.route(any(ValhallaRequest.class))).thenReturn(new ValhallaResponse(null));

    route(USER1, team1Slug).statusCode(200);

    verify(stadiaMapsClient).route(any());
  }

  // ==================== tiers and flags ====================

  @Test
  void anUnlockedTeam_hasNoQuota() {
    dataService.setTeamTier(team1, TeamTier.UNLOCKED);
    fill(TEAM_QUOTA + 5);

    create(USER1, drawnRequest("Sans limite"), null).statusCode(201);
  }

  @Test
  void theFlagClosesThePlanner_evenForAnUnlockedTeam() {
    dataService.setTeamTier(team1, TeamTier.UNLOCKED);
    dataService.setTeamEnableRoutePlanner(team1, false);

    create(USER1, drawnRequest("Fermé"), null)
        .statusCode(400)
        .body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void aPlatformAdmin_isExempt_andNotCounted() {
    User admin = dataService.createPlatformAdminUser("planneradmin@example.com", "Admin");
    fill(TEAM_QUOTA);

    create("planneradmin", drawnRequest("Par l'admin"), null).statusCode(201);
    assertEquals(TEAM_QUOTA, dataService.countPlannerSaves(team1, admin));
  }

  // ==================== TeamDetailDto.plannerQuota ====================

  @Test
  void theTeamDetail_givesTheQuota_toWhoeverMayCreateRoutes() {
    fill(3);

    // user2 is an organiser of team1
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get("/api/teams/" + team1Slug)
        .then()
        .statusCode(200)
        .body("plannerQuota.limit", equalTo(TEAM_QUOTA))
        .body("plannerQuota.used", equalTo(3))
        .body("plannerQuota.resetsOn", equalTo("2026-12-01"));
  }

  @Test
  void theTeamDetail_givesNoQuota_toAMember_orAnAnonymousVisitor() {
    // user3 is a plain member of team1
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug)
        .then()
        .statusCode(200)
        .body("plannerQuota", nullValue());

    given()
        .when()
        .get("/api/teams/" + team1Slug)
        .then()
        .statusCode(200)
        .body("plannerQuota", nullValue());
  }

  @Test
  void anUnlockedTeam_reportsAnUnlimitedQuota() {
    dataService.setTeamTier(team1, TeamTier.UNLOCKED);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug)
        .then()
        .statusCode(200)
        .body("plannerQuota.limit", nullValue())
        .body("plannerQuota.used", equalTo(0));
  }

  @Test
  void theTeamListings_carryNoQuota() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams")
        .then()
        .statusCode(200)
        .body("teams.plannerQuota", everyItem(nullValue()));
  }
}
