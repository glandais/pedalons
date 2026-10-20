package fr.pedalons.api.routes;

import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.route.TrackSurfaceDocument;
import fr.pedalons.domain.route.TrackSurfaceDocument.SurfaceRange;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.route.GpxTrackRepository;
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
