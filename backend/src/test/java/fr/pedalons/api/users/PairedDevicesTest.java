package fr.pedalons.api.users;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertFalse;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.auth.AuthSession;
import fr.pedalons.domain.user.User;
import fr.pedalons.repository.auth.AuthSessionRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.path.json.JsonPath;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The devices paired with an account, listed and unpaired one by one (docs/LEDGER_*.md API-64):
 * each is the session its pairing opened, told apart by {@code AuthSession.deviceClient} — never
 * by parsing its user agent.
 */
@QuarkusTest
class PairedDevicesTest extends AbstractResourceTest {

  private static final String DEVICE_CODE_GRANT = "urn:ietf:params:oauth:grant-type:device_code";

  @Inject AuthSessionRepository authSessionRepository;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  /** Pairs a device of [clientId] with [user] over HTTP, and returns its tokens. */
  private JsonPath pair(String user, String clientId) {
    String body = "{\"clientId\": \"" + clientId + "\"}";
    JsonPath codes =
        given()
            .contentType(ContentType.JSON)
            .body(body)
            .when()
            .post("/api/device/oauth/device")
            .then()
            .statusCode(200)
            .extract()
            .jsonPath();
    given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(ContentType.JSON)
        .body("{\"userCode\": \"" + codes.getString("userCode") + "\", \"confirmed\": true}")
        .when()
        .post("/api/device/oauth/complete")
        .then()
        .statusCode(200);
    return token(
            "{\"grantType\": \""
                + DEVICE_CODE_GRANT
                + "\", \"deviceCode\": \""
                + codes.getString("deviceCode")
                + "\"}")
        .statusCode(200)
        .extract()
        .jsonPath();
  }

  private ValidatableResponse token(String body) {
    return given()
        .contentType(ContentType.JSON)
        .body(body)
        .when()
        .post("/api/device/oauth/token")
        .then();
  }

  private ValidatableResponse refresh(String refreshToken) {
    return token("{\"grantType\": \"refresh_token\", \"refreshToken\": \"" + refreshToken + "\"}");
  }

  private ValidatableResponse list(String user) {
    return given().auth().oauth2(getAccessToken(user)).when().get("/api/users/me/devices").then();
  }

  private ValidatableResponse unpair(String user, String deviceId) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .when()
        .delete("/api/users/me/devices/" + deviceId)
        .then();
  }

  /** A session of the site or the app: no device client. */
  private Long webSessionOf(User user) {
    return QuarkusTransaction.requiringNew()
        .call(() -> {
          AuthSession session =
              new AuthSession(
                  authSessionRepository.getEntityManager().getReference(User.class, user.getId()),
                  "web-" + UUID.randomUUID(),
                  Instant.now().plus(Duration.ofDays(30)));
          session.setUserAgent("Mozilla/5.0");
          authSessionRepository.persist(session);
          return session.getId();
        });
  }

  @Test
  void list_hasEachPairedDevice_newestFirst_andNotTheWebSessions() {
    webSessionOf(user1);
    pair(USER1, "karoo");
    pair(USER1, "garmin");
    pair(USER1, "something-else");

    list(USER1)
        .statusCode(200)
        .body("size()", is(3))
        .body("type", contains("OTHER", "GARMIN", "KAROO"))
        .body("id", everyItem(notNullValue()))
        .body("pairedAt", everyItem(notNullValue()));
    // Someone else's devices are not listed.
    list(USER2).statusCode(200).body("size()", is(0));
  }

  @Test
  void list_hasLastUsedAt_onceTheDeviceRefreshed() {
    JsonPath tokens = pair(USER1, "karoo");
    refresh(tokens.getString("refreshToken")).statusCode(200);

    list(USER1).statusCode(200).body("[0].lastUsedAt", notNullValue());
  }

  @Test
  void unpair_endsThatDeviceOnly() {
    JsonPath karoo = pair(USER1, "karoo");
    JsonPath garmin = pair(USER1, "garmin");
    String garminId = list(USER1).extract().jsonPath().getString("find { it.type == 'GARMIN' }.id");

    unpair(USER1, garminId).statusCode(204);

    list(USER1).body("type", contains("KAROO"));
    refresh(garmin.getString("refreshToken"))
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
    refresh(karoo.getString("refreshToken")).statusCode(200);
    // Twice is not found: it is no longer a live pairing.
    unpair(USER1, garminId).statusCode(404);
  }

  private ValidatableResponse deviceMe(String accessToken) {
    return given().auth().oauth2(accessToken).when().get("/api/device/me").then();
  }

  /** docs/LEDGER_*.md API-65: the access token dies with its pairing, not 15 minutes later. */
  @Test
  void unpair_refusesThatDevicesAccessToken_atOnce() {
    JsonPath karoo = pair(USER1, "karoo");
    JsonPath garmin = pair(USER1, "garmin");
    deviceMe(garmin.getString("accessToken")).statusCode(200);
    String garminId = list(USER1).extract().jsonPath().getString("find { it.type == 'GARMIN' }.id");

    unpair(USER1, garminId).statusCode(204);

    deviceMe(garmin.getString("accessToken")).statusCode(401);
    deviceMe(karoo.getString("accessToken")).statusCode(200);
  }

  /** The token a refresh hands out names the same pairing, and dies with it too. */
  @Test
  void unpair_refusesTheAccessTokenOfARefresh() {
    JsonPath karoo = pair(USER1, "karoo");
    String refreshed =
        refresh(karoo.getString("refreshToken")).statusCode(200).extract().path("accessToken");
    deviceMe(refreshed).statusCode(200);

    unpair(USER1, list(USER1).extract().jsonPath().getString("[0].id")).statusCode(204);

    deviceMe(refreshed).statusCode(401);
  }

  @Test
  void unpair_someoneElsesDevice_isNotFound_andLeavesItPaired() {
    pair(USER1, "karoo");
    String karooId = list(USER1).extract().jsonPath().getString("[0].id");

    unpair(USER2, karooId).statusCode(404);

    list(USER1).body("size()", is(1));
  }

  @Test
  void unpair_aWebSession_isNotFound() {
    Long webSession = webSessionOf(user1);

    unpair(USER1, TsidUtils.toString(webSession)).statusCode(404);

    QuarkusTransaction.requiringNew()
        .run(() -> assertFalse(authSessionRepository.findById(webSession).isRevoked()));
  }
}
