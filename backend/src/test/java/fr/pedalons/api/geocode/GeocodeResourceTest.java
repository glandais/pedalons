package fr.pedalons.api.geocode;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.infrastructure.stadiamaps.GeocodingFeature;
import fr.pedalons.infrastructure.stadiamaps.GeocodingLookup;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The geocoding proxy: what we expose, and to whom (docs/LEDGER_*.md OPS-49, API-129).
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

  private static GeocodingFeature feature(
      String gid, String name, String coarseLocation, Double lon, Double lat) {
    return new GeocodingFeature(
        lon == null || lat == null ? null : new GeocodingFeature.Geometry(List.of(lon, lat)),
        new GeocodingFeature.Properties(gid, name, coarseLocation));
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
                    "whosonfirst:locality:101749323", "Chambéry", "France", 5.909277, 45.584386)));

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

    verifyNoInteractions(geocodingLookup);
  }

  @Test
  void search_aHitWithoutPosition_shouldBeKeptWithNullLatLon() {
    // The v2 autocomplete gives no position for most hits: the client resolves the picked one
    // with /place. Dropping them, as v1 did, would leave the autocomplete empty.
    when(geocodingLookup.search(anyString(), anyString()))
        .thenReturn(
            List.of(feature("whosonfirst:locality:101750851", "Annecy", "France", null, null)));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/geocode/search?q=annecy-sans-point")
        .then()
        .statusCode(200)
        .body("size()", is(1))
        .body("[0].id", equalTo("whosonfirst:locality:101750851"))
        .body("[0].displayName", equalTo("Annecy, France"))
        .body("[0].lat", nullValue())
        .body("[0].lon", nullValue());
  }

  @Test
  void search_shouldDropAHitWithNothingToShowOrToResolve() {
    when(geocodingLookup.search(anyString(), anyString()))
        .thenReturn(
            List.of(
                // No name: nothing to show.
                feature("whosonfirst:locality:1", null, "France", 6.1, 45.9),
                // Neither a position nor a GID to resolve one with.
                feature(null, "Sans coordonnée", null, null, null),
                feature("whosonfirst:locality:101748509", "Annecy", null, 6.1294, 45.8992)));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/geocode/search?q=annecy-partiel")
        .then()
        .statusCode(200)
        .body("size()", is(1))
        .body("[0].displayName", equalTo("Annecy"));
  }

  @Test
  void place_anonymous_shouldBeRefused() {
    given()
        .when()
        .get("/api/geocode/place?id=whosonfirst:locality:101750851")
        .then()
        .statusCode(401);
    verifyNoInteractions(geocodingLookup);
  }

  @Test
  void place_shouldReturnTheResolvedPosition_underTheIdAskedFor() {
    // The provider may answer another GID (locality → localadmin); the client keys on its own.
    when(geocodingLookup.place(eq("whosonfirst:locality:101750851"), anyString()))
        .thenReturn(
            Optional.of(
                feature(
                    "whosonfirst:localadmin:404379599", "Annecy", "France", 6.12273, 45.89964)));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("id", "whosonfirst:locality:101750851")
        .when()
        .get("/api/geocode/place")
        .then()
        .statusCode(200)
        .body("id", equalTo("whosonfirst:locality:101750851"))
        .body("displayName", equalTo("Annecy, France"))
        .body("lat", equalTo(45.89964f))
        .body("lon", equalTo(6.12273f));
  }

  @Test
  void place_unknownToTheProvider_shouldBe404() {
    when(geocodingLookup.place(anyString(), anyString())).thenReturn(Optional.empty());

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("id", "whosonfirst:locality:404")
        .when()
        .get("/api/geocode/place")
        .then()
        .statusCode(404)
        .body("code", equalTo("NOT_FOUND"));
  }

  @Test
  void place_whenTheProviderFails_shouldBe503() {
    when(geocodingLookup.place(anyString(), anyString()))
        .thenThrow(new ServiceUnavailableException(ErrorCode.GEOCODING_UNAVAILABLE));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("id", "whosonfirst:locality:503")
        .when()
        .get("/api/geocode/place")
        .then()
        .statusCode(503)
        .body("code", equalTo("GEOCODING_UNAVAILABLE"));
  }

  @Test
  void place_aMalformedId_shouldBe404_withoutReachingTheProvider() {
    // The id is user input forwarded to an API billed 20 credits a call: anything not shaped like
    // a GID is refused before a call is spent on it.
    for (String id :
        List.of(
            "",
            "annecy",
            "whosonfirst:locality",
            "WhosOnFirst:locality:1",
            "whosonfirst:locality:1&size=40",
            "whosonfirst:locality:1 2",
            "whosonfirst:locality:" + "1".repeat(200))) {
      given()
          .auth()
          .oauth2(getAccessToken(USER1))
          .queryParam("id", id)
          .when()
          .get("/api/geocode/place")
          .then()
          .statusCode(404);
    }
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/geocode/place")
        .then()
        .statusCode(404);

    verifyNoInteractions(geocodingLookup);
  }
}
