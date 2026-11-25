package fr.pedalons.api.routes;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.place.Place;
import fr.pedalons.domain.route.NetworkEdgesDocument;
import fr.pedalons.infrastructure.routedetails.FakeRouteDetailsClient;
import fr.pedalons.infrastructure.routedetails.FakeRouteGeneratorGateway;
import fr.pedalons.infrastructure.routedetails.FakeRouteGeneratorGateway.Problem;
import fr.pedalons.infrastructure.routedetails.RouteDetailsCapabilities;
import fr.pedalons.service.route.network.RouteGeneratorGuard;
import fr.pedalons.util.NetworkEdgesFixtures;
import fr.pedalons.util.NetworkEdgesSeeder;
import fr.pedalons.util.NetworkEdgesSeeder.Seeded;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * {@code GET} and {@code POST /api/teams/{slug}/routes/{route}/retouch} (docs/LEDGER_*.md API-212,
 * docs/plans/2026-11-24-retouche-parcours-lot7c.md): the engine is faked at the level of the HTTP
 * message, so the body it receives (the raw track, the stored document copied as it is), the
 * problems it answers and what the backend makes of them are real. Synthetic coordinates only.
 *
 * <p>The saved route is an out and back of 33 km north of 47.0, 500 m between points.
 */
@QuarkusTest
class RouteRetouchResourceTest extends AbstractResourceTest {

  private static final ObjectMapper JSON = new ObjectMapper();
  private static final double M_PER_DEG = 111_195;

  @Inject NetworkEdgesSeeder seeder;
  @Inject RouteGeneratorGuard guard;
  @Inject EntityManager em;

  private Seeded route;
  private String routeSlug;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    guard.clear();
    FakeRouteGeneratorGateway.reset();
    FakeRouteDetailsClient.reset();
    FakeRouteGeneratorGateway.editEnabled = true;
    dataService.setTeamEnableRoutePlanner(team1, true);
    route = seedRoute("Out and back", true);
    routeSlug = route.route().getSlug();
  }

  @AfterEach
  void restore() {
    FakeRouteGeneratorGateway.reset();
    FakeRouteDetailsClient.reset();
  }

  /** A route with its document (current) and, when asked, its raw line. */
  private Seeded seedRoute(String name, boolean raw) {
    Seeded s = seeder.seedWalk(team1, user1, name, new int[] {0, 0}, new int[] {1, 0});
    if (raw) {
      setRaw(s.trackId(), outAndBackWkt());
    }
    return s;
  }

  private void setRaw(long trackId, String wkt) {
    seeder.sql(
        "update gpx_tracks set raw_geometry = ST_GeomFromText(?1, 4326) where id = ?2",
        wkt,
        trackId);
  }

  private static String outAndBackWkt() {
    StringBuilder sb = new StringBuilder("LINESTRING(");
    int n = 37; // 36 steps of 0.0045 degrees = 18 km up, the same back
    for (int i = 0; i < n; i++) {
      sb.append(i == 0 ? "" : ",").append("-1.5 ").append(47.0 + i * 0.0045);
    }
    for (int i = n - 2; i >= 0; i--) {
      sb.append(",-1.49 ").append(47.0 + i * 0.0045);
    }
    return sb.append(")").toString();
  }

  private ValidatableResponse offer(String user, String slug) {
    var spec = given();
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.when().get("/api/teams/" + team1Slug + "/routes/" + slug + "/retouch").then();
  }

  private ValidatableResponse retouchIn(
      String teamSlug, String user, String slug, Map<String, Object> body) {
    var spec = given().contentType(ContentType.JSON).body(body);
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.when().post("/api/teams/" + teamSlug + "/routes/" + slug + "/retouch").then();
  }

  private ValidatableResponse offerIn(String teamSlug, String user, String slug) {
    var spec = given();
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.when().get("/api/teams/" + teamSlug + "/routes/" + slug + "/retouch").then();
  }

  /** Neither a read of the route nor an offer: the answer is a refusal or an unavailable offer. */
  private void assertShutOut(String teamSlug, String user, String slug) {
    int post = retouchIn(teamSlug, user, slug, resize(30)).extract().statusCode();
    assertTrue(post == 401 || post == 403 || post == 404, "POST answered " + post);
    var get = offerIn(teamSlug, user, slug).extract();
    assertTrue(
        get.statusCode() == 401
            || get.statusCode() == 403
            || get.statusCode() == 404
            || !get.jsonPath().getBoolean("available"),
        "GET answered " + get.statusCode());
    assertTrue(FakeRouteGeneratorGateway.EDITS.isEmpty());
  }

  private ValidatableResponse retouch(String user, String slug, Map<String, Object> body) {
    var spec = given().contentType(ContentType.JSON).body(body);
    if (user != null) {
      spec = spec.auth().oauth2(getAccessToken(user));
    }
    return spec.when().post("/api/teams/" + team1Slug + "/routes/" + slug + "/retouch").then();
  }

  private static Map<String, Object> resize(double km) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("targetDistanceKm", km);
    return body;
  }

  private static Map<String, Object> moveEnd(double lat, double lng) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("end", Map.of("point", Map.of("lat", lat, "lng", lng)));
    return body;
  }

  private double originalKm() {
    return offerLength() / 1000;
  }

  private double offerLength() {
    return offer(USER1, routeSlug).extract().jsonPath().getDouble("originalDistanceM");
  }

  // ---------------------------------------------------------------- the offer

  @Test
  void theOfferGivesTheBoundsFromTheCapabilities() {
    double length = offerLength();
    assertEquals(2 * 36 * 0.0045 * M_PER_DEG, length, length * 0.02);
    offer(USER2, routeSlug)
        .statusCode(200)
        .body("available", equalTo(true))
        .body("operations", equalTo(List.of("RESIZE", "MOVE_END")))
        .body("maxChangeShare", equalTo(0.3f))
        .body("minChangeKm", equalTo(1.0f))
        .body("endSnapM", equalTo(500.0f))
        .body("proposalsMax", equalTo(3))
        .body("rideType", equalTo("ROAD"))
        .body("unavailableReason", nullValue());
    var json = offer(USER2, routeSlug).extract().jsonPath();
    double min = json.getDouble("minDistanceKm");
    double max = json.getDouble("maxDistanceKm");
    // Rounded inwards to the tenth: inside the engine's own bounds
    assertTrue(min >= length * 0.7 / 1000 && min - length * 0.7 / 1000 < 0.1 + 1e-9);
    assertTrue(max <= length * 1.3 / 1000 && length * 1.3 / 1000 - max < 0.1 + 1e-9);
  }

  @Test
  void theOfferIsNotAllowedWithoutTheRightsOfThePlanner() {
    offer(null, routeSlug).statusCode(401);
    offer(USER3, routeSlug)
        .statusCode(200)
        .body("available", equalTo(false))
        .body("unavailableReason", equalTo("NOT_ALLOWED"))
        .body("operations", hasSize(0));
    offer(USER4, routeSlug).statusCode(200).body("unavailableReason", equalTo("NOT_ALLOWED"));
    dataService.setTeamEnableRoutePlanner(team1, false);
    offer(USER2, routeSlug).statusCode(200).body("unavailableReason", equalTo("NOT_ALLOWED"));
    offer(USER2, "no-such-route").statusCode(404);
  }

  @Test
  void anEngineThatCannotEditOffersNothingAndIsNeverCalled() {
    FakeRouteGeneratorGateway.editEnabled = false;
    offer(USER2, routeSlug)
        .statusCode(200)
        .body("unavailableReason", equalTo("ENGINE_UNAVAILABLE"));
    retouch(USER2, routeSlug, resize(30))
        .statusCode(503)
        .body("code", equalTo("GENERATOR_UNAVAILABLE"));
    assertTrue(FakeRouteGeneratorGateway.EDITS.isEmpty());
  }

  @Test
  void anEngineThatOffersOneOperationOnlyIsHonoured() {
    FakeRouteGeneratorGateway.editInfo =
        new RouteDetailsCapabilities.EditInfo(
            List.of("move_end"), List.of("road"), 0.3, 1000, 0.05, 500, 3, 50_000, 4_000_000);
    offer(USER2, routeSlug).body("operations", equalTo(List.of("MOVE_END")));
    retouch(USER2, routeSlug, resize(30)).statusCode(503);
    FakeRouteGeneratorGateway.editInfo =
        new RouteDetailsCapabilities.EditInfo(
            List.of("resize", "move_end"),
            List.of("gravel"),
            0.3,
            1000,
            0.05,
            500,
            3,
            50_000,
            4_000_000);
    offer(USER2, routeSlug).body("unavailableReason", equalTo("ENGINE_UNAVAILABLE"));
  }

  @Test
  void anOfferWithNoValidTargetDoesNotAnnounceResize() {
    // 36 km route: a change of at least 1 km is possible, but the engine's minimum change is
    // above what the share allows (30 % of 36 km = 10.8 km) -> ask for more than that
    FakeRouteGeneratorGateway.editInfo =
        new RouteDetailsCapabilities.EditInfo(
            List.of("resize", "move_end"),
            List.of("road"),
            0.3,
            20_000,
            0.05,
            500,
            3,
            50_000,
            4_000_000);
    offer(USER2, routeSlug).body("operations", equalTo(List.of("MOVE_END")));
  }

  @Test
  void aDocumentTooBigForTheEnginesBodyIsUnsupportedFromTheOffer() {
    FakeRouteGeneratorGateway.editInfo =
        new RouteDetailsCapabilities.EditInfo(
            List.of("resize", "move_end"), List.of("road"), 0.3, 1000, 0.05, 500, 3, 50_000, 1_000);
    offer(USER2, routeSlug).body("unavailableReason", equalTo("UNSUPPORTED"));
  }

  @Test
  void aDocumentThatIsNotCurrentIsNotReadyAndNothingIsComputed() {
    // no document at all
    Seeded none = seeder.seedPending(team1, user1, "No document");
    setRaw(none.trackId(), outAndBackWkt());
    offer(USER2, none.route().getSlug()).body("unavailableReason", equalTo("NOT_READY"));
    retouch(USER2, none.route().getSlug(), resize(30))
        .statusCode(400)
        .body("code", equalTo("ROUTE_RETOUCH_NOT_READY"));
    // a document of an older original: the track was replaced since
    Seeded old = seeder.seedPending(team1, user1, "Old document");
    setRaw(old.trackId(), outAndBackWkt());
    seeder.write(
        old.trackId(),
        NetworkEdgesFixtures.walk(old.rev() - 1, new int[] {0, 0}, new int[] {1, 0}));
    offer(USER2, old.route().getSlug()).body("unavailableReason", equalTo("NOT_READY"));
    // a document of an older shape
    Seeded shape = seeder.seedPending(team1, user1, "Old shape");
    setRaw(shape.trackId(), outAndBackWkt());
    seeder.write(
        shape.trackId(),
        NetworkEdgesFixtures.walk(shape.rev(), new int[] {0, 0}, new int[] {1, 0}));
    seeder.sql(
        "update gpx_tracks set network_edges = jsonb_set(network_edges, '{v}', '0') where id = ?1",
        shape.trackId());
    offer(USER2, shape.route().getSlug()).body("unavailableReason", equalTo("NOT_READY"));
    // no raw line yet (the backfill has not reached it)
    Seeded noRaw = seedRoute("No raw", false);
    offer(USER2, noRaw.route().getSlug()).body("unavailableReason", equalTo("NOT_READY"));
    assertTrue(FakeRouteGeneratorGateway.EDITS.isEmpty());
  }

  @Test
  void aRouteTheEngineCannotTakeIsUnsupported() {
    // too short to have edges
    Seeded tiny = seedRoute("Tiny", true);
    NetworkEdgesDocument ok =
        NetworkEdgesFixtures.walk(tiny.rev(), new int[] {0, 0}, new int[] {1, 0});
    seeder.write(
        tiny.trackId(),
        new NetworkEdgesDocument(
            ok.v(),
            ok.rev(),
            ok.at(),
            NetworkEdgesDocument.STATUS_TOO_SHORT,
            ok.api(),
            ok.rules(),
            ok.profile(),
            ok.dv(),
            ok.len(),
            ok.nodes(),
            ok.edges(),
            ok.unmatched(),
            ok.covered()));
    offer(USER2, tiny.route().getSlug()).body("unavailableReason", equalTo("UNSUPPORTED"));
    retouch(USER2, tiny.route().getSlug(), resize(30))
        .statusCode(400)
        .body("code", equalTo("ROUTE_RETOUCH_UNSUPPORTED"));
    // more points than the engine takes
    FakeRouteGeneratorGateway.editInfo =
        new RouteDetailsCapabilities.EditInfo(
            List.of("resize", "move_end"), List.of("road"), 0.3, 1000, 0.05, 500, 3, 10, 4_000_000);
    offer(USER2, routeSlug).body("unavailableReason", equalTo("UNSUPPORTED"));
    retouch(USER2, routeSlug, resize(30)).body("code", equalTo("ROUTE_RETOUCH_UNSUPPORTED"));
    assertTrue(FakeRouteGeneratorGateway.EDITS.isEmpty());
  }

  // ---------------------------------------------------------------- validation and rights

  @Test
  void rights() {
    retouch(null, routeSlug, resize(30)).statusCode(401);
    retouch(USER3, routeSlug, resize(30)).statusCode(403);
    retouch(USER4, routeSlug, resize(30)).statusCode(403);
    retouch(USER2, "no-such-route", resize(30)).statusCode(404);
    dataService.setTeamEnableRoutePlanner(team1, false);
    retouch(USER2, routeSlug, resize(30)).body("code", equalTo("ROUTE_PLANNER_DISABLED"));
    assertTrue(FakeRouteGeneratorGateway.EDITS.isEmpty());
  }

  @Test
  void aRouteOfAnotherTeamIsNotReachedThroughThisOnesPath() {
    Seeded elsewhere =
        seeder.seedWalk(team2, user1, "Other team", new int[] {0, 0}, new int[] {1, 0});
    setRaw(elsewhere.trackId(), outAndBackWkt());
    String slug = elsewhere.route().getSlug();
    retouchIn(team1Slug, USER1, slug, resize(30)).statusCode(404);
    offerIn(team1Slug, USER1, slug).statusCode(404);
    retouchIn(team1Slug, USER2, slug, resize(30)).statusCode(404);
    assertTrue(FakeRouteGeneratorGateway.EDITS.isEmpty());
  }

  @Test
  void aDeletedRouteIsNotRetouched() {
    seeder.sql("update team_entities set deleted = true where id = ?1", route.route().getId());
    for (String user : List.of(USER1, USER2)) {
      int post = retouch(user, routeSlug, resize(30)).extract().statusCode();
      assertTrue(post == 400 || post == 404, "POST answered " + post);
      var get = offer(user, routeSlug).extract();
      assertTrue(get.statusCode() == 404 || !get.jsonPath().getBoolean("available"));
    }
    assertTrue(FakeRouteGeneratorGateway.EDITS.isEmpty());
  }

  @Test
  void aTeamOnlyRouteIsShutToANonMemberAndToTheAnonymous() {
    Seeded priv = seeder.seedWalk(team2, user1, "Team only", new int[] {0, 0}, new int[] {1, 0});
    setRaw(priv.trackId(), outAndBackWkt());
    seeder.sql("update team_entities set visibility = 'TEAM' where id = ?1", priv.route().getId());
    String slug = priv.route().getSlug();
    assertShutOut(team2Slug, null, slug);
    assertShutOut(team2Slug, USER5, slug);
  }

  @Test
  void aRoutePublishedByLinkInAPrivateTeamIsReadNotRetouchedByANonMember() {
    Seeded linked = seeder.seedWalk(team2, user1, "By link", new int[] {0, 0}, new int[] {1, 0});
    setRaw(linked.trackId(), outAndBackWkt());
    seeder.sql(
        "update team_entities set visibility = 'PUBLIC_UNLISTED' where id = ?1",
        linked.route().getId());
    String slug = linked.route().getSlug();
    assertShutOut(team2Slug, null, slug);
    assertShutOut(team2Slug, USER5, slug);
  }

  @Test
  void exactlyOneOfTheDistanceAndTheEnd() {
    retouch(USER2, routeSlug, new LinkedHashMap<>())
        .statusCode(400)
        .body("code", equalTo("VALIDATION"))
        .body("errorDetails.fieldErrors[0].field", equalTo("targetDistanceKm"));
    Map<String, Object> both = resize(30);
    both.put("end", Map.of("point", Map.of("lat", 47.0, "lng", -1.5)));
    retouch(USER2, routeSlug, both).statusCode(400).body("code", equalTo("VALIDATION"));
    retouch(USER2, routeSlug, Map.of("end", Map.of()))
        .statusCode(400)
        .body("errorDetails.fieldErrors[0].field", equalTo("end"));
    retouch(
            USER2,
            routeSlug,
            Map.of("end", Map.of("point", Map.of("lat", 47.0, "lng", -1.5), "placeId", "x")))
        .statusCode(400)
        .body("errorDetails.fieldErrors[0].field", equalTo("end"));
    assertTrue(FakeRouteGeneratorGateway.EDITS.isEmpty());
  }

  @Test
  void aPlaceOfAnotherTeamOrAnUnreadablePlaceIsInvalid() {
    Place elsewhere = dataService.createPlaceAt(team2, user1, "Elsewhere", 47.1, -1.5);
    retouch(
            USER2,
            routeSlug,
            Map.of("end", Map.of("placeId", TsidUtils.toString(elsewhere.getId()))))
        .statusCode(400)
        .body("code", equalTo("VALIDATION"))
        .body("errorDetails.fieldErrors[0].field", equalTo("end.placeId"));
    retouch(USER2, routeSlug, Map.of("end", Map.of("placeId", "not a tsid!")))
        .statusCode(400)
        .body("errorDetails.fieldErrors[0].field", equalTo("end.placeId"));
    assertTrue(FakeRouteGeneratorGateway.EDITS.isEmpty());
  }

  @Test
  void theBoundsAreJudgedBeforeTheEngineAndTheWindowIsNotDrawnOn() {
    double km = originalKm();
    retouch(USER2, routeSlug, resize(km * 1.4))
        .statusCode(400)
        .body("code", equalTo("ROUTE_RETOUCH_CHANGE_TOO_LARGE"));
    retouch(USER2, routeSlug, resize(km * 0.6))
        .body("code", equalTo("ROUTE_RETOUCH_CHANGE_TOO_LARGE"));
    retouch(USER2, routeSlug, resize(km + 0.5))
        .body("code", equalTo("ROUTE_RETOUCH_CHANGE_TOO_SMALL"));
    assertTrue(FakeRouteGeneratorGateway.EDITS.isEmpty());
    // forty refusals did not use up the window of thirty
    for (int i = 0; i < 40; i++) {
      retouch(USER2, routeSlug, resize(km * 1.4)).statusCode(400);
    }
    retouch(USER2, routeSlug, resize(km * 1.1)).statusCode(200);
  }

  // ---------------------------------------------------------------- what is sent, what comes back

  @Test
  void lengtheningSendsTheRawTrackAndTheStoredDocumentAsItIs() throws Exception {
    double km = originalKm();
    var json =
        retouch(USER2, routeSlug, resize(km * 1.1))
            .statusCode(200)
            .body("operation", equalTo("RESIZE"))
            .body("candidates", hasSize(2))
            .body("candidates[0].kind", equalTo("LENGTHEN"))
            .body("originalAscentM", notNullValue())
            .extract()
            .jsonPath();
    assertEquals(km * 1.1 * 1000, json.getDouble("targetDistanceM"), 0.01);
    double distance = json.getDouble("candidates[0].distanceM");
    assertEquals(km * 1.1 * 1000, distance, km * 1.1 * 1000 * 0.01);
    int start = json.getInt("candidates[0].changed.startIndex");
    int end = json.getInt("candidates[0].changed.endIndex");
    assertTrue(start < end);
    assertTrue(json.getDouble("candidates[0].keptShare") > 0.9);

    assertEquals(1, FakeRouteGeneratorGateway.EDITS.size());
    String sent = FakeRouteGeneratorGateway.EDITS.getFirst();
    JsonNode body = JSON.readTree(sent);
    assertEquals("road", body.get("ride_type").asString());
    assertEquals(0.25, body.get("cursor").asDouble(), 1e-9);
    assertEquals(0, body.get("seed").asLong());
    assertTrue(body.get("operation").has("resize"));
    assertFalse(body.get("operation").has("move_end"));
    assertEquals(
        km * 1.1 * 1000, body.get("operation").get("resize").get("distance_m").asDouble(), 1e-6);
    // the raw track: 73 points
    assertEquals(
        73,
        fr.pedalons.infrastructure.valhalla.Polyline6Decoder.decode(body.get("polyline").asString())
            .size());
    // the document, byte for byte as the database prints it
    String stored =
        QuarkusTransaction.requiringNew()
            .call(() ->
                (String)
                    em.createNativeQuery("select network_edges::text from gpx_tracks where id = ?1")
                        .setParameter(1, route.trackId())
                        .getSingleResult());
    assertTrue(sent.contains("\"network_edges\":" + stored), "the document is copied as it is");
    var headers = FakeRouteGeneratorGateway.EDIT_HEADERS.getFirst();
    assertEquals(FakeRouteGeneratorGateway.TEST_KEY, headers.get("Ord-Namespace-Key"));
    assertEquals(TsidUtils.toString(team1.getId()), headers.get("Ord-Team"));
  }

  @Test
  void shorteningAnOutAndBackCutsItsTip() {
    double km = originalKm();
    retouch(USER2, routeSlug, resize(km * 0.8))
        .statusCode(200)
        .body("candidates[0].kind", equalTo("SHORTEN"))
        .body("candidates[0].changed.newM", notNullValue());
  }

  @Test
  void movingTheEndByAPointAndByAPlace() throws Exception {
    retouch(USER2, routeSlug, moveEnd(47.05, -1.4))
        .statusCode(200)
        .body("operation", equalTo("MOVE_END"))
        .body("targetDistanceM", nullValue())
        .body("candidates[0].kind", equalTo("MOVE_END"))
        .body("candidates[0].variant", equalTo("BEST"))
        .body("candidates[0].endSnapM", notNullValue());
    JsonNode first = JSON.readTree(FakeRouteGeneratorGateway.EDITS.getFirst());
    assertTrue(first.get("operation").has("move_end"));
    assertFalse(first.get("operation").has("resize"));
    assertEquals(
        47.05, first.get("operation").get("move_end").get("point").get("lat").asDouble(), 1e-9);

    Place place = dataService.createPlaceAt(team1, user1, "Cafe", 47.06, -1.41);
    retouch(USER2, routeSlug, Map.of("end", Map.of("placeId", TsidUtils.toString(place.getId()))))
        .statusCode(200);
    JsonNode second = JSON.readTree(FakeRouteGeneratorGateway.EDITS.get(1));
    var point = second.get("operation").get("move_end").get("point");
    assertEquals(47.06, point.get("lat").asDouble(), 1e-6);
    assertEquals(-1.41, point.get("lon").asDouble(), 1e-6);
  }

  @Test
  void theTypeAndTheSeedAndTheCursorAreForwarded() throws Exception {
    Map<String, Object> body = resize(originalKm() * 1.1);
    body.put("seed", 7);
    body.put("discovery", 0.6);
    retouch(USER2, routeSlug, body).statusCode(200);
    JsonNode sent = JSON.readTree(FakeRouteGeneratorGateway.EDITS.getFirst());
    assertEquals(7, sent.get("seed").asLong());
    assertEquals(0.6, sent.get("cursor").asDouble(), 1e-9);
    // a mixed route is asked as gravel, a mountain bike route as mtb
    seeder.sql(
        "update team_entities set surface_type = 'MIXED' where id = ?1", route.route().getId());
    offer(USER2, routeSlug).body("rideType", equalTo("GRAVEL"));
    retouch(USER2, routeSlug, resize(originalKm() * 1.1)).statusCode(200);
    assertEquals(
        "gravel",
        JSON.readTree(FakeRouteGeneratorGateway.EDITS.get(1)).get("ride_type").asString());
    seeder.sql(
        "update team_entities set surface_type = 'MTB' where id = ?1", route.route().getId());
    retouch(USER2, routeSlug, resize(originalKm() * 1.1)).statusCode(200);
    assertEquals(
        "mtb", JSON.readTree(FakeRouteGeneratorGateway.EDITS.get(2)).get("ride_type").asString());
  }

  @Test
  void theWindowIsTheGeneratorsOwn() {
    Map<String, Object> generate = new LinkedHashMap<>();
    generate.put("start", Map.of("lng", -1.5, "lat", 47.2));
    generate.put("distanceKm", 40);
    generate.put("discovery", 1);
    for (int i = 0; i < 30; i++) {
      given()
          .auth()
          .oauth2(getAccessToken(USER2))
          .contentType(ContentType.JSON)
          .body(generate)
          .post("/api/teams/" + team1Slug + "/route-generator")
          .then()
          .statusCode(200);
    }
    retouch(USER2, routeSlug, resize(originalKm() * 1.1))
        .statusCode(429)
        .header("Retry-After", notNullValue())
        .body("code", equalTo("ROUTE_GENERATOR_RATE_LIMITED"));
    assertTrue(FakeRouteGeneratorGateway.EDITS.isEmpty());
    // and the other way round
    guard.clear();
    for (int i = 0; i < 30; i++) {
      retouch(USER2, routeSlug, resize(originalKm() * 1.1)).statusCode(200);
    }
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType(ContentType.JSON)
        .body(generate)
        .post("/api/teams/" + team1Slug + "/route-generator")
        .then()
        .statusCode(429);
  }

  // ---------------------------------------------------------------- what the engine refuses

  private void refusal(String reason, Map<String, Object> request, String code) {
    // every refused request counts in the caller's window: one window per reason
    guard.clear();
    FakeRouteGeneratorGateway.EDIT_PROBLEMS.add(
        new Problem(422, "generation_failed", reason, null, null));
    retouch(USER2, routeSlug, request)
        .statusCode(reason.equals("never") ? 200 : 400)
        .body("code", equalTo(code));
  }

  @Test
  void everyReasonOfTheEngineHasItsCode() {
    double km = originalKm();
    Map<String, Object> shorter = resize(km * 0.8);
    Map<String, Object> longer = resize(km * 1.2);
    Map<String, Object> move = moveEnd(47.05, -1.4);
    // shortening: whatever the reason, no shorter route is a normal answer
    for (String reason :
        List.of(
            "no_economy",
            "no_window",
            "no_candidate",
            "checker_rejected",
            "off_target",
            "budget",
            "no_seam",
            "junction_cut",
            "end_unreachable",
            "something_new")) {
      refusal(reason, shorter, "ROUTE_RETOUCH_NO_SHORTER");
    }
    refusal("order_anomaly", shorter, "ROUTE_RETOUCH_ORDER_ANOMALY");
    refusal("change_too_small", shorter, "ROUTE_RETOUCH_CHANGE_TOO_SMALL");
    refusal("change_too_large", shorter, "ROUTE_RETOUCH_CHANGE_TOO_LARGE");
    refusal("route_not_matched", shorter, "ROUTE_RETOUCH_UNSUPPORTED");
    refusal("route_mismatch", shorter, "ROUTE_RETOUCH_UNSUPPORTED");
    refusal("route_off_coverage", shorter, "GENERATOR_OUT_OF_COVERAGE");
    // lengthening and moving the end
    for (String reason :
        List.of("no_window", "no_candidate", "checker_rejected", "off_target", "budget")) {
      refusal(reason, longer, "ROUTE_RETOUCH_NO_PROPOSAL");
      refusal(reason, move, "ROUTE_RETOUCH_NO_PROPOSAL");
    }
    refusal("no_economy", longer, "ROUTE_RETOUCH_NO_SHORTER");
    refusal("no_seam", longer, "ROUTE_RETOUCH_UNSUPPORTED");
    refusal("end_unreachable", move, "ROUTE_RETOUCH_END_UNREACHABLE");
    refusal("junction_cut", move, "ROUTE_RETOUCH_END_UNREACHABLE");
    refusal("end_too_far", move, "GENERATOR_END_TOO_FAR");
    refusal("order_anomaly", move, "ROUTE_RETOUCH_ORDER_ANOMALY");
  }

  @Test
  void theEnginesOtherAnswers() {
    Map<String, Object> request = resize(originalKm() * 1.2);
    FakeRouteGeneratorGateway.EDIT_PROBLEMS.add(
        new Problem(422, "out_of_coverage", null, null, null));
    retouch(USER2, routeSlug, request)
        .statusCode(400)
        .body("code", equalTo("GENERATOR_OUT_OF_COVERAGE"));
    FakeRouteGeneratorGateway.EDIT_PROBLEMS.add(new Problem(503, "overloaded", null, null, 3));
    retouch(USER2, routeSlug, request)
        .statusCode(503)
        .body("code", equalTo("ROUTE_GENERATOR_BUSY"));
    FakeRouteGeneratorGateway.EDIT_PROBLEMS.add(
        new Problem(503, "data_unavailable", null, null, null));
    retouch(USER2, routeSlug, request)
        .statusCode(503)
        .body("code", equalTo("GENERATOR_UNAVAILABLE"));
    // A body or a document the engine refuses is refused again: not a breakdown to retry
    FakeRouteGeneratorGateway.EDIT_PROBLEMS.add(
        new Problem(400, "invalid_input", null, null, null));
    retouch(USER2, routeSlug, request)
        .statusCode(400)
        .body("code", equalTo("ROUTE_RETOUCH_UNSUPPORTED"));
    FakeRouteGeneratorGateway.EDIT_PROBLEMS.add(
        new Problem(413, "route_too_large", null, null, null));
    retouch(USER2, routeSlug, request)
        .statusCode(400)
        .body("code", equalTo("ROUTE_RETOUCH_UNSUPPORTED"));
  }

  @Test
  void proposalsThatFailTheSanityCheckAreDropped() {
    // the detour jumps 15 km inside the new stretch
    FakeRouteGeneratorGateway.editTamper =
        r -> r.put("distance_m", r.get("distance_m").asDouble() * 2);
    retouch(USER2, routeSlug, resize(originalKm() * 1.2))
        .statusCode(400)
        .body("code", equalTo("ROUTE_RETOUCH_NO_PROPOSAL"));
    retouch(USER2, routeSlug, resize(originalKm() * 0.8))
        .statusCode(400)
        .body("code", equalTo("ROUTE_RETOUCH_NO_SHORTER"));
    // indices outside the polyline
    FakeRouteGeneratorGateway.editTamper =
        r ->
            ((tools.jackson.databind.node.ObjectNode) r.get("changed"))
                .putArray("points")
                .add(5)
                .add(5000);
    retouch(USER2, routeSlug, resize(originalKm() * 1.2))
        .body("code", equalTo("ROUTE_RETOUCH_NO_PROPOSAL"));
  }

  @Test
  void theResponseNamesNoMember() {
    String body =
        retouch(USER2, routeSlug, resize(originalKm() * 1.1)).statusCode(200).extract().asString();
    assertFalse(body.contains("createdBy"));
    assertFalse(body.contains("avatar"));
    assertFalse(body.contains(user1.getEmail()));
    assertFalse(body.contains("user2@"));
  }
}
