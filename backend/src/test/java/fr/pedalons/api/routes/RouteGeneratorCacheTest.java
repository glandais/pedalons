package fr.pedalons.api.routes;

import static fr.pedalons.util.NetworkEdgesFixtures.lat;
import static fr.pedalons.util.NetworkEdgesFixtures.lon;
import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.route.network.RouteGeneratorGuard;
import fr.pedalons.service.route.network.TeamNetworkCache;
import fr.pedalons.util.NetworkEdgesFixtures;
import fr.pedalons.util.NetworkEdgesSeeder;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.MediaType;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The team graph cache of the route generator (docs/LEDGER_*.md API-198, lot 3 plan §2): when a
 * request reuses the graph and when it builds it again. Writes made by plain SQL stand in for the
 * other instance of a rolling deploy, or the previous release: nothing of this instance sees them
 * but the fingerprint.
 */
@QuarkusTest
class RouteGeneratorCacheTest extends AbstractResourceTest {

  private static final int SIZE = 5;

  /** A clock moved by hand. */
  private static final class Hand extends Clock {
    private Instant now = Instant.parse("2026-11-14T10:00:00Z");

    void advance(Duration d) {
      now = now.plus(d);
    }

    @Override
    public ZoneId getZone() {
      return ZoneOffset.UTC;
    }

    @Override
    public Clock withZone(ZoneId zone) {
      return this;
    }

    @Override
    public Instant instant() {
      return now;
    }
  }

  @Inject NetworkEdgesSeeder seeder;
  @Inject RouteGeneratorGuard guard;
  @Inject TeamNetworkCache cache;

  private final Hand clock = new Hand();
  private List<NetworkEdgesSeeder.Seeded> grid;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    guard.clear();
    cache.clearForTest();
    cache.setClockForTest(clock);
    dataService.setTeamEnableRoutePlanner(team1, true);
    grid = seeder.seedGrid(team1, user1, SIZE);
  }

  @AfterEach
  void restoreClock() {
    cache.setClockForTest(null);
    if (maxObservations != null) {
      cache.setMaxObservationsForTest(maxObservations);
      cache.clearForTest();
    }
  }

  private Long maxObservations;

  /** A 10 km loop from the middle of the grid; the network summary, whatever the outcome. */
  private ValidatableResponse generate() {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType(ContentType.JSON)
        .body(Map.of("start", Map.of("lng", lon(2), "lat", lat(2)), "distanceKm", 10))
        .when()
        .post("/api/teams/" + team1Slug + "/route-generator")
        .then();
  }

  private int routeCount() {
    var response = generate().extract();
    Integer ok = response.path("network.routeCount");
    return ok != null ? ok : response.path("errorDetails.routeCount");
  }

  private int pendingCount() {
    var response = generate().extract();
    Integer ok = response.path("network.pendingRouteCount");
    return ok != null ? ok : response.path("errorDetails.pendingRouteCount");
  }

  private int excludedCount() {
    var response = generate().extract();
    Integer ok = response.path("network.excludedRouteCount");
    return ok != null ? ok : response.path("errorDetails.excludedRouteCount");
  }

  private void put(String slug, RouteRequest request) {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", request, MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + slug)
        .then()
        .statusCode(200);
  }

  private static RouteRequest metadata(
      String name, SurfaceType surface, Boolean excludedFromGenerator) {
    return new RouteRequest(
        name,
        MediaDto.builder().build(),
        surface,
        Visibility.PUBLIC,
        null,
        null,
        null,
        null,
        excludedFromGenerator);
  }

  private long builds() {
    return cache.builds();
  }

  // ------------------------------------------------------------------ through the API

  @Test
  void twoIdenticalRequests_buildOnce() {
    long before = builds();
    assertEquals(10, routeCount());
    assertEquals(10, routeCount());
    assertEquals(before + 1, builds());
  }

  @Test
  void savingARouteWithoutTouchingTheGraphColumns_doesNotRebuild() {
    assertEquals(10, routeCount());
    long before = builds();
    put(grid.get(0).route().getSlug(), metadata("Renamed row", SurfaceType.ROAD, null));
    assertEquals(10, routeCount());
    assertEquals(before, builds());
  }

  @Test
  void deletingThenUndeleting_rebuildsEachTime_andTheNetworkFollows() {
    assertEquals(10, routeCount());
    long before = builds();
    String slug = grid.get(4).route().getSlug();
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/routes/" + slug)
        .then()
        .statusCode(204);
    assertEquals(9, routeCount());
    assertEquals(before + 1, builds());
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/routes/" + slug + "/undelete")
        .then()
        .statusCode(200);
    assertEquals(10, routeCount());
    assertEquals(before + 2, builds());
  }

  @Test
  void tickingTheExclusionBox_rebuildsAtOnce() {
    assertEquals(0, excludedCount());
    long before = builds();
    put(grid.get(0).route().getSlug(), metadata("Row 0", SurfaceType.ROAD, true));
    assertEquals(1, excludedCount());
    assertEquals(before + 1, builds());
  }

  @Test
  void changingTheSurfaceType_rebuilds() {
    routeCount();
    long before = builds();
    put(grid.get(1).route().getSlug(), metadata("Row 1", SurfaceType.GRAVEL, null));
    routeCount();
    assertEquals(before + 1, builds());
  }

  @Test
  void aDocumentWrittenAfterwards_waitsForTheRebuildInterval() {
    var fresh = seeder.seedPending(team1, user1, "Fresh");
    assertEquals(1, pendingCount());
    long before = builds();
    seeder.write(
        fresh.trackId(),
        NetworkEdgesFixtures.walk(fresh.rev(), new int[] {0, 0}, new int[] {1, 0}));
    // the catch-up of a save, or the backfill: tracks and documents only
    assertEquals(1, pendingCount());
    assertEquals(before, builds());
    clock.advance(Duration.ofMinutes(9));
    assertEquals(1, pendingCount());
    assertEquals(before, builds());
    clock.advance(Duration.ofMinutes(2));
    assertEquals(0, pendingCount());
    assertEquals(before + 1, builds());
  }

  // ------------------------------------------------------------------ another instance

  @Test
  void aRouteTickedByPlainSql_isSeenAtOnce() {
    assertEquals(0, excludedCount());
    long before = builds();
    seeder.sql(
        "update team_entities set excluded_from_generator = true, version = version + 1"
            + " where id = ?1",
        grid.get(0).route().getId());
    assertEquals(1, excludedCount());
    assertEquals(before + 1, builds());
  }

  /**
   * Past the bound no graph is built (its build would not fit in the heap), and the refusal is
   * remembered like a graph: the documents are read again only when a route changes.
   */
  @Test
  void aTeamOverTheObservationBound_isRefused_withoutReadingItsDocumentsAgain() {
    maxObservations = cache.setMaxObservationsForTest(20);
    long before = builds();
    generate()
        .statusCode(400)
        .body("code", org.hamcrest.Matchers.equalTo("GENERATOR_NETWORK_TOO_LARGE"));
    generate()
        .statusCode(400)
        .body("code", org.hamcrest.Matchers.equalTo("GENERATOR_NETWORK_TOO_LARGE"));
    assertEquals(before, builds());
    // every route but one deleted: the team is under the bound again, and is read again at once
    seeder.sql(
        "update team_entities set deleted = true, version = version + 1"
            + " where team_id = ?1 and entity_type = 2 and id <> ?2",
        team1.getId(),
        grid.get(0).route().getId());
    assertEquals(1, routeCount());
    assertEquals(before + 1, builds());
  }

  @Test
  void aRouteDeletedByPlainSql_isSeenAtOnce() {
    assertEquals(10, routeCount());
    long before = builds();
    seeder.sql(
        "update team_entities set deleted = true, version = version + 1 where id = ?1",
        grid.get(2).route().getId());
    assertEquals(9, routeCount());
    assertEquals(before + 1, builds());
  }

  @Test
  void aDocumentRewrittenByPlainSql_isSeenAfterTheInterval() {
    assertEquals(0, pendingCount());
    long before = builds();
    // the previous release's catch-up: a native write of a document, here a null one
    seeder.sql("update gpx_tracks set network_edges = null where id = ?1", grid.get(3).trackId());
    assertEquals(0, pendingCount());
    assertEquals(before, builds());
    clock.advance(Duration.ofMinutes(11));
    assertEquals(1, pendingCount());
    assertEquals(before + 1, builds());
  }
}
