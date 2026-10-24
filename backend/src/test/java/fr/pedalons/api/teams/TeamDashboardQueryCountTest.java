package fr.pedalons.api.teams;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.ridetemplate.RideTemplate;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.ReportReason;
import fr.pedalons.enums.ReportTargetType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.util.QueryStats;
import io.quarkus.test.junit.QuarkusTest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Database-cost budget for {@code GET /api/teams/{teamSlug}/dashboard}. See {@link
 * AbstractQueryCountTest}.
 *
 * <p>The dashboard takes no page size, so the shape is measured across the data instead: every
 * section is first filled to its page, then the team grows tenfold — more rides, posts, routes,
 * ads, drafts, templates, members, open reports, and more registrations on the very rides the page
 * shows. The pages stay the same size, so neither the statements nor the entities hydrated may
 * follow the data: a section that walked an association, or loaded the whole report queue to count
 * it, would show here.
 */
@QuarkusTest
class TeamDashboardQueryCountTest extends AbstractQueryCountTest {

  private Instant base;
  private Route route;
  private User reporter;
  private final List<RideGroup> openGroups = new ArrayList<>();

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    base = Instant.now().plus(2, ChronoUnit.DAYS);
    route = dataService.createRoute(team1, user1, "Budget route");
    // Not one of the measured users: the listing hides from a caller what they reported, which
    // would leave the member's « Dernières publications » empty in both measurements.
    reporter = dataService.createUser("reporter@example.com", "Budget Reporter");
    dataService.addUserToTeam(reporter, team1, TeamRole.MEMBER);
    openGroups.clear();
  }

  /**
   * {@code count} of everything every section reads, dated after what an earlier call seeded so the
   * rows on the page stay the first ones.
   */
  private void seed(int from, int count) {
    for (int i = from; i < from + count; i++) {
      Ride ride =
          dataService.createRide(
              team1, user1, "Budget Ride " + i, "budget-ride-" + i, base.plus(i, ChronoUnit.HOURS));
      if (i % 2 == 1) {
        dataService.setRideRoute(ride, route);
      }
      // One full group (on the « À traiter » tile) and one open group per ride.
      RideGroup full = dataService.createRideGroupWithMaxParticipants(user1, ride, "Full", 1);
      dataService.createParticipation(full, user2);
      RideGroup open = dataService.createRideGroup(user1, ride, "Open", 1);
      dataService.createParticipation(open, user1);
      // The member is registered too, so their « Vos prochaines sorties » is a full page.
      dataService.createParticipation(open, user3);
      openGroups.add(open);

      dataService.createRide(
          team1,
          user1,
          "Budget Draft " + i,
          "budget-draft-" + i,
          base.plus(i, ChronoUnit.HOURS),
          Visibility.PUBLIC,
          Status.DRAFT);

      Trip trip =
          dataService.createTrip(
              team1, user1, "Budget Trip " + i, base.plus(i, ChronoUnit.HOURS).plusSeconds(1));
      dataService.createTripParticipation(trip, user1);
      dataService.createTripParticipation(trip, user3);

      User author = dataService.createUser("budget" + i + "@example.com", "Budget Member " + i);
      dataService.addUserToTeam(author, team1, TeamRole.MEMBER);
      Post post =
          dataService.createPost(
              team1, author, "Budget Post " + i, Instant.now().minus(i, ChronoUnit.MINUTES));
      dataService.createReport(
          team1, reporter, ReportTargetType.POST, post.getId(), author, ReportReason.SPAM);

      dataService.createRoute(team1, user1, "Budget Route " + i);
      dataService.createAd(team1, author, "Budget Ad " + i, AdType.SALE);

      RideTemplate template =
          dataService.createRideTemplate(
              team1, user1, "Budget Template " + i, "budget-template-" + i);
      dataService.createRideTemplateGroup(user1, template, "A");
      dataService.createRideTemplateGroup(user1, template, "B");
    }
  }

  /** More registrations on the rides already shown: a row must not hydrate them to count them. */
  private void crowdTheShownRides(int extraPerRide) {
    for (int i = 0; i < extraPerRide; i++) {
      User rider = dataService.createUser("rider" + i + "@example.com", "Rider " + i);
      dataService.addUserToTeam(rider, team1, TeamRole.MEMBER);
      for (RideGroup group : openGroups.subList(0, SMALL_PAGE + 2)) {
        dataService.createParticipation(group, rider);
      }
    }
  }

  /** {@code user} null measures an anonymous visitor (docs/LEDGER_*.md API-86). */
  private QueryStats.Counters measure(String label, @Nullable String user) {
    return queryStats.measureAll(
        label,
        () ->
            (user == null ? given() : given().auth().oauth2(getAccessToken(user)))
                .when()
                .get("/api/teams/" + team1Slug + "/dashboard")
                .then()
                .statusCode(200));
  }

  private void assertFlatAcrossData(@Nullable String user) {
    // Five of everything fills every section's page (the largest is five rows).
    seed(0, 5);
    QueryStats.Counters small =
        measure("GET /api/teams/{teamSlug}/dashboard [" + user + ", 5]", user);

    seed(5, LARGE_PAGE - 5);
    crowdTheShownRides(6);
    QueryStats.Counters large =
        measure("GET /api/teams/{teamSlug}/dashboard [" + user + ", " + LARGE_PAGE + "]", user);

    long statementGrowth = large.statements() - small.statements();
    assertTrue(
        statementGrowth <= MAX_STATEMENT_GROWTH,
        () ->
            "N+1 on the dashboard of "
                + user
                + ": "
                + small.statements()
                + " SQL statements with 5 of everything, "
                + large.statements()
                + " with "
                + LARGE_PAGE
                + " (+"
                + statementGrowth
                + ", budget +"
                + MAX_STATEMENT_GROWTH
                + "). A section is running a query per row.");

    long entityGrowth = large.entityLoads() - small.entityLoads();
    assertTrue(
        entityGrowth <= MAX_BOUNDED_ENTITY_GROWTH,
        () ->
            "Entity hydration follows the data on the dashboard of "
                + user
                + ": "
                + small.entityLoads()
                + " entities with 5 of everything, "
                + large.entityLoads()
                + " with "
                + LARGE_PAGE
                + " (+"
                + entityGrowth
                + ", budget +"
                + MAX_BOUNDED_ENTITY_GROWTH
                + "). Every section is a fixed-size page: one is walking an association or loading"
                + " a whole list to count it.");
  }

  /** The administrator gets every section: the widest dashboard, and the one to budget. */
  @Test
  void dashboard_asAdmin_costDoesNotScaleWithTheTeam() {
    assertFlatAcrossData(USER1);
  }

  /** The organizer's tiles go through a different visibility branch (drafts, reports). */
  @Test
  void dashboard_asOrganizer_costDoesNotScaleWithTheTeam() {
    assertFlatAcrossData(USER2);
  }

  /** The member's dashboard, the one most often served. */
  @Test
  void dashboard_asMember_costDoesNotScaleWithTheTeam() {
    assertFlatAcrossData(USER3);
  }

  /** A signed-in visitor: the public part, through the visitor branch of the visibility rules. */
  @Test
  void dashboard_asNonMember_costDoesNotScaleWithTheTeam() {
    assertFlatAcrossData(USER4);
  }

  /** An anonymous visitor: the public part, through the anonymous branch. */
  /** Ledger API-137: a platform admin who is not a member gets the organizer and admin blocks. */
  @Test
  void dashboard_asPlatformAdmin_costDoesNotScaleWithTheTeam() {
    dataService.createPlatformAdminUser("root@example.com", "Root");
    assertFlatAcrossData("root");
  }

  @Test
  void dashboard_anonymously_costDoesNotScaleWithTheTeam() {
    assertFlatAcrossData(null);
  }
}
