package fr.pedalons.api.routes;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.route.GpxTrackRepository;
import fr.pedalons.util.GpsSyncTestData;
import fr.pedalons.util.QueryStats;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Database-cost budget for the route list endpoints.
 *
 * <p>Routes carry a GPX track with its point array, so a list row that touched the track would move
 * a lot more than a few extra entities. See {@link AbstractQueryCountTest}.
 */
@QuarkusTest
class RouteQueryCountTest extends AbstractQueryCountTest {

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  @Inject GpxTrackRepository trackRepository;

  @Inject GpsSyncTestData sync;

  private void seedRoutes(int count) {
    for (int i = 0; i < count; i++) {
      dataService.createRoute(team1, user1, "Budget Route " + i, Visibility.PUBLIC);
    }
  }

  @Test
  void listTeamRoutes_costDoesNotScaleWithRowCount() {
    seedRoutes(LARGE_PAGE);
    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/routes", asUser1(), "/api/teams/" + team1Slug + "/routes");
  }

  @Test
  void listAllRoutes_costDoesNotScaleWithRowCount() {
    seedRoutes(LARGE_PAGE);
    assertFlatQueryCount("GET /api/routes", asUser1(), "/api/routes");
  }

  @Test
  void listAllRoutesAnonymous_costDoesNotScaleWithRowCount() {
    seedRoutes(LARGE_PAGE);
    assertFlatQueryCount("GET /api/routes anonymous", anonymous(), "/api/routes");
  }

  /**
   * Every route of the list tracked at two of user1's services in automatic sync, so that each row
   * carries {@code gpsSyncStatuses} (docs/LEDGER_*.md API-120) — resolved for the page, never per
   * row.
   */
  private List<Route> seedSyncedRoutes(int count) {
    GpsServiceConnection hammerhead = sync.connect(user1, GpsServiceType.HAMMERHEAD, true);
    GpsServiceConnection garmin = sync.connect(user1, GpsServiceType.GARMIN, true);
    List<Route> routes = new ArrayList<>();
    for (int i = 0; i < count; i++) {
      Route route = dataService.createRoute(team1, user1, "Synced Route " + i, Visibility.PUBLIC);
      sync.attachGpx(route, user1);
      sync.recordManualUpload(domain.getId(), hammerhead, route, "hh-" + i);
      sync.recordManualUpload(domain.getId(), garmin, route, "gc-" + i);
      routes.add(route);
    }
    return routes;
  }

  @Test
  void listTeamRoutes_gpsSyncStatuses_costDoesNotScaleWithRowCount() {
    seedSyncedRoutes(LARGE_PAGE);

    // Not vacuous: every row carries both services.
    List<List<Object>> statuses =
        asUser1()
            .get()
            .when()
            .get("/api/teams/" + team1Slug + "/routes?size=" + SMALL_PAGE)
            .then()
            .statusCode(200)
            .extract()
            .path("routes.gpsSyncStatuses");
    assertEquals(SMALL_PAGE, statuses.size());
    statuses.forEach(s -> assertEquals(2, s.size()));

    assertFlatQueryCount(
        "GET /api/teams/{teamSlug}/routes (gps sync statuses)",
        asUser1(),
        "/api/teams/" + team1Slug + "/routes");
  }

  @Test
  void listAllRoutes_gpsSyncStatuses_costDoesNotScaleWithRowCount() {
    seedSyncedRoutes(LARGE_PAGE);
    assertFlatQueryCount("GET /api/routes (gps sync statuses)", asUser1(), "/api/routes");
  }

  @Test
  void bulk_gpsSyncStatuses_costDoesNotScaleWithRouteCount() {
    List<String> slugs = seedSyncedRoutes(SMALL_PAGE).stream().map(Route::getSlug).toList();
    QueryStats.Counters one = measureBulk("GET routes/bulk [1 route, synced]", slugs.subList(0, 1));
    QueryStats.Counters three = measureBulk("GET routes/bulk [3 routes, synced]", slugs);
    assertTrue(
        three.statements() - one.statements() < 2,
        "the sync statuses of the bulk must be read per batch, not per route: "
            + one.statements()
            + " statements for 1 route, "
            + three.statements()
            + " for 3");
  }

  /** Routes each holding a stored surface document, so the bulk has something to read per row. */
  private List<String> seedRoutesWithSurfaces(int count) {
    List<String> slugs = new ArrayList<>();
    for (int i = 0; i < count; i++) {
      Route route = dataService.createRoute(team1, user1, "Surface Route " + i, Visibility.PUBLIC);
      slugs.add(route.getSlug());
      Long trackId = route.getTracks().getFirst().getId();
      TrackSurfaceDocument doc =
          new TrackSurfaceDocument(
              1,
              "ok",
              null,
              null,
              Instant.now(),
              "bicycle",
              10000.0,
              List.of(new SurfaceRange(0, 10000.0, "paved")),
              List.of());
      QuarkusTransaction.requiringNew().run(() -> trackRepository.updateSurfaces(trackId, doc));
    }
    return slugs;
  }

  private QueryStats.Counters measureBulk(String label, List<String> slugs) {
    return queryStats.measureAll(
        label,
        () ->
            asUser1()
                .get()
                .queryParam("slug", slugs)
                .queryParam("geometry", true)
                .when()
                .get("/api/teams/" + team1Slug + "/routes/bulk")
                .then()
                .statusCode(200));
  }

  @Test
  void bulkWithSurfaces_costDoesNotScaleWithRouteCount() {
    List<String> slugs = seedRoutesWithSurfaces(SMALL_PAGE);
    QueryStats.Counters one =
        measureBulk("GET routes/bulk [1 route, surfaces]", slugs.subList(0, 1));
    QueryStats.Counters three = measureBulk("GET routes/bulk [3 routes, surfaces]", slugs);
    // A bound rather than an equality, like the other budgets: a read per route would cost +2
    assertTrue(
        three.statements() - one.statements() < 2,
        "the surfaces of the bulk must be read per page, not per route: "
            + one.statements()
            + " statements for 1 route, "
            + three.statements()
            + " for 3");
  }
}
