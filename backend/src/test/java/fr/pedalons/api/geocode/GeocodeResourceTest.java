package fr.pedalons.api.geocode;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.infrastructure.stadiamaps.GeocodingFeature;
import fr.pedalons.infrastructure.stadiamaps.GeocodingLookup;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The geocoding proxy: what we expose, and to whom (docs/LEDGER_*.md OPS-49).
 *
 * <p>The upstream client is mocked: these tests are about our layer, not about the provider's data,
 * and a test suite that queried the real API would spend the quota of whoever runs it.
 *
 * <p>{@link GeocodingLookup} is what is mocked, not the REST client behind it: it is the seam
 * between our layer and Stadia Maps', and it carries the cache. What it does when the provider
 * misbehaves is its own test, {@code GeocodingLookupTest}; the JSON mapping of a real answer is
 * {@code GeocodingResponseJsonTest}.
 */
@QuarkusTest
class GeocodeResourceTest extends AbstractResourceTest {

  @InjectMock GeocodingLookup geocodingLookup;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private static GeocodingFeature feature(String gid, String label, Double lon, Double lat) {
    return new GeocodingFeature(
        lon == null || lat == null ? null : new GeocodingFeature.Geometry(List.of(lon, lat)),
        new GeocodingFeature.Properties(gid, label, label));
  }

  @Test
  void search_anonymous_shouldBeRefused() {
    // Public data, but not a public relay: an anonymous endpoint here would be a free geocoder
    // spending our Stadia Maps quota, with our key, for anyone.
    given().when().get("/api/geocode/search?q=chambery-anonymous").then().statusCode(401);
  }

  @Test
  void search_shouldReturnPlacesWithLatLonInThatOrder() {
    when(geocodingLookup.search(anyString(), anyString()))
        .thenReturn(
            List.of(
                feature(
                    "whosonfirst:locality:101749323", "Chambéry, France", 5.909277, 45.584386)));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/geocode/search?q=chambery-nominal")
        .then()
        .statusCode(200)
        .body("size()", is(1))
        .body("[0].id", equalTo("whosonfirst:locality:101749323"))
        .body("[0].displayName", equalTo("Chambéry, France"))
        // GeoJSON serves [lon, lat]; the contract names them, so no client has to remember.
        .body("[0].lat", equalTo(45.584386f))
        .body("[0].lon", equalTo(5.909277f));
  }

  @Test
  void search_belowThreeCharacters_shouldNotReachTheProvider() {
    // The clients already gate on three characters. Asking upstream anyway would be a billed call
    // for a query that matches half of France.
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/geocode/search?q=ch")
        .then()
        .statusCode(200)
        .body("size()", is(0));

    org.mockito.Mockito.verifyNoInteractions(geocodingLookup);
  }

  @Test
  void search_shouldDropAHitWithNoCoordinate() {
    when(geocodingLookup.search(anyString(), anyString()))
        .thenReturn(
            List.of(
                feature("openstreetmap:venue:node/1", "Sans coordonnée", null, null),
                feature("whosonfirst:locality:101748509", "Annecy, France", 6.1294, 45.8992)));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/geocode/search?q=annecy-partiel")
        .then()
        .statusCode(200)
        .body("size()", is(1))
        .body("[0].displayName", equalTo("Annecy, France"));
  }
}
