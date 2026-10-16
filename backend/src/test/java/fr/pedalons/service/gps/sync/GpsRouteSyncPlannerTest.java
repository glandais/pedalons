package fr.pedalons.service.gps.sync;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.gps.GpsRouteSync;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.ride.RideParticipation;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.util.GpsSyncTestData;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The planner's desired state, one case per trigger (docs/LEDGER_*.md API-120 §9): it is the only
 * thing that notices registrations, cancellations, route changes and the rest — no business code
 * calls it — so every one of them is checked here, on the tracking rows it writes.
 */
@QuarkusTest
class GpsRouteSyncPlannerTest extends AbstractResourceTest {

  @Inject GpsRouteSyncPlanner planner;
  @Inject GpsSyncTestData sync;

  private Instant now;
  private Ride ride;
  private RideGroup groupA;
  private RideGroup groupB;
  private Route rideRoute;
  private RideParticipation registration;
  private GpsServiceConnection connection;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    // user3 is a member of team1; the ride leaves in two days, within the 7-day horizon.
    ride =
        dataService.createRide(
            team1, user1, "Sortie du jeudi", "jeudi", now.plus(2, ChronoUnit.DAYS));
    rideRoute = sync.routeWithGpx(ride, user1, "Boucle des étangs");
    dataService.setRideRoute(ride, rideRoute);
    groupA = dataService.createRideGroup(user1, ride, "Groupe A", 0);
    groupB = dataService.createRideGroup(user1, ride, "Groupe B", 1);
    registration = dataService.createParticipation(groupA, user3);
    connection = sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
  }

  private GpsRouteSync row() {
    return sync.row(connection.getId(), ride.getId()).orElseThrow();
  }

  @Test
  void registration_givesOneRowWithTheRideRoute() {
    planner.plan(now);

    GpsRouteSync row = row();
    assertEquals(domain.getId(), row.getDomainId());
    assertEquals(groupA.getId(), row.getRideGroupId());
    assertEquals(rideRoute.getId(), row.getDesiredRouteId());
    assertNotNull(row.getDesiredHash());
    assertNull(row.getExternalRouteId());
    assertTrue(row.getDesiredName().contains("Groupe A"), row.getDesiredName());
    assertTrue(row.getDesiredName().contains("Boucle des étangs"), row.getDesiredName());
    assertTrue(row.getDesiredName().matches("^\\d{4}-\\d{2}-\\d{2} · .*"), row.getDesiredName());
  }

  @Test
  void replayingATick_writesNothing() {
    planner.plan(now);
    GpsRouteSync before = row();

    assertEquals(0, planner.plan(now));
    assertEquals(before.getUpdatedAt(), row().getUpdatedAt());
  }

  @Test
  void leavingTheRide_neverSent_deletesTheRow() {
    planner.plan(now);
    dataService.deleteParticipation(registration);

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), ride.getId()).isEmpty());
  }

  @Test
  void leavingTheRide_alreadySent_asksForTheDeletion() {
    planner.plan(now);
    sync.markSynced(row().getId(), "ext-1");
    dataService.deleteParticipation(registration);

    planner.plan(now);

    GpsRouteSync row = row();
    assertNull(row.getDesiredHash());
    assertNull(row.getDesiredRouteId());
    assertEquals("ext-1", row.getExternalRouteId());
  }

  @Test
  void cancelledRide_asksForTheDeletion() {
    planner.plan(now);
    sync.markSynced(row().getId(), "ext-1");
    sync.setRideStatus(ride, Status.CANCELLED);

    planner.plan(now);

    assertNull(row().getDesiredHash());
  }

  @Test
  void deletedRide_asksForTheDeletion() {
    planner.plan(now);
    sync.markSynced(row().getId(), "ext-1");
    dataService.deleteRide(ride);

    planner.plan(now);

    assertNull(row().getDesiredHash());
  }

  @Test
  void groupRemovedFromTheRide_asksForTheDeletion() {
    planner.plan(now);
    sync.markSynced(row().getId(), "ext-1");
    // What orphanRemoval does when the organiser drops a group: the group and its registrations
    // go for good. No foreign key held the tracking row back.
    dataService.deleteParticipation(registration);
    dataService.deleteRideGroup(groupA);

    planner.plan(now);

    GpsRouteSync row = row();
    assertNull(row.getDesiredHash());
    assertEquals("ext-1", row.getExternalRouteId());
  }

  @Test
  void newGroupRoute_changesTheHashOnTheSameRow() {
    planner.plan(now);
    GpsRouteSync before = row();
    Route groupRoute = sync.routeWithGpx(ride, user1, "Variante longue");
    sync.setGroupRoute(groupA, groupRoute);

    planner.plan(now);

    GpsRouteSync after = row();
    assertEquals(before.getId(), after.getId());
    assertEquals(groupRoute.getId(), after.getDesiredRouteId());
    assertNotEquals(before.getDesiredHash(), after.getDesiredHash());
  }

  @Test
  void newGpx_changesTheHash() {
    planner.plan(now);
    String before = row().getDesiredHash();
    // A new GPX makes a new asset (RouteService.updateRoute → GpxProcessingService).
    sync.attachGpx(rideRoute, user1);

    planner.plan(now);

    assertNotEquals(before, row().getDesiredHash());
  }

  @Test
  void switchingGroup_keepsTheRowAndChangesTheName() {
    planner.plan(now);
    GpsRouteSync before = row();
    sync.moveParticipation(registration, groupB);

    planner.plan(now);

    GpsRouteSync after = row();
    assertEquals(before.getId(), after.getId());
    assertEquals(groupB.getId(), after.getRideGroupId());
    assertTrue(after.getDesiredName().contains("Groupe B"));
    assertNotEquals(before.getDesiredHash(), after.getDesiredHash());
  }

  @Test
  void newDepartureDate_changesTheHash() {
    planner.plan(now);
    String before = row().getDesiredHash();
    sync.setGroupStartAt(groupA, now.plus(4, ChronoUnit.DAYS));

    planner.plan(now);

    assertNotEquals(before, row().getDesiredHash());
  }

  @Test
  void deletedGroupRoute_fallsBackOnTheRideRoute() {
    // The same selection as the device's findUpcomingRegisteredGroups: a deleted group route is
    // as good as none.
    Route groupRoute = sync.routeWithGpx(ride, user1, "Variante");
    sync.setGroupRoute(groupA, groupRoute);
    planner.plan(now);
    assertEquals(groupRoute.getId(), row().getDesiredRouteId());

    dataService.deleteRoute(groupRoute);
    planner.plan(now);

    assertEquals(rideRoute.getId(), row().getDesiredRouteId());
  }

  @Test
  void groupWithoutRoute_usesTheRideRoute_andNoRouteAtAll_givesNothing() {
    dataService.deleteRoute(rideRoute);

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), ride.getId()).isEmpty());
  }

  @Test
  void routeWithoutGpx_givesNothing() {
    Route bare = dataService.createRoute(team1, user1, "Sans trace");
    sync.setGroupRoute(groupA, bare);

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), ride.getId()).isEmpty());
  }

  @Test
  void beyondTheHorizon_givesNothing() {
    sync.setGroupStartAt(groupA, now.plus(8, ChronoUnit.DAYS));

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), ride.getId()).isEmpty());
  }

  @Test
  void aDayAfterTheDeparture_asksForTheDeletion() {
    planner.plan(now);
    sync.markSynced(row().getId(), "ext-1");

    // Two days later the group left yesterday morning, beyond the 24 h retention.
    planner.plan(now.plus(3, ChronoUnit.DAYS).plus(1, ChronoUnit.HOURS));

    assertNull(row().getDesiredHash());
  }

  @Test
  void draftRide_givesNothing() {
    sync.setRideStatus(ride, Status.DRAFT);

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), ride.getId()).isEmpty());
  }

  @Test
  void syncTurnedOff_givesNothing_andRemovesWhatWasSent() {
    sync.setAutoSync(connection.getId(), false);
    planner.plan(now);
    assertTrue(sync.row(connection.getId(), ride.getId()).isEmpty());

    sync.setAutoSync(connection.getId(), true);
    planner.plan(now);
    sync.markSynced(row().getId(), "ext-1");
    sync.setAutoSync(connection.getId(), false);
    planner.plan(now);

    assertNull(row().getDesiredHash());
    assertEquals("ext-1", row().getExternalRouteId());
  }

  /** What a plain member could not download is never sent to their service (user3 is MEMBER). */
  @Test
  void draftRoute_isNotSentToAPlainMember() {
    sync.setRouteStatus(rideRoute, Status.DRAFT);

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), ride.getId()).isEmpty());
  }

  @Test
  void routeHiddenByModeration_isRemovedFromAPlainMember() {
    planner.plan(now);
    sync.markSynced(row().getId(), "ext-1");
    sync.hideByModeration(rideRoute);

    planner.plan(now);

    assertNull(row().getDesiredHash());
    assertEquals("ext-1", row().getExternalRouteId());
  }

  @Test
  void draftGroupRoute_fallsBackToTheRideRoute() {
    Route groupRoute = sync.routeWithGpx(ride, user1, "Variante");
    sync.setRouteStatus(groupRoute, Status.DRAFT);
    sync.setGroupRoute(groupA, groupRoute);

    planner.plan(now);

    assertEquals(rideRoute.getId(), row().getDesiredRouteId());
  }

  @Test
  void reconnectionRequired_leavesTheRowsAlone() {
    planner.plan(now);
    sync.markSynced(row().getId(), "ext-1");
    String hash = row().getDesiredHash();
    sync.markReconnectRequired(connection.getId());
    dataService.deleteParticipation(registration);

    planner.plan(now);

    assertEquals(hash, row().getDesiredHash());
  }

  @Test
  void registeredNonMember_givesNothing() {
    // user4 is not a member of team1: leaving a team does not remove a registration, but the
    // device selection — and this one — only follows the teams one still belongs to.
    dataService.createParticipation(groupB, user4);
    GpsServiceConnection outsider = sync.connect(user4, GpsServiceType.WAHOO, true);

    planner.plan(now);

    assertTrue(sync.rows(outsider.getId()).isEmpty());
  }

  @Test
  void hiddenByModeration_givesNothingToAMember() {
    hideByModeration(ride);

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), ride.getId()).isEmpty());
  }

  @Test
  void everyConnectionOfTheUser_getsItsOwnRow() {
    GpsServiceConnection wahoo = sync.connect(user3, GpsServiceType.WAHOO, true);

    planner.plan(now);

    assertEquals(1, sync.rows(connection.getId()).size());
    assertEquals(1, sync.rows(wahoo.getId()).size());
  }

  @Test
  void otherDomain_isPlannedApart() {
    Domain other = dataService.createDomain("other.example", "Other", "https://other.example");
    User rider = dataService.createUser(other, "rider@other.example", "Rider");
    Team team = dataService.createTeam(other, rider, "Other team", "other-team", Visibility.PUBLIC);
    Ride otherRide =
        dataService.createRide(team, rider, "Autre sortie", "autre", now.plus(1, ChronoUnit.DAYS));
    Route otherRoute = sync.routeWithGpx(otherRide, rider, "Autre route");
    dataService.setRideRoute(otherRide, otherRoute);
    RideGroup otherGroup = dataService.createRideGroup(rider, otherRide, "G", 0);
    dataService.createParticipation(otherGroup, rider);
    GpsServiceConnection otherConnection = sync.connect(rider, GpsServiceType.HAMMERHEAD, true);

    planner.plan(now);

    List<GpsRouteSync> rows = sync.rows(otherConnection.getId());
    assertEquals(1, rows.size());
    assertEquals(other.getId(), rows.getFirst().getDomainId());
    assertEquals(domain.getId(), row().getDomainId());
  }

  private void hideByModeration(Ride target) {
    dataService.hideForModeration(target);
  }
}
