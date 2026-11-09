package fr.pedalons.api.device;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.repository.auth.AuthSessionRepository;
import fr.pedalons.repository.auth.DeviceCodeRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.path.json.JsonPath;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The device flow (RFC 8628) Karoo and Garmin pair with, end to end over HTTP (docs/LEDGER_*.md
 * AUD-16, audit B12): the device asks for codes, polls while the user decides, and collects its
 * tokens exactly once. The confirmation step itself is {@link DeviceOAuthConfirmationTest}, the
 * guessing budget {@link DeviceOAuthThrottleTest}.
 */
@QuarkusTest
class DeviceOAuthFlowTest extends AbstractResourceTest {

  private static final String DEVICE_CODE_GRANT = "urn:ietf:params:oauth:grant-type:device_code";
  private static final String OTHER_HOST = "other.example.com";

  @Inject DeviceCodeRepository deviceCodeRepository;
  @Inject AuthSessionRepository authSessionRepository;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private JsonPath start(String body) {
    return given()
        .contentType(ContentType.JSON)
        .body(body)
        .when()
        .post("/api/device/oauth/device")
        .then()
        .statusCode(200)
        .extract()
        .jsonPath();
  }

  private JsonPath start() {
    return start("{\"clientId\": \"karoo\"}");
  }

  private ValidatableResponse token(String body) {
    return given()
        .contentType(ContentType.JSON)
        .body(body)
        .when()
        .post("/api/device/oauth/token")
        .then();
  }

  private ValidatableResponse poll(String deviceCode) {
    return token(
        "{\"grantType\": \"" + DEVICE_CODE_GRANT + "\", \"deviceCode\": \"" + deviceCode + "\"}");
  }

  private ValidatableResponse complete(String accessToken, String host, String userCode) {
    return given()
        .header("X-Forwarded-Host", host)
        .auth()
        .oauth2(accessToken)
        .contentType(ContentType.JSON)
        .body("{\"userCode\": \"" + userCode + "\", \"confirmed\": true}")
        .when()
        .post("/api/device/oauth/complete")
        .then();
  }

  private ValidatableResponse complete(String user, String userCode) {
    return complete(getAccessToken(user), domain.getDomain(), userCode);
  }

  private ValidatableResponse verify(String userCode) {
    return given().queryParam("code", userCode).when().get("/api/device/oauth/verify").then();
  }

  /** Moves the code's expiry into the past, as ten minutes of waiting would. */
  private void expire(String userCode) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            deviceCodeRepository.update(
                "expiresAt = ?1 where userCode = ?2",
                Instant.now().minus(Duration.ofMinutes(1)),
                userCode));
  }

  private long deviceSessionsOf(User user, String clientId) {
    return QuarkusTransaction.requiringNew()
        .call(() ->
            authSessionRepository.count(
                "user.id = ?1 and userAgent = ?2", user.getId(), clientId + " Device"));
  }

  // --- Starting the flow ---

  @Test
  void start_returnsTheCodesTheDeviceShowsAndPollsWith() {
    JsonPath codes = start();
    String userCode = codes.getString("userCode");
    String verificationUri = codes.getString("verificationUri");

    // Six characters from an alphabet without 0/O and 1/I, read off a small screen.
    assertEquals(true, userCode.matches("[A-HJ-NP-Z2-9]{6}"), userCode);
    assertEquals(domain.getBaseUrl() + "/karoo", verificationUri);
    assertEquals(verificationUri + "?code=" + userCode, codes.getString("verificationUriComplete"));
    assertEquals(600, codes.getInt("expiresIn"));
    assertEquals(5, codes.getInt("interval"));

    // Only its hash is kept: the database alone cannot poll for someone else's tokens.
    String deviceCode = codes.getString("deviceCode");
    assertEquals(
        0L,
        QuarkusTransaction.requiringNew()
            .call(() -> deviceCodeRepository.count("deviceCodeHash", deviceCode)));
    assertEquals(1L, QuarkusTransaction.requiringNew().call(() -> deviceCodeRepository.count()));
  }

  @Test
  void start_withoutClientId_isAGenericDevice() {
    String userCode = start("{}").getString("userCode");

    verify(userCode).statusCode(200).body("clientId", equalTo("device"));
  }

  @Test
  void start_eachRequestGetsItsOwnCodes() {
    JsonPath first = start();
    JsonPath second = start();

    assertEquals(false, first.getString("userCode").equals(second.getString("userCode")));
    assertEquals(false, first.getString("deviceCode").equals(second.getString("deviceCode")));
  }

  // --- Polling ---

  @Test
  void poll_beforeTheUserDecides_isPendingEveryTime() {
    String deviceCode = start().getString("deviceCode");

    poll(deviceCode).statusCode(400).body("code", equalTo("AUTHORIZATION_PENDING"));
    poll(deviceCode).statusCode(400).body("code", equalTo("AUTHORIZATION_PENDING"));
  }

  @Test
  void poll_unknownDeviceCode_isInvalid() {
    poll("not-a-device-code").statusCode(400).body("code", equalTo("TOKEN_INVALID"));
  }

  @Test
  void poll_withoutDeviceCode_isRefused() {
    token("{\"grantType\": \"" + DEVICE_CODE_GRANT + "\"}").statusCode(400);
    token("{\"grantType\": \"" + DEVICE_CODE_GRANT + "\", \"deviceCode\": \"  \"}").statusCode(400);
  }

  @Test
  void token_unknownGrantType_isRefused() {
    String deviceCode = start().getString("deviceCode");

    token("{\"grantType\": \"password\", \"deviceCode\": \"" + deviceCode + "\"}").statusCode(400);
  }

  // --- Approval and exchange ---

  @Test
  void approved_theDeviceCollectsTokensForTheApprovingUser() {
    JsonPath codes = start();
    complete(USER1, codes.getString("userCode")).statusCode(200);
    verify(codes.getString("userCode")).statusCode(200).body("authorized", is(true));

    JsonPath tokens =
        poll(codes.getString("deviceCode"))
            .statusCode(200)
            .body("tokenType", equalTo("Bearer"))
            .body("expiresIn", equalTo(15 * 60))
            .body("accessToken", not(emptyOrNullString()))
            .body("refreshToken", not(emptyOrNullString()))
            .extract()
            .jsonPath();

    assertEquals(1L, deviceSessionsOf(user1, "karoo"));
    assertEquals(0L, deviceSessionsOf(user2, "karoo"));

    // The access token opens the device API, and the refresh token renews it.
    given()
        .auth()
        .oauth2(tokens.getString("accessToken"))
        .when()
        .get("/api/device/me")
        .then()
        .statusCode(200);
    token(
            "{\"grantType\": \"refresh_token\", \"refreshToken\": \""
                + tokens.getString("refreshToken")
                + "\"}")
        .statusCode(200)
        .body("accessToken", not(emptyOrNullString()));
  }

  @Test
  void approved_userCodeIsCaseInsensitive() {
    JsonPath codes = start();

    complete(USER1, codes.getString("userCode").toLowerCase()).statusCode(200);

    poll(codes.getString("deviceCode")).statusCode(200);
  }

  @Test
  void approved_deviceCodeIsSpentByTheExchange() {
    JsonPath codes = start();
    complete(USER1, codes.getString("userCode")).statusCode(200);
    poll(codes.getString("deviceCode")).statusCode(200);

    // Replaying the device code mints nothing more: a copy of it is worth no session.
    poll(codes.getString("deviceCode")).statusCode(400).body("code", equalTo("TOKEN_INVALID"));
    assertEquals(1L, deviceSessionsOf(user1, "karoo"));
    // And the user code is gone with it.
    verify(codes.getString("userCode")).statusCode(404);
    complete(USER2, codes.getString("userCode"))
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
  }

  @Test
  void approved_sameUserConfirmingTwice_changesNothing() {
    JsonPath codes = start();
    complete(USER1, codes.getString("userCode")).statusCode(200);

    complete(USER1, codes.getString("userCode")).statusCode(200);

    poll(codes.getString("deviceCode")).statusCode(200);
    assertEquals(1L, deviceSessionsOf(user1, "karoo"));
  }

  @Test
  void approved_anotherAccountCannotTakeTheCodeOver() {
    JsonPath codes = start();
    complete(USER1, codes.getString("userCode")).statusCode(200);

    complete(USER2, codes.getString("userCode"))
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));

    poll(codes.getString("deviceCode")).statusCode(200);
    assertEquals(1L, deviceSessionsOf(user1, "karoo"));
    assertEquals(0L, deviceSessionsOf(user2, "karoo"));
  }

  // --- Expiry and refusal ---

  @Test
  void expired_beforeApproval_cannotBeApprovedNorExchanged() {
    JsonPath codes = start();
    expire(codes.getString("userCode"));

    verify(codes.getString("userCode")).statusCode(404);
    complete(USER1, codes.getString("userCode"))
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
    poll(codes.getString("deviceCode")).statusCode(400).body("code", equalTo("TOKEN_EXPIRED"));
  }

  @Test
  void expired_afterApproval_theSlowDeviceGetsNothing() {
    JsonPath codes = start();
    complete(USER1, codes.getString("userCode")).statusCode(200);
    expire(codes.getString("userCode"));

    poll(codes.getString("deviceCode")).statusCode(400).body("code", equalTo("TOKEN_EXPIRED"));
    assertEquals(0L, deviceSessionsOf(user1, "karoo"));
  }

  @Test
  void unknownUserCode_isInvalid() {
    complete(USER1, "ZZZZZ2").statusCode(400).body("code", equalTo("TOKEN_INVALID"));
  }

  // --- Multi-tenancy ---

  @Test
  void anotherDomainsAccount_cannotApproveThisDomainsCode() {
    Domain other = dataService.createDomain(OTHER_HOST, "Other", "https://" + OTHER_HOST);
    User elsewhere = dataService.createVerifiedUser(other, EMAIL1, "Same address, other site");
    JsonPath codes = start();

    complete(jwtService.generateAccessToken(elsewhere), OTHER_HOST, codes.getString("userCode"))
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));

    verify(codes.getString("userCode")).statusCode(200).body("authorized", is(false));
    poll(codes.getString("deviceCode"))
        .statusCode(400)
        .body("code", equalTo("AUTHORIZATION_PENDING"));
  }

  @Test
  void start_onAnotherDomain_sendsTheUserToThatDomain() {
    dataService.createDomain(OTHER_HOST, "Other", "https://" + OTHER_HOST);

    given()
        .header("X-Forwarded-Host", OTHER_HOST)
        .contentType(ContentType.JSON)
        .body("{\"clientId\": \"garmin\"}")
        .when()
        .post("/api/device/oauth/device")
        .then()
        .statusCode(200)
        .body("verificationUri", equalTo("https://" + OTHER_HOST + "/garmin"));
  }
}
