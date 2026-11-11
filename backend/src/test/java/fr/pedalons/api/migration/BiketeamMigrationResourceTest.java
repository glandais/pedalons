package fr.pedalons.api.migration;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasKey;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.nullValue;
import static org.hamcrest.Matchers.startsWith;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TokenUtils;
import fr.pedalons.domain.migration.BiketeamMigrationJob;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.enums.BiketeamMigrationStatus;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.migration.live.BiketeamTestData;
import fr.pedalons.service.migration.live.BiketeamTestTokens;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** The public side of the biketeam live migration: preview and confirm (§4 of the plan). */
@QuarkusTest
class BiketeamMigrationResourceTest extends AbstractResourceTest {

  static final String PREVIEW = "/api/biketeam-migration/preview";
  static final String CONFIRM = "/api/biketeam-migration/confirm";

  @Inject BiketeamTestData biketeamData;

  @BeforeEach
  void setUpTest() {
    setUp();
  }

  private ValidatableResponse preview(String token, String user) {
    var spec = given().contentType(ContentType.JSON).body(Map.of("requestToken", token));
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.when().post(PREVIEW).then();
  }

  private ValidatableResponse confirm(String token, String user) {
    var spec = given().contentType(ContentType.JSON).body(Map.of("requestToken", token));
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.when().post(CONFIRM).then();
  }

  // ─── preview ──────────────────────────────────────────────────────────────

  @Test
  void preview_isPublic_andAsksToSignIn() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");

    preview(req.token(), null)
        .statusCode(200)
        .body("requestId", equalTo(req.requestId()))
        .body("teamId", equalTo("n-peloton"))
        .body("teamName", equalTo("Team n-peloton"))
        .body("requestedBy", equalTo("Jane D."))
        .body("$", not(hasKey("dryRun")))
        .body("$", not(hasKey("reset")))
        .body("summary.routes", equalTo(2))
        .body("summary.faqPage", equalTo(true))
        .body("targetDomainName", equalTo(domain.getName()))
        .body("targetTeamSlug", equalTo("n-peloton"))
        .body("targetState", equalTo("NEW"))
        .body("existingTeamName", nullValue())
        .body("trashedTeamSetAside", nullValue())
        .body("confirmable", equalTo(false))
        .body("blockReason", equalTo("LOGIN_REQUIRED"))
        .body(
            "cancelUrl",
            equalTo(req.returnUrl() + "?request=" + req.requestId() + "&outcome=cancelled"));
  }

  @Test
  void preview_signedIn_isConfirmable() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");

    preview(req.token(), USER4)
        .statusCode(200)
        .body("confirmable", equalTo(true))
        .body("blockReason", nullValue());
  }

  @Test
  void preview_expiredOrForged_isRefused() {
    BiketeamTestTokens.Request old =
        BiketeamTestTokens.request(
            UUID.randomUUID().toString(), "n-peloton", Instant.now().minusSeconds(3600));
    preview(old.token(), null).statusCode(400).body("code", equalTo("BIKETEAM_REQUEST_EXPIRED"));

    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    String forged = req.token().substring(0, req.token().length() - 2) + "AA";
    preview(forged, null).statusCode(400).body("code", equalTo("BIKETEAM_REQUEST_INVALID"));
  }

  @Test
  void preview_slugOfANativeTeam_isAConflict() {
    // team-1 is a native Pédalons team of the standard fixture.
    BiketeamTestTokens.Request req = BiketeamTestTokens.request(team1Slug);

    preview(req.token(), USER4)
        .statusCode(200)
        .body("targetState", equalTo("SLUG_CONFLICT"))
        .body("existingTeamName", equalTo(team1.getName()))
        .body("confirmable", equalTo(false))
        .body("blockReason", equalTo("SLUG_CONFLICT"));
    confirm(req.token(), USER4).statusCode(409).body("code", equalTo("BIKETEAM_SLUG_CONFLICT"));
  }

  @Test
  void preview_existingMigratedTeam_isReservedToItsAdmins() {
    Team migrated =
        dataService.createTeam(domain, user1, "Migrated", "migrated", Visibility.PUBLIC);
    biketeamData.mapTeam("migrated", migrated);
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("migrated");

    preview(req.token(), USER3)
        .statusCode(200)
        .body("targetState", equalTo("EXISTING_MIGRATED"))
        .body("existingTeamName", equalTo("Migrated"))
        .body("blockReason", equalTo("NOT_TEAM_ADMIN"));
    confirm(req.token(), USER3).statusCode(403).body("code", equalTo("BIKETEAM_NOT_TEAM_ADMIN"));

    preview(req.token(), USER1).statusCode(200).body("confirmable", equalTo(true));
    confirm(req.token(), USER1).statusCode(200);
  }

  @Test
  void preview_migratedTeamInTheTrash_atTheSlug_isNew_andSaysItIsSetAside() {
    Team migrated =
        dataService.createTeam(domain, user1, "Old Migrated", "trashed-one", Visibility.PUBLIC);
    biketeamData.mapTeam("trashed-one", migrated);
    biketeamData.trashTeam(migrated.getId());
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("trashed-one");

    preview(req.token(), USER4)
        .statusCode(200)
        .body("targetState", equalTo("NEW"))
        .body("targetTeamSlug", equalTo("trashed-one"))
        .body("existingTeamName", nullValue())
        .body("trashedTeamSetAside", equalTo("Old Migrated"))
        .body("confirmable", equalTo(true));
  }

  @Test
  void preview_nativeTeamInTheTrash_atTheSlug_isAConflict_notSetAside() {
    Team nativeTeam =
        dataService.createTeam(
            domain, user1, "Native Trashed", "native-trashed", Visibility.PUBLIC);
    biketeamData.trashTeam(nativeTeam.getId());
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("native-trashed");

    preview(req.token(), USER4)
        .statusCode(200)
        .body("targetState", equalTo("SLUG_CONFLICT"))
        .body("trashedTeamSetAside", nullValue());
  }

  @Test
  void preview_teamMigratedInAnotherDomain_isRefused() {
    Domain other = dataService.createDomain("other.example", "Other", "https://other.example");
    var owner = dataService.createUser(other, "owner@other.example", "Owner");
    Team elsewhere =
        dataService.createTeam(other, owner, "Elsewhere", "elsewhere", Visibility.PUBLIC);
    biketeamData.mapTeam("elsewhere", elsewhere);
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("elsewhere");

    preview(req.token(), USER4)
        .statusCode(200)
        .body("targetState", equalTo("MIGRATED_IN_OTHER_DOMAIN"))
        .body("blockReason", equalTo("MIGRATED_IN_OTHER_DOMAIN"));
    confirm(req.token(), USER4)
        .statusCode(409)
        .body("code", equalTo("BIKETEAM_MIGRATED_IN_OTHER_DOMAIN"));
  }

  @Test
  void preview_whileAJobRuns_saysSo() {
    biketeamData.createActiveJob(domain, user5, "busy-team");
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("busy-team");

    preview(req.token(), USER4).statusCode(200).body("blockReason", equalTo("MIGRATION_RUNNING"));
    confirm(req.token(), USER4).statusCode(409).body("code", equalTo("BIKETEAM_MIGRATION_RUNNING"));
  }

  // ─── confirm ──────────────────────────────────────────────────────────────

  @Test
  void confirm_withoutSession_is401() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");
    confirm(req.token(), null).statusCode(401);
  }

  @Test
  void confirm_mintsAGrant_boundToTheUserAndTheDomain() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");

    String redirectUrl =
        confirm(req.token(), USER4)
            .statusCode(200)
            .body(
                "redirectUrl",
                startsWith(req.returnUrl() + "?request=" + req.requestId() + "&grant=bmg_"))
            .extract()
            .path("redirectUrl");
    String grant = redirectUrl.substring(redirectUrl.indexOf("&grant=") + "&grant=".length());
    assertEquals(47, grant.length());

    BiketeamMigrationJob job = biketeamData.findJob(req.requestId());
    assertEquals(BiketeamMigrationStatus.GRANTED, job.getStatus());
    assertEquals(TokenUtils.hashToken(grant), job.getGrantHash());
    assertEquals(user4.getId(), job.getUser().getId());
    assertEquals(domain.getId(), job.getDomain().getId());
    assertEquals(domain.getBaseUrl(), job.getBaseUrl());
    assertEquals("n-peloton", job.getBiketeamTeamId());

    // Once confirmed by user4, nobody else can take the request over.
    preview(req.token(), USER5)
        .statusCode(200)
        .body("blockReason", equalTo("REQUEST_ALREADY_USED"));
    confirm(req.token(), USER5)
        .statusCode(409)
        .body("code", equalTo("BIKETEAM_REQUEST_ALREADY_USED"));
  }

  @Test
  void reconfirm_bySameUser_replacesTheGrant() {
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("n-peloton");

    String first = confirm(req.token(), USER4).statusCode(200).extract().path("redirectUrl");
    String second = confirm(req.token(), USER4).statusCode(200).extract().path("redirectUrl");

    assertNotEquals(first, second);
    String secondGrant = second.substring(second.indexOf("&grant=") + 7);
    assertEquals(
        TokenUtils.hashToken(secondGrant), biketeamData.findJob(req.requestId()).getGrantHash());
  }

  /**
   * A domain alias pinned on the migrated team blocks nothing: no migration trashes a live team any
   * more. A request still carrying {@code reset: true} — a biketeam not yet updated — is the same
   * incremental migration.
   */
  @Test
  void confirm_intoATeamAnAliasIsPinnedOn_isAccepted_evenWithALegacyResetClaim() {
    Team migrated = dataService.createTeam(domain, user4, "Pinned", "pinned", Visibility.PUBLIC);
    biketeamData.mapTeam("pinned", migrated);
    dataService.createDomainAlias(
        "pinned.example", domain, migrated, "Pinned site", "https://pinned.example");

    for (BiketeamTestTokens.Request req :
        new BiketeamTestTokens.Request[] {
          BiketeamTestTokens.request("pinned"),
          BiketeamTestTokens.legacyRequest("pinned", false, true)
        }) {
      preview(req.token(), USER4)
          .statusCode(200)
          .body("targetState", equalTo("EXISTING_MIGRATED"))
          .body("confirmable", equalTo(true))
          .body("blockReason", nullValue());
      confirm(req.token(), USER4).statusCode(200);
    }
  }

  @Test
  void confirm_existingMigratedTeam_byAPlainMember_is403() {
    Team migrated = dataService.createTeam(domain, user1, "Members", "members", Visibility.PUBLIC);
    dataService.addUserToTeam(user2, migrated, TeamRole.ORGANIZER);
    biketeamData.mapTeam("members", migrated);
    BiketeamTestTokens.Request req = BiketeamTestTokens.request("members");

    confirm(req.token(), USER2).statusCode(403).body("code", equalTo("BIKETEAM_NOT_TEAM_ADMIN"));
  }
}
