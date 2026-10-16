package fr.pedalons.api.device;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WindDirection;
import fr.pedalons.service.gps.sync.GpsRouteSyncPlanner;
import fr.pedalons.util.GpsSyncTestData;
import fr.pedalons.util.QueryStats;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Database cost of {@code registeredGroups} on {@code GET /api/device/routes}: one query for the
 * whole list, whatever the number of groups the user is registered in.
 *
 * <p>Two members of the same teams see the same rides and routes; one is registered in {@link
 * #SMALL_PAGE} groups, the other in 20 (the cap). Serving the second must cost exactly as many
 * statements as the first — also once each route has sync rows at the user's GPS services
 * ({@code syncStatuses}, docs/LEDGER_*.md API-121): one more query for the whole list.
 */
@QuarkusTest
class DeviceRoutesQueryCountTest extends AbstractQueryCountTest {

  private static final int MANY = 20;

  @Inject GpsSyncTestData sync;
  @Inject GpsRouteSyncPlanner planner;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  @Test
  void registeredGroups_costDoesNotScaleWithRegistrations() {
    Route route =
        dataService.createRouteWithProperties(
            team1,
            user1,
            "Boucle budget",
            Visibility.TEAM,
            50000,
            500,
            SurfaceType.ROAD,
            WindDirection.NORTH,
            47.2,
            -1.55,
            47.3,
            -1.5);
    Ride ride =
        dataService.createRide(
            team1, user1, "Sortie budget", "sortie-budget", Instant.now().plus(2, ChronoUnit.DAYS));
    List<RideGroup> groups = new ArrayList<>();
    for (int i = 0; i < MANY; i++) {
      RideGroup group = dataService.createRideGroup(user1, ride, "Groupe " + i, i);
      group.setRoute(route);
      dataService.updateRideGroup(group);
      groups.add(group);
    }
    for (int i = 0; i < MANY; i++) {
      dataService.createParticipation(groups.get(i), user3);
      if (i < SMALL_PAGE) {
        dataService.createParticipation(groups.get(i), user2);
      }
    }

    // Warm-up: whatever is cached on the first request must not be billed to either measure.
    measure(USER2, "warm-up");
    QueryStats.Counters few = measure(USER2, SMALL_PAGE + " registrations");
    QueryStats.Counters many = measure(USER3, MANY + " registrations");

    assertEquals(SMALL_PAGE, registeredGroupCount(USER2));
    assertEquals(MANY, registeredGroupCount(USER3));
    assertEquals(
        few.statements(),
        many.statements(),
        () -> "registeredGroups costs a query per group: " + few + " vs " + many);
    assertEquals(
        few.entityLoads(),
        many.entityLoads(),
        () -> "registeredGroups hydrates an entity per group: " + few + " vs " + many);
  }

  @Test
  void registeredGroupsSyncStatuses_costDoesNotScaleWithSyncRows() {
    // One ride per group, each on a route of its own: the planner keeps a row per ride and
    // connection, so user3 ends up with MANY rows per service, user2 with SMALL_PAGE.
    Instant start = Instant.now().plus(2, ChronoUnit.DAYS);
    List<RideGroup> groups = new ArrayList<>();
    for (int i = 0; i < MANY; i++) {
      Route route =
          dataService.createRouteWithProperties(
              team1,
              user1,
              "Boucle " + i,
              Visibility.TEAM,
              50000,
              500,
              SurfaceType.ROAD,
              WindDirection.NORTH,
              47.2,
              -1.55,
              47.3,
              -1.5);
      sync.attachGpx(route, user1);
      Ride ride =
          dataService.createRide(
              team1, user1, "Sortie " + i, "sortie-sync-" + i, start.plusSeconds(60L * i));
      dataService.setRideRoute(ride, route);
      groups.add(dataService.createRideGroup(user1, ride, "Groupe " + i, 0));
    }
    for (int i = 0; i < MANY; i++) {
      dataService.createParticipation(groups.get(i), user3);
      if (i < SMALL_PAGE) {
        dataService.createParticipation(groups.get(i), user2);
      }
    }
    List<GpsServiceConnection> connections = new ArrayList<>();
    for (var user : List.of(user2, user3)) {
      connections.add(sync.connect(user, GpsServiceType.HAMMERHEAD, true));
      connections.add(sync.connect(user, GpsServiceType.GARMIN, true));
    }
    planner.plan(Instant.now());
    // Half of them sent, so the statuses differ from row to row.
    for (GpsServiceConnection connection : connections) {
      var rows = sync.rows(connection.getId());
      for (int i = 0; i < rows.size(); i += 2) {
        sync.markSynced(rows.get(i).getId(), "ext-" + connection.getId() + "-" + i);
      }
    }

    measure(USER2, "warm-up");
    QueryStats.Counters few = measure(USER2, SMALL_PAGE + " groups with sync rows");
    QueryStats.Counters many = measure(USER3, MANY + " groups with sync rows");

    assertEquals(SMALL_PAGE, registeredGroupCount(USER2));
    assertEquals(MANY, registeredGroupCount(USER3));
    assertEquals(
        2 * MANY,
        sync.rows(connections.get(2).getId()).size()
            + sync.rows(connections.get(3).getId()).size());
    assertEquals(
        2,
        given()
            .auth()
            .oauth2(getAccessToken(USER3))
            .when()
            .get("/api/device/routes")
            .then()
            .statusCode(200)
            .extract()
            .jsonPath()
            .getList("registeredGroups[" + (MANY - 1) + "].syncStatuses")
            .size());
    assertEquals(
        few.statements(),
        many.statements(),
        () -> "syncStatuses costs a query per group: " + few + " vs " + many);
    assertEquals(
        few.entityLoads(),
        many.entityLoads(),
        () -> "syncStatuses hydrates an entity per group: " + few + " vs " + many);
  }

  private int registeredGroupCount(String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .when()
        .get("/api/device/routes")
        .then()
        .statusCode(200)
        .extract()
        .jsonPath()
        .getList("registeredGroups")
        .size();
  }

  private QueryStats.Counters measure(String user, String label) {
    String token = getAccessToken(user);
    return queryStats.measureAll(
        "GET /api/device/routes [" + label + "]",
        () -> given().auth().oauth2(token).when().get("/api/device/routes").then().statusCode(200));
  }
}
