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
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripParticipation;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.GpsSyncTestData;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.File;
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

  @Inject DomainResolver domainResolver;

  @Inject GpsRouteSyncPlanner planner;
  @Inject GpsSyncTestData sync;
  @Inject RouteService routeService;
  @Inject PedalonsQueryContext queryContext;
  @Inject AssetRepository assetRepository;

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
    domainResolver.setDomainForTest(domain);
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
    // A GPX attached to a route without one makes a new asset; a track edit instead stamps a new
    // content revision on the same row (docs/LEDGER_*.md API-128).
    sync.attachGpx(rideRoute, user1);

    planner.plan(now);

    assertNotEquals(before, row().getDesiredHash());
  }

  private fr.pedalons.domain.asset.Asset filteredGpx() {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            assetRepository
                .find(
                    "teamEntity.id = ?1 and type = ?2",
                    rideRoute.getId(),
                    AssetType.ROUTE_FILTERED_GPX)
                .firstResult());
  }

  /** The real update path: a track edit replaces the file of the existing asset row (API-128). */
  private void editTheTrack() {
    queryContext.setUserForTest(user1);
    routeService.updateRoute(
        team1Slug,
        rideRoute.getSlug(),
        new RouteRequest(
            rideRoute.getName(),
            MediaDto.builder().build(),
            SurfaceType.ROAD,
            rideRoute.getVisibility(),
            null),
        new File("src/test/resources/example.gpx").toPath());
  }

  @Test
  void gpxReplacedInPlace_throughTheUpdatePath_changesTheHash() {
    planner.plan(now);
    String before = row().getDesiredHash();
    Long assetId = filteredGpx().getId();

    editTheTrack();

    // Same asset row, new file: the asset id alone could not tell.
    assertEquals(assetId, filteredGpx().getId());
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

  // ------------------------------------------------------------------ trip stages

  private static final String TRIP_NAME = "Traversée des Alpes";

  private Trip trip;
  private TripStage stage1;
  private TripStage stage2;
  private Route stage1Route;
  private Route stage2Route;
  private TripParticipation tripRegistration;

  /**
   * A published trip of team1 with two stages leaving tomorrow and the day after, each with its own
   * GPX route, user3 registered — beside the ride of {@link #setUp}, which every case keeps.
   */
  private void seedTrip() {
    trip = dataService.createTrip(team1, user1, TRIP_NAME, now.plus(1, ChronoUnit.DAYS));
    stage1 = dataService.createTripStage(user1, trip, "Étape 1", 0, now.plus(1, ChronoUnit.DAYS));
    stage2 = dataService.createTripStage(user1, trip, "Étape 2", 1, now.plus(2, ChronoUnit.DAYS));
    stage1Route = sync.routeWithGpx(team1, user1, "Col du Galibier");
    stage2Route = sync.routeWithGpx(team1, user1, "Col de l'Iseran");
    sync.setStageRoute(stage1, stage1Route);
    sync.setStageRoute(stage2, stage2Route);
    tripRegistration = dataService.createTripParticipation(trip, user3);
  }

  private GpsRouteSync stageRow(TripStage stage) {
    return sync.row(connection.getId(), stage.getId()).orElseThrow();
  }

  @Test
  void tripRegistration_givesOneRowPerStage_withTheStageId_noGroup_andTheStageName() {
    seedTrip();

    planner.plan(now);

    GpsRouteSync row = stageRow(stage1);
    assertEquals(domain.getId(), row.getDomainId());
    assertEquals(stage1.getId(), row.getRideId());
    assertNull(row.getRideGroupId());
    assertEquals(stage1Route.getId(), row.getDesiredRouteId());
    assertEquals(stage1.getDateTime(), row.getGroupStartAt());
    assertNotNull(row.getDesiredHash());
    assertEquals(
        GpsSyncNames.stageName(stage1.getDateTime(), stage1.getTimezone(), TRIP_NAME, "Étape 1"),
        row.getDesiredName());
    assertTrue(
        row.getDesiredName().matches("^\\d{4}-\\d{2}-\\d{2} - " + TRIP_NAME + " - Étape 1$"),
        row.getDesiredName());
    assertEquals(stage2Route.getId(), stageRow(stage2).getDesiredRouteId());
    // The ride's row is still there: the stages do not replace it.
    assertEquals(rideRoute.getId(), row().getDesiredRouteId());
    assertEquals(3, sync.rows(connection.getId()).size());
  }

  @Test
  void tripStages_replayingATick_writesNothing() {
    seedTrip();
    planner.plan(now);
    GpsRouteSync before = stageRow(stage1);

    assertEquals(0, planner.plan(now));
    assertEquals(before.getUpdatedAt(), stageRow(stage1).getUpdatedAt());
  }

  @Test
  void leavingTheTrip_neverSent_deletesTheRows_andKeepsTheRide() {
    seedTrip();
    planner.plan(now);
    dataService.deleteTripParticipation(tripRegistration);

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), stage1.getId()).isEmpty());
    assertTrue(sync.row(connection.getId(), stage2.getId()).isEmpty());
    assertNotNull(row().getDesiredHash());
  }

  @Test
  void leavingTheTrip_alreadySent_asksForTheDeletion() {
    seedTrip();
    planner.plan(now);
    sync.markSynced(stageRow(stage1).getId(), "ext-stage");
    dataService.deleteTripParticipation(tripRegistration);

    planner.plan(now);

    GpsRouteSync row = stageRow(stage1);
    assertNull(row.getDesiredHash());
    assertNull(row.getDesiredRouteId());
    assertEquals("ext-stage", row.getExternalRouteId());
  }

  @Test
  void stageAdded_getsItsRow() {
    seedTrip();
    planner.plan(now);
    TripStage stage3 =
        dataService.createTripStage(user1, trip, "Étape 3", 2, now.plus(3, ChronoUnit.DAYS));
    Route stage3Route = sync.routeWithGpx(team1, user1, "Col de la Madeleine");
    sync.setStageRoute(stage3, stage3Route);

    planner.plan(now);

    assertEquals(stage3Route.getId(), stageRow(stage3).getDesiredRouteId());
  }

  @Test
  void stageDeleted_asksForTheDeletion() {
    seedTrip();
    planner.plan(now);
    sync.markSynced(stageRow(stage2).getId(), "ext-stage");
    // What TripService.updateTrip does to a stage the organiser removes.
    dataService.deleteTripStage(stage2);

    planner.plan(now);

    assertNull(stageRow(stage2).getDesiredHash());
    assertEquals("ext-stage", stageRow(stage2).getExternalRouteId());
    assertNotNull(stageRow(stage1).getDesiredHash());
  }

  @Test
  void newStageRoute_changesTheRouteAndTheHashOnTheSameRow() {
    seedTrip();
    planner.plan(now);
    sync.markSynced(stageRow(stage1).getId(), "ext-stage");
    GpsRouteSync before = stageRow(stage1);
    Route variant = sync.routeWithGpx(team1, user1, "Col du Télégraphe");
    sync.setStageRoute(stage1, variant);

    planner.plan(now);

    GpsRouteSync after = stageRow(stage1);
    assertEquals(before.getId(), after.getId());
    assertEquals(variant.getId(), after.getDesiredRouteId());
    assertNotEquals(before.getDesiredHash(), after.getDesiredHash());
    // The route at the service is updated in place, not created anew.
    assertEquals("ext-stage", after.getExternalRouteId());
  }

  @Test
  void stageRouteRemoved_asksForTheDeletion() {
    seedTrip();
    planner.plan(now);
    sync.markSynced(stageRow(stage1).getId(), "ext-stage");
    sync.setStageRoute(stage1, null);

    planner.plan(now);

    assertNull(stageRow(stage1).getDesiredHash());
    assertEquals("ext-stage", stageRow(stage1).getExternalRouteId());
  }

  @Test
  void stageWithoutRoute_givesNothing_notTheTripRoute() {
    seedTrip();
    sync.setStageRoute(stage1, null);
    sync.setTripRoute(trip, sync.routeWithGpx(team1, user1, "Tracé complet"));

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), stage1.getId()).isEmpty());
    assertEquals(stage2Route.getId(), stageRow(stage2).getDesiredRouteId());
  }

  @Test
  void stageRouteWithoutGpx_givesNothing() {
    seedTrip();
    sync.setStageRoute(stage1, dataService.createRoute(team1, user1, "Sans trace"));

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), stage1.getId()).isEmpty());
  }

  @Test
  void draftStageRoute_isNotSentToAPlainMember() {
    seedTrip();
    sync.setRouteStatus(stage1Route, Status.DRAFT);

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), stage1.getId()).isEmpty());
  }

  @Test
  void stageMovedBeyondTheHorizon_asksForTheDeletion() {
    seedTrip();
    planner.plan(now);
    sync.markSynced(stageRow(stage2).getId(), "ext-stage");
    // The window is the stage's own departure, not the trip's.
    sync.setStageDateTime(stage2, now.plus(8, ChronoUnit.DAYS));

    planner.plan(now);

    assertNull(stageRow(stage2).getDesiredHash());
    assertNotNull(stageRow(stage1).getDesiredHash());
  }

  @Test
  void stageBeyondTheHorizon_givesNothing_whileTheTripHasStarted() {
    seedTrip();
    sync.setStageDateTime(stage2, now.plus(9, ChronoUnit.DAYS));

    planner.plan(now);

    assertNotNull(stageRow(stage1).getDesiredHash());
    assertTrue(sync.row(connection.getId(), stage2.getId()).isEmpty());
  }

  @Test
  void cancelledTrip_asksForTheDeletion() {
    seedTrip();
    planner.plan(now);
    sync.markSynced(stageRow(stage1).getId(), "ext-stage");
    sync.setTripStatus(trip, Status.CANCELLED);

    planner.plan(now);

    assertNull(stageRow(stage1).getDesiredHash());
    assertTrue(sync.row(connection.getId(), stage2.getId()).isEmpty());
  }

  @Test
  void draftTrip_givesNothing() {
    seedTrip();
    sync.setTripStatus(trip, Status.DRAFT);

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), stage1.getId()).isEmpty());
    assertTrue(sync.row(connection.getId(), stage2.getId()).isEmpty());
  }

  @Test
  void deletedTrip_asksForTheDeletion() {
    seedTrip();
    planner.plan(now);
    sync.markSynced(stageRow(stage1).getId(), "ext-stage");
    sync.deleteTrip(trip);

    planner.plan(now);

    assertNull(stageRow(stage1).getDesiredHash());
    assertEquals("ext-stage", stageRow(stage1).getExternalRouteId());
  }

  @Test
  void tripHiddenByModeration_givesNothingToAMember_butStaysWithAnOrganizer() {
    seedTrip();
    // user2 is an organizer of team1: a moderator sees hidden content.
    dataService.createTripParticipation(trip, user2);
    GpsServiceConnection organizer = sync.connect(user2, GpsServiceType.WAHOO, true);
    dataService.hideForModeration(trip);

    planner.plan(now);

    assertTrue(sync.row(connection.getId(), stage1.getId()).isEmpty());
    assertTrue(sync.row(organizer.getId(), stage1.getId()).isPresent());
    assertTrue(sync.row(organizer.getId(), stage2.getId()).isPresent());
  }

  @Test
  void rideAndStageOnTheSameRoute_getTwoRows_thatNeverClearEachOther() {
    seedTrip();
    sync.setStageRoute(stage1, rideRoute);

    planner.plan(now);

    GpsRouteSync rideRow = row();
    GpsRouteSync stage = stageRow(stage1);
    assertNotEquals(rideRow.getId(), stage.getId());
    assertEquals(rideRoute.getId(), rideRow.getDesiredRouteId());
    assertEquals(rideRoute.getId(), stage.getDesiredRouteId());
    assertEquals(groupA.getId(), rideRow.getRideGroupId());
    assertNull(stage.getRideGroupId());
    assertNotEquals(rideRow.getDesiredName(), stage.getDesiredName());

    // A second pass writes nothing: neither kind clears the other's row.
    assertEquals(0, planner.plan(now));
    assertEquals(rideRow.getDesiredHash(), row().getDesiredHash());
    assertEquals(stage.getDesiredHash(), stageRow(stage1).getDesiredHash());
  }

  @Test
  void otherDomain_tripStagesArePlannedApart() {
    seedTrip();
    Domain other = dataService.createDomain("other.example", "Other", "https://other.example");
    User rider = dataService.createUser(other, "rider@other.example", "Rider");
    Team team = dataService.createTeam(other, rider, "Other team", "other-team", Visibility.PUBLIC);
    Trip otherTrip =
        dataService.createTrip(team, rider, "Autre voyage", now.plus(1, ChronoUnit.DAYS));
    TripStage otherStage =
        dataService.createTripStage(rider, otherTrip, "Unique", 0, now.plus(1, ChronoUnit.DAYS));
    sync.setStageRoute(otherStage, sync.routeWithGpx(team, rider, "Autre route"));
    dataService.createTripParticipation(otherTrip, rider);
    GpsServiceConnection otherConnection = sync.connect(rider, GpsServiceType.HAMMERHEAD, true);

    planner.plan(now);

    List<GpsRouteSync> rows = sync.rows(otherConnection.getId());
    assertEquals(1, rows.size());
    assertEquals(other.getId(), rows.getFirst().getDomainId());
    assertEquals(otherStage.getId(), rows.getFirst().getRideId());
    assertEquals(domain.getId(), stageRow(stage1).getDomainId());
  }
}
