package fr.pedalons.api.migration;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.anEmptyMap;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasKey;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.enums.BiketeamMigrationStatus;
import fr.pedalons.service.migration.live.BiketeamMigrationJobService;
import fr.pedalons.service.migration.live.BiketeamTestData;
import fr.pedalons.service.migration.live.BiketeamTestTokens;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** The M2M side of the biketeam live migration: trigger and status (§5 of the plan). */
@QuarkusTest
class BiketeamMigrationInternalResourceTest extends AbstractResourceTest {

  static final String JOBS = "/api/internal/biketeam-migration/jobs";
  static final String SECRET_HEADER = "X-Biketeam-Migration-Secret";

  @Inject BiketeamTestData biketeamData;
  @Inject BiketeamMigrationJobService jobService;

  @BeforeEach
  void setUpTest() {
    setUp();
  }

  /** Confirms {@code req} as user4 and returns the grant biketeam would receive. */
  private String confirmAndGetGrant(BiketeamTestTokens.Request req) {
    String redirectUrl =
        given()
            .auth()
            .oauth2(getAccessToken(USER4))
            .contentType(ContentType.JSON)
            .body(Map.of("requestToken", req.token()))
            .when()
            .post("/api/biketeam-migration/confirm")
            .then()
            .statusCode(200)
            .extract()
            .path("redirectUrl");
    return redirectUrl.substring(redirectUrl.indexOf("&grant=") + "&grant=".length());
  }

  private static Map<String, Object> body(BiketeamTestTokens.Request req, String grant) {
    Map<String, Object> body = new HashMap<>();
    body.put("requestId", req.requestId());
    body.put("grant", grant);
    body.put("teamId", req.teamId());
    return body;
  }

  private static ValidatableResponse trigger(Map<String, Object> body) {
    return given()
        .header(SECRET_HEADER, BiketeamTestTokens.TRIGGER_SECRET)
        .contentType(ContentType.JSON)
        .body(body)
        .when()
        .post(JOBS)
        .then();
  }

  @Test
  void withoutOrWithAWrongSecret_is401() {
    given()
        .contentType(ContentType.JSON)
        .body(Map.of())
        .when()
        .post(JOBS)
        .then()
        .statusCode(401)
        .body("code", equalTo("UNAUTHORIZED"));
    given()
        .header(SECRET_HEADER, "not-the-secret")
        .when()
        .get(JOBS + "/0abc")
        .then()
        .statusCode(401)
        .body("code", equalTo("UNAUTHORIZED"));
  }

  @Test
  void trigger_queuesTheJob_andAReplayAnswersTheSameJob() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    String grant = confirmAndGetGrant(req);

    String jobId =
        trigger(body(req, grant))
            .statusCode(202)
            .body("status", equalTo("QUEUED"))
            .body("targetTeamSlug", equalTo("n-peloton"))
            .extract()
            .path("jobId");
    assertEquals(BiketeamMigrationStatus.QUEUED, biketeamData.findJob(req.requestId()).getStatus());

    // Biketeam lost the response and retries with the same grant.
    trigger(body(req, grant)).statusCode(200).body("jobId", equalTo(jobId));

    given()
        .header(SECRET_HEADER, BiketeamTestTokens.TRIGGER_SECRET)
        .when()
        .get(JOBS + "/" + jobId)
        .then()
        .statusCode(200)
        .body("jobId", equalTo(jobId))
        .body("requestId", equalTo(req.requestId()))
        .body("teamId", equalTo("n-peloton"))
        .body("$", not(hasKey("dryRun")))
        .body("$", not(hasKey("reset")))
        .body("status", equalTo("QUEUED"))
        .body("progress.phase", equalTo("QUEUED"))
        .body("counts.routes.total", equalTo(0))
        .body("warnings", empty())
        .body("$", hasKey("targetTeam"))
        .body("targetTeam", nullValue())
        .body("$", hasKey("error"))
        .body("error", nullValue())
        .body("$", hasKey("urlMap"))
        .body("urlMap", nullValue());
  }

  @Test
  void trigger_withAFieldThatDiffers_isRefused() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    String grant = confirmAndGetGrant(req);

    Map<String, Object> otherRequest = body(req, grant);
    otherRequest.put("requestId", BiketeamTestTokens.request("n-peloton").requestId());
    trigger(otherRequest).statusCode(403).body("code", equalTo("BIKETEAM_GRANT_INVALID"));

    Map<String, Object> otherTeam = body(req, grant);
    otherTeam.put("teamId", "someone-else");
    trigger(otherTeam).statusCode(403).body("code", equalTo("BIKETEAM_GRANT_INVALID"));

    trigger(body(req, "bmg_unknown"))
        .statusCode(403)
        .body("code", equalTo("BIKETEAM_GRANT_INVALID"));
    assertEquals(
        BiketeamMigrationStatus.GRANTED, biketeamData.findJob(req.requestId()).getStatus());
  }

  @Test
  void trigger_withAReplacedGrant_isRefused() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    String first = confirmAndGetGrant(req);
    String second = confirmAndGetGrant(req);

    trigger(body(req, first)).statusCode(403).body("code", equalTo("BIKETEAM_GRANT_INVALID"));
    trigger(body(req, second)).statusCode(202);
  }

  @Test
  void trigger_withAnExpiredGrant_expiresTheRow() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    String grant = confirmAndGetGrant(req);
    biketeamData.expireGrant(req.requestId());

    trigger(body(req, grant)).statusCode(400).body("code", equalTo("BIKETEAM_GRANT_EXPIRED"));
    assertEquals(
        BiketeamMigrationStatus.EXPIRED, biketeamData.findJob(req.requestId()).getStatus());
  }

  // ─── a grant that lapsed unredeemed ───────────────────────────────────────

  private static ValidatableResponse preview(BiketeamTestTokens.Request req, String token) {
    return given()
        .auth()
        .oauth2(token)
        .contentType(ContentType.JSON)
        .body(Map.of("requestToken", req.token()))
        .when()
        .post("/api/biketeam-migration/preview")
        .then();
  }

  /**
   * The request is still valid, and nothing was ever triggered: the same user confirms again and
   * gets a new grant — before the hourly sweep as after it, and after a late trigger marked the row
   * EXPIRED.
   */
  private void assertReconfirmable(BiketeamTestTokens.Request req, String lapsedGrant) {
    preview(req, getAccessToken(USER4))
        .statusCode(200)
        .body("confirmable", equalTo(true))
        .body("blockReason", nullValue());
    String grant = confirmAndGetGrant(req);
    assertEquals(
        BiketeamMigrationStatus.GRANTED, biketeamData.findJob(req.requestId()).getStatus());
    trigger(body(req, lapsedGrant)).statusCode(403).body("code", equalTo("BIKETEAM_GRANT_INVALID"));
    trigger(body(req, grant)).statusCode(202).body("status", equalTo("QUEUED"));
  }

  @Test
  void aLapsedGrant_beforeTheSweep_canBeReconfirmed() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    String grant = confirmAndGetGrant(req);
    biketeamData.expireGrant(req.requestId());
    assertEquals(
        BiketeamMigrationStatus.GRANTED, biketeamData.findJob(req.requestId()).getStatus());

    assertReconfirmable(req, grant);
  }

  @Test
  void aLapsedGrant_afterTheSweep_canBeReconfirmed() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    String grant = confirmAndGetGrant(req);
    biketeamData.expireGrant(req.requestId());
    jobService.expireGrants();
    assertEquals(
        BiketeamMigrationStatus.EXPIRED, biketeamData.findJob(req.requestId()).getStatus());

    assertReconfirmable(req, grant);
  }

  @Test
  void aLapsedGrant_afterALateTrigger_canBeReconfirmed() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    String grant = confirmAndGetGrant(req);
    biketeamData.expireGrant(req.requestId());
    trigger(body(req, grant)).statusCode(400).body("code", equalTo("BIKETEAM_GRANT_EXPIRED"));

    assertReconfirmable(req, grant);
  }

  @Test
  void aLapsedGrant_staysAnotherUsersRequest() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    confirmAndGetGrant(req);
    biketeamData.expireGrant(req.requestId());
    jobService.expireGrants();

    preview(req, getAccessToken(USER5))
        .statusCode(200)
        .body("blockReason", equalTo("REQUEST_ALREADY_USED"));
  }

  @Test
  void aRedeemedRequest_isUsedForGood() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    trigger(body(req, confirmAndGetGrant(req))).statusCode(202);

    preview(req, getAccessToken(USER4))
        .statusCode(200)
        .body("blockReason", equalTo("REQUEST_ALREADY_USED"));
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .contentType(ContentType.JSON)
        .body(Map.of("requestToken", req.token()))
        .when()
        .post("/api/biketeam-migration/confirm")
        .then()
        .statusCode(409)
        .body("code", equalTo("BIKETEAM_REQUEST_ALREADY_USED"));
  }

  @Test
  void trigger_whileAnotherJobOfTheTeamIsActive_is409WithThatJob() {
    BiketeamTestTokens.Request a = BiketeamTestTokens.request("n-peloton");
    BiketeamTestTokens.Request b = BiketeamTestTokens.request("n-peloton");
    String grantA = confirmAndGetGrant(a);
    String grantB = confirmAndGetGrant(b);

    String jobA = trigger(body(a, grantA)).statusCode(202).extract().path("jobId");
    trigger(body(b, grantB))
        .statusCode(409)
        .body("code", equalTo("BIKETEAM_MIGRATION_RUNNING"))
        .body("activeJobId", equalTo(jobA));
  }

  @Test
  void trigger_withAMissingField_is400() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    for (String field : new String[] {"requestId", "grant", "teamId"}) {
      Map<String, Object> incomplete = body(req, "bmg_x");
      incomplete.remove(field);
      trigger(incomplete).statusCode(400).body("code", equalTo("VALIDATION"));
    }
  }

  /**
   * A biketeam not yet updated (Pédalons is deployed first) signs {@code dryRun} and {@code reset}
   * into its request and sends them with its trigger: neither is read, whatever its value or type,
   * and the job is the same incremental migration as any other.
   */
  @Test
  void aBiketeamNotYetUpdated_stillSendingDryRunAndReset_isAccepted_andBothAreIgnored() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.legacyRequest("n-peloton", false, true);
    preview(req, getAccessToken(USER4))
        .statusCode(200)
        .body("confirmable", equalTo(true))
        .body("$", not(hasKey("dryRun")))
        .body("$", not(hasKey("reset")));
    String grant = confirmAndGetGrant(req);

    Map<String, Object> legacy = body(req, grant);
    legacy.put("dryRun", false);
    legacy.put("reset", true);
    String jobId =
        trigger(legacy)
            .statusCode(202)
            .body("status", equalTo("QUEUED"))
            .body("targetTeamSlug", equalTo("n-peloton"))
            .extract()
            .path("jobId");

    // The replay of a lost response, with other values and another type: still the same job.
    Map<String, Object> replay = body(req, grant);
    replay.put("dryRun", "yes");
    replay.put("reset", 0);
    trigger(replay).statusCode(200).body("jobId", equalTo(jobId));
  }

  @Test
  void status_ofAnUnknownJobAMalformedIdOrAMereGrant_is404BiketeamJobNotFound() {
    // BIKETEAM_JOB_NOT_FOUND is the only 404 biketeam reads as JOB_LOST: every case says so.
    for (String unknown : new String[] {"0hx3k2m9q8r4t", "not-a-tsid!"}) {
      given()
          .header(SECRET_HEADER, BiketeamTestTokens.TRIGGER_SECRET)
          .when()
          .get(JOBS + "/" + unknown)
          .then()
          .statusCode(404)
          .contentType(ContentType.JSON)
          .body("code", equalTo("BIKETEAM_JOB_NOT_FOUND"));
    }

    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    confirmAndGetGrant(req);
    String grantedRowId = TsidUtils.toString(biketeamData.findJob(req.requestId()).getId());
    given()
        .header(SECRET_HEADER, BiketeamTestTokens.TRIGGER_SECRET)
        .when()
        .get(JOBS + "/" + grantedRowId)
        .then()
        .statusCode(404)
        .body("code", equalTo("BIKETEAM_JOB_NOT_FOUND"));
  }

  @Test
  void biketeamMigrationEndpoints_areNotInTheContract() {
    // Neither the M2M endpoints nor the page's preview/confirm: all hidden, DTOs included (a
    // class-level @Schema would put them back in the components). Only the BIKETEAM_* codes of
    // the shared ErrorCode enum stay.
    given()
        .when()
        .get("/q/openapi?format=json")
        .then()
        .statusCode(200)
        .body("paths", hasKey("/api/version"))
        .body("paths.findAll { it.key.startsWith('/api/internal') }", anEmptyMap())
        .body("paths.findAll { it.key.startsWith('/api/biketeam-migration') }", anEmptyMap())
        .body("components.schemas.findAll { it.key.startsWith('BiketeamMigration') }", anEmptyMap())
        .body("components.schemas.ErrorCode.enum", hasItem("BIKETEAM_REQUEST_INVALID"))
        .body("components.schemas.ErrorCode.enum", hasItem("BIKETEAM_JOB_NOT_FOUND"));
  }
}
