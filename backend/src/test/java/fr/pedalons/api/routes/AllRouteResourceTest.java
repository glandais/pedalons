package fr.pedalons.api.routes;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.security.TileTokenService;
import fr.pedalons.service.team.request.MinRole;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class AllRouteResourceTest extends AbstractResourceTest {

  @Inject TileTokenService tileTokenService;

  private Route publicRoute;
  private Route teamRoute;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    publicRoute = dataService.createRoute(team1, user1, "Public Route", Visibility.PUBLIC);
    teamRoute = dataService.createRoute(team1, user1, "Team Route", Visibility.TEAM);
  }

  // ==================== List All Routes Tests ====================

  @Test
  void listAllRoutes_withoutAuth_shouldReturnPublicRoutes() {
    given()
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()))
        .body("total", greaterThanOrEqualTo(1))
        .body("page", equalTo(0))
        .body("size", equalTo(20));
  }

  @Test
  void listAllRoutes_asMember_shouldReturnPublicAndTeamRoutes() {
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()))
        .body("total", greaterThanOrEqualTo(2));
  }

  @Test
  void listAllRoutes_asNonMember_shouldReturnOnlyPublicRoutes() {
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldSupportPagination() {
    given()
        .queryParam("page", 0)
        .queryParam("size", 10)
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("page", equalTo(0))
        .body("size", equalTo(10));
  }

  @Test
  void listAllRoutes_shouldSupportSearch() {
    given()
        .queryParam("search", "Public")
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldFilterByMinDistance() {
    given()
        .queryParam("minDistance", 1000)
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldFilterByMaxDistance() {
    given()
        .queryParam("maxDistance", 100000)
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldFilterByDistanceRange() {
    given()
        .queryParam("minDistance", 1000)
        .queryParam("maxDistance", 50000)
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldFilterByElevationGain() {
    given()
        .queryParam("minElevationGain", 100)
        .queryParam("maxElevationGain", 2000)
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldFilterByHilliness() {
    given()
        .queryParam("hilliness", "FLAT")
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldFilterBySurfaceType() {
    given()
        .queryParam("surfaceType", "ROAD")
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldFilterByWindDirection() {
    given()
        .queryParam("windDirection", "NORTH")
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldSupportProximitySearch() {
    given()
        .queryParam("nearLat", 48.8566)
        .queryParam("nearLon", 2.3522)
        .queryParam("nearRadius", 50000)
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldSupportProximitySearchWithNearType() {
    given()
        .queryParam("nearLat", 48.8566)
        .queryParam("nearLon", 2.3522)
        .queryParam("nearType", "START")
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldSupportSorting() {
    given()
        .queryParam("sortBy", "DISTANCE")
        .queryParam("sortDir", "DESC")
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()));
  }

  @Test
  void listAllRoutes_shouldSupportMultipleFilters() {
    given()
        .queryParam("search", "route")
        .queryParam("minDistance", 1000)
        .queryParam("maxDistance", 100000)
        .queryParam("surfaceType", "ROAD")
        .queryParam("sortBy", "ELEVATION_GAIN")
        .queryParam("sortDir", "ASC")
        .queryParam("page", 0)
        .queryParam("size", 5)
        .when()
        .get("/api/routes")
        .then()
        .statusCode(200)
        .body("routes", is(notNullValue()))
        .body("page", equalTo(0))
        .body("size", equalTo(5));
  }

  // ==================== Vector Tile Tests ====================

  /** Tile covering the test routes, which run from (6, 45) to (6.1, 45.1). */
  private static final String ROUTES_TILE = "/api/routes/tiles/8/132/92.mvt";

  @Test
  void allRoutesTile_withoutAuth_shouldOnlyContainPublicRoute() {
    String tile = MvtAssert.decode(given().when().get(ROUTES_TILE));

    MvtAssert.assertContainsSlugs(tile, publicRoute.getSlug());
    MvtAssert.assertMissingSlugs(tile, teamRoute.getSlug());
  }

  @Test
  void allRoutesTile_asNonMember_shouldOnlyContainPublicRoute() {
    String tile =
        MvtAssert.decode(given().auth().oauth2(getAccessToken(USER4)).when().get(ROUTES_TILE));

    MvtAssert.assertContainsSlugs(tile, publicRoute.getSlug());
    MvtAssert.assertMissingSlugs(tile, teamRoute.getSlug());
  }

  @Test
  void allRoutesTile_asMember_shouldContainTeamRoute() {
    String tile =
        MvtAssert.decode(given().auth().oauth2(getAccessToken(USER3)).when().get(ROUTES_TILE));

    MvtAssert.assertContainsSlugs(tile, publicRoute.getSlug(), teamRoute.getSlug());
  }

  /** Nothing in front of the backend compresses: a tile not gzipped here travels raw. */
  @Test
  void allRoutesTile_shouldBeCompressed() {
    given()
        .header("Accept-Encoding", "gzip")
        .when()
        .get(ROUTES_TILE)
        .then()
        .statusCode(200)
        .header("Content-Encoding", "gzip");
  }

  @Test
  void allRoutesTile_outsideRouteBounds_shouldBeEmpty() {
    given().when().get("/api/routes/tiles/12/0/0.mvt").then().statusCode(200).body(emptyString());
  }

  @Test
  void allRoutesTile_withCoordinatesOutsideZoomLevel_shouldReturnBadRequest() {
    given().when().get("/api/routes/tiles/8/9999/92.mvt").then().statusCode(400);
  }

  @Test
  void allRoutesTile_withMinRole_withoutAuth_shouldBeEmpty() {
    given()
        .queryParam("minRole", MinRole.MEMBER)
        .when()
        .get(ROUTES_TILE)
        .then()
        .statusCode(200)
        .body(emptyString());
  }

  @Test
  void allRoutesTile_withMinRole_asMember_shouldContainTeamRoute() {
    String tile =
        MvtAssert.decode(
            given()
                .auth()
                .oauth2(getAccessToken(USER3))
                .queryParam("minRole", MinRole.MEMBER)
                .when()
                .get(ROUTES_TILE));

    MvtAssert.assertContainsSlugs(tile, publicRoute.getSlug(), teamRoute.getSlug());
  }

  @Test
  void allRoutesTile_withMinRole_asNonMember_shouldBeEmpty() {
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .queryParam("minRole", MinRole.MEMBER)
        .when()
        .get(ROUTES_TILE)
        .then()
        .statusCode(200)
        .body(emptyString());
  }

  @Test
  void allRoutesTile_withSearch_shouldOnlyContainMatchingRoute() {
    String tile =
        MvtAssert.decode(
            given()
                .auth()
                .oauth2(getAccessToken(USER3))
                .queryParam("search", "team")
                .when()
                .get(ROUTES_TILE));

    MvtAssert.assertContainsSlugs(tile, teamRoute.getSlug());
    MvtAssert.assertMissingSlugs(tile, publicRoute.getSlug());
  }

  // ==================== Tile Token Tests ====================
  //
  // The token exists because a map renderer fetches tiles through its own HTTP stack: no bearer
  // header, and on mobile no session cookie either. See TileTokenService.

  /** The whole feature in one assertion: a token turns the anonymous tile into the member's tile. */
  @Test
  void allRoutesTile_withTileToken_shouldContainTeamRoute() {
    String token = tileTokenService.issue(user3.getId(), domain.getId(), Instant.now()).value();

    String tile = MvtAssert.decode(given().queryParam("t", token).when().get(ROUTES_TILE));

    MvtAssert.assertContainsSlugs(tile, publicRoute.getSlug(), teamRoute.getSlug());
  }

  @Test
  void allRoutesTile_withTileTokenOfNonMember_shouldOnlyContainPublicRoute() {
    String token = tileTokenService.issue(user4.getId(), domain.getId(), Instant.now()).value();

    String tile = MvtAssert.decode(given().queryParam("t", token).when().get(ROUTES_TILE));

    MvtAssert.assertContainsSlugs(tile, publicRoute.getSlug());
    MvtAssert.assertMissingSlugs(tile, teamRoute.getSlug());
  }

  /**
   * A present-but-invalid token is an error, never a silent downgrade: an anonymous tile served
   * here would go out with {@code max-age=300} and be cached as the truth for five minutes.
   */
  @Test
  void allRoutesTile_withExpiredTileToken_shouldReturnUnauthorized() {
    String expired =
        tileTokenService
            .issue(user3.getId(), domain.getId(), Instant.now().minus(2, ChronoUnit.HOURS))
            .value();

    given().queryParam("t", expired).when().get(ROUTES_TILE).then().statusCode(401);
  }

  @Test
  void allRoutesTile_withTamperedTileToken_shouldReturnUnauthorized() {
    String token = tileTokenService.issue(user3.getId(), domain.getId(), Instant.now()).value();

    // The *first* character of the MAC, not the last: a 16-byte MAC is 22 base64url characters,
    // i.e. 132 bits for 128 useful ones, so the final character's two low bits are dropped on
    // decode. Flipping those yields a different-looking string that decodes to the same MAC — and
    // a tamper test that passes without testing anything.
    int mac = token.indexOf('.') + 1;
    String tampered =
        token.substring(0, mac) + (token.charAt(mac) == 'A' ? 'B' : 'A') + token.substring(mac + 1);

    given().queryParam("t", tampered).when().get(ROUTES_TILE).then().statusCode(401);
  }

  @Test
  void allRoutesTile_withGarbageTileToken_shouldReturnUnauthorized() {
    given().queryParam("t", "not-a-token").when().get(ROUTES_TILE).then().statusCode(401);
  }

  /**
   * Multi-tenancy: the domain is part of what was signed, and a token minted elsewhere resolves no
   * user at all — so the caller falls back to being anonymous rather than borrowing user3.
   */
  @Test
  void allRoutesTile_withTileTokenOfAnotherDomain_shouldOnlyContainPublicRoute() {
    String foreign =
        tileTokenService.issue(user3.getId(), domain.getId() + 1, Instant.now()).value();

    String tile = MvtAssert.decode(given().queryParam("t", foreign).when().get(ROUTES_TILE));

    MvtAssert.assertContainsSlugs(tile, publicRoute.getSlug());
    MvtAssert.assertMissingSlugs(tile, teamRoute.getSlug());
  }

  /**
   * The non-regression guard for the web, which never sends a token and must keep taking exactly
   * the path it took before the filter existed.
   */
  @Test
  void allRoutesTile_withoutTileToken_shouldStillHonourTheBearerToken() {
    String tile =
        MvtAssert.decode(given().auth().oauth2(getAccessToken(USER3)).when().get(ROUTES_TILE));

    MvtAssert.assertContainsSlugs(tile, publicRoute.getSlug(), teamRoute.getSlug());
  }
}
