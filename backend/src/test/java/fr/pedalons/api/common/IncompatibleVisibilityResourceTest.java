package fr.pedalons.api.common;

import static fr.pedalons.util.WallTimes.wall;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.route.Route;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.rides.request.GroupRequest;
import fr.pedalons.dto.rides.request.RideRequest;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.trips.request.StageRequest;
import fr.pedalons.dto.trips.request.TripRequest;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.ws.rs.core.MediaType;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@code INCOMPATIBLE_VISIBILITY} as a client receives it (docs/LEDGER_*.md API-176, plan §4.4):
 * the typed {@code errorDetails} of a refused ride, the replay with {@code alignVisibility}, and the
 * refused route lowering with its usages, a refused trip and a refused restore. On team1 (public)
 * user1 is admin.
 */
@QuarkusTest
class IncompatibleVisibilityResourceTest extends AbstractResourceTest {

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private static RideRequest ride(String routeSlug, @Nullable Boolean align) {
    return new RideRequest(
        "Open Sunday",
        MediaDto.builder().build(),
        wall(Instant.now().plus(7, ChronoUnit.DAYS)),
        Status.PUBLISHED,
        Visibility.PUBLIC,
        null,
        null,
        null,
        null,
        List.of(GroupRequest.builder().name("Fast").routeSlug(routeSlug).build()),
        null,
        null,
        align);
  }

  @Test
  void aPublicRideOnATeamRoute_isRefusedWithTheRoutes_thenAlignedOnReplay() {
    Route route = dataService.createRoute(team1, user1, "Members Loop", Visibility.TEAM);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(ride(route.getSlug(), null))
        .when()
        .post("/api/teams/" + team1Slug + "/rides")
        .then()
        .statusCode(400)
        .body("code", equalTo("INCOMPATIBLE_VISIBILITY"))
        .body("errorDetails.type", equalTo("INCOMPATIBLE_VISIBILITY"))
        .body("errorDetails.routes", hasSize(1))
        .body("errorDetails.routes[0].slug", equalTo(route.getSlug()))
        .body("errorDetails.routes[0].name", equalTo("Members Loop"))
        .body("errorDetails.routes[0].visibility", equalTo("TEAM"))
        .body("errorDetails.routes[0].proposedVisibility", equalTo("PUBLIC_UNLISTED"))
        .body("errorDetails.usages", empty());
    assertEquals(Visibility.TEAM, dataService.routeVisibility(route));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(ride(route.getSlug(), true))
        .when()
        .post("/api/teams/" + team1Slug + "/rides")
        .then()
        .statusCode(201)
        .body("visibility", equalTo("PUBLIC"));
    assertEquals(Visibility.PUBLIC_UNLISTED, dataService.routeVisibility(route));
  }

  @Test
  void aPublicTripOnATeamStageRoute_isRefusedWithTheRoutes_thenAlignedOnReplay() {
    Route route = dataService.createRoute(team1, user1, "Day One", Visibility.TEAM);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(trip(route.getSlug(), null))
        .when()
        .post("/api/teams/" + team1Slug + "/trips")
        .then()
        .statusCode(400)
        .body("code", equalTo("INCOMPATIBLE_VISIBILITY"))
        .body("errorDetails.type", equalTo("INCOMPATIBLE_VISIBILITY"))
        .body("errorDetails.routes", hasSize(1))
        .body("errorDetails.routes[0].slug", equalTo(route.getSlug()))
        .body("errorDetails.routes[0].visibility", equalTo("TEAM"))
        .body("errorDetails.routes[0].proposedVisibility", equalTo("PUBLIC_UNLISTED"))
        .body("errorDetails.usages", empty());
    assertEquals(Visibility.TEAM, dataService.routeVisibility(route));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(trip(route.getSlug(), true))
        .when()
        .post("/api/teams/" + team1Slug + "/trips")
        .then()
        .statusCode(201)
        .body("visibility", equalTo("PUBLIC"));
    assertEquals(Visibility.PUBLIC_UNLISTED, dataService.routeVisibility(route));
  }

  /** No body to carry alignVisibility: the restore is refused with the routes to raise first. */
  @Test
  void restoringAPublicTripWhoseRouteWentTeam_isRefusedWithTheRoutes() {
    Route route = dataService.createRoute(team1, user1, "Whole Line", Visibility.PUBLIC);
    Trip trip =
        dataService.createTrip(
            team1, user1, "Summer Tour", Instant.now().plus(7, ChronoUnit.DAYS), Visibility.PUBLIC);
    dataService.setTripRoute(trip, route);
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/teams/" + team1Slug + "/trips/" + trip.getSlug())
        .then()
        .statusCode(204);
    dataService.setRouteVisibility(route, Visibility.TEAM);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .when()
        .post("/api/teams/" + team1Slug + "/trips/" + trip.getSlug() + "/undelete")
        .then()
        .statusCode(400)
        .body("code", equalTo("INCOMPATIBLE_VISIBILITY"))
        .body("errorDetails.routes", hasSize(1))
        .body("errorDetails.routes[0].slug", equalTo(route.getSlug()))
        .body("errorDetails.usages", empty());
  }

  private static TripRequest trip(String stageRouteSlug, @Nullable Boolean align) {
    return new TripRequest(
        "Open Tour",
        MediaDto.builder().build(),
        wall(Instant.now().plus(7, ChronoUnit.DAYS)),
        Status.PUBLISHED,
        Visibility.PUBLIC,
        null,
        null,
        List.of(
            StageRequest.builder()
                .name("Day 1")
                .dateTime(wall(Instant.now().plus(7, ChronoUnit.DAYS)))
                .routeSlug(stageRouteSlug)
                .media(MediaDto.builder().build())
                .build()),
        null,
        align);
  }

  @Test
  void loweringARouteUnderAPublicRide_isRefusedWithTheUsages() {
    Route route = dataService.createRoute(team1, user1, "Open Loop", Visibility.PUBLIC);
    Ride ride =
        dataService.createRide(
            team1,
            user1,
            "Sunday",
            "sunday",
            Instant.now().plus(7, ChronoUnit.DAYS),
            Visibility.PUBLIC_UNLISTED);
    dataService.setRideRoute(ride, route);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart(
            "route",
            new RouteRequest(
                "Open Loop", MediaDto.builder().build(), SurfaceType.ROAD, Visibility.TEAM, null),
            MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + route.getSlug())
        .then()
        .statusCode(400)
        .body("code", equalTo("INCOMPATIBLE_VISIBILITY"))
        .body("errorDetails.routes", empty())
        .body("errorDetails.usages", hasSize(1))
        .body("errorDetails.usages[0].type", equalTo("RIDE"))
        .body("errorDetails.usages[0].slug", equalTo("sunday"))
        .body("errorDetails.usages[0].name", equalTo("Sunday"))
        .body("errorDetails.usages[0].visibility", equalTo("PUBLIC_UNLISTED"));
    assertEquals(Visibility.PUBLIC, dataService.routeVisibility(route));

    // The detail says so before the editor even tries.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + route.getSlug())
        .then()
        .statusCode(200)
        .body("permissions.allowedVisibilities", equalTo(List.of("PUBLIC_UNLISTED", "PUBLIC")));
  }
}
