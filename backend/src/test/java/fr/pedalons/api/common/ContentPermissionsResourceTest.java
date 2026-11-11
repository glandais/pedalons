package fr.pedalons.api.common;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.anyOf;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.hasKey;
import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.response.ValidatableResponse;
import io.restassured.specification.RequestSpecification;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The computed rights of docs/LEDGER_*.md API-176 (plan §4.5) as the clients receive them: the
 * {@code permissions} block of every entity detail, the {@code accessible} flag of its team, and
 * the content fields of {@code TeamDetailDto} — for an anonymous caller, an outsider, a member, an
 * organizer, a team admin and a platform admin, on a public team, an unlisted one, a private one
 * with {@code publicContentAllowed} and a private one without.
 *
 * <p>On each team user1 is admin, user2 organizer, user3 member; user4 belongs to none of them.
 * The entities are {@code PUBLIC}, except in the private team without the flag, which can only
 * hold {@code TEAM} content ({@code V87}). The ads are written by user3.
 */
@QuarkusTest
class ContentPermissionsResourceTest extends AbstractResourceTest {

  private static final String ROOT = "root";

  /** anonymous, outsider, member, organizer, admin, platform admin. */
  private static final String[] CALLERS = {null, USER4, USER3, USER2, USER1, ROOT};

  private static final List<String> ALL = List.of("TEAM", "PUBLIC_UNLISTED", "PUBLIC");
  private static final List<String> TEAM_ONLY = List.of("TEAM");

  private Team unlistedTeam;
  private Team closedTeam;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.createPlatformAdminUser("root@example.com", "Root");
    dataService.setTeamPublicContentAllowed(team2, true);
    unlistedTeam =
        dataService.createTeam(user1, "Unlisted", "unlisted-team", Visibility.PUBLIC_UNLISTED);
    closedTeam = dataService.createTeam(user1, "Closed", "closed-team", Visibility.TEAM);
    for (Team team : List.of(unlistedTeam, closedTeam)) {
      dataService.addUserToTeam(user2, team, TeamRole.ORGANIZER);
      dataService.addUserToTeam(user3, team, TeamRole.MEMBER);
    }
    Instant soon = Instant.now().plus(7, ChronoUnit.DAYS);
    for (Team team : List.of(team1, unlistedTeam, team2, closedTeam)) {
      Visibility visibility = team == closedTeam ? Visibility.TEAM : Visibility.PUBLIC;
      // With a group still to leave: the detail's canRegister also says what the join would.
      dataService.createRideGroup(
          user1, dataService.createRide(team, user1, "Ride", "ride", soon, visibility), "Group");
      dataService.createRoute(team, user1, "Route", visibility);
      // A route of its own for the stage: the trip's usage takes TEAM out of its editor's list
      // (docs/LEDGER_*.md API-176, plan §4.4), and "route" keeps the team's whole list.
      Route stageRoute = dataService.createRoute(team, user1, "Stage route", visibility);
      dataService.createPost(team, user2, "Post", Instant.now(), visibility);
      Trip trip = dataService.createTrip(team, user1, "Trip", soon, visibility);
      // With a route: the stage embeds its summary, which must carry no visibilities.
      dataService.setTripStageRoute(
          dataService.createTripStage(user1, trip, "Stage", 0), stageRoute);
      dataService.createAdditionalPage(team, user1, "Page", 0, visibility);
      dataService.createAd(team, user3, "Ad", AdType.SALE);
    }
  }

  private RequestSpecification as(@Nullable String user) {
    RequestSpecification spec = given();
    return user == null ? spec : spec.auth().oauth2(getAccessToken(user));
  }

  private List<Team> teams() {
    return List.of(team1, unlistedTeam, team2, closedTeam);
  }

  private static boolean isMember(@Nullable String caller) {
    return USER1.equals(caller) || USER2.equals(caller) || USER3.equals(caller);
  }

  private static boolean belongs(@Nullable String caller) {
    return isMember(caller) || ROOT.equals(caller);
  }

  private static boolean organizes(@Nullable String caller) {
    return USER1.equals(caller) || USER2.equals(caller) || ROOT.equals(caller);
  }

  private static boolean administers(@Nullable String caller) {
    return USER1.equals(caller) || ROOT.equals(caller);
  }

  /** The expected block, absent fields left out as the server leaves them out. */
  private Map<String, Object> expected(String type, @Nullable String caller, Team team) {
    boolean write =
        switch (type) {
          case "page" -> administers(caller);
          // user3 wrote the ads.
          case "ad" -> administers(caller) || USER3.equals(caller);
          default -> organizes(caller);
        };
    Map<String, Object> block = new LinkedHashMap<>();
    block.put("canEdit", write);
    block.put("canDelete", write);
    if (type.equals("ride") || type.equals("trip")) {
      block.put("canRegister", belongs(caller));
    }
    if (!type.equals("page") && !type.equals("ad")) {
      block.put("canComment", belongs(caller));
    }
    if (type.equals("ride") || type.equals("trip")) {
      block.put("canSeeParticipants", belongs(caller));
    }
    if (type.equals("ad")) {
      block.put("allowedVisibilities", TEAM_ONLY);
    } else if (!type.equals("stage")) {
      block.put(
          "allowedVisibilities",
          team.getVisibility() == Visibility.TEAM && team != team2 ? TEAM_ONLY : ALL);
    }
    block.put("indexable", team == team1 && !type.equals("ad"));
    return block;
  }

  private static boolean readable(String type, @Nullable String caller, Team team, Team closed) {
    if (type.equals("ad") || team == closed) {
      return belongs(caller);
    }
    return true;
  }

  @Test
  void theBlock_onEveryDetail_forEveryCaller_andEveryTeam() {
    Map<String, String> paths =
        Map.of(
            "ride", "/rides/ride",
            "route", "/routes/route",
            "post", "/posts/post",
            "trip", "/trips/trip",
            "page", "/pages/page",
            "ad", "/classifieds/ad");
    for (Team team : teams()) {
      for (String caller : CALLERS) {
        for (var entry : paths.entrySet()) {
          String type = entry.getKey();
          String where = type + " / " + caller + " / " + team.getSlug();
          ValidatableResponse response =
              as(caller).when().get("/api/teams/" + team.getSlug() + entry.getValue()).then();
          if (!readable(type, caller, team, closedTeam)) {
            response.statusCode(anyOf(equalTo(401), equalTo(403), equalTo(404)));
            continue;
          }
          response.statusCode(200);
          Map<String, Object> block = response.extract().jsonPath().getMap("permissions");
          assertEquals(expected(type, caller, team), block, where);
          boolean accessible = team.getVisibility() != Visibility.TEAM || belongs(caller);
          assertEquals(
              accessible, response.extract().jsonPath().getBoolean("team.accessible"), where);
          if (type.equals("trip")) {
            Map<String, Object> stage =
                response.extract().jsonPath().getMap("stages[0].permissions");
            assertEquals(expected("stage", caller, team), stage, "stage / " + where);
            // The stage's route is an embedded summary: the route's block, no visibilities.
            Map<String, Object> stageRoute =
                response.extract().jsonPath().getMap("stages[0].route.permissions");
            Map<String, Object> embeddedRoute = expected("route", caller, team);
            embeddedRoute.remove("allowedVisibilities");
            assertEquals(embeddedRoute, stageRoute, "stage route / " + where);
          }
        }
      }
    }
  }

  /**
   * The stage's route is used by a {@code PUBLIC} trip outside the closed team: its editors are
   * offered no {@code TEAM}, which the save would refuse (docs/LEDGER_*.md API-176, plan §4.4).
   * Anyone else gets the team's list, unchanged: the usage may be a draft or a hidden trip they
   * cannot see, which a missing {@code TEAM} would give away.
   */
  @Test
  void aRouteUsedPublicly_leavesTeamOut_forItsEditorsOnly() {
    for (Team team : teams()) {
      for (String caller : CALLERS) {
        String where = caller + " / " + team.getSlug();
        ValidatableResponse response =
            as(caller).when().get("/api/teams/" + team.getSlug() + "/routes/stage-route").then();
        if (!readable("route", caller, team, closedTeam)) {
          response.statusCode(anyOf(equalTo(401), equalTo(403), equalTo(404)));
          continue;
        }
        response.statusCode(200);
        List<String> teamList =
            team.getVisibility() == Visibility.TEAM && team != team2 ? TEAM_ONLY : ALL;
        List<String> expected =
            organizes(caller) && team != closedTeam
                ? List.of("PUBLIC_UNLISTED", "PUBLIC")
                : teamList;
        assertEquals(
            expected,
            response.extract().jsonPath().getList("permissions.allowedVisibilities"),
            where);
      }
    }
  }

  @Test
  void listRows_carryTheBlock_withoutVisibilities() {
    for (String caller : CALLERS) {
      as(caller)
          .when()
          .get("/api/teams/" + team1Slug + "/publications")
          .then()
          .statusCode(200)
          .body("publications.permissions", everyItem(not(hasKey("allowedVisibilities"))))
          .body("publications.permissions.canEdit", everyItem(equalTo(organizes(caller))))
          .body("publications.team.accessible", everyItem(equalTo(true)));
      as(caller)
          .when()
          .get("/api/teams/" + team1Slug + "/routes")
          .then()
          .statusCode(200)
          .body("routes.permissions", everyItem(not(hasKey("allowedVisibilities"))))
          .body("routes.permissions.canEdit", everyItem(equalTo(organizes(caller))));
    }
    as(USER3)
        .when()
        .get("/api/teams/" + team1Slug + "/classifieds")
        .then()
        .statusCode(200)
        .body("ads.permissions", everyItem(not(hasKey("allowedVisibilities"))))
        .body("ads.permissions.canEdit", everyItem(equalTo(true)));
  }

  @Test
  void aPrivateTeamsPublicRide_saysTheTeamIsNotAccessible_toAnOutsider() {
    for (String caller : new String[] {null, USER4}) {
      as(caller)
          .when()
          .get("/api/teams/" + team2Slug + "/rides/ride")
          .then()
          .statusCode(200)
          .body("team.accessible", equalTo(false));
      // And GET team agrees.
      as(caller)
          .when()
          .get("/api/teams/" + team2Slug)
          .then()
          .statusCode(anyOf(equalTo(401), equalTo(403), equalTo(404)));
    }
  }

  /**
   * On a detail, {@code canRegister} is what the join answers: false once every group of the ride
   * has left ({@code RIDE_PAST}) or the trip is over ({@code TRIP_FINISHED}), for a member and for
   * a platform admin alike; the open ride of the fixture says true and the join takes the member.
   * Each verdict is checked against the join endpoint itself.
   */
  @Test
  void canRegister_onADetail_isWhatTheJoinAnswers() {
    Instant past = Instant.now().minus(2, ChronoUnit.DAYS);
    Ride left = dataService.createRide(team1, user1, "Left", "left", past, Visibility.PUBLIC);
    RideGroup leftGroup = dataService.createRideGroup(user1, left, "Gone");
    Trip finished = dataService.createTrip(team1, user1, "Finished", past, Visibility.PUBLIC);
    dataService.createTripStage(user1, finished, "Over", past);

    for (String caller : new String[] {USER3, ROOT}) {
      as(caller)
          .when()
          .get("/api/teams/" + team1Slug + "/rides/left")
          .then()
          .statusCode(200)
          .body("permissions.canRegister", equalTo(false));
      as(caller)
          .contentType("application/json")
          .when()
          .post(
              "/api/teams/"
                  + team1Slug
                  + "/rides/left/groups/"
                  + TsidUtils.toString(leftGroup.getId())
                  + "/join")
          .then()
          .statusCode(409)
          .body("code", equalTo("RIDE_PAST"));

      as(caller)
          .when()
          .get("/api/teams/" + team1Slug + "/trips/" + finished.getSlug())
          .then()
          .statusCode(200)
          .body("permissions.canRegister", equalTo(false));
      as(caller)
          .contentType("application/json")
          .when()
          .post("/api/teams/" + team1Slug + "/trips/" + finished.getSlug() + "/join")
          .then()
          .statusCode(409)
          .body("code", equalTo("TRIP_FINISHED"));
    }

    // The control: an open ride says true, and the join agrees.
    String groupId =
        as(USER3)
            .when()
            .get("/api/teams/" + team1Slug + "/rides/ride")
            .then()
            .statusCode(200)
            .body("permissions.canRegister", equalTo(true))
            .extract()
            .path("groups[0].id");
    as(USER3)
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/rides/ride/groups/" + groupId + "/join")
        .then()
        .statusCode(anyOf(equalTo(200), equalTo(201)));
  }

  /** Each row of the table of plan §4.2, for every caller who may read the team. */
  @Test
  void teamDetail_contentVisibilities_andDefault() {
    record Row(Team team, List<String> content, String defaultVisibility, boolean flag) {}
    for (Row row :
        List.of(
            new Row(team1, ALL, "PUBLIC", false),
            new Row(unlistedTeam, ALL, "PUBLIC_UNLISTED", false),
            new Row(team2, ALL, "TEAM", true),
            new Row(closedTeam, TEAM_ONLY, "TEAM", false))) {
      for (String caller : CALLERS) {
        boolean readsTeam = row.team().getVisibility() != Visibility.TEAM || belongs(caller);
        if (!readsTeam) {
          continue;
        }
        String where = row.team().getSlug() + " / " + caller;
        var json =
            as(caller)
                .when()
                .get("/api/teams/" + row.team().getSlug())
                .then()
                .statusCode(200)
                .extract()
                .jsonPath();
        for (String type : List.of("ride", "rideTemplate", "route", "post", "trip", "teamPage")) {
          assertEquals(
              row.content(),
              json.getList("allowedContentVisibilities." + type),
              type + " / " + where);
        }
        assertEquals(TEAM_ONLY, json.getList("allowedContentVisibilities.ad"), "ad / " + where);
        assertEquals(row.defaultVisibility(), json.getString("defaultContentVisibility"), where);
        assertEquals(row.flag(), json.getBoolean("publicContentAllowed"), where);
      }
    }
  }

  @Test
  void teamList_carriesTheContentFields() {
    as(USER3)
        .when()
        .get("/api/teams?minRole=MEMBER")
        .then()
        .statusCode(200)
        .body(
            "teams.find { it.slug == 'closed-team' }.allowedContentVisibilities.ride",
            equalTo(TEAM_ONLY))
        .body("teams.find { it.slug == 'team-2' }.allowedContentVisibilities.ride", equalTo(ALL))
        .body("teams.find { it.slug == 'team-2' }.defaultContentVisibility", equalTo("TEAM"));
  }
}
