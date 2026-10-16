package fr.pedalons.api.device;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.gps.GpsRouteSync;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WindDirection;
import fr.pedalons.repository.gps.GpsRouteSyncRepository;
import fr.pedalons.service.gps.sync.GpsRouteSyncPlanner;
import fr.pedalons.service.gps.sync.GpsSyncNames;
import fr.pedalons.util.GpsSyncTestData;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.path.json.JsonPath;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code registeredGroups} of {@code GET /api/device/routes}: the groups the device's user is
 * registered in, each with the route to load, so a device can fetch the track without the route's
 * detail.
 */
@QuarkusTest
class DeviceRegisteredGroupsResourceTest extends AbstractResourceTest {

  @Inject GpsSyncTestData sync;
  @Inject GpsRouteSyncPlanner planner;
  @Inject GpsRouteSyncRepository syncRepository;

  private Route groupRoute;
  private Route rideRoute;
  private Instant inTwoDays;
  private int slugCounter;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    groupRoute = route(team1, "Boucle du groupe", 82500, 950);
    rideRoute = route(team1, "Boucle de la sortie", 40000, 300);
    inTwoDays = Instant.now().plus(2, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS);
    slugCounter = 0;
  }

  /** A route with a start point, as every route the GPX pipeline stores has. */
  private Route route(Team team, String name, int distance, int elevationGain) {
    return dataService.createRouteWithProperties(
        team,
        user1,
        name,
        Visibility.TEAM,
        distance,
        elevationGain,
        SurfaceType.ROAD,
        WindDirection.NORTH,
        47.2,
        -1.55,
        47.3,
        -1.5);
  }

  private Route route(Team team, String name) {
    return route(team, name, 10000, 100);
  }

  private Ride ride(Team team, String name, Instant start, Status status, @Nullable Route route) {
    Ride ride =
        dataService.createRide(
            team, user1, name, "sortie-" + (++slugCounter), start, Visibility.TEAM, status);
    // Before any group: merging the detached ride later would wipe its groups (orphanRemoval).
    if (route != null) {
      dataService.setRideRoute(ride, route);
    }
    return ride;
  }

  private Ride ride(String name, Instant start, @Nullable Route route) {
    return ride(team1, name, start, Status.PUBLISHED, route);
  }

  private RideGroup group(Ride ride, String name, @Nullable Route route, @Nullable Instant start) {
    RideGroup group = dataService.createRideGroup(user1, ride, name);
    if (route != null || start != null) {
      group.setRoute(route);
      if (start != null) {
        group.setStartAt(start);
      }
      dataService.updateRideGroup(group);
    }
    return group;
  }

  private JsonPath fetch(String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .when()
        .get("/api/device/routes")
        .then()
        .statusCode(200)
        .extract()
        .jsonPath();
  }

  private List<String> groupNames(String user) {
    return fetch(user).getList("registeredGroups.groupName", String.class);
  }

  @Test
  void registeredGroup_isListedWithItsRoute() {
    Ride ride = ride("Sortie du samedi", inTwoDays, rideRoute);
    Instant groupStart = inTwoDays.plus(30, ChronoUnit.MINUTES);
    RideGroup group = group(ride, "Groupe A", groupRoute, groupStart);
    dataService.createParticipation(group, user3);

    List<Map<String, Object>> groups = fetch(USER3).getList("registeredGroups");

    assertEquals(1, groups.size());
    Map<String, Object> g = groups.get(0);
    assertEquals(team1Slug, g.get("teamSlug"));
    assertEquals(ride.getSlug(), g.get("rideSlug"));
    assertEquals("Sortie du samedi", g.get("rideName"));
    assertEquals("Groupe A", g.get("groupName"));
    assertEquals(groupRoute.getSlug(), g.get("routeSlug"));
    assertEquals("Boucle du groupe", g.get("routeName"));
    assertEquals(82500f, ((Number) g.get("distance")).floatValue());
    assertEquals(950f, ((Number) g.get("elevationGain")).floatValue());
    assertEquals(groupStart, Instant.parse((String) g.get("startDateTime")));
    assertEquals(dataService.getTimezone(ride.getId()), g.get("timezone"));
  }

  @Test
  void groupTheUserIsNotRegisteredIn_isAbsent() {
    Ride ride = ride("Sortie", inTwoDays, null);
    RideGroup mine = group(ride, "Le mien", groupRoute, null);
    RideGroup other = group(ride, "Un autre", groupRoute, null);
    dataService.createParticipation(mine, user3);
    dataService.createParticipation(other, user2);

    assertEquals(List.of("Le mien"), groupNames(USER3));
    // Registered nowhere: nothing, even though the team has rides with routes.
    assertEquals(List.of(), groupNames(USER1));
  }

  @Test
  void groupOutsideTheWindow_isAbsent() {
    Instant now = Instant.now();
    RideGroup tooLate =
        group(ride("Trop loin", now.plus(8, ChronoUnit.DAYS), null), "Loin", groupRoute, null);
    RideGroup tooEarly =
        group(ride("Passée", now.minus(13, ChronoUnit.HOURS), null), "Passé", groupRoute, null);
    RideGroup underWay =
        group(ride("En cours", now.minus(6, ChronoUnit.HOURS), null), "En route", groupRoute, null);
    dataService.createParticipation(tooLate, user3);
    dataService.createParticipation(tooEarly, user3);
    dataService.createParticipation(underWay, user3);

    assertEquals(List.of("En route"), groupNames(USER3));
  }

  @Test
  void groupOfAnUnpublishedOrDeletedRide_isAbsent() {
    Ride draft = ride(team1, "Brouillon", inTwoDays, Status.DRAFT, null);
    Ride cancelled = ride(team1, "Annulée", inTwoDays, Status.CANCELLED, null);
    Ride deleted = ride("Supprimée", inTwoDays, null);
    dataService.createParticipation(group(draft, "Brouillon", groupRoute, null), user3);
    dataService.createParticipation(group(cancelled, "Annulé", groupRoute, null), user3);
    dataService.createParticipation(group(deleted, "Supprimé", groupRoute, null), user3);
    dataService.deleteRide(deleted);

    assertEquals(List.of(), groupNames(USER3));
  }

  @Test
  void groupWithoutRoute_fallsBackOnTheRidesRoute() {
    Ride ride = ride("Sortie", inTwoDays, rideRoute);
    dataService.createParticipation(group(ride, "Sans trace", null, null), user3);

    JsonPath json = fetch(USER3);

    assertEquals(rideRoute.getSlug(), json.getString("registeredGroups[0].routeSlug"));
    assertEquals("Boucle de la sortie", json.getString("registeredGroups[0].routeName"));
    assertEquals(inTwoDays, Instant.parse(json.getString("registeredGroups[0].startDateTime")));
  }

  @Test
  void groupWhoseRouteIsDeleted_fallsBackOnTheRidesRoute() {
    Route doomed = route(team1, "Boucle supprimee");
    Ride ride = ride("Sortie", inTwoDays, rideRoute);
    dataService.createParticipation(group(ride, "Trace supprimée", doomed, null), user3);
    dataService.deleteRoute(doomed);

    assertEquals(rideRoute.getSlug(), fetch(USER3).getString("registeredGroups[0].routeSlug"));
  }

  @Test
  void groupWhoseRouteADeviceCannotLoad_fallsBackOnTheRidesRoute() {
    // A DRAFT route, and one hidden by moderation: a plain member's download would 404 on both.
    Route draft = route(team1, "Boucle brouillon");
    dataService.setTeamEntityStatus(draft, Status.DRAFT);
    Route hidden = route(team1, "Boucle masquee");
    dataService.hideForModeration(hidden);
    Ride ride = ride("Sortie", inTwoDays, rideRoute);
    dataService.createParticipation(group(ride, "Brouillon", draft, null), user3);
    Ride other = ride("Autre sortie", inTwoDays.plusSeconds(60), rideRoute);
    RideGroup hiddenGroup = group(other, "Masqué", hidden, null);
    dataService.createParticipation(hiddenGroup, user3);
    dataService.createParticipation(group(other, "Masqué orga", hidden, null), user2);

    assertEquals(
        List.of(rideRoute.getSlug(), rideRoute.getSlug()),
        fetch(USER3).getList("registeredGroups.routeSlug", String.class));
    // An organizer can load both, so the group's own route stays.
    assertEquals(
        List.of(hidden.getSlug()),
        fetch(USER2).getList("registeredGroups.routeSlug", String.class));
    // Neither route for a member, and no ride route either: nothing to load, the group goes.
    Ride bare = ride("Sans repli", inTwoDays.plusSeconds(120), null);
    dataService.createParticipation(group(bare, "Sans repli", draft, null), user3);
    assertEquals(List.of("Brouillon", "Masqué"), groupNames(USER3));
  }

  @Test
  void groupOfARideHiddenByModeration_isListedOnlyForModerators() {
    Ride ride = ride("Signalée", inTwoDays, rideRoute);
    dataService.createParticipation(group(ride, "Membre", null, null), user3);
    dataService.createParticipation(group(ride, "Organisateur", null, null), user2);
    dataService.hideForModeration(ride);

    assertEquals(List.of(), groupNames(USER3));
    assertEquals(List.of("Organisateur"), groupNames(USER2));
  }

  @Test
  void groupOfAnotherTeam_isAbsentOnAPinnedAlias() {
    dataService.createDomainAlias(
        "np.localhost", domain, team1, "N-Peloton", "http://np.localhost");
    Ride pinned = ride("Équipe épinglée", inTwoDays, rideRoute);
    dataService.createParticipation(group(pinned, "Épinglé", null, null), user3);
    Route team2Route = route(team2, "Boucle equipe 2");
    Ride other = ride(team2, "Équipe 2", inTwoDays, Status.PUBLISHED, team2Route);
    dataService.createParticipation(group(other, "Ailleurs", null, null), user3);

    // On the parent domain, user3 — a member of both teams — gets both.
    assertEquals(2, groupNames(USER3).size());
    List<String> onAlias =
        given()
            .auth()
            .oauth2(getAccessToken(USER3))
            .header("X-Forwarded-Host", "np.localhost")
            .when()
            .get("/api/device/routes")
            .then()
            .statusCode(200)
            .extract()
            .jsonPath()
            .getList("registeredGroups.groupName", String.class);
    assertEquals(List.of("Épinglé"), onAlias);
  }

  @Test
  void groupWithNoRouteAtAll_isExcluded() {
    Route doomed = route(team1, "Boucle supprimee");
    Ride bare = ride("Sans trace", inTwoDays, null);
    dataService.createParticipation(group(bare, "Nu", null, null), user3);
    Ride deletedRoute = ride("Trace supprimée", inTwoDays, doomed);
    dataService.createParticipation(group(deletedRoute, "Orphelin", null, null), user3);
    dataService.deleteRoute(doomed);

    assertEquals(List.of(), groupNames(USER3));
  }

  @Test
  void groupOfATeamTheUserLeft_isAbsent() {
    Route team2Route = route(team2, "Boucle equipe 2");
    Ride ride = ride(team2, "Sortie équipe 2", inTwoDays, Status.PUBLISHED, team2Route);
    dataService.createParticipation(group(ride, "Groupe équipe 2", null, null), user3);
    assertEquals(List.of("Groupe équipe 2"), groupNames(USER3));

    dataService.removeMember(user3, team2);

    assertEquals(List.of(), groupNames(USER3));
  }

  @Test
  void groupOnAnotherDomain_isAbsent() {
    Domain other = dataService.createDomain("other.example.com", "Other", "https://other.test");
    Team otherTeam =
        dataService.createTeam(other, user1, "Autre equipe", "autre-equipe", Visibility.PUBLIC);
    dataService.addUserToTeam(user3, otherTeam, TeamRole.MEMBER);
    Route otherRoute = route(otherTeam, "Boucle ailleurs");
    Ride ride = ride(otherTeam, "Ailleurs", inTwoDays, Status.PUBLISHED, otherRoute);
    dataService.createParticipation(group(ride, "Groupe ailleurs", null, null), user3);

    assertEquals(List.of(), groupNames(USER3));
  }

  @Test
  void groups_areSortedByDeparture() {
    Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    Ride later = ride("Plus tard", now.plus(5, ChronoUnit.DAYS), null);
    Ride sooner = ride("Bientôt", now.plus(1, ChronoUnit.DAYS), null);
    Ride same = ride("Même sortie", now.plus(3, ChronoUnit.DAYS), null);
    dataService.createParticipation(group(later, "J+5", groupRoute, null), user3);
    dataService.createParticipation(group(sooner, "J+1", groupRoute, null), user3);
    // The group's own departure decides, not the ride's.
    dataService.createParticipation(
        group(same, "J+3 décalé", groupRoute, now.plus(Duration.ofDays(3)).plusSeconds(7200)),
        user3);
    Ride early = ride("Matin", now.plus(3, ChronoUnit.DAYS).plusSeconds(3600), null);
    dataService.createParticipation(group(early, "J+3 tôt", groupRoute, null), user3);

    assertEquals(List.of("J+1", "J+3 tôt", "J+3 décalé", "J+5"), groupNames(USER3));
  }

  @Test
  void registeredGroups_areCapped() {
    for (int i = 0; i < 25; i++) {
      Ride ride = ride("Sortie " + i, inTwoDays.plus(i, ChronoUnit.HOURS), null);
      dataService.createParticipation(group(ride, "Groupe " + i, groupRoute, null), user3);
    }

    List<String> names = groupNames(USER3);

    assertEquals(20, names.size());
    assertEquals("Groupe 0", names.get(0));
    assertTrue(names.contains("Groupe 19"));
  }

  // ------------------------------------------------------------------ syncStatuses (API-121)

  private static Map<String, String> status(GpsServiceType serviceType, String state) {
    return Map.of("serviceType", serviceType.name(), "state", state);
  }

  private List<Map<String, String>> syncStatuses(String user, int index) {
    return fetch(user).getList("registeredGroups[" + index + "].syncStatuses");
  }

  /** The planner's automatic row for the ride on that connection. */
  private GpsRouteSync autoRow(GpsServiceConnection connection, Ride ride) {
    return sync.row(connection.getId(), ride.getId()).orElseThrow();
  }

  @Test
  void syncStatuses_routeSentToTheService_isSent() {
    sync.attachGpx(rideRoute, user1);
    Ride ride = ride("Sortie", inTwoDays, rideRoute);
    dataService.createParticipation(group(ride, "Groupe", null, null), user3);
    GpsServiceConnection hammerhead = sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    planner.plan(Instant.now());
    sync.markSynced(autoRow(hammerhead, ride).getId(), "ext-1");

    assertEquals(List.of(status(GpsServiceType.HAMMERHEAD, "SENT")), syncStatuses(USER3, 0));
  }

  @Test
  void syncStatuses_routeNotSentYet_isPending_andAReconnectionIsReported() {
    sync.attachGpx(groupRoute, user1);
    Ride ride = ride("Sortie", inTwoDays, rideRoute);
    dataService.createParticipation(group(ride, "Groupe", groupRoute, null), user3);
    sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    GpsServiceConnection garmin = sync.connect(user3, GpsServiceType.GARMIN, true);
    planner.plan(Instant.now());
    sync.markReconnectRequired(garmin.getId());

    // One entry per service, in a stable order; the group's own route is the one followed.
    assertEquals(
        List.of(
            status(GpsServiceType.HAMMERHEAD, "PENDING"),
            status(GpsServiceType.GARMIN, "RECONNECT_REQUIRED")),
        syncStatuses(USER3, 0));
  }

  @Test
  void syncStatuses_routeUploadedByHand_isSent() {
    Ride ride = ride("Sortie", inTwoDays, rideRoute);
    dataService.createParticipation(group(ride, "Groupe", null, null), user3);
    GpsServiceConnection hammerhead = sync.connect(user3, GpsServiceType.HAMMERHEAD, false);
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                syncRepository.upsertManual(
                    domain.getId(),
                    user3.getId(),
                    hammerhead.getId(),
                    rideRoute.getId(),
                    "Boucle de la sortie",
                    "hash",
                    "ext-manual",
                    Instant.now()));

    assertEquals(List.of(status(GpsServiceType.HAMMERHEAD, "SENT")), syncStatuses(USER3, 0));
  }

  @Test
  void syncStatuses_manualUploadThenGpxReplaced_isOutdated() {
    Asset sent = sync.attachGpx(rideRoute, user1);
    Ride ride = ride("Sortie", inTwoDays, rideRoute);
    dataService.createParticipation(group(ride, "Groupe", null, null), user3);
    GpsServiceConnection hammerhead = sync.connect(user3, GpsServiceType.HAMMERHEAD, false);
    String name = "Boucle de la sortie";
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                syncRepository.upsertManual(
                    domain.getId(),
                    user3.getId(),
                    hammerhead.getId(),
                    rideRoute.getId(),
                    name,
                    GpsSyncNames.hash(sent.getId(), name),
                    "ext-manual",
                    Instant.now()));
    assertEquals(List.of(status(GpsServiceType.HAMMERHEAD, "SENT")), syncStatuses(USER3, 0));

    // The organiser replaces the GPX: nothing updates a manual upload, the Karoo holds the old one.
    sync.attachGpx(rideRoute, user1);

    assertEquals(List.of(status(GpsServiceType.HAMMERHEAD, "OUTDATED")), syncStatuses(USER3, 0));
  }

  @Test
  void syncStatuses_routeNotFollowed_isEmpty() {
    sync.attachGpx(rideRoute, user1);
    Ride ride = ride("Sortie", inTwoDays, rideRoute);
    dataService.createParticipation(group(ride, "Sans service", null, null), user3);
    // A connection without the automatic sync: nothing sent, nothing to report.
    sync.connect(user3, GpsServiceType.HAMMERHEAD, false);
    planner.plan(Instant.now());

    assertEquals(List.of(), syncStatuses(USER3, 0));
  }

  @Test
  void syncStatuses_areThoseOfTheUserOnly() {
    sync.attachGpx(rideRoute, user1);
    Ride ride = ride("Sortie", inTwoDays, rideRoute);
    dataService.createParticipation(group(ride, "Groupe de user3", null, null), user3);
    dataService.createParticipation(group(ride, "Groupe de user2", null, null), user2);
    GpsServiceConnection hammerhead = sync.connect(user3, GpsServiceType.HAMMERHEAD, true);
    sync.connect(user2, GpsServiceType.HAMMERHEAD, false);
    planner.plan(Instant.now());
    sync.markSynced(autoRow(hammerhead, ride).getId(), "ext-1");

    assertEquals(List.of(status(GpsServiceType.HAMMERHEAD, "SENT")), syncStatuses(USER3, 0));
    // Same route, same service, another member: user3's row says nothing about user2's device.
    assertEquals(List.of(), syncStatuses(USER2, 0));
  }

  @Test
  void userWithoutTeam_getsAnEmptyList() {
    assertEquals(List.of(), groupNames(USER5));
  }
}
