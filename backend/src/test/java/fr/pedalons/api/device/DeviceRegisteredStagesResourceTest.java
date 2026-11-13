package fr.pedalons.api.device;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WindDirection;
import fr.pedalons.util.GpsSyncTestData;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.path.json.JsonPath;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code registeredStages} of {@code GET /api/device/routes?stages=true}: the stages of the trips
 * the device's user is registered for, each with its own route (docs/LEDGER_*.md API-168). The
 * field only exists for a device that asks: without the parameter the response is the one the
 * Garmin app has always read.
 */
@QuarkusTest
class DeviceRegisteredStagesResourceTest extends AbstractResourceTest {

  @Inject GpsSyncTestData sync;
  @Inject EntityManager em;

  private Instant now;
  private Trip trip;
  private TripStage stage1;
  private TripStage stage2;
  private Route stage1Route;
  private Route stage2Route;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
    trip =
        dataService.createTrip(team1, user1, "Traversée des Alpes", now.plus(1, ChronoUnit.DAYS));
    stage1 = dataService.createTripStage(user1, trip, "Étape 1", 0, now.plus(1, ChronoUnit.DAYS));
    stage2 = dataService.createTripStage(user1, trip, "Étape 2", 1, now.plus(2, ChronoUnit.DAYS));
    stage1Route = route("Col du Galibier", 82500, 2100);
    stage2Route = route("Col de l'Iseran", 64000, 1800);
    sync.setStageRoute(stage1, stage1Route);
    sync.setStageRoute(stage2, stage2Route);
    dataService.createTripParticipation(trip, user3);
  }

  private Route route(String name, int distance, int elevationGain) {
    return dataService.createRouteWithProperties(
        team1,
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

  private JsonPath fetch(String user, boolean stages) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .when()
        .get("/api/device/routes" + (stages ? "?stages=true" : ""))
        .then()
        .statusCode(200)
        .extract()
        .jsonPath();
  }

  private List<String> stageNames(String user) {
    return fetch(user, true).getList("registeredStages.stageName", String.class);
  }

  @Test
  void withoutTheParameter_theFieldIsAbsent() {
    String body =
        given()
            .auth()
            .oauth2(getAccessToken(USER3))
            .when()
            .get("/api/device/routes")
            .then()
            .statusCode(200)
            .extract()
            .asString();

    // Absent, not null and not empty: the Garmin app parses the whole body in counted memory.
    assertFalse(body.contains("registeredStages"), body);
  }

  @Test
  void registeredStage_isListedWithItsOwnRoute() {
    JsonPath json = fetch(USER3, true);

    assertEquals(List.of("Étape 1", "Étape 2"), json.getList("registeredStages.stageName"));
    assertEquals(team1.getSlug(), json.getString("registeredStages[0].teamSlug"));
    assertEquals(trip.getSlug(), json.getString("registeredStages[0].tripSlug"));
    assertEquals("Traversée des Alpes", json.getString("registeredStages[0].tripName"));
    assertEquals(stage1Route.getSlug(), json.getString("registeredStages[0].routeSlug"));
    assertEquals("Col du Galibier", json.getString("registeredStages[0].routeName"));
    assertEquals(82500f, json.getFloat("registeredStages[0].distance"));
    assertEquals(2100f, json.getFloat("registeredStages[0].elevationGain"));
    assertEquals(
        now.plus(1, ChronoUnit.DAYS),
        Instant.parse(json.getString("registeredStages[0].startDateTime")));
    assertEquals(stage1.getTimezone(), json.getString("registeredStages[0].timezone"));
    assertEquals(List.of(), json.getList("registeredStages[0].syncStatuses"));
    assertNull(json.getString("registeredStages[0].startPlaceName"));
    assertEquals(team1.getName(), json.getString("registeredStages[0].teamName"));
    assertEquals("PUBLISHED", json.getString("registeredStages[0].status"));
    // No stored end on a stage built by the test: the departure plus three hours.
    assertEquals(
        now.plus(1, ChronoUnit.DAYS).plus(3, ChronoUnit.HOURS),
        Instant.parse(json.getString("registeredStages[0].endDateTime")));
    assertEquals(stage2Route.getSlug(), json.getString("registeredStages[1].routeSlug"));
  }

  @Test
  void registeredStage_carriesTheNamesOfItsPlaces() {
    Place start = dataService.createPlace(team1, user1, "Bourg-d'Oisans");
    Place end = dataService.createPlace(team1, user1, "Valloire");
    QuarkusTransaction.requiringNew()
        .run(() -> {
          TripStage managed = em.find(TripStage.class, stage1.getId());
          managed.setStartPlace(em.find(Place.class, start.getId()));
          managed.setEndPlace(em.find(Place.class, end.getId()));
        });

    JsonPath json = fetch(USER3, true);

    assertEquals("Bourg-d'Oisans", json.getString("registeredStages[0].startPlaceName"));
    assertEquals("Valloire", json.getString("registeredStages[0].endPlaceName"));
  }

  @Test
  void someoneNotRegistered_hasNoStage() {
    assertEquals(List.of(), stageNames(USER2));
  }

  @Test
  void stageWithoutRoute_isLeftOut_neverTheTripRoute() {
    sync.setTripRoute(trip, route("Parcours du voyage", 300000, 6000));
    sync.setStageRoute(stage1, null);

    assertEquals(List.of("Étape 2"), stageNames(USER3));
  }

  @Test
  void window_appliesToEachStageDeparture() {
    TripStage far =
        dataService.createTripStage(
            user1, trip, "Étape lointaine", 2, now.plus(9, ChronoUnit.DAYS));
    sync.setStageRoute(far, route("Loin", 50000, 500));
    TripStage past =
        dataService.createTripStage(user1, trip, "Étape d'hier", 3, now.minus(2, ChronoUnit.DAYS));
    sync.setStageRoute(past, route("Hier", 50000, 500));
    // Left a few hours ago: maybe still under way, so still listed, and first.
    TripStage underWay =
        dataService.createTripStage(
            user1, trip, "Étape en cours", 4, now.minus(3, ChronoUnit.HOURS));
    sync.setStageRoute(underWay, route("En cours", 50000, 500));

    assertEquals(List.of("Étape en cours", "Étape 1", "Étape 2"), stageNames(USER3));
  }

  @Test
  void draftTrip_hasNoStage() {
    Trip draft =
        dataService.createTrip(
            team1,
            user1,
            "Brouillon",
            now.plus(1, ChronoUnit.DAYS),
            Visibility.TEAM,
            Status.DRAFT,
            null);
    TripStage stage =
        dataService.createTripStage(user1, draft, "Étape cachée", 0, now.plus(1, ChronoUnit.DAYS));
    sync.setStageRoute(stage, route("Caché", 50000, 500));
    dataService.createTripParticipation(draft, user3);

    assertTrue(stageNames(USER3).stream().noneMatch("Étape cachée"::equals));
  }

  @Test
  void cancelledTrip_keepsItsStages_markedCancelled() {
    Trip cancelled =
        dataService.createTrip(
            team1,
            user1,
            "Voyage annulé",
            now.plus(1, ChronoUnit.DAYS),
            Visibility.TEAM,
            Status.CANCELLED,
            null);
    TripStage stage =
        dataService.createTripStage(
            user1, cancelled, "Étape annulée", 0, now.plus(3, ChronoUnit.DAYS));
    sync.setStageRoute(stage, route("Annulé", 50000, 500));
    dataService.createTripParticipation(cancelled, user3);

    JsonPath json = fetch(USER3, true);

    assertEquals(
        List.of("Étape 1", "Étape 2", "Étape annulée"), json.getList("registeredStages.stageName"));
    assertEquals("CANCELLED", json.getString("registeredStages[2].status"));
  }

  @Test
  void rides_areUntouchedByTheParameter() {
    assertEquals(
        fetch(USER3, false).getList("registeredGroups"),
        fetch(USER3, true).getList("registeredGroups"));
  }
}
