package fr.pedalons.api.routes;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.route.RouteService;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.specification.RequestSpecification;
import java.util.List;
import java.util.stream.IntStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code GET /api/teams/{teamSlug}/routes/bulk}.
 *
 * <p>The endpoint exists so a screen showing several routes at once (a ride's stages, a comparison
 * view) does not cost one request per route. What is asserted here is the batching contract itself
 * — several slugs answered in one call, unknown/unreadable ones silently dropped rather than
 * failing the batch, the stored geometry returned untouched (or omitted wholesale on {@code
 * geometry=false}), the combined extent, and the size cap.
 */
@QuarkusTest
class RouteBulkResourceTest extends AbstractResourceTest {

  private String bulkUrl(String teamSlug) {
    return "/api/teams/" + teamSlug + "/routes/bulk";
  }

  private RequestSpecification withSlugs(String teamSlug, String... slugs) {
    RequestSpecification spec = given();
    for (String slug : slugs) {
      spec = spec.queryParam("slug", slug);
    }
    return spec;
  }

  private void seedRouteAt(
      Team team,
      User creator,
      String name,
      Visibility visibility,
      double lat1,
      double lon1,
      double lat2,
      double lon2) {
    List<GpxTrack.TrackPoint> points =
        List.of(
            new GpxTrack.TrackPoint(lat1, lon1, 500.0, 0.0),
            new GpxTrack.TrackPoint(lat2, lon2, 510.0, 10_000.0));
    String geometry = String.format("LINESTRING(%f %f,%f %f)", lon1, lat1, lon2, lat2);
    dataService.createRoute(team, creator, name, visibility, geometry, points);
  }

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  @Test
  void getRoutesBulk_withSeveralSlugs_shouldReturnAllOfThemInRequestOrder() {
    seedRouteAt(team1, user1, "Route A", Visibility.PUBLIC, 45.0, 6.0, 45.1, 6.1);
    seedRouteAt(team1, user1, "Route B", Visibility.PUBLIC, 46.0, 7.0, 46.2, 7.2);

    // Requested in reverse alphabetical order: the response must follow the request, not the DB.
    withSlugs(team1Slug, "route-b", "route-a")
        .when()
        .get(bulkUrl(team1Slug))
        .then()
        .statusCode(200)
        .body("routes", hasSize(2))
        .body("routes[0].slug", equalTo("route-b"))
        .body("routes[1].slug", equalTo("route-a"));
  }

  @Test
  void getRoutesBulk_withAnUnknownSlug_shouldSilentlyOmitIt() {
    seedRouteAt(team1, user1, "Route A", Visibility.PUBLIC, 45.0, 6.0, 45.1, 6.1);

    withSlugs(team1Slug, "route-a", "no-such-route")
        .when()
        .get(bulkUrl(team1Slug))
        .then()
        .statusCode(200)
        .body("routes", hasSize(1))
        .body("routes[0].slug", equalTo("route-a"));
  }

  @Test
  void getRoutesBulk_withNoSlugs_shouldReturnAnEmptyAnswer() {
    given()
        .when()
        .get(bulkUrl(team1Slug))
        .then()
        .statusCode(200)
        .body("routes", hasSize(0))
        .body("extent", nullValue());
  }

  private List<GpxTrack.TrackPoint> wobblyTrack(int storedPoints) {
    return IntStream.range(0, storedPoints)
        .mapToObj(i -> {
          double wobble = i % 2 == 0 ? 0 : 0.00001; // ~1.1 m
          return new GpxTrack.TrackPoint(45.0 + wobble, 6.0 + i * 0.0001, 100 + i, i * 7.8);
        })
        .toList();
  }

  /**
   * There is no read-time decimation left anywhere: a batch hands back the stored track of every
   * route it resolves, whatever its size and however many routes were named. That is the whole
   * point of the change that removed 'simplify' and 'points' — the stored track is already
   * Douglas-Peucker-filtered at import, and re-filtering it on read cost the elevation carried in
   * the same coordinates for a payload gain that measurement showed to be near zero.
   */
  @Test
  void getRoutesBulk_shouldReturnTheStoredTrackOfEveryRoute() {
    int storedPoints = 1_500;
    dataService.createRoute(
        team1,
        user1,
        "Wobbly Route A",
        Visibility.PUBLIC,
        "LINESTRING(6 45,6.1 45)",
        wobblyTrack(storedPoints));
    dataService.createRoute(
        team1,
        user1,
        "Wobbly Route B",
        Visibility.PUBLIC,
        "LINESTRING(6 45,6.1 45)",
        wobblyTrack(storedPoints));

    withSlugs(team1Slug, "wobbly-route-a", "wobbly-route-b")
        .when()
        .get(bulkUrl(team1Slug))
        .then()
        .statusCode(200)
        .body("routes", hasSize(2))
        .body("routes[0].tracks[0].line.coordinates", hasSize(storedPoints))
        .body("routes[1].tracks[0].line.coordinates", hasSize(storedPoints));
  }

  /**
   * Every coordinate keeps its elevation and cumulative distance. That is what lets a client draw
   * the elevation profile from this payload instead of asking for one, and it is the reason the
   * separate profile endpoint was removed rather than kept alongside.
   */
  @Test
  void getRoutesBulk_shouldReturnFourOrdinatesPerCoordinate() {
    List<GpxTrack.TrackPoint> roof =
        List.of(
            new GpxTrack.TrackPoint(45.0, 6.0, 100.0, 0.0),
            new GpxTrack.TrackPoint(45.05, 6.0, 200.0, 5_000.0),
            new GpxTrack.TrackPoint(45.1, 6.0, 100.0, 10_000.0));
    dataService.createRoute(
        team1, user1, "Roof Route", Visibility.PUBLIC, "LINESTRING(6 45,6 45.1)", roof);

    withSlugs(team1Slug, "roof-route")
        .when()
        .get(bulkUrl(team1Slug))
        .then()
        .statusCode(200)
        .body("routes[0].tracks[0].line.coordinates", hasSize(3))
        .body("routes[0].tracks[0].line.coordinates[1]", hasSize(4))
        .body("routes[0].tracks[0].line.coordinates[1][2]", equalTo(200.0f))
        .body("routes[0].tracks[0].line.coordinates[1][3]", equalTo(5_000.0f));
  }

  /**
   * A multi-track route returns every track whole. Each track's cumulative distance restarts at
   * zero, which is exactly why clients chain the tracks (rebasing each one and bridging the gap)
   * rather than concatenating the measures blindly.
   */
  @Test
  void getRoutesBulk_withAManyTracksRoute_shouldReturnEveryTrackWhole() {
    int tracksPerRoute = 5;
    int pointsPerTrack = 100;
    List<List<GpxTrack.TrackPoint>> tracks =
        IntStream.range(0, tracksPerRoute).mapToObj(t -> wobblyTrack(pointsPerTrack)).toList();
    dataService.createRouteWithTracks(team1, user1, "Many Tracks", Visibility.PUBLIC, tracks);

    withSlugs(team1Slug, "many-tracks")
        .when()
        .get(bulkUrl(team1Slug))
        .then()
        .statusCode(200)
        .body("routes[0].tracks", hasSize(tracksPerRoute))
        .body("routes[0].tracks[0].line.coordinates", hasSize(pointsPerTrack))
        .body("routes[0].tracks[4].line.coordinates", hasSize(pointsPerTrack))
        // Each track starts its own measure at zero.
        .body("routes[0].tracks[4].line.coordinates[0][3]", equalTo(0.0f));
  }

  /**
   * 'geometry=false' is what the screens that only name a route use — a ride editor listing each
   * group's route, a ride page linking its GPX. They used to ask for 'points=2' to approximate
   * this; saying it outright costs nothing and reads as what it is.
   */
  @Test
  void getRoutesBulk_withGeometryFalse_shouldReturnNoTracks() {
    dataService.createRoute(
        team1,
        user1,
        "Wobbly Route",
        Visibility.PUBLIC,
        "LINESTRING(6 45,6.1 45)",
        wobblyTrack(500));

    withSlugs(team1Slug, "wobbly-route")
        .queryParam("geometry", false)
        .when()
        .get(bulkUrl(team1Slug))
        .then()
        .statusCode(200)
        .body("routes", hasSize(1))
        .body("routes[0].slug", equalTo("wobbly-route"))
        .body("routes[0].name", equalTo("Wobbly Route"))
        .body("routes[0].tracks", hasSize(0))
        // No geometry was sent, so there is no box to frame it with — null, not a degenerate box.
        .body("extent", nullValue());
  }

  @Test
  void getRoutesBulk_extent_shouldCoverEveryReturnedRoute() {
    seedRouteAt(team1, user1, "Route A", Visibility.PUBLIC, 45.0, 6.0, 45.1, 6.1);
    seedRouteAt(team1, user1, "Route B", Visibility.PUBLIC, 46.0, 7.0, 46.2, 7.2);

    withSlugs(team1Slug, "route-a", "route-b")
        .when()
        .get(bulkUrl(team1Slug))
        .then()
        .statusCode(200)
        .body("extent.minLon", equalTo(6.0f))
        .body("extent.minLat", equalTo(45.0f))
        .body("extent.maxLon", equalTo(7.2f))
        .body("extent.maxLat", equalTo(46.2f));
  }

  @Test
  void getRoutesBulk_extent_shouldIgnoreARouteDroppedForUnreadability() {
    seedRouteAt(team1, user1, "Route A", Visibility.PUBLIC, 45.0, 6.0, 45.1, 6.1);
    // A private route far away: must not widen the extent once it is filtered out.
    seedRouteAt(team1, user1, "Secret Route", Visibility.TEAM, 60.0, 20.0, 61.0, 21.0);

    withSlugs(team1Slug, "route-a", "secret-route")
        .when()
        .get(bulkUrl(team1Slug))
        .then()
        .statusCode(200)
        .body("routes", hasSize(1))
        .body("extent.minLon", equalTo(6.0f))
        .body("extent.maxLon", equalTo(6.1f));
  }

  /**
   * Defect B3: the extent must be framed on the track geometry only. A waypoint imported from a
   * GPX (a meeting cafe, a car park) can sit tens of km off the actual loop; since no renderer
   * draws waypoints (see {@code routeToGeoJSON} on the web), including it in the extent would
   * zoom a map out until the ride is a squiggle in one corner.
   */
  @Test
  void getRoutesBulk_extent_shouldIgnoreAWaypointFarFromTheTrack() {
    Route route =
        dataService.createRoute(
            team1,
            user1,
            "Route With A Distant Waypoint",
            Visibility.PUBLIC,
            "LINESTRING(6 45,6.1 45.1)",
            List.of(
                new GpxTrack.TrackPoint(45.0, 6.0, 500.0, 0.0),
                new GpxTrack.TrackPoint(45.1, 6.1, 510.0, 10_000.0)));
    dataService.addWaypoint(route, user1, "Meeting Cafe", 60.0, 20.0);

    withSlugs(team1Slug, route.getSlug())
        .when()
        .get(bulkUrl(team1Slug))
        .then()
        .statusCode(200)
        .body("routes[0].waypoints", hasSize(1))
        .body("extent.minLon", equalTo(6.0f))
        .body("extent.minLat", equalTo(45.0f))
        .body("extent.maxLon", equalTo(6.1f))
        .body("extent.maxLat", equalTo(45.1f));
  }

  @Test
  void getRoutesBulk_withTooManySlugs_shouldReturn400() {
    List<String> tooMany =
        IntStream.rangeClosed(0, RouteService.MAX_BULK_SLUGS).mapToObj(i -> "slug-" + i).toList();

    RequestSpecification spec = given();
    for (String slug : tooMany) {
      spec = spec.queryParam("slug", slug);
    }

    spec.when().get(bulkUrl(team1Slug)).then().statusCode(400);
  }

  @Test
  void getRoutesBulk_atTheCap_shouldStillAnswer() {
    List<String> atCap =
        IntStream.range(0, RouteService.MAX_BULK_SLUGS).mapToObj(i -> "slug-" + i).toList();

    RequestSpecification spec = given();
    for (String slug : atCap) {
      spec = spec.queryParam("slug", slug);
    }

    spec.when().get(bulkUrl(team1Slug)).then().statusCode(200).body("routes", hasSize(0));
  }

  @Test
  void getRoutesBulk_shouldNotLeakAPrivateRouteOfAnotherTeamToANonMember() {
    seedRouteAt(team2, user1, "Secret Route", Visibility.TEAM, 45.0, 6.0, 45.1, 6.1);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .queryParam("slug", "secret-route")
        .when()
        .get(bulkUrl(team2Slug))
        .then()
        .statusCode(200)
        .body("routes", hasSize(0))
        .body("extent", nullValue());
  }

  @Test
  void getRoutesBulk_shouldExposeAPrivateRouteOfAnotherTeamToItsMember() {
    seedRouteAt(team2, user1, "Secret Route", Visibility.TEAM, 45.0, 6.0, 45.1, 6.1);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("slug", "secret-route")
        .when()
        .get(bulkUrl(team2Slug))
        .then()
        .statusCode(200)
        .body("routes", hasSize(1))
        .body("routes[0].slug", equalTo("secret-route"));
  }

  @Test
  void getRoutesBulk_toNonexistentTeam_shouldReturn404() {
    given()
        .queryParam("slug", "whatever")
        .when()
        .get(bulkUrl("no-such-team"))
        .then()
        .statusCode(404);
  }

  /** The empty-batch fast path must not skip the team lookup every sibling endpoint does. */
  @Test
  void getRoutesBulk_toNonexistentTeamWithNoSlugs_shouldStillReturn404() {
    given().when().get(bulkUrl("no-such-team")).then().statusCode(404);
  }
}
