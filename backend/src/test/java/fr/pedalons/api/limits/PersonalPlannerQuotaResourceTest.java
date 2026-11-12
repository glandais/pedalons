package fr.pedalons.api.limits;

import static fr.pedalons.service.route.planner.PlannerStateFixtures.importedOnly;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.planner.PlannerState;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.TeamTier;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.valhalla.StadiaMapsClient;
import fr.pedalons.service.limits.LimitsClock;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.ws.rs.core.MediaType;
import java.io.File;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Map;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

/**
 * The personal route planner quota of the GPX tools (docs/LEDGER_*.md BILL-10, design §3.2 and §6):
 * 10 saves of a drawn track per calendar month (UTC) for whoever is a member of no unlocked team of
 * the site, none otherwise; the promotion of a drawn preview counted against the team; the route
 * calculation without a team refused once the quota is spent; the daily cap of calculations. The
 * clock is injected; Stadia Maps is mocked.
 */
@QuarkusTest
class PersonalPlannerQuotaResourceTest extends AbstractResourceTest {

  private static final File EXAMPLE_GPX = new File("src/test/resources/example.gpx");

  private static final Instant NOW = Instant.parse("2026-11-15T10:00:00Z");

  private static final int PERSONAL_QUOTA = 10;

  private static final String FROM_POINTS_BODY =
      """
      {"name": "Tracé", "points": [{"lng": 4.8357, "lat": 45.7640},
       {"lng": 4.8500, "lat": 45.7700}]}
      """;

  private static final String POINTS_PREVIEW =
      "{\"name\":\"Redessiné\",\"points\":[{\"lng\":4.8357,\"lat\":45.7640},"
          + "{\"lng\":4.85,\"lat\":45.77}]}";

  @Inject LimitsClock limitsClock;

  @Inject ObjectMapper objectMapper;

  @Inject EntityManager em;

  @InjectMock @RestClient StadiaMapsClient stadiaMapsClient;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    Mockito.reset(stadiaMapsClient);
    limitsClock.setForTest(Clock.fixed(NOW, ZoneOffset.UTC));
    dataService.setDomainEnableGpxPlanner(domain, true);
    // The fixture's teams are FREE: nobody has an unlocked team until a test says so
    dataService.setTeamTier(team1, TeamTier.FREE);
    dataService.setTeamTier(team2, TeamTier.FREE);
    dataService.setTeamEnableRoutePlanner(team1, true);
  }

  @AfterEach
  void resetClock() {
    limitsClock.setForTest(null);
  }

  // ==================== helpers ====================

  private ValidatableResponse fromPoints(String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(FROM_POINTS_BODY)
        .when()
        .post("/api/gpx-previews/from-points")
        .then();
  }

  private String uploadPreview(String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .multiPart("gpxFile", EXAMPLE_GPX, "application/gpx+xml")
        .when()
        .post("/api/gpx-previews")
        .then()
        .statusCode(201)
        .extract()
        .path("id");
  }

  private ValidatableResponse updatePreview(String previewId, String previewJson, File gpx) {
    var spec =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .multiPart("preview", previewJson, MediaType.APPLICATION_JSON);
    if (gpx != null) {
      spec = spec.multiPart("gpxFile", gpx, "application/gpx+xml");
    }
    return spec.when().put("/api/gpx-previews/" + previewId).then();
  }

  private String stateJson(String name, PlannerState state) throws Exception {
    return objectMapper.writeValueAsString(Map.of("name", name, "plannerState", state));
  }

  private ValidatableResponse promote(String previewId, String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(
            new RouteRequest(
                "Promu", MediaDto.builder().build(), SurfaceType.ROAD, Visibility.PUBLIC, null))
        .when()
        .post("/api/gpx-previews/" + previewId + "/routes/" + team1Slug)
        .then();
  }

  private ValidatableResponse route(String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(MediaType.APPLICATION_JSON)
        .body(
            "{\"from\": {\"lng\": 4.8357, \"lat\": 45.7640},"
                + " \"to\": {\"lng\": 4.8500, \"lat\": 45.7700}, \"profile\": \"BIKE\"}")
        .when()
        .post("/api/router")
        .then();
  }

  private ValidatableResponse me(String user) {
    return given().auth().oauth2(getAccessToken(user)).when().get("/api/users/me").then();
  }

  private void fill(User user, int saves) {
    dataService.addPlannerSaves(user, null, saves, NOW);
  }

  private static void assertPersonalQuotaReached(ValidatableResponse response, long current) {
    response
        .statusCode(403)
        .body("code", equalTo("PLANNER_QUOTA_REACHED"))
        .body("errorDetails.scope", equalTo("PERSONAL"))
        .body("errorDetails.limit", equalTo(PERSONAL_QUOTA))
        .body("errorDetails.current", equalTo((int) current))
        .body("errorDetails.resetsOn", equalTo("2026-12-01"))
        .body("errorDetails.teamName", nullValue());
  }

  // ==================== the count ====================

  @Test
  void aUserInNoUnlockedTeam_hasTenSaves() {
    fill(user1, PERSONAL_QUOTA - 1);

    fromPoints(USER1).statusCode(201);
    assertEquals(PERSONAL_QUOTA, dataService.countPlannerSaves(null, user1));

    assertPersonalQuotaReached(fromPoints(USER1), PERSONAL_QUOTA);
    assertEquals(PERSONAL_QUOTA, dataService.countPlannerSaves(null, user1));
  }

  @Test
  void aRedrawOfAPreview_countsOne_aFileOrImportedPiecesNothing() throws Exception {
    String previewId = uploadPreview(USER1);
    assertEquals(0, dataService.countPlannerSaves(null, user1));

    updatePreview(previewId, POINTS_PREVIEW, null).statusCode(200);
    assertEquals(1, dataService.countPlannerSaves(null, user1));

    updatePreview(previewId, "{\"name\":\"Remplacé\"}", EXAMPLE_GPX).statusCode(200);
    updatePreview(previewId, "{\"name\":\"Renommé\"}", null).statusCode(200);
    updatePreview(previewId, stateJson("Importé", importedOnly()), null).statusCode(200);
    assertEquals(1, dataService.countPlannerSaves(null, user1));
  }

  @Test
  void atTheQuota_aRedrawIsRefused_butAnUploadStaysOpen() {
    String previewId = uploadPreview(USER1);
    fill(user1, PERSONAL_QUOTA);

    assertPersonalQuotaReached(updatePreview(previewId, POINTS_PREVIEW, null), PERSONAL_QUOTA);
    uploadPreview(USER1);
  }

  @Test
  void theCountStartsAgain_onTheFirstOfTheMonth_inUtc() {
    fill(user1, PERSONAL_QUOTA);

    limitsClock.setForTest(Clock.fixed(Instant.parse("2026-11-30T23:59:00Z"), ZoneOffset.UTC));
    fromPoints(USER1).statusCode(403);

    limitsClock.setForTest(Clock.fixed(Instant.parse("2026-12-01T00:01:00Z"), ZoneOffset.UTC));
    fromPoints(USER1).statusCode(201);
  }

  // ==================== who has a quota ====================

  @Test
  void aMemberOfAnUnlockedTeam_whateverTheRole_isUnlimited() {
    // user3 is a plain member of team2
    dataService.setTeamTier(team2, TeamTier.UNLOCKED);
    fill(user3, PERSONAL_QUOTA + 3);

    fromPoints(USER3).statusCode(201);
    me(USER3)
        .statusCode(200)
        .body("plannerQuota.limit", nullValue())
        .body("plannerQuota.used", equalTo(0));
  }

  @Test
  void aMemberOfAnUnlockedTeamOfAnotherDomain_keepsTheQuota() {
    Domain other =
        dataService.createDomain("other.example.com", "Other", "http://other.example.com");
    User otherAdmin = dataService.createUser(other, "boss@other.example.com", "Boss");
    Team otherTeam =
        dataService.createTeam(other, otherAdmin, "Ailleurs", "ailleurs", Visibility.PUBLIC);
    dataService.setTeamTier(otherTeam, TeamTier.UNLOCKED);
    dataService.addUserToTeam(user4, otherTeam, TeamRole.MEMBER);
    fill(user4, PERSONAL_QUOTA);

    assertPersonalQuotaReached(fromPoints(USER4), PERSONAL_QUOTA);
    me(USER4).statusCode(200).body("plannerQuota.limit", equalTo(PERSONAL_QUOTA));
  }

  @Test
  void me_reportsThePersonalQuota() {
    fill(user1, 4);

    me(USER1)
        .statusCode(200)
        .body("plannerQuota.limit", equalTo(PERSONAL_QUOTA))
        .body("plannerQuota.used", equalTo(4))
        .body("plannerQuota.resetsOn", equalTo("2026-12-01"));
  }

  // ==================== the promotion of a drawn preview ====================

  @Test
  void promotingADrawnPreview_countsAgainstTheTeam() {
    String previewId = fromPoints(USER1).statusCode(201).extract().path("id");

    promote(previewId, USER1).statusCode(201);

    assertEquals(1, dataService.countPlannerSaves(team1, user1));
    assertEquals(1, dataService.countPlannerSaves(null, user1));
  }

  @Test
  void promotingADrawnPreview_isRefusedWhenTheTeamQuotaIsSpent() {
    String previewId = fromPoints(USER1).statusCode(201).extract().path("id");
    dataService.addPlannerSaves(user1, team1, 20, NOW);

    promote(previewId, USER1)
        .statusCode(403)
        .body("code", equalTo("PLANNER_QUOTA_REACHED"))
        .body("errorDetails.scope", equalTo("TEAM"))
        .body("errorDetails.teamName", equalTo("Team 1"));
  }

  @Test
  void promotingAnUploadedPreview_countsNothing() {
    String previewId = uploadPreview(USER1);
    dataService.addPlannerSaves(user1, team1, 20, NOW);

    promote(previewId, USER1).statusCode(201);
    assertEquals(20, dataService.countPlannerSaves(team1, user1));
  }

  // ==================== the route calculation ====================

  @Test
  void routing_withoutTeam_isRefusedOnceThePersonalQuotaIsSpent_beforeCallingStadia() {
    fill(user1, PERSONAL_QUOTA);

    assertPersonalQuotaReached(route(USER1), PERSONAL_QUOTA);

    verify(stadiaMapsClient, never()).route(any());
  }

  @Test
  void routing_pastTheDailyCap_isRefusedWith429_whateverTheTier() {
    dataService.setTeamTier(team2, TeamTier.UNLOCKED);
    QuarkusTransaction.requiringNew()
        .run(() ->
            em.createNativeQuery(
                    "insert into router_daily_calls (id, user_id, day, calls)"
                        + " values (1, :userId, :day, 300)")
                .setParameter("userId", user3.getId())
                .setParameter("day", LocalDate.of(2026, 11, 15))
                .executeUpdate());

    route(USER3)
        .statusCode(429)
        .header("Retry-After", notNullValue())
        .body("code", equalTo("ROUTING_DAILY_LIMIT_REACHED"));

    verify(stadiaMapsClient, never()).route(any());
  }
}
