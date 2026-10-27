package fr.pedalons.api.auth;

import static io.restassured.RestAssured.given;
import static org.hamcrest.MatcherAssert.assertThat;
import static org.hamcrest.Matchers.*;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.auth.AuthToken;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AuthTokenType;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.repository.auth.AuthTokenRepository;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.auth.JwtService;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.mailer.MockMailbox;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class AuthResourceTest extends AbstractResourceTest {

  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject AuthTokenRepository authTokenRepository;
  @Inject UserRepository userRepository;
  @Inject JwtService jwtService;
  @Inject MockMailbox mailbox;

  private Domain domain;

  @BeforeEach
  protected void setUp() {
    super.setUp();
    domain = dataService.getOrCreateDefaultDomain();
    mailbox.clear();
  }

  // --- Register tests ---

  @Test
  void register_shouldReturn200AndSendEmail() {
    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "newuser@example.com",
              "displayName": "New User",
              "acceptTerms": true
            }
            """)
        .when()
        .post("/api/auth/register")
        .then()
        .statusCode(200)
        .body("message", containsString("Verification"));
  }

  @Test
  void register_withInvalidEmail_shouldReturn400() {
    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "not-an-email",
              "displayName": "Test",
              "acceptTerms": true
            }
            """)
        .when()
        .post("/api/auth/register")
        .then()
        .statusCode(400);
  }

  @Test
  void register_withExistingEmail_shouldReturn400() {
    dataService.createVerifiedUser("existing@example.com", "Existing");

    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "existing@example.com",
              "displayName": "Test",
              "acceptTerms": true
            }
            """)
        .when()
        .post("/api/auth/register")
        .then()
        .statusCode(400)
        .body("code", equalTo("EMAIL_ALREADY_EXISTS"));
  }

  @Test
  void register_withoutAcceptingTheTerms_shouldReturn400() {
    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "noterms@example.com",
              "displayName": "No Terms"
            }
            """)
        .when()
        .post("/api/auth/register")
        .then()
        .statusCode(400)
        .body("code", equalTo("VALIDATION"));

    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "noterms@example.com",
              "displayName": "No Terms",
              "acceptTerms": false
            }
            """)
        .when()
        .post("/api/auth/register")
        .then()
        .statusCode(400)
        .body("code", equalTo("VALIDATION"));

    assertThat(mailbox.getMailsSentTo("noterms@example.com").size(), is(0));
  }

  @Test
  void register_withAnOffensiveDisplayName_shouldReturnContentRejected() {
    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "rude@example.com",
              "displayName": "Gros connard",
              "acceptTerms": true
            }
            """)
        .when()
        .post("/api/auth/register")
        .then()
        .statusCode(400)
        .body("code", equalTo("CONTENT_REJECTED"))
        .body("errorDetails.fieldErrors[0].field", equalTo("displayName"));
  }

  @Test
  void register_withMissingFields_shouldReturn400() {
    given()
        .contentType(ContentType.JSON)
        .body("{}")
        .when()
        .post("/api/auth/register")
        .then()
        .statusCode(400);
  }

  // --- Verify Email tests ---

  @Test
  void verifyEmail_withValidToken_shouldReturn200() {
    createVerificationToken("verify@example.com", "Test User", "valid-token");

    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"valid-token\", \"password\": \"ownerpass123\"}")
        .when()
        .post("/api/auth/verify-email")
        .then()
        .statusCode(200)
        .body("accessToken", is(notNullValue()))
        .body("user.email", equalTo("verify@example.com"))
        .cookie("refresh_token", is(notNullValue()));
  }

  @Test
  void verifyEmail_withInvalidToken_shouldReturn400() {
    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"invalid-token\", \"password\": \"ownerpass123\"}")
        .when()
        .post("/api/auth/verify-email")
        .then()
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
  }

  @Test
  void verifyEmail_withExpiredToken_shouldReturn400() {
    createExpiredVerificationToken("expired@example.com", "Test", "expired-token");

    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"expired-token\", \"password\": \"ownerpass123\"}")
        .when()
        .post("/api/auth/verify-email")
        .then()
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
  }

  // --- OTP tests ---

  @Test
  void requestOtp_shouldReturn200() {
    dataService.createVerifiedUser("otp@example.com", "OTP User");

    given()
        .contentType(ContentType.JSON)
        .body("{\"email\": \"otp@example.com\"}")
        .when()
        .post("/api/auth/otp")
        .then()
        .statusCode(200)
        .body("message", containsString("code"));
  }

  @Test
  void requestOtp_withNonexistentEmail_shouldStillReturn200() {
    // Should not reveal if email exists
    given()
        .contentType(ContentType.JSON)
        .body("{\"email\": \"nonexistent@example.com\"}")
        .when()
        .post("/api/auth/otp")
        .then()
        .statusCode(200);
  }

  @Test
  void verifyOtp_withValidCode_shouldReturn200() {
    User user = dataService.createVerifiedUser("otp@example.com", "OTP User");
    createOtpToken(user, "123456");

    given()
        .contentType(ContentType.JSON)
        .body("{\"email\": \"otp@example.com\", \"code\": \"123456\"}")
        .when()
        .post("/api/auth/otp/verify")
        .then()
        .statusCode(200)
        .body("accessToken", is(notNullValue()))
        .body("user.email", equalTo("otp@example.com"))
        .cookie("refresh_token", is(notNullValue()));
  }

  @Test
  void verifyOtp_withInvalidCode_shouldReturn400() {
    User user = dataService.createVerifiedUser("otp@example.com", "OTP User");
    createOtpToken(user, "123456");

    given()
        .contentType(ContentType.JSON)
        .body("{\"email\": \"otp@example.com\", \"code\": \"000000\"}")
        .when()
        .post("/api/auth/otp/verify")
        .then()
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
  }

  // --- Refresh tests ---

  @Test
  void refresh_withValidCookie_shouldReturn200() {
    User user = dataService.createVerifiedUser("refresh@example.com", "Refresh User");
    String refreshToken = dataService.createRefreshTokenForUser(user);

    given()
        .contentType(ContentType.JSON)
        .cookie("refresh_token", refreshToken)
        .when()
        .post("/api/auth/refresh")
        .then()
        .statusCode(200)
        .body("accessToken", is(notNullValue()))
        .body("user.email", equalTo("refresh@example.com"));
  }

  /**
   * The SSR seeds {@code /me} with the refresh's user: without its GPS services, a Karoo back from
   * the Hammerhead authorization stayed on « Associer Hammerhead ».
   */
  @Test
  void refresh_returnsTheConnectedServices() {
    User user = dataService.createVerifiedUser("refresh-gps@example.com", "Refresh Gps");
    dataService.createGpsServiceConnection(user, GpsServiceType.HAMMERHEAD);
    String refreshToken = dataService.createRefreshTokenForUser(user);

    given()
        .contentType(ContentType.JSON)
        .cookie("refresh_token", refreshToken)
        .when()
        .post("/api/auth/refresh")
        .then()
        .statusCode(200)
        .body("user.connectedServices.serviceType", contains("HAMMERHEAD"));
  }

  @Test
  void refresh_withCookie_rotatesTheCookieAndKeepsTheTokenOutOfTheBody() {
    User user = dataService.createVerifiedUser("rotate-web@example.com", "Web User");
    String refreshToken = dataService.createRefreshTokenForUser(user);

    String rotated =
        given()
            .contentType(ContentType.JSON)
            .cookie("refresh_token", refreshToken)
            .when()
            .post("/api/auth/refresh")
            .then()
            .statusCode(200)
            .body("refreshToken", is(nullValue()))
            .extract()
            .cookie("refresh_token");

    assertThat(rotated, allOf(notNullValue(), not(equalTo(refreshToken))));
    // Another tab, still holding the old cookie: served, and the new cookie is left as it is.
    given()
        .contentType(ContentType.JSON)
        .cookie("refresh_token", refreshToken)
        .when()
        .post("/api/auth/refresh")
        .then()
        .statusCode(200)
        .body("accessToken", is(notNullValue()))
        .header("Set-Cookie", is(nullValue()));
  }

  @Test
  void refresh_withHeader_returnsTheRotatedTokenInTheBody() {
    User user = dataService.createVerifiedUser("rotate-app@example.com", "App User");
    String refreshToken = dataService.createRefreshTokenForUser(user);

    String rotated =
        given()
            .contentType(ContentType.JSON)
            .header("X-Refresh-Token", refreshToken)
            .when()
            .post("/api/auth/refresh")
            .then()
            .statusCode(200)
            .extract()
            .path("refreshToken");

    assertThat(rotated, allOf(notNullValue(), not(equalTo(refreshToken))));
    given()
        .contentType(ContentType.JSON)
        .header("X-Refresh-Token", rotated)
        .when()
        .post("/api/auth/refresh")
        .then()
        .statusCode(200)
        .body("refreshToken", is(notNullValue()));
  }

  @Test
  void refresh_withoutCookie_shouldReturn403() {
    given().contentType(ContentType.JSON).when().post("/api/auth/refresh").then().statusCode(403);
  }

  @Test
  void refresh_withInvalidCookie_shouldReturn403() {
    given()
        .contentType(ContentType.JSON)
        .cookie("refresh_token", "invalid-token")
        .when()
        .post("/api/auth/refresh")
        .then()
        .statusCode(403);
  }

  // --- Logout tests ---

  @Test
  void logout_shouldReturn204AndDeleteCookie() {
    User user = dataService.createVerifiedUser("logout@example.com", "Logout User");
    String refreshToken = dataService.createRefreshTokenForUser(user);

    given()
        .contentType(ContentType.JSON)
        .cookie("refresh_token", refreshToken)
        .when()
        .post("/api/auth/logout")
        .then()
        .statusCode(204)
        .cookie("refresh_token", equalTo(""));
  }

  @Test
  void logout_withoutCookie_shouldStillReturn204() {
    given().contentType(ContentType.JSON).when().post("/api/auth/logout").then().statusCode(204);
  }

  @Test
  void logout_shouldInvalidateRefreshToken() {
    User user = dataService.createVerifiedUser("logout@example.com", "Logout User");
    String refreshToken = dataService.createRefreshTokenForUser(user);

    // Logout
    given()
        .contentType(ContentType.JSON)
        .cookie("refresh_token", refreshToken)
        .when()
        .post("/api/auth/logout")
        .then()
        .statusCode(204);

    // Try to refresh with same token
    given()
        .contentType(ContentType.JSON)
        .cookie("refresh_token", refreshToken)
        .when()
        .post("/api/auth/refresh")
        .then()
        .statusCode(403);
  }

  // --- Logout All tests ---

  @Test
  void logoutAll_withAuth_shouldReturn204() {
    User user = dataService.createVerifiedUser("logoutall@example.com", "Logout All User");
    String accessToken = jwtService.generateAccessToken(user);

    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(accessToken)
        .when()
        .post("/api/auth/logout-all")
        .then()
        .statusCode(204);
  }

  @Test
  void logoutAll_withoutAuth_shouldReturn401() {
    given()
        .contentType(ContentType.JSON)
        .when()
        .post("/api/auth/logout-all")
        .then()
        .statusCode(401);
  }

  @Test
  void logoutAll_shouldInvalidateAllSessions() {
    User user = dataService.createVerifiedUser("logoutall@example.com", "User");
    String accessToken = jwtService.generateAccessToken(user);
    String refreshToken1 = dataService.createRefreshTokenForUser(user);
    String refreshToken2 = dataService.createRefreshTokenForUser(user);

    // Logout all
    given()
        .contentType(ContentType.JSON)
        .auth()
        .oauth2(accessToken)
        .when()
        .post("/api/auth/logout-all")
        .then()
        .statusCode(204);

    // Both refresh tokens should be invalid
    given()
        .contentType(ContentType.JSON)
        .cookie("refresh_token", refreshToken1)
        .when()
        .post("/api/auth/refresh")
        .then()
        .statusCode(403);

    given()
        .contentType(ContentType.JSON)
        .cookie("refresh_token", refreshToken2)
        .when()
        .post("/api/auth/refresh")
        .then()
        .statusCode(403);
  }

  // --- Login (password) tests ---

  @Test
  void login_withValidCredentials_shouldReturn200() {
    createVerifiedUserWithPassword("login@example.com", "Login User", "mypassword123");

    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "login@example.com",
              "password": "mypassword123"
            }
            """)
        .when()
        .post("/api/auth/login")
        .then()
        .statusCode(200)
        .body("accessToken", is(notNullValue()))
        .body("user.email", equalTo("login@example.com"))
        .cookie("refresh_token", is(notNullValue()));
  }

  @Test
  void login_withWrongPassword_shouldReturn400() {
    createVerifiedUserWithPassword("login@example.com", "Login User", "mypassword123");

    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "login@example.com",
              "password": "wrongpassword"
            }
            """)
        .when()
        .post("/api/auth/login")
        .then()
        .statusCode(400)
        .body("code", equalTo("INVALID_CREDENTIALS"));
  }

  // --- Password throttle (docs/LEDGER_*.md SEC-7, audit M4) ---

  private io.restassured.response.ValidatableResponse login(String email, String password) {
    return given()
        .contentType(ContentType.JSON)
        .body("{\"email\": \"" + email + "\", \"password\": \"" + password + "\"}")
        .when()
        .post("/api/auth/login")
        .then();
  }

  @Test
  void login_afterFiveWrongPasswords_isRefusedEvenWithTheRightOne() {
    createVerifiedUserWithPassword("stuffed@example.com", "Login User", "mypassword123");
    for (int i = 0; i < 5; i++) {
      login("stuffed@example.com", "guess" + i).statusCode(400);
    }

    login("stuffed@example.com", "mypassword123")
        .statusCode(429)
        .header("Retry-After", "900")
        .body("code", equalTo("LOGIN_RATE_LIMITED"));
  }

  @Test
  void login_throttleIgnoresTheCaseOfTheAddress() {
    createVerifiedUserWithPassword("stuffed@example.com", "Login User", "mypassword123");
    for (int i = 0; i < 5; i++) {
      login(i % 2 == 0 ? "Stuffed@Example.com" : "stuffed@example.com", "guess" + i)
          .statusCode(400);
    }

    login("stuffed@example.com", "mypassword123").statusCode(429);
  }

  @Test
  void login_unknownAddress_isThrottledLikeAnAccount() {
    // Answering 400 for ever here while an account locks would tell which addresses exist.
    for (int i = 0; i < 5; i++) {
      login("ghost@example.com", "guess" + i).statusCode(400);
    }

    login("ghost@example.com", "guess").statusCode(429).body("code", equalTo("LOGIN_RATE_LIMITED"));
  }

  @Test
  void login_rightPassword_wipesTheEarlierFailures() {
    createVerifiedUserWithPassword("typo@example.com", "Login User", "mypassword123");
    for (int i = 0; i < 4; i++) {
      login("typo@example.com", "typo" + i).statusCode(400);
    }
    login("typo@example.com", "mypassword123").statusCode(200);

    for (int i = 0; i < 4; i++) {
      login("typo@example.com", "typo" + i).statusCode(400);
    }
    login("typo@example.com", "mypassword123").statusCode(200);
  }

  @Test
  void login_throttleIsPerAddress() {
    createVerifiedUserWithPassword("stuffed@example.com", "Login User", "mypassword123");
    createVerifiedUserWithPassword("bystander@example.com", "Other User", "mypassword123");
    for (int i = 0; i < 5; i++) {
      login("stuffed@example.com", "guess" + i).statusCode(400);
    }

    login("bystander@example.com", "mypassword123").statusCode(200);
  }

  @Test
  void login_withNoPasswordSet_shouldReturn400WithInvalidCredentials() {
    dataService.createVerifiedUser("nopassword@example.com", "No Password User");

    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "nopassword@example.com",
              "password": "anypassword"
            }
            """)
        .when()
        .post("/api/auth/login")
        .then()
        .statusCode(400)
        .body("code", equalTo("INVALID_CREDENTIALS"));
  }

  @Test
  void login_withNonexistentEmail_shouldReturn400WithInvalidCredentials() {
    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "ghost@example.com",
              "password": "anypassword"
            }
            """)
        .when()
        .post("/api/auth/login")
        .then()
        .statusCode(400)
        .body("code", equalTo("INVALID_CREDENTIALS"));
  }

  // --- Sign-up link: address shown first, password chosen on activation (SEC-9, SEC-24) ---

  @Test
  void register_storesNoPassword() {
    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "pwdregister@example.com",
              "displayName": "Pwd User",
              "acceptTerms": true
            }
            """)
        .when()
        .post("/api/auth/register")
        .then()
        .statusCode(200);

    AuthToken token =
        authTokenRepository
            .findValidByEmailAndType(
                "pwdregister@example.com", AuthTokenType.EMAIL_VERIFICATION, domain.getId())
            .orElseThrow();
    // No password travels with the link: AuthToken has no column for one any more
    // (docs/LEDGER_*.md API-57).
    assertThat(token.getPendingTermsAcceptedAt(), is(notNullValue()));
  }

  /**
   * Audit L4: whoever typed the address at sign-up chose the password, and it survived the owner's
   * click. The password is now chosen on activation only — the token carries none
   * (docs/LEDGER_*.md API-57).
   */
  @Test
  void verifyEmail_setsThePasswordChosenOnActivation() {
    createSignUpVerificationToken("pwdverify@example.com", "Pwd Verify", "verify-pwd-token");

    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"verify-pwd-token\", \"password\": \"ownerpass123\"}")
        .when()
        .post("/api/auth/verify-email")
        .then()
        .statusCode(200)
        .body("accessToken", is(notNullValue()));

    User user = dataService.findUserByEmail("pwdverify@example.com");
    assertThat(user.getTermsAcceptedAt(), is(notNullValue()));
    login("pwdverify@example.com", "ownerpass123").statusCode(200);
  }

  @Test
  void verifyEmail_withoutAPassword_isRefusedAndSpendsNothing() {
    createVerificationToken("nopwd@example.com", "No Pwd", "no-pwd-token");

    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"no-pwd-token\"}")
        .when()
        .post("/api/auth/verify-email")
        .then()
        .statusCode(400)
        .body("code", equalTo("VALIDATION"));

    preview("no-pwd-token").statusCode(200);
  }

  @Test
  void preview_showsTheAddress_opensNoSession_andSpendsNothing() {
    createVerificationToken("preview@example.com", "Preview", "preview-token");

    preview("preview-token")
        .statusCode(200)
        .body("email", equalTo("preview@example.com"))
        .body("kind", equalTo("SIGN_UP"))
        .body("accessToken", is(nullValue()))
        .header("Set-Cookie", is(nullValue()));
    preview("preview-token").statusCode(200);

    assertThat(userRepository.count("email", "preview@example.com"), is(0L));
  }

  @Test
  void preview_ofAnInvalidLink_isRefused() {
    preview("no-such-token").statusCode(400).body("code", equalTo("TOKEN_INVALID"));
  }

  @Test
  void preview_ofALinkFromAnotherSite_isRefused() {
    Domain other =
        dataService.createDomain("other.example.com", "Other", "https://other.example.com");
    createVerificationToken("elsewhere@example.com", "Elsewhere", "elsewhere-token", other);

    preview("elsewhere-token").statusCode(400).body("code", equalTo("TOKEN_INVALID"));
  }

  /** Audit M5, second door: an address-change link signed its follower into the account. */
  @Test
  void confirmEmailChange_changesTheAddress_andOpensNoSession() {
    User user = dataService.createVerifiedUser("before@example.com", "Changing");
    createEmailChangeToken(user, "after@example.com", "change-token");

    preview("change-token")
        .statusCode(200)
        .body("email", equalTo("after@example.com"))
        .body("kind", equalTo("EMAIL_CHANGE"));

    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"change-token\"}")
        .when()
        .post("/api/auth/confirm-email-change")
        .then()
        .statusCode(204)
        .header("Set-Cookie", is(nullValue()));

    assertThat(dataService.findUserByEmail("after@example.com").getId(), equalTo(user.getId()));
    // Spent.
    preview("change-token").statusCode(400);
  }

  /**
   * The access tokens still running on the member's other devices carry the old address: they must
   * keep opening the account until they expire (docs/LEDGER_*.md API-73).
   */
  @Test
  void confirmEmailChange_keepsTheAccessTokensIssuedBeforeIt() {
    User user = dataService.createVerifiedUser("stale@example.com", "Stale");
    String accessTokenBefore = jwtService.generateAccessToken(user);
    createEmailChangeToken(user, "fresh@example.com", "stale-change-token");

    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"stale-change-token\"}")
        .when()
        .post("/api/auth/confirm-email-change")
        .then()
        .statusCode(204);

    given()
        .auth()
        .oauth2(accessTokenBefore)
        .when()
        .get("/api/users/me")
        .then()
        .statusCode(200)
        .body("email", equalTo("fresh@example.com"));
  }

  @Test
  void eachLinkOpensOnlyItsOwnDoor() {
    User user = dataService.createVerifiedUser("door@example.com", "Door");
    createEmailChangeToken(user, "door-new@example.com", "door-change-token");
    createVerificationToken("door-signup@example.com", "Door Signup", "door-signup-token");

    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"door-change-token\", \"password\": \"ownerpass123\"}")
        .when()
        .post("/api/auth/verify-email")
        .then()
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"door-signup-token\"}")
        .when()
        .post("/api/auth/confirm-email-change")
        .then()
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
  }

  private io.restassured.response.ValidatableResponse preview(String token) {
    return given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"" + token + "\"}")
        .when()
        .post("/api/auth/verify-email/preview")
        .then();
  }

  /** A token issued before the form asked: the account must not record a consent never given. */
  @Test
  void verifyEmail_withATokenIssuedBeforeTheTermsCheckbox_recordsNoAcceptance() {
    createVerificationToken("legacyterms@example.com", "Legacy Terms", "legacy-terms-token");

    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"legacy-terms-token\", \"password\": \"ownerpass123\"}")
        .when()
        .post("/api/auth/verify-email")
        .then()
        .statusCode(200);

    User user = dataService.findUserByEmail("legacyterms@example.com");
    assertThat(user.getTermsAcceptedAt(), is(nullValue()));
  }

  // --- Forgot password tests ---

  @Test
  void forgotPassword_withExistingUser_shouldReturn200AndSendEmail() {
    createVerifiedUserWithPassword("forgot@example.com", "Forgot User", "oldpassword");
    mailbox.clear();

    given()
        .contentType(ContentType.JSON)
        .body("{\"email\": \"forgot@example.com\"}")
        .when()
        .post("/api/auth/forgot-password")
        .then()
        .statusCode(200)
        .body("message", is(notNullValue()));

    assertThat(mailbox.getMailsSentTo("forgot@example.com").size(), is(1));
  }

  /** docs/LEDGER_*.md API-146: the address typed with other capitals still finds the account. */
  @Test
  void forgotPassword_ignoresTheCaseOfTheAddress() {
    createVerifiedUserWithPassword("forgot@example.com", "Forgot User", "oldpassword");
    mailbox.clear();

    given()
        .contentType(ContentType.JSON)
        .body("{\"email\": \" Forgot@Example.COM \"}")
        .when()
        .post("/api/auth/forgot-password")
        .then()
        .statusCode(200);

    assertThat(mailbox.getMailsSentTo("forgot@example.com").size(), is(1));
  }

  @Test
  void login_ignoresTheCaseOfTheAddress() {
    createVerifiedUserWithPassword("login@example.com", "Login User", "mypassword123");

    login("Login@Example.com", "mypassword123")
        .statusCode(200)
        .body("user.email", equalTo("login@example.com"));
  }

  @Test
  void register_storesTheAddressInLowerCase() {
    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "NewUser@Example.com",
              "displayName": "New User",
              "acceptTerms": true
            }
            """)
        .when()
        .post("/api/auth/register")
        .then()
        .statusCode(200);

    assertThat(mailbox.getMailsSentTo("newuser@example.com").size(), is(1));
  }

  @Test
  void forgotPassword_withNonexistentEmail_shouldStillReturn200() {
    given()
        .contentType(ContentType.JSON)
        .body("{\"email\": \"ghost@example.com\"}")
        .when()
        .post("/api/auth/forgot-password")
        .then()
        .statusCode(200);
  }

  @Test
  void resetPassword_withValidToken_shouldReturn200AndLogin() {
    createVerifiedUserWithPassword("reset@example.com", "Reset User", "oldpassword");
    createPasswordResetToken("reset@example.com", "reset-token-654321");

    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "token": "reset-token-654321",
              "newPassword": "newpassword123"
            }
            """)
        .when()
        .post("/api/auth/reset-password")
        .then()
        .statusCode(200)
        .body("accessToken", is(notNullValue()))
        .body("user.email", equalTo("reset@example.com"))
        .cookie("refresh_token", is(notNullValue()));
  }

  @Test
  void resetPassword_withInvalidToken_shouldReturn400() {
    createVerifiedUserWithPassword("reset@example.com", "Reset User", "oldpassword");
    createPasswordResetToken("reset@example.com", "reset-token-654321");

    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "token": "wrong-token",
              "newPassword": "newpassword123"
            }
            """)
        .when()
        .post("/api/auth/reset-password")
        .then()
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
  }

  @Test
  void resetPassword_afterReset_shouldAllowLoginWithNewPassword() {
    createVerifiedUserWithPassword("reset2@example.com", "Reset2 User", "oldpassword");
    createPasswordResetToken("reset2@example.com", "reset-token-111222");

    // Reset password
    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "token": "reset-token-111222",
              "newPassword": "brandnewpass"
            }
            """)
        .when()
        .post("/api/auth/reset-password")
        .then()
        .statusCode(200);

    // Login with new password
    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "email": "reset2@example.com",
              "password": "brandnewpass"
            }
            """)
        .when()
        .post("/api/auth/login")
        .then()
        .statusCode(200)
        .body("accessToken", is(notNullValue()));
  }

  @Test
  void resetPassword_withAlreadyUsedToken_shouldReturn400() {
    createVerifiedUserWithPassword("reset3@example.com", "Reset3 User", "oldpassword");
    createPasswordResetToken("reset3@example.com", "reset-token-777888");

    // First use succeeds
    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "token": "reset-token-777888",
              "newPassword": "newpassword123"
            }
            """)
        .when()
        .post("/api/auth/reset-password")
        .then()
        .statusCode(200);

    // Second use must fail — token is consumed
    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "token": "reset-token-777888",
              "newPassword": "anotherpassword"
            }
            """)
        .when()
        .post("/api/auth/reset-password")
        .then()
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
  }

  @Test
  void verifyEmail_withAlreadyUsedToken_shouldReturn400() {
    createVerificationToken("verify2@example.com", "Test User2", "reuse-token");

    // First use succeeds
    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"reuse-token\", \"password\": \"ownerpass123\"}")
        .when()
        .post("/api/auth/verify-email")
        .then()
        .statusCode(200);

    // Second use must fail — token is consumed
    given()
        .contentType(ContentType.JSON)
        .body("{\"token\": \"reuse-token\", \"password\": \"ownerpass123\"}")
        .when()
        .post("/api/auth/verify-email")
        .then()
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
  }

  @Test
  void resetPassword_withExpiredToken_shouldReturn400() {
    createVerifiedUserWithPassword("reset4@example.com", "Reset4 User", "oldpassword");
    createExpiredPasswordResetToken("reset4@example.com", "reset-token-999111");

    given()
        .contentType(ContentType.JSON)
        .body(
            """
            {
              "token": "reset-token-999111",
              "newPassword": "newpassword123"
            }
            """)
        .when()
        .post("/api/auth/reset-password")
        .then()
        .statusCode(400)
        .body("code", equalTo("TOKEN_INVALID"));
  }

  // --- Helper methods ---

  void createVerificationToken(String email, String displayName, String token) {
    createVerificationToken(email, displayName, token, domain);
  }

  @Transactional
  void createVerificationToken(String email, String displayName, String token, Domain on) {
    String tokenHash = hashToken(token);
    AuthToken authToken =
        new AuthToken(
            email,
            tokenHash,
            AuthTokenType.EMAIL_VERIFICATION,
            Instant.now().plus(24, ChronoUnit.HOURS),
            on.getId());
    authToken.setPendingDisplayName(displayName);
    authToken.setPendingDomainId(on.getId());
    authTokenRepository.persist(authToken);
  }

  @Transactional
  void createEmailChangeToken(User user, String newEmail, String token) {
    authTokenRepository.persist(
        new AuthToken(
            userRepository.findById(user.getId()),
            newEmail,
            hashToken(token),
            AuthTokenType.EMAIL_CHANGE,
            Instant.now().plus(24, ChronoUnit.HOURS),
            domain.getId()));
  }

  @Transactional
  void createExpiredVerificationToken(String email, String displayName, String token) {
    String tokenHash = hashToken(token);
    AuthToken authToken =
        new AuthToken(
            email,
            tokenHash,
            AuthTokenType.EMAIL_VERIFICATION,
            Instant.now().minus(1, ChronoUnit.HOURS),
            domain.getId());
    authToken.setPendingDisplayName(displayName);
    authToken.setPendingDomainId(domain.getId());
    authTokenRepository.persist(authToken);
  }

  @Transactional
  void createOtpToken(User user, String code) {
    String tokenHash = hashToken(code);
    AuthToken authToken =
        new AuthToken(
            user,
            user.getEmail(),
            tokenHash,
            AuthTokenType.OTP,
            Instant.now().plus(5, ChronoUnit.MINUTES),
            domain.getId());
    authTokenRepository.persist(authToken);
  }

  @Transactional
  void createVerifiedUserWithPassword(String email, String displayName, String password) {
    Domain domain = dataService.getOrCreateDefaultDomain();
    User user = new User(domain, email, displayName);
    user.markEmailVerified();
    user.setPasswordHash(io.quarkus.elytron.security.common.BcryptUtil.bcryptHash(password));
    userRepository.persistAndFlush(user);
  }

  @Transactional
  void createSignUpVerificationToken(String email, String displayName, String token) {
    String tokenHash = hashToken(token);
    AuthToken authToken =
        new AuthToken(
            email,
            tokenHash,
            AuthTokenType.EMAIL_VERIFICATION,
            Instant.now().plus(24, ChronoUnit.HOURS),
            domain.getId());
    authToken.setPendingDisplayName(displayName);
    authToken.setPendingDomainId(domain.getId());
    // As register does: the sign-up form's terms checkbox was ticked.
    authToken.setPendingTermsAcceptedAt(authToken.getCreatedAt());
    authTokenRepository.persist(authToken);
  }

  @Transactional
  void createPasswordResetToken(String email, String code) {
    User user = userRepository.findByEmailAndDomain(domain.getId(), email).orElseThrow();
    String tokenHash = hashToken(code);
    AuthToken authToken =
        new AuthToken(
            user,
            email,
            tokenHash,
            fr.pedalons.enums.AuthTokenType.PASSWORD_RESET,
            Instant.now().plus(5, ChronoUnit.MINUTES),
            domain.getId());
    authTokenRepository.persist(authToken);
  }

  @Transactional
  void createExpiredPasswordResetToken(String email, String code) {
    User user = userRepository.findByEmailAndDomain(domain.getId(), email).orElseThrow();
    String tokenHash = hashToken(code);
    AuthToken authToken =
        new AuthToken(
            user,
            email,
            tokenHash,
            fr.pedalons.enums.AuthTokenType.PASSWORD_RESET,
            Instant.now().minus(1, ChronoUnit.HOURS),
            domain.getId());
    authTokenRepository.persist(authToken);
  }

  private String hashToken(String token) {
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      byte[] hash = digest.digest(token.getBytes(StandardCharsets.UTF_8));
      return Base64.getEncoder().encodeToString(hash);
    } catch (NoSuchAlgorithmException e) {
      throw new RuntimeException("SHA-256 not available", e);
    }
  }
}
