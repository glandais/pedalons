package fr.pedalons.api.publications;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.nullValue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.common.BaseEntity;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.trip.Trip;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.specification.RequestSpecification;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code when=UPCOMING_FIRST} on the team and the cross-team publication lists (docs/LEDGER_*.md
 * API-185, rule RL15): one list in two sections — « À venir », the rides and trips not over yet
 * judged by their end, soonest departure first; then « Plus tôt », everything else, posts included,
 * latest first — with {@code upcomingTotal}, the size of the first section, on every page.
 */
@QuarkusTest
class PublicationUpcomingFirstTest extends AbstractResourceTest {

  private Ride longUnderWay;
  private Ride underWay;
  private Ride future1;
  private Ride future2;
  private Ride tieA;
  private Ride tieB;
  private Trip trip;
  private Post post;
  private Ride overRecent;
  private Ride overOld;
  private Post post2;
  private Ride pastTieA;
  private Ride pastTieB;
  private Trip pastTrip;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    dataService.setTeamModules(team1, true, true);
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    // Left 5 h ago, its stored end still ahead: under way, so « À venir », and first there.
    longUnderWay = dataService.createRide(team1, user1, "Longue", "longue", now.minus(hours(5)));
    dataService.setEndDateTime(longUnderWay.getId(), now.plus(hours(1)));
    // No stored end: the departure plus 3 h, under way for two more hours.
    underWay = dataService.createRide(team1, user1, "En cours", "en-cours", now.minus(hours(1)));
    future1 = dataService.createRide(team1, user1, "Demain", "demain", now.plus(hours(24)));
    future2 = dataService.createRide(team1, user1, "Après", "apres", now.plus(hours(48)));
    // Same departure: the id breaks the tie, the older first in « À venir ».
    tieA = dataService.createRide(team1, user1, "Égalité A", "egalite-a", now.plus(hours(72)));
    tieB = dataService.createRide(team1, user1, "Égalité B", "egalite-b", now.plus(hours(72)));
    trip = dataService.createTrip(team1, user1, "Voyage à venir", now.plus(hours(240)));
    // A post has no end: « Plus tôt », at its publication date, between the outings over.
    post = dataService.createPost(team1, user1, "Billet récent", now.minus(hours(2)));
    // Same departure as longUnderWay, but over: the section is judged by the end.
    overRecent = dataService.createRide(team1, user1, "Finie", "finie", now.minus(hours(5)));
    overOld = dataService.createRide(team1, user1, "Ancienne", "ancienne", now.minus(hours(48)));
    post2 = dataService.createPost(team1, user1, "Billet ancien", now.minus(hours(60)));
    // Same departure: the id breaks the tie, the newer first in « Plus tôt ».
    pastTieA = dataService.createRide(team1, user1, "Passée A", "passee-a", now.minus(hours(96)));
    pastTieB = dataService.createRide(team1, user1, "Passée B", "passee-b", now.minus(hours(96)));
    pastTrip = dataService.createTrip(team1, user1, "Voyage passé", now.minus(hours(720)));
  }

  private static Duration hours(int h) {
    return Duration.ofHours(h);
  }

  private static String id(BaseEntity entity) {
    return TsidUtils.toString(entity.getId());
  }

  private String[] upcomingSection() {
    return new String[] {
      id(longUnderWay), id(underWay), id(future1), id(future2), id(tieA), id(tieB), id(trip)
    };
  }

  private String[] earlierSection() {
    return new String[] {
      id(post), id(overRecent), id(overOld), id(post2), id(pastTieB), id(pastTieA), id(pastTrip)
    };
  }

  private String[] wholeList() {
    String[] upcoming = upcomingSection();
    String[] earlier = earlierSection();
    String[] all = new String[upcoming.length + earlier.length];
    System.arraycopy(upcoming, 0, all, 0, upcoming.length);
    System.arraycopy(earlier, 0, all, upcoming.length, earlier.length);
    return all;
  }

  private RequestSpecification asUser1() {
    return given().auth().oauth2(getAccessToken(USER1));
  }

  private String teamList() {
    return "/api/teams/" + team1Slug + "/publications";
  }

  @Test
  void upcomingThenEarlier_inOneTotalOrder_withTheSizeOfTheFirstSection() {
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body("publications.id", contains(wholeList()))
        .body("total", equalTo(14))
        .body("upcomingTotal", equalTo(7));
  }

  @Test
  void theBoundary_fallsInTheMiddleOfAPage_withTheSameCountsOnEveryPage() {
    String[] all = wholeList();
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .queryParam("size", 5)
        .queryParam("page", 0)
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body("publications.id", contains(all[0], all[1], all[2], all[3], all[4]))
        .body("total", equalTo(14))
        .body("upcomingTotal", equalTo(7));
    // Positions 5 and 6 are « À venir » (below upcomingTotal), 7 to 9 « Plus tôt ».
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .queryParam("size", 5)
        .queryParam("page", 1)
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body(
            "publications.id", contains(id(tieB), id(trip), id(post), id(overRecent), id(overOld)))
        .body("total", equalTo(14))
        .body("upcomingTotal", equalTo(7));
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .queryParam("size", 5)
        .queryParam("page", 2)
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body("publications.id", contains(id(post2), id(pastTieB), id(pastTieA), id(pastTrip)))
        .body("upcomingTotal", equalTo(7));
  }

  @Test
  void theBoundary_fallsBetweenTwoPages() {
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .queryParam("size", 7)
        .queryParam("page", 0)
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body("publications.id", contains(upcomingSection()))
        .body("upcomingTotal", equalTo(7));
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .queryParam("size", 7)
        .queryParam("page", 1)
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body("publications.id", contains(earlierSection()))
        .body("upcomingTotal", equalTo(7));
  }

  @Test
  void participating_appliesToBothSections() {
    RideGroup group = dataService.createRideGroup(user1, underWay, "G");
    dataService.createParticipation(group, user1);
    RideGroup pastGroup = dataService.createRideGroup(user1, overOld, "G");
    dataService.createParticipation(pastGroup, user1);
    dataService.createTripParticipation(trip, user1);
    dataService.createTripParticipation(pastTrip, user1);
    // Someone else's registration does not count.
    RideGroup otherGroup = dataService.createRideGroup(user1, future1, "G");
    dataService.createParticipation(otherGroup, user2);

    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .queryParam("participating", true)
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body("publications.id", contains(id(underWay), id(trip), id(overOld), id(pastTrip)))
        .body("total", equalTo(4))
        .body("upcomingTotal", equalTo(2));
  }

  @Test
  void type_appliesToBothSections() {
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .queryParam("type", "RIDE")
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body(
            "publications.id",
            contains(
                id(longUnderWay),
                id(underWay),
                id(future1),
                id(future2),
                id(tieA),
                id(tieB),
                id(overRecent),
                id(overOld),
                id(pastTieB),
                id(pastTieA)))
        .body("total", equalTo(10))
        .body("upcomingTotal", equalTo(6));
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .queryParam("type", "TRIP")
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body("publications.id", contains(id(trip), id(pastTrip)))
        .body("total", equalTo(2))
        .body("upcomingTotal", equalTo(1));
    // Posts only: everything in « Plus tôt ».
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .queryParam("type", "POST")
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body("publications.id", contains(id(post), id(post2)))
        .body("total", equalTo(2))
        .body("upcomingTotal", equalTo(0));
  }

  @Test
  void theCrossTeamList_servesTheSameOrder_andItsCountTheWholeList() {
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .when()
        .get("/api/publications")
        .then()
        .statusCode(200)
        .body("publications.id", contains(wholeList()))
        .body("total", equalTo(14))
        .body("upcomingTotal", equalTo(7));
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .when()
        .get("/api/publications/count")
        .then()
        .statusCode(200)
        .body("total", equalTo(14));
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .when()
        .get(teamList() + "/count")
        .then()
        .statusCode(200)
        .body("total", equalTo(14));
  }

  @Test
  void sortDir_isIgnored() {
    asUser1()
        .queryParam("when", "UPCOMING_FIRST")
        .queryParam("sortDir", "ASC")
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body("publications.id", contains(wholeList()));
  }

  @Test
  void anAnonymousParticipatingList_isEmpty_withAnEmptyFirstSection() {
    given()
        .queryParam("when", "UPCOMING_FIRST")
        .queryParam("participating", true)
        .when()
        .get("/api/publications")
        .then()
        .statusCode(200)
        .body("publications", empty())
        .body("total", equalTo(0))
        .body("upcomingTotal", equalTo(0));
  }

  @Test
  void withoutWhen_theListIsUnchanged_newestFirst_noSections() {
    // Same departure for longUnderWay and overRecent: the newer id first, as before.
    asUser1()
        .when()
        .get(teamList())
        .then()
        .statusCode(200)
        .body(
            "publications.id",
            contains(
                id(trip),
                id(tieB),
                id(tieA),
                id(future2),
                id(future1),
                id(underWay),
                id(post),
                id(overRecent),
                id(longUnderWay),
                id(overOld),
                id(post2),
                id(pastTieB),
                id(pastTieA),
                id(pastTrip)))
        .body("total", equalTo(14))
        .body("upcomingTotal", nullValue());
    asUser1()
        .queryParam("when", "UPCOMING")
        .when()
        .get("/api/publications")
        .then()
        .statusCode(200)
        .body("publications.id", contains(upcomingSection()))
        .body("upcomingTotal", nullValue());
  }
}
