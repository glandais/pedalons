package fr.pedalons.api.rides;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Database-cost budget for the participants of a ride or a trip (docs/LEDGER_*.md API-12).
 *
 * <p>Two shapes, because they regress independently:
 *
 * <ul>
 *   <li>the paginated {@code …/participants} lists must cost the same for a page of 3 and a page of
 *       30 — the users are selected directly, never through a walk of the participations;
 *   <li>the ride and trip details embed a bounded preview, so a ride of 30 participants must cost
 *       no more to read than a ride of 3. Walking {@code group.getParticipations()} to count or to
 *       draw avatars would hydrate every registration again, which is what this catches.
 * </ul>
 */
@QuarkusTest
class ParticipantListQueryCountTest extends AbstractQueryCountTest {

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private List<User> seedUsers(String prefix, int count) {
    List<User> users = new ArrayList<>();
    for (int i = 0; i < count; i++) {
      users.add(dataService.createUser(prefix + i + "@example.com", "Rider " + prefix + " " + i));
    }
    return users;
  }

  private RideGroup seedRide(String slug, int participants) {
    Ride ride =
        dataService.createRide(
            team1,
            user1,
            "Ride " + slug,
            slug,
            Instant.now().plus(7, ChronoUnit.DAYS),
            Visibility.PUBLIC,
            Status.PUBLISHED);
    RideGroup group = dataService.createRideGroup(user1, ride, "Group A", 0);
    // A second group, so the ride-wide list and the preview lookup both span several groups.
    RideGroup other = dataService.createRideGroup(user1, ride, "Group B", 1);
    List<User> users = seedUsers(slug, participants);
    for (int i = 0; i < users.size(); i++) {
      dataService.createParticipation(i % 2 == 0 ? group : other, users.get(i));
    }
    return group;
  }

  private Trip seedTrip(String name, int participants) {
    Trip trip =
        dataService.createTrip(
            team1, user1, name, Instant.now().plus(7, ChronoUnit.DAYS), Visibility.PUBLIC);
    dataService.createTripStage(user1, trip, name + " Stage", 0);
    for (User user : seedUsers(trip.getSlug(), participants)) {
      dataService.createTripParticipation(trip, user);
    }
    return trip;
  }

  @Test
  void listRideParticipants_costDoesNotScaleWithRowCount() {
    seedRide("crowded-ride", LARGE_PAGE * 2);
    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/rides/{rideSlug}/participants",
        asUser1(),
        "/api/teams/" + team1Slug + "/rides/crowded-ride/participants");
  }

  @Test
  void listRideGroupParticipants_costDoesNotScaleWithRowCount() {
    RideGroup group = seedRide("crowded-group", LARGE_PAGE * 2);
    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/rides/{rideSlug}/participants?groupId=",
        // Members only (docs/LEDGER_*.md API-144): an anonymous call is refused.
        asUser1(),
        "/api/teams/"
            + team1Slug
            + "/rides/crowded-group/participants?groupId="
            + TsidUtils.toString(group.getId()));
  }

  @Test
  void listTripParticipants_costDoesNotScaleWithRowCount() {
    Trip trip = seedTrip("Crowded Trip", LARGE_PAGE);
    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/trips/{tripSlug}/participants",
        asUser1(),
        "/api/teams/" + team1Slug + "/trips/" + trip.getSlug() + "/participants");
  }

  @Test
  void rideDetail_costDoesNotScaleWithParticipantCount() {
    seedRide("small-ride", SMALL_PAGE);
    seedRide("large-ride", LARGE_PAGE);
    assertFlatAcrossResources(
        "GET /api/teams/{teamSlug}/rides/{rideSlug} (participants preview)",
        asUser1(),
        "/api/teams/" + team1Slug + "/rides/small-ride",
        "/api/teams/" + team1Slug + "/rides/large-ride");
  }

  @Test
  void tripDetail_costDoesNotScaleWithParticipantCount() {
    Trip small = seedTrip("Small Trip", SMALL_PAGE);
    Trip large = seedTrip("Large Trip", LARGE_PAGE);
    assertFlatAcrossResources(
        "GET /api/teams/{teamSlug}/trips/{tripSlug} (participants preview)",
        asUser1(),
        "/api/teams/" + team1Slug + "/trips/" + small.getSlug(),
        "/api/teams/" + team1Slug + "/trips/" + large.getSlug());
  }
}
