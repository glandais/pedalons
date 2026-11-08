package fr.pedalons.api.config;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The cartography settings {@code GET /api/config} now serves, so the clients stop hard-coding them.
 *
 * <p>{@code /api/config} is {@code @PermitAll}: an anonymous visitor must get the map settings too,
 * or the landing page cannot draw a map before login.
 */
@QuarkusTest
class ConfigMapSettingsTest extends AbstractResourceTest {

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  @Test
  void getConfig_shouldServeTheBasemapsInSwitcherOrder() {
    given()
        .when()
        .get("/api/config")
        .then()
        .statusCode(200)
        .body("mapStyles", not(empty()))
        .body("mapStyles[0].id", not(emptyOrNullString()))
        .body("mapStyles[0].label", not(emptyOrNullString()))
        .body("mapStyles[0].url", startsWith("http"))
        // The first style is the light default and declares its dark counterpart, which is the
        // whole point of the field: the app switches theme without a second round-trip.
        .body("mapStyles[0].darkVariant", startsWith("http"));
  }

  @Test
  void getConfig_shouldGroupTheBasemapsForTheSwitcher() {
    // Every style names its section, so a client can render headings without a table of its own.
    given()
        .when()
        .get("/api/config")
        .then()
        .statusCode(200)
        .body("mapStyles.group", everyItem(not(emptyOrNullString())))
        .body("mapStyles.group", hasItems("vector", "satellite", "raster"));
  }

  @Test
  void getConfig_shouldPointRasterBasemapsAtTheGeneratedStyleEndpoint() {
    // A raster provider serves tiles and no style.json — the server wraps it, and that is what
    // lets a client which only knows how to take a style URL render a satellite or OSM fond.
    given()
        .when()
        .get("/api/config")
        .then()
        .statusCode(200)
        .body("mapStyles.find { it.id == 'osm' }.url", endsWith("/api/map/styles/osm.json"))
        .body("mapStyles.find { it.id == 'osm' }.url", startsWith("http"))
        // A raster basemap is an aerial or a printed map: it has no night rendering to switch to.
        .body("mapStyles.find { it.id == 'osm' }.darkVariant", is(nullValue()));
  }

  @Test
  void getConfig_shouldCarryTheAttributionOnlyWhereTheStyleDocumentHasNone() {
    // `attribution` is ADDITIVE: a client shows it on top of what the map engine reads from the
    // style document. Filling it in for a provider that already credits itself would double the
    // credit on every map — so the invariant worth guarding is not "it is set" but "it is set
    // exactly where the document is silent".
    //
    // IGN's PLAN.IGN/standard.json declares no attribution at all, and neither does the TMS
    // metadata.json it points at: without this field that basemap renders uncredited.
    given()
        .when()
        .get("/api/config")
        .then()
        .statusCode(200)
        .body("mapStyles.find { it.id == 'ign-vector' }.attribution", containsString("IGN"))
        // The cycling style puts "© OpenStreetMap contributors" on its own source; a second copy
        // here
        // would show twice, since deduplication would need a byte-for-byte match on a string a
        // third party owns.
        .body("mapStyles.find { it.id == 'cycling' }.attribution", is(nullValue()))
        // Same for a raster basemap: its credit is on the source of the wrapper we generate.
        .body("mapStyles.find { it.id == 'osm' }.attribution", is(nullValue()));
  }

  @Test
  void getStyle_shouldRenderAOneLayerRasterStyle() {
    given()
        .when()
        .get("/api/map/styles/osm.json")
        .then()
        .statusCode(200)
        .body("version", equalTo(8))
        .body("layers", hasSize(1))
        .body("layers[0].type", equalTo("raster"))
        .body("layers[0].source", equalTo("raster"))
        .body("sources.raster.type", equalTo("raster"))
        .body("sources.raster.tiles", hasSize(1))
        .body("sources.raster.tiles[0]", containsString("{z}"))
        .body("sources.raster.maxzoom", equalTo(19))
        .body("sources.raster.attribution", containsString("OpenStreetMap"));
  }

  @Test
  void getStyle_shouldCarryTheProvidersShallowestZoom() {
    // SCAN 25 starts at z6; without minzoom a world-zoom map fires a wall of 404s.
    given()
        .when()
        .get("/api/map/styles/ign-scan25.json")
        .then()
        .statusCode(200)
        .body("sources.raster.minzoom", equalTo(6))
        .body("sources.raster.maxzoom", equalTo(16));
  }

  @Test
  void getStyle_forAHostedVectorStyle_shouldBe404() {
    // `cycling` is hosted elsewhere, not generated here: the endpoint must not invent one.
    given().when().get("/api/map/styles/cycling.json").then().statusCode(404);
  }

  @Test
  void getStyle_forAnUnknownId_shouldBe404() {
    given().when().get("/api/map/styles/does-not-exist.json").then().statusCode(404);
  }

  @Test
  void getConfig_shouldServeTheTileHostAndADefaultCamera() {
    given()
        .when()
        .get("/api/config")
        .then()
        .statusCode(200)
        .body("tileServerBaseUrl", startsWith("http"))
        .body("defaultCenter.lat", allOf(greaterThan(-90f), lessThan(90f)))
        .body("defaultCenter.lon", allOf(greaterThan(-180f), lessThan(180f)))
        .body("defaultCenter.zoom", greaterThan(0f));
  }

  @Test
  void getConfig_shouldServeTheElevationSource() {
    // Served for the same reason the basemaps are: it was hard-coded in the web client, and the
    // mobile app — which now shades its relief from the very same TileJSON — had none at all.
    given()
        .when()
        .get("/api/config")
        .then()
        .statusCode(200)
        .body("terrain.url", startsWith("http"))
        .body("terrain.maxZoom", greaterThan(0));
  }

  @Test
  void getConfig_shouldNotLeakTheInternalRenderer() {
    // tileserver.url is the private renderer the thumbnail service talks to (localhost:18080 in
    // test). Handing it to a client would be useless at best and an SSRF hint at worst.
    given()
        .when()
        .get("/api/config")
        .then()
        .statusCode(200)
        .body("tileServerBaseUrl", not(containsString("localhost")));
  }

  @Test
  void getConfig_anonymous_shouldStillCarryTheMapSettings() {
    given()
        .when()
        .get("/api/config")
        .then()
        .statusCode(200)
        .body("mapStyles", not(empty()))
        .body("defaultCenter", is(notNullValue()));
  }

  @Test
  void getConfig_withNoFloorConfigured_shouldOmitMinSupportedAppVersion() {
    // %test sets no floor, and Jackson is NON_NULL: the field must be absent rather than "".
    given()
        .when()
        .get("/api/config")
        .then()
        .statusCode(200)
        .body("$", not(hasKey("minSupportedAppVersion")));
  }

  @Test
  void getConfig_onAMultiTeamDomain_shouldFallBackToTheConfiguredCentre() {
    // The standard fixture's domain is not pinned and not single-team, so no team dictates the
    // camera: it must be the deployment default (46.6 / 2.3), not a team's geometry.
    given()
        .when()
        .get("/api/config")
        .then()
        .statusCode(200)
        .body("defaultCenter.lat", equalTo(46.6f))
        .body("defaultCenter.lon", equalTo(2.3f));
  }
}
