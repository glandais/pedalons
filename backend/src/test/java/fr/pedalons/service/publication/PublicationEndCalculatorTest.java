package fr.pedalons.service.publication;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneOffset;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.Test;

/**
 * The rule of {@link PublicationEndCalculator}, on entities held in memory (docs/LEDGER_*.md
 * API-85). The values it stores at each entry point are covered by {@code PublicationEndStoredTest}.
 */
class PublicationEndCalculatorTest {

  private static final Instant START = Instant.parse("2026-06-07T07:00:00Z");

  private final PublicationEndCalculator calculator = new PublicationEndCalculator();

  private static Route route(float meters) {
    Route route = new Route();
    route.setDistance(meters);
    return route;
  }

  private static Ride ride() {
    Ride ride = new Ride();
    ride.setDateTime(START);
    return ride;
  }

  private static RideGroup group(
      Ride ride, @Nullable LocalTime time, @Nullable Route route, @Nullable Float speed) {
    RideGroup group = new RideGroup(null, ride, "G");
    // A time read in UTC, so that 10:00 is 10:00Z; the zone is the resolver's concern.
    EventTimezoneResolver.setStart(group, ride.getDateTime(), time, ZoneOffset.UTC);
    group.setRoute(route);
    group.setAverageSpeed(speed);
    ride.addGroup(group);
    return group;
  }

  @Test
  void theDefaultDuration_isThreeHours() {
    assertEquals(Duration.ofHours(3), PublicationEndCalculator.DEFAULT_DURATION);
  }

  @Test
  void aRideWithoutGroup_lastsTheDefaultDuration() {
    assertEquals(START.plus(Duration.ofHours(3)), calculator.rideEnd(ride()));
  }

  @Test
  void aGroup_endsAfterItsRoute_atItsSpeed() {
    Ride ride = ride();
    group(ride, null, route(50_000), 25f);
    assertEquals(START.plus(Duration.ofHours(2)), calculator.rideEnd(ride));
  }

  @Test
  void aGroupWithoutRoute_fallsBackOnTheRidesRoute() {
    Ride ride = ride();
    ride.setRoute(route(100_000));
    group(ride, null, null, 20f);
    assertEquals(START.plus(Duration.ofHours(5)), calculator.rideEnd(ride));
  }

  @Test
  void aGroupWithoutSpeedOrRoute_takesTheDefaultDuration() {
    Ride noSpeed = ride();
    group(noSpeed, null, route(10_000), null);
    assertEquals(START.plus(Duration.ofHours(3)), calculator.rideEnd(noSpeed));

    Ride noRoute = ride();
    group(noRoute, null, null, 30f);
    assertEquals(START.plus(Duration.ofHours(3)), calculator.rideEnd(noRoute));
  }

  @Test
  void aDeletedRoute_countsAsNoRoute() {
    Ride ride = ride();
    Route deleted = route(200_000);
    deleted.setDeleted(true);
    group(ride, null, deleted, 20f);
    assertEquals(START.plus(Duration.ofHours(3)), calculator.rideEnd(ride));
  }

  @Test
  void theRideEnds_withItsLatestGroup_eachFromItsOwnStart() {
    Ride ride = ride();
    group(ride, null, route(50_000), 25f); // 07:00 → 09:00
    // From its stored start_at, the one departure every reader shares (docs/LEDGER_*.md API-60):
    // 08:00 → 10:00 at 30 km/h.
    group(ride, LocalTime.of(8, 0), route(60_000), 30f);
    assertEquals(Instant.parse("2026-06-07T10:00:00Z"), calculator.rideEnd(ride));
  }

  @Test
  void aTrip_endsWithItsLatestLiveStage_andEachStageGetsItsOwnEnd() {
    Trip trip = new Trip();
    trip.setDateTime(START);
    TripStage first = new TripStage(null, trip, "J1", "j1");
    first.setDateTime(START);
    first.setRoute(route(80_000));
    first.setAverageSpeed(20f);
    TripStage second = new TripStage(null, trip, "J2", "j2");
    second.setDateTime(START.plus(Duration.ofDays(1)));
    TripStage dropped = new TripStage(null, trip, "J3", "j3");
    dropped.setDateTime(START.plus(Duration.ofDays(5)));
    dropped.setDeleted(true);
    trip.addStage(first);
    trip.addStage(second);
    trip.addStage(dropped);

    PublicationEndCalculator.TripEnds ends = calculator.tripEnds(trip);

    assertEquals(START.plus(Duration.ofDays(1)).plus(Duration.ofHours(3)), ends.end());
    assertEquals(START.plus(Duration.ofHours(4)), ends.stages().get(first));
    assertFalse(ends.stages().containsKey(dropped));
  }

  @Test
  void aTripWithoutStage_lastsTheDefaultDuration() {
    Trip trip = new Trip();
    trip.setDateTime(START);
    assertEquals(START.plus(Duration.ofHours(3)), calculator.tripEnds(trip).end());
  }

  @Test
  void refresh_writesOnlyWhatChanged_andLeavesAPostAlone() {
    Ride ride = ride();
    assertTrue(calculator.refresh(ride));
    assertEquals(START.plus(Duration.ofHours(3)), ride.getEndDateTime());
    assertFalse(calculator.refresh(ride));

    Post post = new Post();
    post.setDateTime(START);
    assertFalse(calculator.refresh(post));
    assertNull(post.getEndDateTime());
  }

  @Test
  void effectiveEnd_fallsBackOnTheDefaultDuration_whenNothingIsStored() {
    Ride ride = ride();
    assertEquals(START.plus(Duration.ofHours(3)), PublicationEndCalculator.effectiveEnd(ride));
    ride.setEndDateTime(START.plus(Duration.ofHours(1)));
    assertEquals(START.plus(Duration.ofHours(1)), PublicationEndCalculator.effectiveEnd(ride));
  }

  // --- estimated arrival and duration (docs/LEDGER_*.md API-165) ---------------------------------

  @Test
  void estimate_ofAGroup_isItsRouteAtItsSpeed_fromItsOwnStart() {
    Ride ride = ride();
    RideGroup group = group(ride, LocalTime.of(9, 0), route(50_000), 25f);

    PublicationEndCalculator.LegEstimate estimate = PublicationEndCalculator.estimate(group);

    assertEquals(Instant.parse("2026-06-07T11:00:00Z"), estimate.arrival());
    assertEquals(120, estimate.durationMinutes());
  }

  @Test
  void estimate_ofAGroupWithoutRoute_ridesTheRidesRoute() {
    Ride ride = ride();
    ride.setRoute(route(100_000));
    RideGroup group = group(ride, null, null, 20f);

    PublicationEndCalculator.LegEstimate estimate = PublicationEndCalculator.estimate(group);

    assertEquals(START.plus(Duration.ofHours(5)), estimate.arrival());
    assertEquals(300, estimate.durationMinutes());
  }

  /** No default speed or duration here, unlike the end: a screen shows nothing rather than a guess. */
  @Test
  void estimate_withoutSpeedOrDistance_isAbsent() {
    Ride ride = ride();
    RideGroup noSpeed = group(ride, null, route(50_000), null);
    RideGroup noRoute = group(ride, null, null, 25f);
    Route deleted = route(50_000);
    deleted.setDeleted(true);
    RideGroup deletedRoute = group(ride, null, deleted, 25f);
    RideGroup emptyRoute = group(ride, null, route(0), 25f);

    assertNull(PublicationEndCalculator.estimate(noSpeed));
    assertNull(PublicationEndCalculator.estimate(noRoute));
    assertNull(PublicationEndCalculator.estimate(deletedRoute));
    assertNull(PublicationEndCalculator.estimate(emptyRoute));
    // The stored end still has its default for the same group.
    assertEquals(START.plus(Duration.ofHours(3)), calculator.rideEnd(ride));
  }

  @Test
  void estimate_ofAStage_isItsRouteAtItsSpeed_andAbsentWithoutEither() {
    Trip trip = new Trip();
    trip.setDateTime(START);
    TripStage routed = new TripStage(null, trip, "J1", "j1");
    routed.setDateTime(START);
    routed.setRoute(route(80_000));
    routed.setAverageSpeed(20f);
    TripStage noSpeed = new TripStage(null, trip, "J2", "j2");
    noSpeed.setDateTime(START);
    noSpeed.setRoute(route(80_000));

    PublicationEndCalculator.LegEstimate estimate = PublicationEndCalculator.estimate(routed);

    assertEquals(START.plus(Duration.ofHours(4)), estimate.arrival());
    assertEquals(240, estimate.durationMinutes());
    assertNull(PublicationEndCalculator.estimate(noSpeed));
  }

  @Test
  void estimate_roundsTheDurationToTheNearestMinute() {
    // 10 km at 24 km/h: 25 min exactly; 10.1 km: 25 min 15 s → 25.
    assertEquals(25, PublicationEndCalculator.estimate(START, 10_000f, 24f).durationMinutes());
    assertEquals(25, PublicationEndCalculator.estimate(START, 10_100f, 24f).durationMinutes());
    // 10.2 km: 25 min 30 s → 26.
    assertEquals(26, PublicationEndCalculator.estimate(START, 10_200f, 24f).durationMinutes());
  }
}
