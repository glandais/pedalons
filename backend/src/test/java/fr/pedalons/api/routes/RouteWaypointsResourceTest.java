package fr.pedalons.api.routes;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.GeoPoint;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.routes.request.RouteRequest;
import fr.pedalons.dto.routes.request.WaypointRequest;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.SurfaceType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.enums.WaypointOrigin;
import fr.pedalons.enums.WaypointType;
import fr.pedalons.repository.asset.AssetRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.builder.MultiPartSpecBuilder;
import io.restassured.path.json.config.JsonPathConfig;
import io.restassured.response.Response;
import io.restassured.specification.MultiPartSpecification;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.MediaType;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/**
 * The waypoints of a route: typed, placed on the track and edited as a list (docs/LEDGER_*.md
 * WEB-100, C3c).
 */
@QuarkusTest
class RouteWaypointsResourceTest extends AbstractResourceTest {

  private static final File WAYPOINTS_GPX = new File("src/test/resources/waypoints.gpx");
  private static final File TWO_TRACKS_GPX = new File("src/test/resources/two_tracks.gpx");

  @Inject AssetRepository assetRepository;
  @Inject ObjectMapper objectMapper;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  // ------------------------------------------------------------------ helpers

  private static RouteRequest request(List<WaypointRequest> waypoints, List<GeoPoint> points) {
    return new RouteRequest(
        "Boucle",
        MediaDto.builder().markdown("Parcours").build(),
        SurfaceType.ROAD,
        Visibility.PUBLIC,
        points,
        null,
        null,
        waypoints);
  }

  private static WaypointRequest author(String name, WaypointType type, double lat, double lng) {
    return new WaypointRequest(null, new GeoPoint(lng, lat), type, name, null, null, null);
  }

  /** The route part as UTF-8 bytes: RestAssured would write an accent as "?" in its default charset. */
  private MultiPartSpecification routePart(Object route) {
    byte[] json =
        (route instanceof String text ? text : objectMapper.writeValueAsString(route))
            .getBytes(StandardCharsets.UTF_8);
    return new MultiPartSpecBuilder(json)
        .controlName("route")
        .mimeType(MediaType.APPLICATION_JSON)
        .build();
  }

  private Response create(File gpx, List<WaypointRequest> waypoints) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart(routePart(request(waypoints, null)))
        .multiPart("gpxFile", gpx, "application/gpx+xml")
        .when()
        .post("/api/teams/" + team1Slug + "/routes");
  }

  private String createFromFile() {
    return create(WAYPOINTS_GPX, null).then().statusCode(201).extract().path("slug");
  }

  private Response update(String slug, List<WaypointRequest> waypoints, File gpx) {
    var spec =
        given().auth().oauth2(getAccessToken(USER1)).multiPart(routePart(request(waypoints, null)));
    if (gpx != null) {
      spec = spec.multiPart("gpxFile", gpx, "application/gpx+xml");
    }
    return spec.when().put("/api/teams/" + team1Slug + "/routes/" + slug);
  }

  private Response updateRaw(String slug, String routeJson) {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart(routePart(routeJson))
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + slug);
  }

  private Response get(String slug) {
    return given().when().get("/api/teams/" + team1Slug + "/routes/" + slug);
  }

  /** The waypoints of a route as the API returns them. */
  private List<Map<String, Object>> waypoints(String slug) {
    // Doubles, not RestAssured's default floats: the editor sends the positions back as it got them
    return get(slug)
        .then()
        .statusCode(200)
        .extract()
        .jsonPath()
        .using(new JsonPathConfig(JsonPathConfig.NumberReturnType.DOUBLE))
        .getList("waypoints");
  }

  /** What the editor sends back for the waypoints it received, unchanged. */
  private static List<WaypointRequest> echo(List<Map<String, Object>> received) {
    List<WaypointRequest> list = new ArrayList<>();
    for (Map<String, Object> w : received) {
      @SuppressWarnings("unchecked")
      List<Number> coordinates =
          (List<Number>) ((Map<String, Object>) w.get("geometry")).get("coordinates");
      list.add(
          new WaypointRequest(
              (String) w.get("id"),
              new GeoPoint(coordinates.get(0).doubleValue(), coordinates.get(1).doubleValue()),
              WaypointType.valueOf((String) w.get("type")),
              (String) w.get("name"),
              (String) w.get("description"),
              w.get("distance") == null ? null : ((Number) w.get("distance")).doubleValue(),
              null));
    }
    return list;
  }

  private record AssetState(long fileId, long contentRevision) {}

  private Map<AssetType, AssetState> assets(String slug) {
    Long routeId = TsidUtils.toLong(get(slug).then().extract().path("id"));
    return QuarkusTransaction.requiringNew()
        .call(
            () -> {
              Map<AssetType, AssetState> states = new HashMap<>();
              for (Asset a : assetRepository.list("teamEntity.id = ?1", routeId)) {
                states.put(
                    a.getType(),
                    new AssetState(
                        a.getFileId(),
                        // What the GPS sync fingerprint uses: coalesce(contentRevision, id)
                        a.getContentRevision() != null ? a.getContentRevision() : a.getId()));
              }
              return states;
            });
  }

  private static Map<String, Object> named(List<Map<String, Object>> list, String name) {
    return list.stream().filter(w -> name.equals(w.get("name"))).findFirst().orElseThrow();
  }

  // ------------------------------------------------------------------ create

  @Test
  void createRoute_fromGpx_importsTypedPlacedWaypoints() {
    String slug = createFromFile();

    List<Map<String, Object>> waypoints = waypoints(slug);

    assertEquals(3, waypoints.size());
    assertEquals("WATER", named(waypoints, "Source").get("type"));
    assertEquals("CAFE", named(waypoints, "Café du coin").get("type"));
    assertEquals("INFO", named(waypoints, "Mystère").get("type"));
    for (Map<String, Object> w : waypoints) {
      assertEquals("IMPORTED", w.get("origin"));
      assertTrue(w.get("distance") != null, "on the track: " + w.get("name"));
      assertTrue(w.get("id") != null);
    }
    // By distance along the route
    double previous = -1;
    for (Map<String, Object> w : waypoints) {
      double distance = ((Number) w.get("distance")).doubleValue();
      assertTrue(distance >= previous, "sorted by distance");
      previous = distance;
    }
  }

  @Test
  void createRoute_withList_storesAuthorPoints_ignoresFileWaypoints() {
    String slug =
        create(
                WAYPOINTS_GPX,
                List.of(author("Sommet", WaypointType.SUMMIT, 47.2024271, -1.5456685)))
            .then()
            .statusCode(201)
            .extract()
            .path("slug");

    List<Map<String, Object>> waypoints = waypoints(slug);

    assertEquals(1, waypoints.size(), "the <wpt> of the file are ignored");
    assertEquals("Sommet", waypoints.getFirst().get("name"));
    assertEquals("SUMMIT", waypoints.getFirst().get("type"));
    assertEquals("AUTHOR", waypoints.getFirst().get("origin"));
  }

  // ------------------------------------------------------------------ update, waypoints only

  @Test
  void updateRoute_pointsOnly_keepsTrackAndOriginal_rewritesFilteredAndFit() {
    String slug = createFromFile();
    Map<AssetType, AssetState> before = assets(slug);
    String stateBefore = get(slug).then().extract().path("elevationState");
    List<WaypointRequest> list = new ArrayList<>(echo(waypoints(slug)));
    list.add(author("Toilettes", WaypointType.TOILETS, 47.2024271, -1.5456685));

    update(slug, list, null).then().statusCode(200);

    Map<AssetType, AssetState> after = assets(slug);
    assertEquals(
        before.get(AssetType.ROUTE_ORIGINAL_GPX),
        after.get(AssetType.ROUTE_ORIGINAL_GPX),
        "the original is the track: untouched");
    assertEquals(
        before.get(AssetType.ROUTE_THUMBNAIL_LIGHT), after.get(AssetType.ROUTE_THUMBNAIL_LIGHT));
    assertNotEquals(
        before.get(AssetType.ROUTE_FILTERED_GPX).fileId(),
        after.get(AssetType.ROUTE_FILTERED_GPX).fileId());
    assertTrue(
        after.get(AssetType.ROUTE_FILTERED_GPX).contentRevision()
            > before.get(AssetType.ROUTE_FILTERED_GPX).contentRevision(),
        "GPS sync sends the route again");
    assertNotEquals(
        before.get(AssetType.ROUTE_FIT).fileId(), after.get(AssetType.ROUTE_FIT).fileId());
    assertEquals(stateBefore, get(slug).then().extract().path("elevationState"));
    assertEquals(4, waypoints(slug).size());
  }

  @Test
  void updateRoute_sameList_writesNoFile() {
    String slug = createFromFile();
    Map<AssetType, AssetState> before = assets(slug);

    update(slug, echo(waypoints(slug)), null).then().statusCode(200);

    assertEquals(before, assets(slug), "a save of the same list sends no route to the GPS again");
  }

  @Test
  void updateRoute_listOmitted_leavesWaypoints() {
    String slug = createFromFile();
    List<Map<String, Object>> before = waypoints(slug);

    update(slug, null, null).then().statusCode(200);

    assertEquals(before, waypoints(slug));
  }

  // ------------------------------------------------------------------ update, the track changes

  @Test
  void updateRoute_redraw_keepsAndReanchorsWaypoints_offTrackWhenFar() {
    dataService.setTeamEnableRoutePlanner(team1, true);
    String slug = createFromFile();
    List<Map<String, Object>> before = waypoints(slug);

    // A shorter drawing: it passes by the Source and the Mystère, no longer by the café
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .multiPart(
            "route",
            request(
                null,
                List.of(
                    new GeoPoint(-1.5480203, 47.2059982), new GeoPoint(-1.5462658, 47.2034113))),
            MediaType.APPLICATION_JSON)
        .when()
        .put("/api/teams/" + team1Slug + "/routes/" + slug)
        .then()
        .statusCode(200);

    List<Map<String, Object>> after = waypoints(slug);

    assertEquals(3, after.size());
    assertEquals(
        before.stream().map(w -> w.get("id")).sorted().toList(),
        after.stream().map(w -> w.get("id")).sorted().toList(),
        "the rows are the same ones");
    assertTrue(named(after, "Source").get("distance") != null);
    assertTrue(named(after, "Café du coin").get("distance") == null, "270 m away: off the track");
    assertEquals(
        "Café du coin", after.getLast().get("name"), "off the track, listed after the others");
    assertEquals("CAFE", named(after, "Café du coin").get("type"), "and kept, as typed");
  }

  @Test
  void updateRoute_newFile_replacesImported_keepsAuthor() {
    String slug = createFromFile();
    List<WaypointRequest> list = new ArrayList<>(echo(waypoints(slug)));
    list.add(author("Atelier", WaypointType.BIKE_SHOP, 47.2024271, -1.5456685));
    update(slug, list, null).then().statusCode(200);
    String authorId = (String) named(waypoints(slug), "Atelier").get("id");
    List<Object> importedBefore =
        waypoints(slug).stream()
            .filter(w -> "IMPORTED".equals(w.get("origin")))
            .map(w -> w.get("id"))
            .toList();

    update(slug, null, WAYPOINTS_GPX).then().statusCode(200);

    List<Map<String, Object>> after = waypoints(slug);
    assertEquals(4, after.size(), "the author's one and the file's three");
    assertEquals(authorId, named(after, "Atelier").get("id"));
    assertEquals("AUTHOR", named(after, "Atelier").get("origin"));
    List<Object> importedAfter =
        after.stream()
            .filter(w -> "IMPORTED".equals(w.get("origin")))
            .map(w -> w.get("id"))
            .toList();
    assertEquals(3, importedAfter.size());
    assertTrue(
        importedAfter.stream().noneMatch(importedBefore::contains),
        "the imported ones are the new file's");
  }

  // ------------------------------------------------------------------ validation

  @Test
  void updateRoute_knownIdKeepsOrigin_unknownIdIsAuthor_malformedIdIs400() {
    String slug = createFromFile();
    List<Map<String, Object>> received = waypoints(slug);
    String knownId = (String) named(received, "Source").get("id");
    GeoPoint onTrack = new GeoPoint(-1.5462658, 47.2034113);

    update(
            slug,
            List.of(
                // Claims to be the author's: the stored origin wins
                new WaypointRequest(
                    knownId,
                    onTrack,
                    WaypointType.WATER,
                    "Source",
                    null,
                    null,
                    WaypointOrigin.AUTHOR),
                new WaypointRequest(
                    TsidUtils.toString(1L),
                    onTrack,
                    WaypointType.INFO,
                    "Nouveau",
                    null,
                    null,
                    null)),
            null)
        .then()
        .statusCode(200);

    List<Map<String, Object>> after = waypoints(slug);
    assertEquals(2, after.size());
    assertEquals("IMPORTED", named(after, "Source").get("origin"));
    assertEquals("AUTHOR", named(after, "Nouveau").get("origin"));

    update(
            slug,
            List.of(
                new WaypointRequest(
                    "not an id", onTrack, WaypointType.INFO, "x", null, null, null)),
            null)
        .then()
        .statusCode(400);
    update(
            slug,
            List.of(
                new WaypointRequest(knownId, onTrack, WaypointType.INFO, "x", null, null, null),
                new WaypointRequest(knownId, onTrack, WaypointType.INFO, "y", null, null, null)),
            null)
        .then()
        .statusCode(400);
  }

  @Test
  void updateRoute_tooManyWaypoints_isRejected() {
    String slug = createFromFile();
    List<WaypointRequest> list = new ArrayList<>();
    for (int i = 0; i < 501; i++) {
      list.add(author("p" + i, WaypointType.INFO, 47.2024271, -1.5456685));
    }

    update(slug, list, null).then().statusCode(400);
  }

  @Test
  void updateRoute_nameTooLong_isRejected() {
    String slug = createFromFile();

    update(slug, List.of(author("x".repeat(251), WaypointType.INFO, 47.2024271, -1.5456685)), null)
        .then()
        .statusCode(400);
  }

  @Test
  void updateRoute_unacceptableText_isContentRejected() {
    String slug = createFromFile();

    update(slug, List.of(author("Gros connard", WaypointType.INFO, 47.2024271, -1.5456685)), null)
        .then()
        .statusCode(400)
        .body("code", equalTo("CONTENT_REJECTED"));
  }

  @Test
  void updateRoute_emptyName_isAccepted() {
    String slug = createFromFile();

    update(slug, List.of(author("", WaypointType.WATER, 47.2024271, -1.5456685)), null)
        .then()
        .statusCode(200);

    assertEquals("", waypoints(slug).getFirst().get("name"));
  }

  // ------------------------------------------------------------------ read

  @Test
  void routeDetail_legacyRow_isInfoImported() {
    var route = dataService.createRoute(team1, user1, "Ancien", Visibility.PUBLIC);
    dataService.addWaypoint(route, user1, "Vieux point", 45.0, 6.0);

    given()
        .when()
        .get("/api/teams/" + team1Slug + "/routes/" + route.getSlug())
        .then()
        .statusCode(200)
        .body("waypoints", hasSize(1))
        .body("waypoints[0].name", equalTo("Vieux point"))
        .body("waypoints[0].type", equalTo("INFO"))
        .body("waypoints[0].origin", equalTo("IMPORTED"))
        .body("waypoints[0]", not(hasKey("distance")));
  }

  @Test
  void tracksAreReturnedInIdOrder() {
    String slug = create(TWO_TRACKS_GPX, null).then().statusCode(201).extract().path("slug");

    get(slug)
        .then()
        .statusCode(200)
        .body("tracks", hasSize(2))
        // The track DTO carries no name: the files tell them apart by where they start
        // ("Première partie" near lon -1.58, "Seconde partie" near lon -0.92)
        .body("tracks[0].line.coordinates[0][0]", lessThan(-1.0f))
        .body("tracks[1].line.coordinates[0][0]", greaterThan(-1.0f));
  }
}
