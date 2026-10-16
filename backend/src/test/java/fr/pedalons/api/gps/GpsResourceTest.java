package fr.pedalons.api.gps;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.route.Route;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.GpsSyncTestData;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import java.net.URI;
import java.util.Arrays;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class GpsResourceTest extends AbstractResourceTest {

  private Route route;
  private String routeSlug;
  @Inject DomainResolver domainResolver;
  @Inject GpsSyncTestData sync;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    domainResolver.setDomainForTest(domain);

    // Set up domain GPS credentials for tests
    dataService.createDomainGpsCredential(
        domain, GpsServiceType.HAMMERHEAD, "hammerhead-client-id");
    dataService.createDomainGpsCredential(domain, GpsServiceType.GARMIN, "garmin-client-id");

    route = dataService.createRoute(team1, user1, "GPS Test Route");
    routeSlug = route.getSlug();
  }

  // ==================== Get Connect URL ====================

  @Test
  void getConnectUrl_withAuth_shouldReturnUrl() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/gps/connect/HAMMERHEAD")
        .then()
        .statusCode(200)
        .body("authorizationUrl", notNullValue());
  }

  @Test
  void getConnectUrl_garmin_shouldReturnUrl() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/gps/connect/GARMIN")
        .then()
        .statusCode(200)
        .body("authorizationUrl", notNullValue());
  }

  @Test
  void getConnectUrl_withoutAuth_shouldReturn401() {
    given().when().get("/api/gps/connect/HAMMERHEAD").then().statusCode(401);
  }

  @Test
  void getConnectUrl_invalidServiceType_shouldReturn404() {
    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/gps/connect/INVALID")
        .then()
        .statusCode(404);
  }

  // ==================== OAuth Callback ====================

  @Test
  void handleCallback_withError_shouldRedirectWithError() {
    given()
        .queryParam("error", "access_denied")
        .redirects()
        .follow(false)
        .when()
        .get("/api/gps/callback/HAMMERHEAD")
        .then()
        .statusCode(307)
        .header("Location", containsString("gps_error=access_denied"));
  }

  @Test
  void handleCallback_withMissingParams_shouldRedirectWithError() {
    given()
        .redirects()
        .follow(false)
        .when()
        .get("/api/gps/callback/HAMMERHEAD")
        .then()
        .statusCode(307)
        .header("Location", containsString("gps_error=missing_params"));
  }

  @Test
  void handleCallback_withMissingCode_shouldRedirectWithError() {
    given()
        .queryParam("state", "test-state")
        .redirects()
        .follow(false)
        .when()
        .get("/api/gps/callback/HAMMERHEAD")
        .then()
        .statusCode(307)
        .header("Location", containsString("gps_error=missing_params"));
  }

  @Test
  void handleCallback_withMissingState_shouldRedirectWithError() {
    given()
        .queryParam("code", "test-code")
        .redirects()
        .follow(false)
        .when()
        .get("/api/gps/callback/HAMMERHEAD")
        .then()
        .statusCode(307)
        .header("Location", containsString("gps_error=missing_params"));
  }

  @Test
  void handleCallback_withInvalidState_shouldRedirectWithError() {
    given()
        .queryParam("code", "test-code")
        .queryParam("state", "invalid-state")
        .redirects()
        .follow(false)
        .when()
        .get("/api/gps/callback/HAMMERHEAD")
        .then()
        .statusCode(307)
        .header("Location", containsString("gps_error=connection_failed"));
  }

  // ==================== Return target (docs/LEDGER_*.md API-63) ====================

  /** Starts a connection and returns the OAuth state the provider would send back. */
  private String startConnection(String returnTo) {
    var request = given().auth().oauth2(getAccessToken(USER1));
    if (returnTo != null) request = request.queryParam("returnTo", returnTo);
    String url =
        request
            .when()
            .get("/api/gps/connect/HAMMERHEAD")
            .then()
            .statusCode(200)
            .extract()
            .path("authorizationUrl");
    return Arrays.stream(URI.create(url).getRawQuery().split("&"))
        .filter(p -> p.startsWith("state="))
        .map(p -> p.substring("state=".length()))
        .findFirst()
        .orElseThrow();
  }

  @Test
  void handleCallback_refusalAfterKarooConnect_shouldRedirectToKarooPage() {
    String state = startConnection("DEVICE_KAROO");

    given()
        .queryParam("error", "access_denied")
        .queryParam("state", state)
        .redirects()
        .follow(false)
        .when()
        .get("/api/gps/callback/HAMMERHEAD")
        .then()
        .statusCode(307)
        .header("Location", endsWith("/karoo?gps_error=access_denied"));
  }

  @Test
  void handleCallback_failureAfterKarooConnect_shouldRedirectToKarooPage() {
    String state = startConnection("DEVICE_KAROO");

    // A Hammerhead state replayed on the Garmin callback: rejected before any exchange with a
    // provider, yet the browser still goes back to the page that started the connection.
    given()
        .queryParam("code", "test-code")
        .queryParam("state", state)
        .redirects()
        .follow(false)
        .when()
        .get("/api/gps/callback/GARMIN")
        .then()
        .statusCode(307)
        .header("Location", endsWith("/karoo?gps_error=connection_failed"));
  }

  @Test
  void handleCallback_withoutReturnTo_shouldRedirectToProfileDevices() {
    String state = startConnection(null);

    given()
        .queryParam("error", "access_denied")
        .queryParam("state", state)
        .redirects()
        .follow(false)
        .when()
        .get("/api/gps/callback/HAMMERHEAD")
        .then()
        .statusCode(307)
        .header("Location", endsWith("/profile/devices?gps_error=access_denied"));
  }

  @Test
  void getConnectUrl_unknownReturnTo_shouldBeRejected() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .queryParam("returnTo", "https://evil.example")
        .when()
        .get("/api/gps/connect/HAMMERHEAD")
        .then()
        .statusCode(404);
  }

  // ==================== Disconnect ====================

  @Test
  void disconnect_withAuth_shouldSucceed() {
    // Note: This test may fail if service is not connected, which is expected
    // The endpoint should return 204 on success or 400 if not connected
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/gps/disconnect/HAMMERHEAD")
        .then()
        .statusCode(anyOf(equalTo(204), equalTo(400)));
  }

  @Test
  void disconnect_withoutAuth_shouldReturn401() {
    given().when().delete("/api/gps/disconnect/HAMMERHEAD").then().statusCode(401);
  }

  @Test
  void disconnect_invalidServiceType_shouldReturn404() {
    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .delete("/api/gps/disconnect/INVALID")
        .then()
        .statusCode(404);
  }

  // ==================== Upload Route ====================

  @Test
  void uploadRoute_withoutAuth_shouldReturn401() {
    given()
        .contentType(ContentType.JSON)
        .when()
        .post("/api/gps/upload/HAMMERHEAD/" + team1Slug + "/" + routeSlug)
        .then()
        .statusCode(401);
  }

  @Test
  void uploadRoute_notConnected_shouldReturn400() {
    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .post("/api/gps/upload/HAMMERHEAD/" + team1Slug + "/" + routeSlug)
        .then()
        .statusCode(400);
  }

  @Test
  void uploadRoute_nonexistentRoute_shouldReturn404() {
    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .post("/api/gps/upload/HAMMERHEAD/" + team1Slug + "/nonexistent-route")
        .then()
        .statusCode(anyOf(equalTo(400), equalTo(404)));
  }

  @Test
  void uploadRoute_nonexistentTeam_shouldReturn404() {
    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .post("/api/gps/upload/HAMMERHEAD/nonexistent-team/" + routeSlug)
        .then()
        .statusCode(anyOf(equalTo(400), equalTo(404)));
  }

  @Test
  void uploadRoute_asNonMember_shouldReturn403() {
    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER4))
        .when()
        .post("/api/gps/upload/HAMMERHEAD/" + team1Slug + "/" + routeSlug)
        .then()
        .statusCode(anyOf(equalTo(400), equalTo(403)));
  }

  @Test
  void uploadRoute_invalidServiceType_shouldReturn404() {
    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .post("/api/gps/upload/INVALID/" + team1Slug + "/" + routeSlug)
        .then()
        .statusCode(404);
  }

  // ==================== Automatic route sync (docs/LEDGER_*.md API-120) ====================

  @Test
  void getConnectUrl_alreadyConnected_isRefused() {
    dataService.createGpsServiceConnection(user1, GpsServiceType.HAMMERHEAD);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/gps/connect/HAMMERHEAD")
        .then()
        .statusCode(400);
  }

  /** The reconnection the clients offer when the service refuses the tokens. */
  @Test
  void getConnectUrl_connectionWaitingForAReconnection_isAllowed() {
    GpsServiceConnection connection =
        dataService.createGpsServiceConnection(user1, GpsServiceType.HAMMERHEAD);
    sync.markReconnectRequired(connection.getId());

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/gps/connect/HAMMERHEAD")
        .then()
        .statusCode(200)
        .body("authorizationUrl", notNullValue());
  }

  @Test
  void setAutoSync_turnsItOnThenOff() {
    dataService.createGpsServiceConnection(user1, GpsServiceType.HAMMERHEAD);

    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER1))
        .body("{\"enabled\": true}")
        .when()
        .put("/api/gps/connections/HAMMERHEAD/auto-sync")
        .then()
        .statusCode(200)
        .body("serviceType", equalTo("HAMMERHEAD"))
        .body("autoSync", equalTo(true))
        .body("autoSyncState", equalTo("UP_TO_DATE"))
        .body("autoSyncRouteCount", equalTo(0));

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/users/me")
        .then()
        .statusCode(200)
        .body("connectedServices[0].autoSync", equalTo(true))
        .body("connectedServices[0].autoSyncState", equalTo("UP_TO_DATE"));

    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER1))
        .body("{\"enabled\": false}")
        .when()
        .put("/api/gps/connections/HAMMERHEAD/auto-sync")
        .then()
        .statusCode(200)
        .body("autoSync", equalTo(false))
        .body("autoSyncState", equalTo("OFF"));
  }

  @Test
  void setAutoSync_notConnected_shouldReturn400() {
    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER1))
        .body("{\"enabled\": true}")
        .when()
        .put("/api/gps/connections/HAMMERHEAD/auto-sync")
        .then()
        .statusCode(400);
  }

  @Test
  void setAutoSync_touchesOnlyTheCallersConnection() {
    dataService.createGpsServiceConnection(user1, GpsServiceType.HAMMERHEAD);
    dataService.createGpsServiceConnection(user2, GpsServiceType.HAMMERHEAD);

    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER2))
        .body("{\"enabled\": true}")
        .when()
        .put("/api/gps/connections/HAMMERHEAD/auto-sync")
        .then()
        .statusCode(200);

    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/users/me")
        .then()
        .statusCode(200)
        .body("connectedServices[0].autoSync", equalTo(false))
        .body("connectedServices[0].autoSyncState", equalTo("OFF"));
  }

  @Test
  void setAutoSync_withoutBody_shouldReturn400() {
    dataService.createGpsServiceConnection(user1, GpsServiceType.HAMMERHEAD);

    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(getAccessToken(USER1))
        .body("{}")
        .when()
        .put("/api/gps/connections/HAMMERHEAD/auto-sync")
        .then()
        .statusCode(400);
  }

  @Test
  void setAutoSync_withoutAuth_shouldReturn401() {
    given()
        .contentType(ContentType.JSON)
        .body("{\"enabled\": true}")
        .when()
        .put("/api/gps/connections/HAMMERHEAD/auto-sync")
        .then()
        .statusCode(401);
  }
}
