package fr.pedalons.api.oauth;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.repository.auth.OAuthAuthorizationCodeRepository;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.path.json.JsonPath;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The OAuth 2.0 authorization code flow with PKCE external applications use (docs/LEDGER_*.md
 * API-199), end to end over HTTP: the site approves for the signed-in member, the application
 * exchanges the code once with its verifier, calls the API, refreshes, and is revoked from the
 * profile like a paired device.
 */
@QuarkusTest
class OAuthFlowTest extends AbstractResourceTest {

  private static final String CLIENT = "Mon appli";
  private static final String REDIRECT = "https://app.example.org/callback";
  private static final String VERIFIER = "a-verifier-of-at-least-forty-three-characters-0123456789";
  private static final String OTHER_HOST = "other.example.com";

  @Inject OAuthAuthorizationCodeRepository authorizationCodeRepository;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
  }

  private static String challengeOf(String verifier) {
    try {
      return Base64.getUrlEncoder()
          .withoutPadding()
          .encodeToString(
              MessageDigest.getInstance("SHA-256")
                  .digest(verifier.getBytes(StandardCharsets.US_ASCII)));
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  private static Map<String, Object> approval(String redirectUri) {
    Map<String, Object> body = new HashMap<>();
    body.put("clientId", CLIENT);
    body.put("redirectUri", redirectUri);
    body.put("codeChallenge", challengeOf(VERIFIER));
    body.put("codeChallengeMethod", "S256");
    body.put("state", "xyz 1&2");
    body.put("confirmed", true);
    return body;
  }

  private ValidatableResponse authorize(String user, Map<String, Object> body) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType(ContentType.JSON)
        .body(body)
        .when()
        .post("/api/oauth/authorize")
        .then();
  }

  /** Approves as [user] and returns the query parameters the application receives. */
  private Map<String, String> approve(String user, String redirectUri) {
    String location =
        authorize(user, approval(redirectUri)).statusCode(200).extract().path("redirectUri");
    assertTrue(location.startsWith(redirectUri), location);
    Map<String, String> params = new HashMap<>();
    for (String pair : location.substring(redirectUri.length() + 1).split("&")) {
      String[] kv = pair.split("=", 2);
      params.put(kv[0], URLDecoder.decode(kv[1], StandardCharsets.UTF_8));
    }
    return params;
  }

  private ValidatableResponse token(Map<String, String> form) {
    return given()
        .contentType(ContentType.URLENC)
        .formParams(form)
        .when()
        .post("/api/oauth/token")
        .then();
  }

  private ValidatableResponse exchange(
      String code, String clientId, String redirect, String verifier) {
    return token(
        Map.of(
            "grant_type", "authorization_code",
            "code", code,
            "client_id", clientId,
            "redirect_uri", redirect,
            "code_verifier", verifier));
  }

  private ValidatableResponse refresh(String refreshToken) {
    return token(Map.of("grant_type", "refresh_token", "refresh_token", refreshToken));
  }

  private JsonPath connect(String user) {
    String code = approve(user, REDIRECT).get("code");
    return exchange(code, CLIENT, REDIRECT, VERIFIER).statusCode(200).extract().jsonPath();
  }

  // --- Approval ---

  @Test
  void approve_sendsTheCodeAndTheStateToTheRedirectUri() {
    Map<String, String> params = approve(USER1, REDIRECT);

    assertEquals("xyz 1&2", params.get("state"));
    // Only its hash is kept.
    String code = params.get("code");
    assertEquals(
        0L,
        QuarkusTransaction.requiringNew()
            .call(() -> authorizationCodeRepository.count("codeHash", code)));
    assertEquals(
        1L, QuarkusTransaction.requiringNew().call(() -> authorizationCodeRepository.count()));
  }

  @Test
  void approve_acceptsAnyHostADeepLinkAndAnExistingQuery() {
    assertEquals(false, approve(USER1, "http://localhost:8765/cb").get("code").isBlank());
    assertEquals(false, approve(USER1, "com.example.app:/oauth").get("code").isBlank());

    String location =
        authorize(USER1, approval("myapp://callback?from=pedalons"))
            .statusCode(200)
            .extract()
            .path("redirectUri");
    assertTrue(location.startsWith("myapp://callback?from=pedalons&code="), location);
  }

  @Test
  void approve_refusesWhatABrowserWouldRunOrCannotFollow() {
    authorize(USER1, approval("javascript:alert(1)")).statusCode(400);
    authorize(USER1, approval("data:text/html,x")).statusCode(400);
    authorize(USER1, approval("/relative/path")).statusCode(400);
    authorize(USER1, approval("https://app.example.org/cb#fragment")).statusCode(400);
    authorize(USER1, approval("not a uri")).statusCode(400);
    // Reads as one host, goes to another.
    authorize(USER1, approval("https://pedalons.fr@elsewhere.example/cb")).statusCode(400);

    Map<String, Object> disguised = approval(REDIRECT);
    disguised.put("clientId", "app\u202Egpj.exe");
    authorize(USER1, disguised).statusCode(400);
  }

  @Test
  void approve_anApplicationCannotApproveTheNextOne() {
    String applicationToken = connect(USER1).getString("access_token");

    given()
        .auth()
        .oauth2(applicationToken)
        .contentType(ContentType.JSON)
        .body(approval(REDIRECT))
        .when()
        .post("/api/oauth/authorize")
        .then()
        .statusCode(403);
  }

  @Test
  void refresh_anApplicationSessionRefreshesNowhereElse() {
    String refreshToken = connect(USER1).getString("refresh_token");

    // The site's refresh would hand out a token that names no session, hence not revocable at
    // once; the devices' is not for applications.
    given()
        .header("X-Refresh-Token", refreshToken)
        .when()
        .post("/api/auth/refresh")
        .then()
        .statusCode(403);
    given()
        .contentType(ContentType.JSON)
        .body("{\"grantType\": \"refresh_token\", \"refreshToken\": \"" + refreshToken + "\"}")
        .when()
        .post("/api/device/oauth/token")
        .then()
        .statusCode(400);

    refresh(refreshToken).statusCode(200);
  }

  @Test
  void aDevicePairingCannotCallItselfAnApplication() {
    given()
        .contentType(ContentType.JSON)
        .body("{\"clientId\": \"oauth:Mon appli\"}")
        .when()
        .post("/api/device/oauth/device")
        .then()
        .statusCode(400);
  }

  @Test
  void approve_needsASession() {
    given()
        .contentType(ContentType.JSON)
        .body(approval(REDIRECT))
        .when()
        .post("/api/oauth/authorize")
        .then()
        .statusCode(401);
  }

  @Test
  void approve_needsTheExplicitConfirmationAndAnS256Challenge() {
    Map<String, Object> unconfirmed = approval(REDIRECT);
    unconfirmed.remove("confirmed");
    authorize(USER1, unconfirmed).statusCode(400);

    Map<String, Object> plain = approval(REDIRECT);
    plain.put("codeChallengeMethod", "plain");
    authorize(USER1, plain).statusCode(400);

    Map<String, Object> noChallenge = approval(REDIRECT);
    noChallenge.remove("codeChallenge");
    authorize(USER1, noChallenge).statusCode(400);
  }

  // --- Exchange ---

  @Test
  void exchange_givesTokensThatOpenTheApiForTheApprovingUser() {
    String code = approve(USER1, REDIRECT).get("code");

    JsonPath tokens =
        exchange(code, CLIENT, REDIRECT, VERIFIER)
            .statusCode(200)
            .header("Cache-Control", containsString("no-store"))
            .body("token_type", equalTo("Bearer"))
            .body("expires_in", equalTo(15 * 60))
            .body("access_token", not(emptyOrNullString()))
            .body("refresh_token", not(emptyOrNullString()))
            .extract()
            .jsonPath();

    given()
        .auth()
        .oauth2(tokens.getString("access_token"))
        .when()
        .get("/api/users/me")
        .then()
        .statusCode(200)
        .body("email", equalTo(EMAIL1));
  }

  @Test
  void exchange_aCodeIsGoodOnce() {
    String code = approve(USER1, REDIRECT).get("code");

    exchange(code, CLIENT, REDIRECT, VERIFIER).statusCode(200);
    exchange(code, CLIENT, REDIRECT, VERIFIER)
        .statusCode(400)
        .body("error", equalTo("invalid_grant"));
  }

  @Test
  void exchange_aWrongVerifierIsRefusedAndBurnsTheCode() {
    String code = approve(USER1, REDIRECT).get("code");

    exchange(code, CLIENT, REDIRECT, VERIFIER + "x")
        .statusCode(400)
        .body("error", equalTo("invalid_grant"));
    exchange(code, CLIENT, REDIRECT, VERIFIER)
        .statusCode(400)
        .body("error", equalTo("invalid_grant"));
  }

  @Test
  void exchange_anotherClientOrRedirectUriIsRefused() {
    exchange(approve(USER1, REDIRECT).get("code"), "Autre appli", REDIRECT, VERIFIER)
        .statusCode(400)
        .body("error", equalTo("invalid_grant"));
    exchange(approve(USER1, REDIRECT).get("code"), CLIENT, REDIRECT + "/else", VERIFIER)
        .statusCode(400)
        .body("error", equalTo("invalid_grant"));
  }

  @Test
  void exchange_anExpiredCodeIsRefused() {
    String code = approve(USER1, REDIRECT).get("code");
    QuarkusTransaction.requiringNew()
        .run(() ->
            authorizationCodeRepository.update(
                "expiresAt = ?1", Instant.now().minus(Duration.ofMinutes(1))));

    exchange(code, CLIENT, REDIRECT, VERIFIER)
        .statusCode(400)
        .body("error", equalTo("invalid_grant"));
  }

  @Test
  void exchange_onAnotherSiteIsRefused() {
    dataService.createDomain(OTHER_HOST, "Other", "https://" + OTHER_HOST);
    String code = approve(USER1, REDIRECT).get("code");

    given()
        .header("X-Forwarded-Host", OTHER_HOST)
        .contentType(ContentType.URLENC)
        .formParams(
            Map.of(
                "grant_type", "authorization_code",
                "code", code,
                "client_id", CLIENT,
                "redirect_uri", REDIRECT,
                "code_verifier", VERIFIER))
        .when()
        .post("/api/oauth/token")
        .then()
        .statusCode(400)
        .body("error", equalTo("invalid_grant"));
  }

  @Test
  void token_missingParametersAndUnknownGrants() {
    token(Map.of("code", "x")).statusCode(400).body("error", equalTo("invalid_request"));
    token(Map.of("grant_type", "authorization_code", "code", "x"))
        .statusCode(400)
        .body("error", equalTo("invalid_request"));
    token(Map.of("grant_type", "refresh_token"))
        .statusCode(400)
        .body("error", equalTo("invalid_request"));
    token(Map.of("grant_type", "password", "username", "a", "password", "b"))
        .statusCode(400)
        .body("error", equalTo("unsupported_grant_type"));
    exchange("not-a-code", CLIENT, REDIRECT, VERIFIER)
        .statusCode(400)
        .body("error", equalTo("invalid_grant"));
  }

  // --- Refresh ---

  @Test
  void refresh_rotatesTheRefreshTokenAndRenewsTheAccess() {
    JsonPath tokens = connect(USER1);

    JsonPath renewed =
        refresh(tokens.getString("refresh_token"))
            .statusCode(200)
            .body("access_token", not(emptyOrNullString()))
            .body("refresh_token", not(emptyOrNullString()))
            .extract()
            .jsonPath();

    assertEquals(
        false, renewed.getString("refresh_token").equals(tokens.getString("refresh_token")));
    given()
        .auth()
        .oauth2(renewed.getString("access_token"))
        .when()
        .get("/api/users/me")
        .then()
        .statusCode(200);
    refresh(renewed.getString("refresh_token")).statusCode(200);
  }

  @Test
  void refresh_unknownTokenIsRefused() {
    refresh("not-a-refresh-token").statusCode(400).body("error", equalTo("invalid_grant"));
  }

  @Test
  void refresh_aDeviceSessionDoesNotRefreshHere() {
    // A Karoo's refresh token belongs on /api/device/oauth/token.
    String deviceRefreshToken = "device-refresh-token-0123456789";
    QuarkusTransaction.requiringNew()
        .run(() -> {
          var session = dataService.createPairedDevice(user1, "karoo");
          session.setRefreshTokenHash(fr.pedalons.common.TokenUtils.hashToken(deviceRefreshToken));
        });

    refresh(deviceRefreshToken).statusCode(400).body("error", equalTo("invalid_grant"));
  }

  // --- Listed and revoked from the profile ---

  @Test
  void theApplicationIsListedWithTheDevicesAndRevokedFromThere() {
    JsonPath tokens = connect(USER1);
    String me = getAccessToken(USER1);

    String id =
        given()
            .auth()
            .oauth2(me)
            .when()
            .get("/api/users/me/devices")
            .then()
            .statusCode(200)
            .body("", hasSize(1))
            .body("[0].type", equalTo("OTHER"))
            .body("[0].applicationName", equalTo(CLIENT))
            .extract()
            .path("[0].id");

    given().auth().oauth2(me).when().delete("/api/users/me/devices/" + id).then().statusCode(204);

    // Refused at once, access token and refresh token alike.
    given()
        .auth()
        .oauth2(tokens.getString("access_token"))
        .when()
        .get("/api/users/me")
        .then()
        .statusCode(401);
    refresh(tokens.getString("refresh_token"))
        .statusCode(400)
        .body("error", equalTo("invalid_grant"));
  }

  // --- The contract, served by the API ---

  @Test
  void theContractIsPublicUnderApi_withTheDownloadsAndTheTokenEndpoint() {
    given()
        .when()
        .get("/api/openapi?format=json")
        .then()
        .statusCode(200)
        .body("paths", hasKey("/api/oauth/token"))
        .body("paths", hasKey("/api/download/team/assets/{teamSlug}/{assetId}/{fileName}"))
        .body("paths", hasKey("/api/download/public/images/{teamSlug}/{assetId}/{size}"))
        .body("paths", hasKey("/api/download/public/avatars/{fileId}/{size}"))
        .body("paths", hasKey("/api/gpx-previews/{previewId}/gpx"));
  }
}
