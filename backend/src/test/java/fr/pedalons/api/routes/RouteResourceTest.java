package fr.pedalons.api.routes;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.route.ClimbData;
import fr.pedalons.domain.route.GpxTrack;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.common.request.SlugChangeRequest;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.security.TileTokenService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.MediaType;
import java.io.File;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class RouteResourceTest extends AbstractResourceTest {

  @Inject TileTokenService tileTokenService;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  // ==================== List Routes Tests ====================

  @Test
  void listRoutes_withoutAuth_shouldSucceed() {
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(200)
        .body("routes", notNullValue())
        .body("total", greaterThanOrEqualTo(0));
  }

  @Test
  void listRoutes_asMember_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(200)
        .body("routes", notNullValue());
  }

  @Test
  void listRoutes_asNonMember_shouldSucceed() {
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(200)
        .body("routes", notNullValue());
  }

  @Test
  void listRoutes_toNonexistentTeam_shouldReturn404() {
    given()
        .when()
        .get("/api/teams/nonexistent-team/routes")
        .then()
        // empty list
        .statusCode(404);
  }

  @Test
  void listRoutes_shouldSupportPagination() {
    given()
        .queryParam("page", 1)
        .queryParam("size", 10)
        .when()
        .get("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(200)
        .body("page", equalTo(1))
        .body("size", equalTo(10));
  }

  // ==================== Create Route Tests ====================

  @Test
  void createRoute_asAdmin_shouldSucceed() {
    File gpxFile = new File("src/test/resources/example.gpx");

    RouteRequest route =
        new RouteRequest(
            "Admin Route",
            MediaDto.builder().markdown("A test route").build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", gpxFile, "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(201)
        .body("name", equalTo("Admin Route"))
        .body("media.markdown", equalTo("A test route"))
        .body("distance", greaterThan(0.0f))
        .body("elevationGain", greaterThanOrEqualTo(0.0f));
  }

  @Test
  void createRoute_asOrganizer_shouldSucceed() {
    File gpxFile = new File("src/test/resources/example.gpx");

    RouteRequest route =
        new RouteRequest(
            "Organizer Route",
            MediaDto.builder().markdown("Route by organizer").build(),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", gpxFile, "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(201)
        .body("name", equalTo("Organizer Route"));
  }

  @Test
  void createRoute_asMember_shouldBeDenied() {
    File gpxFile = new File("src/test/resources/example.gpx");

    RouteRequest route =
        new RouteRequest(
            "Member Route",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", gpxFile, "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(403);
  }

  @Test
  void createRoute_withoutAuth_shouldReturn401() {
    File gpxFile = new File("src/test/resources/example.gpx");

    RouteRequest route =
        new RouteRequest(
            "Unauth Route",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    given()
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", gpxFile, "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(401);
  }

  @Test
  void createRoute_asNonMember_shouldReturn403() {
    File gpxFile = new File("src/test/resources/example.gpx");

    RouteRequest route =
        new RouteRequest(
            "NonMember Route",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", gpxFile, "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(403);
  }

  @Test
  void createRoute_withInvalidGpx_shouldReturn400AndNotCreateRoute() {
    File invalidGpx = new File("src/test/resources/invalid.gpx");

    RouteRequest route =
        new RouteRequest(
            "Route That Should Not Exist",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    int routesBefore =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .when()
            .get("/api/teams/" + team1Slug + "/routes")
            .then()
            .statusCode(200)
            .extract()
            .path("total");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", invalidGpx, "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(400)
        .body("code", equalTo("GPX_FAILURE"));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(200)
        .body("total", equalTo(routesBefore));
  }

  @Test
  void createRoute_withoutGpxFile_shouldReturn400() {
    RouteRequest route =
        new RouteRequest(
            "No GPX Route",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(400);
  }

  // ==================== Route planner toggle ====================

  /** Two points near Lyon: enough for the planner path, cheap enough not to matter. */
  private static List<GeoPoint> plannerPoints() {
    return List.of(new GeoPoint(4.8357, 45.7640), new GeoPoint(4.8500, 45.7700));
  }

  @Test
  void createRoute_withPoints_whenPlannerDisabled_shouldReturn400() {
    RouteRequest route =
        new RouteRequest(
            "Drawn Route",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            plannerPoints());

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(400)
        .body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  @Test
  void createRoute_withPoints_whenPlannerEnabled_shouldSucceed() {
    dataService.setTeamEnableRoutePlanner(team1, true);

    RouteRequest route =
        new RouteRequest(
            "Drawn Route",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            plannerPoints());

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(201)
        .body("name", equalTo("Drawn Route"));
  }

  /** The toggle is about drawing only: importing a file must stay open. */
  @Test
  void createRoute_withGpxFile_whenPlannerDisabled_shouldSucceed() {
    File gpxFile = new File("src/test/resources/example.gpx");

    RouteRequest route =
        new RouteRequest(
            "Imported Route",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", gpxFile, "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(201);
  }

  @Test
  void updateRoute_withPoints_whenPlannerDisabled_shouldReturn400() {
    Route existing = dataService.createRoute(team1, user1, "Existing Route");

    RouteRequest route =
        new RouteRequest(
            "Existing Route",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            plannerPoints());

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + existing.getSlug())
        .then()
        .statusCode(400)
        .body("code", equalTo("ROUTE_PLANNER_DISABLED"));
  }

  /** Track frozen, metadata still editable. */
  @Test
  void updateRoute_metadataOnly_whenPlannerDisabled_shouldSucceed() {
    Route existing = dataService.createRoute(team1, user1, "Existing Route");

    RouteRequest route =
        new RouteRequest(
            "Renamed Route", MediaDto.builder().build(), SurfaceType.ROAD, Visibility.PUBLIC, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + existing.getSlug())
        .then()
        .statusCode(200)
        .body("name", equalTo("Renamed Route"));
  }

  @Test
  void createRoute_toNonexistentTeam_shouldReturn404() {
    File gpxFile = new File("src/test/resources/example.gpx");

    RouteRequest route =
        new RouteRequest(
            "Test Route", MediaDto.builder().build(), SurfaceType.GRAVEL, Visibility.PUBLIC, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", gpxFile, "application/gpx+xml")
        .when()
        .post("/api/teams/nonexistent-team/routes")
        .then()
        .statusCode(404);
  }

  // ==================== Get Route Tests ====================

  /**
   * A climb is named after the waypoint at its top; one with no waypoint near its summit has no
   * name (docs/LEDGER_*.md API-10). The waypoint is stored as a PostGIS point: this also pins the
   * latitude/longitude order on the way to the naming.
   */
  @Test
  void getRoute_climbs_areNamedAfterTheWaypointAtTheirTop() {
    double step = 100 / 111_195.0; // 100 m of latitude
    List<GpxTrack.TrackPoint> points = new java.util.ArrayList<>();
    for (int i = 0; i < 80; i++) {
      points.add(new GpxTrack.TrackPoint(45.0 + i * step, 6.0, 100 + i * 5.0, i * 100.0));
    }
    Route route =
        dataService.createRouteWithClimbs(
            team1,
            user1,
            "Route des cols",
            points,
            List.of(
                new ClimbData(500, 125, 2000, 200, 1500, 75, 75, 0, 5, 5, List.of()),
                new ClimbData(4000, 300, 6000, 400, 2000, 100, 100, 0, 5, 5, List.of())));
    // At the top of the second climb (6000 m, point 60), a few metres off the track.
    dataService.addWaypoint(route, user1, "Col du Test", 45.0 + 60 * step, 6.0005);

    given()
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + route.getSlug())
        .then()
        .statusCode(200)
        .body("tracks[0].climbs", hasSize(2))
        .body("tracks[0].climbs[0]", not(hasKey("name")))
        .body("tracks[0].climbs[1].name", equalTo("Col du Test"));
  }

  @Test
  void getRoute_withoutAuth_shouldSucceed() {
    Route testRoute = dataService.createRoute(team1, user1, "Public Route", Visibility.PUBLIC);

    given()
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(200)
        .body("id", equalTo(TsidUtils.toString(testRoute.getId())))
        .body("name", equalTo("Public Route"));
  }

  @Test
  void getRoute_asMember_shouldSucceed() {
    Route testRoute = dataService.createRoute(team1, user1, "Member Get Route", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(200)
        .body("name", equalTo("Member Get Route"));
  }

  @Test
  void getRoute_asNonMember_shouldSucceed() {
    Route testRoute =
        dataService.createRoute(team1, user1, "NonMember Get Route", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(200)
        .body("name", equalTo("NonMember Get Route"));
  }

  @Test
  void getRoute_nonexistent_shouldReturn404() {
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/routes/nonexistent-route")
        .then()
        .statusCode(404);
  }

  @Test
  void getRoute_toNonexistentTeam_shouldReturn404() {
    given().when().get("/api/teams/nonexistent-team/routes/some-route").then().statusCode(404);
  }

  // ==================== Update Route Tests ====================

  @Test
  void updateRoute_asAdmin_shouldSucceed() {
    Route testRoute = dataService.createRoute(team1, user1, "Original Name", Visibility.PUBLIC);

    RouteRequest route =
        new RouteRequest(
            "Updated Name",
            MediaDto.builder().markdown("Updated description").build(),
            SurfaceType.MTB,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated Name"))
        .body("media.markdown", equalTo("Updated description"));
  }

  @Test
  void updateRoute_asOrganizer_shouldSucceed() {
    Route testRoute =
        dataService.createRoute(team1, user1, "Organizer Update Route", Visibility.PUBLIC);

    RouteRequest route =
        new RouteRequest(
            "Updated by Organizer",
            MediaDto.builder().markdown("Organizer updated").build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated by Organizer"));
  }

  @Test
  void updateRoute_asMember_shouldBeDenied() {
    Route testRoute =
        dataService.createRoute(team1, user1, "Member Update Route", Visibility.PUBLIC);

    RouteRequest route =
        new RouteRequest(
            "Hacked by Member",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(403);
  }

  @Test
  void updateRoute_withoutAuth_shouldReturn401() {
    Route testRoute =
        dataService.createRoute(team1, user1, "Unauth Update Route", Visibility.PUBLIC);

    RouteRequest route =
        new RouteRequest(
            "Unauthorized Update",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    given()
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(401);
  }

  @Test
  void updateRoute_asNonMember_shouldReturn403() {
    Route testRoute =
        dataService.createRoute(team1, user1, "NonMember Update Route", Visibility.PUBLIC);

    RouteRequest route =
        new RouteRequest(
            "Hacked by NonMember",
            MediaDto.builder().build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(403);
  }

  @Test
  void updateRoute_withNewGpxFile_shouldSucceed() {
    Route testRoute = dataService.createRoute(team1, user1, "Original Route", Visibility.PUBLIC);

    RouteRequest route =
        new RouteRequest(
            "Updated Route",
            MediaDto.builder().markdown("Updated with new GPX").build(),
            SurfaceType.GRAVEL,
            Visibility.PUBLIC,
            null);

    File gpxFile = new File("src/test/resources/example.gpx");

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", gpxFile, "application/gpx+xml")
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(200)
        .body("name", equalTo("Updated Route"))
        .body("media.markdown", equalTo("Updated with new GPX"))
        .body("distance", greaterThan(0.0f))
        .body("elevationGain", greaterThanOrEqualTo(0.0f));
  }

  @Test
  void updateRoute_nonexistent_shouldReturn404() {
    RouteRequest route =
        new RouteRequest(
            "Nonexistent", MediaDto.builder().build(), SurfaceType.GRAVEL, Visibility.PUBLIC, null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/nonexistent-route")
        .then()
        .statusCode(404);
  }

  // ==================== Delete Route Tests ====================

  @Test
  void deleteRoute_asAdmin_shouldSucceed() {
    Route testRoute = dataService.createRoute(team1, user1, "To Delete", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(204);

    // Verify route is no longer accessible
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(404);
  }

  @Test
  void deleteRoute_asOrganizer_shouldSucceed() {
    Route testRoute = dataService.createRoute(team1, user1, "Organizer Delete", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .delete("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(204);
  }

  @Test
  void deleteRoute_asMember_shouldBeDenied() {
    Route testRoute = dataService.createRoute(team1, user1, "Member Delete", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .delete("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(403);
  }

  @Test
  void deleteRoute_withoutAuth_shouldReturn401() {
    Route testRoute = dataService.createRoute(team1, user1, "Unauth Delete", Visibility.PUBLIC);

    given()
        .when()
        .delete("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(401);
  }

  @Test
  void deleteRoute_asNonMember_shouldReturn403() {
    Route testRoute = dataService.createRoute(team1, user1, "NonMember Delete", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .delete("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug())
        .then()
        .statusCode(403);
  }

  @Test
  void deleteRoute_nonexistent_shouldReturn404() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/routes/nonexistent-route")
        .then()
        .statusCode(404);
  }

  // ==================== Change Slug Tests ====================

  @Test
  void changeSlug_asAdmin_shouldSucceed() {
    Route testRoute = dataService.createRoute(team1, user1, "Slug Change Route", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(new SlugChangeRequest("new-route-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug() + "/slug")
        .then()
        .statusCode(200)
        .body("slug", equalTo("new-route-slug"));
  }

  @Test
  void changeSlug_asOrganizer_shouldSucceed() {
    Route testRoute =
        dataService.createRoute(team1, user1, "Organizer Slug Route", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(new SlugChangeRequest("organizer-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug() + "/slug")
        .then()
        .statusCode(200)
        .body("slug", equalTo("organizer-slug"));
  }

  @Test
  void changeSlug_asMember_shouldReturn403() {
    Route testRoute = dataService.createRoute(team1, user1, "Member Slug Route", Visibility.PUBLIC);

    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .contentType("application/json")
        .body(new SlugChangeRequest("hacked-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug() + "/slug")
        .then()
        .statusCode(403);
  }

  @Test
  void changeSlug_withoutAuth_shouldReturn401() {
    Route testRoute = dataService.createRoute(team1, user1, "Unauth Slug Route", Visibility.PUBLIC);

    given()
        .contentType("application/json")
        .body(new SlugChangeRequest("unauth-slug"))
        .when()
        .patch("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug() + "/slug")
        .then()
        .statusCode(401);
  }

  /**
   * "bulk", "count", "bounds" and "tiles" are literal path segments {@code RouteResource} declares
   * alongside {@code /{routeSlug}} — a route slugged one of them would be permanently shadowed by
   * that sibling endpoint. Rejected with the same 409 shape as a genuine slug-uniqueness conflict,
   * since the slug is well-formed and simply unavailable, not malformed.
   */
  @Test
  void changeSlug_toALiteralSiblingOfTheRouteResource_shouldReturn409() {
    Route testRoute =
        dataService.createRoute(team1, user1, "Reserved Slug Route", Visibility.PUBLIC);

    for (String reserved : new String[] {"bulk", "count", "bounds", "tiles"}) {
      given()
          .auth()
          .oauth2(getAccessToken(USER1))
          .contentType("application/json")
          .body(new SlugChangeRequest(reserved))
          .when()
          .patch("/api/teams/" + team1Slug + "/routes/" + testRoute.getSlug() + "/slug")
          .then()
          .statusCode(409);
    }
  }

  /**
   * A route named so its slugified form collides with a reserved word is auto-suffixed on
   * creation, exactly like a genuine slug collision — see {@code SlugService.generateSlug}.
   */
  @Test
  void createRoute_namedAfterAReservedSlug_shouldSuffixIt() {
    File gpxFile = new File("src/test/resources/example.gpx");

    RouteRequest route =
        new RouteRequest(
            "Bulk",
            MediaDto.builder().markdown("Named after a reserved word").build(),
            SurfaceType.ROAD,
            Visibility.PUBLIC,
            null);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart("route", route, MediaType.APPLICATION_JSON)
        .multiPart("gpxFile", gpxFile, "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/routes")
        .then()
        .statusCode(201)
        .body("slug", equalTo("bulk-1"));
  }

  // ==================== Vector Tile Tests ====================

  /** Tile covering the test routes, which run from (6, 45) to (6.1, 45.1). */
  private String routesTile() {
    return "/api/teams/" + team1Slug + "/routes/tiles/8/132/92.mvt";
  }

  @Test
  void routesTile_withoutAuth_shouldOnlyContainPublicRoute() {
    Route publicRoute = dataService.createRoute(team1, user1, "Tile Public", Visibility.PUBLIC);
    Route teamRoute = dataService.createRoute(team1, user1, "Tile Team", Visibility.TEAM);

    String tile = MvtAssert.decode(given().when().get(routesTile()));

    MvtAssert.assertContainsSlugs(tile, publicRoute.getSlug());
    MvtAssert.assertMissingSlugs(tile, teamRoute.getSlug());
  }

  @Test
  void routesTile_asMember_shouldContainTeamRoute() {
    Route publicRoute = dataService.createRoute(team1, user1, "Tile Public", Visibility.PUBLIC);
    Route teamRoute = dataService.createRoute(team1, user1, "Tile Team", Visibility.TEAM);

    String tile =
        MvtAssert.decode(given().auth().oauth2(getAccessToken(USER3)).when().get(routesTile()));

    MvtAssert.assertContainsSlugs(tile, publicRoute.getSlug(), teamRoute.getSlug());
  }

  @Test
  void routesTile_forUnknownTeam_shouldReturn404() {
    given()
        .when()
        .get("/api/teams/does-not-exist/routes/tiles/8/132/92.mvt")
        .then()
        .statusCode(404);
  }

  @Test
  void routesTile_outsideRouteBounds_shouldBeEmpty() {
    dataService.createRoute(team1, user1, "Tile Public", Visibility.PUBLIC);

    given()
        .when()
        .get("/api/teams/" + team1Slug + "/routes/tiles/12/0/0.mvt")
        .then()
        .statusCode(200)
        .body(emptyString());
  }

  @Test
  void routesTile_withSearch_shouldOnlyContainMatchingRoute() {
    Route alpha = dataService.createRoute(team1, user1, "Tile Alpha", Visibility.PUBLIC);
    Route beta = dataService.createRoute(team1, user1, "Tile Beta", Visibility.PUBLIC);

    String tile = MvtAssert.decode(given().queryParam("search", "alpha").when().get(routesTile()));

    MvtAssert.assertContainsSlugs(tile, alpha.getSlug());
    MvtAssert.assertMissingSlugs(tile, beta.getSlug());
  }

  @Test
  void routesTile_withNonMatchingSurfaceType_shouldBeEmpty() {
    dataService.createRoute(team1, user1, "Tile Public", Visibility.PUBLIC);

    given()
        .queryParam("surfaceType", SurfaceType.MTB)
        .when()
        .get(routesTile())
        .then()
        .statusCode(200)
        .body(emptyString());
  }

  @Test
  void routesTile_withTileToken_shouldContainTeamRoute() {
    Route publicRoute = dataService.createRoute(team1, user1, "Tile Public", Visibility.PUBLIC);
    Route teamRoute = dataService.createRoute(team1, user1, "Tile Team", Visibility.TEAM);
    String token = tileTokenService.issue(user3.getId(), domain.getId(), Instant.now()).value();

    String tile = MvtAssert.decode(given().queryParam("t", token).when().get(routesTile()));

    MvtAssert.assertContainsSlugs(tile, publicRoute.getSlug(), teamRoute.getSlug());
  }

  @Test
  void routesTile_withExpiredTileToken_shouldReturnUnauthorized() {
    dataService.createRoute(team1, user1, "Tile Public", Visibility.PUBLIC);
    String expired =
        tileTokenService
            .issue(user3.getId(), domain.getId(), Instant.now().minus(2, ChronoUnit.HOURS))
            .value();

    given().queryParam("t", expired).when().get(routesTile()).then().statusCode(401);
  }

  // ==================== Route Usages Tests ====================

  private static final Instant USAGE_TIME = Instant.parse("2026-08-01T09:00:00Z");

  private String usagesUrl(Route route) {
    return "/api/teams/" + team1Slug + "/routes/" + route.getSlug() + "/usages";
  }

  @Test
  void getRouteUsages_withNoUsages_shouldReturnEmptyList() {
    Route route = dataService.createRoute(team1, user1, "Unused Route", Visibility.PUBLIC);

    given().when().get(usagesUrl(route)).then().statusCode(200).body("usages", hasSize(0));
  }

  @Test
  void getRouteUsages_referencedDirectlyByRide_shouldListRideOnce() {
    Route route = dataService.createRoute(team1, user1, "Ride Route", Visibility.PUBLIC);
    Ride ride = dataService.createRide(team1, user1, "Sunday Ride", "sunday-ride", USAGE_TIME);
    dataService.setRideRoute(ride, route);

    given()
        .when()
        .get(usagesUrl(route))
        .then()
        .statusCode(200)
        .body("usages", hasSize(1))
        .body("usages[0].type", equalTo("RIDE"))
        .body("usages[0].slug", equalTo(ride.getSlug()))
        .body("usages[0].name", equalTo("Sunday Ride"))
        .body("usages[0].teamSlug", equalTo(team1Slug))
        .body("usages[0].referencedDirectly", equalTo(true))
        .body("usages[0].viaChildNames", hasSize(0));
  }

  @Test
  void getRouteUsages_referencedViaRideGroup_shouldListRideWithGroupName() {
    Route route = dataService.createRoute(team1, user1, "Group Route", Visibility.PUBLIC);
    Ride ride = dataService.createRide(team1, user1, "Group Ride", "group-ride", USAGE_TIME);
    RideGroup group = dataService.createRideGroup(user1, ride, "Fast Group");
    dataService.setRideGroupRoute(group, route);

    given()
        .when()
        .get(usagesUrl(route))
        .then()
        .statusCode(200)
        .body("usages", hasSize(1))
        .body("usages[0].type", equalTo("RIDE"))
        .body("usages[0].slug", equalTo(ride.getSlug()))
        .body("usages[0].referencedDirectly", equalTo(false))
        .body("usages[0].viaChildNames", contains("Fast Group"));
  }

  @Test
  void getRouteUsages_referencedByTripDirectlyAndViaStage_shouldListTripOnce() {
    Route route = dataService.createRoute(team1, user1, "Trip Route", Visibility.PUBLIC);
    Trip trip = dataService.createTrip(team1, user1, "Alps Trip", USAGE_TIME);
    dataService.setTripRoute(trip, route);
    TripStage stage = dataService.createTripStage(user1, trip, "Stage 1");
    dataService.setTripStageRoute(stage, route);

    given()
        .when()
        .get(usagesUrl(route))
        .then()
        .statusCode(200)
        .body("usages", hasSize(1))
        .body("usages[0].type", equalTo("TRIP"))
        .body("usages[0].slug", equalTo(trip.getSlug()))
        .body("usages[0].referencedDirectly", equalTo(true))
        .body("usages[0].viaChildNames", contains("Stage 1"));
  }

  /**
   * A trip usage carries the date of its last live stage, so the route page can render the range
   * (docs/LEDGER_*.md API-9); a ride carries none.
   */
  @Test
  void getRouteUsages_trip_carriesItsEndDate_rideDoesNot() {
    Route route = dataService.createRoute(team1, user1, "Range Route", Visibility.PUBLIC);
    Trip trip = dataService.createTrip(team1, user1, "Range Trip", USAGE_TIME);
    dataService.setTripRoute(trip, route);
    Instant lastDay = USAGE_TIME.plus(3, ChronoUnit.DAYS);
    dataService.createTripStage(user1, trip, "Day 1", 0, USAGE_TIME);
    dataService.createTripStage(user1, trip, "Day 4", 1, lastDay);
    TripStage ghost =
        dataService.createTripStage(
            user1, trip, "Deleted Day", 2, lastDay.plus(2, ChronoUnit.DAYS));
    dataService.deleteTripStage(ghost);
    Trip bare = dataService.createTrip(team1, user1, "Bare Trip", USAGE_TIME.minusSeconds(60));
    dataService.setTripRoute(bare, route);
    Ride ride = dataService.createRide(team1, user1, "Range Ride", "range-ride", USAGE_TIME);
    dataService.setRideRoute(ride, route);

    given()
        .when()
        .get(usagesUrl(route))
        .then()
        .statusCode(200)
        .body("usages", hasSize(3))
        .body(
            "usages.find { it.slug == '" + trip.getSlug() + "' }.endDate",
            equalTo(lastDay.toString()))
        .body("usages.find { it.slug == '" + bare.getSlug() + "' }.endDate", nullValue())
        .body("usages.find { it.slug == 'range-ride' }.endDate", nullValue());
  }

  @Test
  void getRouteUsages_softDeletedRide_shouldBeExcluded() {
    Route route = dataService.createRoute(team1, user1, "Deleted Ride Route", Visibility.PUBLIC);
    Ride ride = dataService.createRide(team1, user1, "Doomed Ride", "doomed-ride", USAGE_TIME);
    dataService.setRideRoute(ride, route);
    dataService.deleteRide(ride);

    given().when().get(usagesUrl(route)).then().statusCode(200).body("usages", hasSize(0));
  }

  @Test
  void getRouteUsages_referencedOnlyViaDeletedStage_shouldExcludeTrip() {
    Route route = dataService.createRoute(team1, user1, "Deleted Stage Route", Visibility.PUBLIC);
    Trip trip = dataService.createTrip(team1, user1, "Stage Only Trip", USAGE_TIME);
    TripStage stage = dataService.createTripStage(user1, trip, "Ghost Stage");
    dataService.setTripStageRoute(stage, route);
    dataService.deleteTripStage(stage);

    given().when().get(usagesUrl(route)).then().statusCode(200).body("usages", hasSize(0));
  }

  @Test
  void getRouteUsages_draftRide_shouldBeHiddenFromAnonymousButVisibleToOrganizer() {
    Route route = dataService.createRoute(team1, user1, "Draft Ride Route", Visibility.PUBLIC);
    Ride ride =
        dataService.createRide(team1, user1, "Draft Ride", "draft-ride", USAGE_TIME, Status.DRAFT);
    dataService.setRideRoute(ride, route);

    // Anonymous: a draft usage is not visible
    given().when().get(usagesUrl(route)).then().statusCode(200).body("usages", hasSize(0));

    // Organizer: the draft usage is visible
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .when()
        .get(usagesUrl(route))
        .then()
        .statusCode(200)
        .body("usages", hasSize(1))
        .body("usages[0].slug", equalTo(ride.getSlug()));
  }

  @Test
  void getRouteUsages_teamVisibilityRide_shouldBeHiddenFromNonMemberButVisibleToMember() {
    Route route = dataService.createRoute(team1, user1, "Team Ride Route", Visibility.PUBLIC);
    Ride ride =
        dataService.createRide(team1, user1, "Team Ride", "team-ride", USAGE_TIME, Visibility.TEAM);
    dataService.setRideRoute(ride, route);

    // Non-member: a TEAM-visibility usage is hidden
    given()
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .get(usagesUrl(route))
        .then()
        .statusCode(200)
        .body("usages", hasSize(0));

    // Member: the usage is visible
    given()
        .auth()
        .oauth2(getAccessToken(USER3))
        .when()
        .get(usagesUrl(route))
        .then()
        .statusCode(200)
        .body("usages", hasSize(1));
  }

  @Test
  void getRouteUsages_nonexistentRoute_shouldReturn404() {
    given()
        .when()
        .get("/api/teams/" + team1Slug + "/routes/nonexistent-route/usages")
        .then()
        .statusCode(404);
  }

  @Test
  void getRouteUsages_toNonexistentTeam_shouldReturn404() {
    given()
        .when()
        .get("/api/teams/nonexistent-team/routes/some-route/usages")
        .then()
        .statusCode(404);
  }
}
