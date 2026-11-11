package fr.pedalons.api.teams;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TokenUtils;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.TeamTier;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.ValidatableResponse;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The member cap of the free plan on its four ways in — joining, an addition by an administrator,
 * an invitation sent, an invitation accepted (docs/LEDGER_*.md BILL-10).
 *
 * <p>Fixture reminder: {@code team1} is public, joinable and may add members; user1 is ADMIN, user2
 * ORGANIZER, user3 MEMBER — three members. user4 and user5 are not members. Teams of the fixture are
 * born {@code FREE}, so the cap is 25.
 */
@QuarkusTest
class TeamLimitsResourceTest extends AbstractResourceTest {

  private static final int LIMIT = 25;
  private static final int FIXTURE_MEMBERS = 3;

  @BeforeEach
  void setUpTest() {
    setUp();
  }

  /** Brings team1 up to {@code members} members. */
  private void fillTeam1To(int members) {
    dataService.addFillerMembers(team1, "filler", members - FIXTURE_MEMBERS);
  }

  private ValidatableResponse join(String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(ContentType.JSON)
        .when()
        .post("/api/teams/" + team1Slug + "/members/join")
        .then();
  }

  private ValidatableResponse addMember(String actingUser, User target) {
    return given()
        .auth()
        .oauth2(getAccessToken(actingUser))
        .contentType(ContentType.JSON)
        .body(Map.of("userId", TsidUtils.toString(target.getId()), "role", "MEMBER"))
        .when()
        .post("/api/teams/" + team1Slug + "/members")
        .then();
  }

  private ValidatableResponse invite(String actingUser, String email) {
    return given()
        .auth()
        .oauth2(getAccessToken(actingUser))
        .contentType(ContentType.JSON)
        .body(Map.of("email", email))
        .when()
        .post("/api/teams/" + team1Slug + "/invitations")
        .then();
  }

  private ValidatableResponse accept(String user, String token) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(ContentType.JSON)
        .body(Map.of("token", token))
        .when()
        .post("/api/invitations/accept")
        .then();
  }

  private static void assertLimitReached(ValidatableResponse response, long current) {
    response
        .statusCode(409)
        .body("code", equalTo("TEAM_MEMBER_LIMIT_REACHED"))
        .body("errorDetails.type", equalTo("TEAM_MEMBER_LIMIT_REACHED"))
        .body("errorDetails.limit", equalTo(LIMIT))
        .body("errorDetails.current", equalTo((int) current));
  }

  private void assertMemberCount(int expected) {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug)
        .then()
        .statusCode(200)
        .body("memberCount", equalTo(expected));
  }

  // ==================== Joining ====================

  @Test
  void join_withOnePlaceLeft_takesItThenTheNextIsRefused() {
    fillTeam1To(LIMIT - 1);

    join(USER4).statusCode(201);
    assertLimitReached(join(USER5), LIMIT);
    assertMemberCount(LIMIT);
  }

  @Test
  void join_alreadyAMember_isStillAlreadyRegistered_atTheCap() {
    fillTeam1To(LIMIT);

    join(USER3).statusCode(409).body("code", equalTo("ALREADY_REGISTERED"));
  }

  // ==================== Addition by an administrator ====================

  @Test
  void addMember_atTheCap_isRefused() {
    fillTeam1To(LIMIT);

    assertLimitReached(addMember(USER1, user4), LIMIT);
    assertMemberCount(LIMIT);
  }

  @Test
  void addMember_belowTheCap_passes() {
    fillTeam1To(LIMIT - 1);

    addMember(USER1, user4).statusCode(201);
  }

  // ==================== Invitation sent ====================

  @Test
  void invite_atTheCap_isRefused() {
    fillTeam1To(LIMIT);

    assertLimitReached(invite(USER1, "newcomer@example.com"), LIMIT);
  }

  @Test
  void invite_countsPendingInvitations() {
    fillTeam1To(LIMIT - 3);
    dataService.createPendingInvitation(team1, user1, "pending-1@example.com");
    dataService.createPendingInvitation(team1, user1, "pending-2@example.com");

    // 22 members + 2 pending: room for one more invitation, not for two.
    invite(USER1, "newcomer@example.com").statusCode(201);
    assertLimitReached(invite(USER1, "another@example.com"), LIMIT);
  }

  /** A re-invitation replaces the live one: it is not counted twice. */
  @Test
  void invite_resendingAPendingInvitation_atTheCap_passes() {
    fillTeam1To(LIMIT - 1);
    dataService.createPendingInvitation(team1, user1, "pending@example.com");

    invite(USER1, "pending@example.com").statusCode(201);
  }

  @Test
  void invite_aLapsedInvitation_isNotCounted() {
    fillTeam1To(LIMIT - 1);
    String token = dataService.createPendingInvitation(team1, user1, "lapsed@example.com");
    dataService.expireInvitation(TokenUtils.hashToken(token));

    invite(USER1, "newcomer@example.com").statusCode(201);
  }

  // ==================== Invitation accepted ====================

  /** Its own pending invitation does not count against the invitee. */
  @Test
  void accept_withOnePlaceLeft_passes() {
    dataService.markEmailVerified(user4);
    String token = dataService.createPendingInvitation(team1, user1, EMAIL4);
    fillTeam1To(LIMIT - 1);

    accept(USER4, token).statusCode(200);
    assertMemberCount(LIMIT);
  }

  /** Sent under the cap, the invitation finds the team full: others came in meanwhile. */
  @Test
  void accept_afterTheTeamFilledUp_isRefused() {
    dataService.markEmailVerified(user4);
    String token = dataService.createPendingInvitation(team1, user1, EMAIL4);
    fillTeam1To(LIMIT);

    assertLimitReached(accept(USER4, token), LIMIT);
    assertMemberCount(LIMIT);
  }

  // ==================== Unlocked tier ====================

  @Test
  void unlocked_acceptsEveryWayInBeyondTheFreeCap() {
    dataService.setTeamTier(team1, TeamTier.UNLOCKED);
    fillTeam1To(LIMIT);
    dataService.markEmailVerified(user5);
    String token = dataService.createPendingInvitation(team1, user1, EMAIL5);

    join(USER4).statusCode(201);
    invite(USER1, "newcomer@example.com").statusCode(201);
    accept(USER5, token).statusCode(200);
    User extra = dataService.createUser(domain, "extra@example.com", "Extra");
    addMember(USER1, extra).statusCode(201);

    assertMemberCount(LIMIT + 3);
  }

  // ==================== Platform admin ====================

  @Test
  void platformAdmin_isExemptFromTheCap() {
    dataService.createPlatformAdminUser("padmin@example.com", "Platform Admin");
    fillTeam1To(LIMIT);

    join("padmin").statusCode(201);
    addMember("padmin", user4).statusCode(201);
    invite("padmin", "newcomer@example.com").statusCode(201);

    assertMemberCount(LIMIT + 2);
  }

  // ==================== Downgrade ====================

  /** Nothing is lost going back to the free plan: the team keeps its 30, refuses the 31st. */
  @Test
  void downgradedTeam_keepsItsMembersAndRefusesTheNext() {
    dataService.setTeamTier(team1, TeamTier.UNLOCKED);
    fillTeam1To(30);
    dataService.setTeamTier(team1, TeamTier.FREE);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug)
        .then()
        .statusCode(200)
        .body("tier", equalTo("FREE"))
        .body("memberLimit", equalTo(LIMIT))
        .body("memberCount", equalTo(30));

    assertLimitReached(join(USER4), 30);
    assertLimitReached(addMember(USER1, user4), 30);
    assertLimitReached(invite(USER1, "newcomer@example.com"), 30);
    assertMemberCount(30);
  }
}
