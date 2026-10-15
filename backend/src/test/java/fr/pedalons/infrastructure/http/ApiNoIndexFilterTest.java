package fr.pedalons.infrastructure.http;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

/** The API stays out of search indexes, the public images (og:image) stay in. */
@QuarkusTest
class ApiNoIndexFilterTest {

  @Test
  void everyApiPathIsNoIndex_butThePublicImages() {
    assertTrue(ApiNoIndexFilter.isNoIndex("/api/version"));
    assertTrue(ApiNoIndexFilter.isNoIndex("/api/teams/x/routes/y/usages"));
    assertTrue(ApiNoIndexFilter.isNoIndex("/api/download/public/assets/team/1/route.gpx"));
    assertTrue(ApiNoIndexFilter.isNoIndex("/api/download/public/avatars/1/64"));
    assertTrue(ApiNoIndexFilter.isNoIndex("/api"));

    assertFalse(ApiNoIndexFilter.isNoIndex("/api/download/public/images/team/1/1200"));
    assertFalse(ApiNoIndexFilter.isNoIndex("/apidocs"));
    assertFalse(ApiNoIndexFilter.isNoIndex("/q/health"));
    assertFalse(ApiNoIndexFilter.isNoIndex(null));
  }

  @Test
  void aJsonResponseCarriesTheHeader() {
    given()
        .when()
        .get("/api/version")
        .then()
        .statusCode(200)
        .header(ApiNoIndexFilter.HEADER, equalTo(ApiNoIndexFilter.VALUE));
  }

  @Test
  void aResponseJaxRsNeverProducedCarriesItToo() {
    given()
        .when()
        .get("/api/no-such-endpoint")
        .then()
        .statusCode(404)
        .header(ApiNoIndexFilter.HEADER, equalTo(ApiNoIndexFilter.VALUE));
  }

  @Test
  void aPublicGpxCarriesTheHeader() {
    given()
        .when()
        .get("/api/download/public/assets/no-such-team/0aaaaaaaaaaaa/route.gpx")
        .then()
        .header(ApiNoIndexFilter.HEADER, equalTo(ApiNoIndexFilter.VALUE));
  }

  @Test
  void aPublicImageDoesNot() {
    given()
        .when()
        .get("/api/download/public/images/no-such-team/0aaaaaaaaaaaa/1200")
        .then()
        .header(ApiNoIndexFilter.HEADER, nullValue());
  }
}
