package fr.pedalons.api.ads;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.dto.ads.request.AdContactRequest;
import fr.pedalons.dto.ads.request.AdRequest;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.enums.AdType;
import fr.pedalons.enums.Status;
import io.quarkus.mailer.Mail;
import io.quarkus.mailer.MockMailbox;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.math.BigDecimal;
import java.util.List;
import org.hamcrest.Matchers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The contact relay exists so that no contact detail is ever published. These tests are therefore
 * as much about what the API does <em>not</em> return as about what it delivers.
 */
@QuarkusTest
class AdContactResourceTest extends AbstractResourceTest {

  @Inject MockMailbox mailbox;

  private String adSlug;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    mailbox.clear();
    adSlug = createAd();
  }

  private String createAd() {
    return given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body(
            new AdRequest(
                "Vélo de route taille M",
                MediaDto.builder().markdown("Bon état").build(),
                Status.PUBLISHED,
                AdType.SALE,
                BigDecimal.valueOf(900),
                null,
                null,
                null))
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds")
        .then()
        .statusCode(201)
        .extract()
        .path("slug");
  }

  private io.restassured.specification.RequestSpecification as(String user) {
    return given()
        .auth()
        .oauth2(getAccessToken(user))
        .contentType("application/json")
        .body(new AdContactRequest("Bonjour, le vélo est-il toujours disponible ?"));
  }

  @Test
  void contact_asAnotherMember_relaysToAuthorWithReplyToSender() {
    as(USER2)
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds/" + adSlug + "/contact")
        .then()
        .statusCode(204);

    List<Mail> sent = mailbox.getMailsSentTo(user1.getEmail());
    assertEquals(1, sent.size(), "the author receives exactly one message");
    Mail mail = sent.getFirst();
    // The author can answer the buyer; that is the whole mechanism.
    assertTrue(
        mail.getReplyTo().contains(user2.getEmail()),
        "Reply-To must carry the sender so the author can answer");
    assertTrue(mail.getText().contains("Bonjour, le vélo est-il toujours disponible ?"));
    assertTrue(mail.getText().contains(user2.getDisplayName()));
    // The setting that stops these messages is a link, not a menu path to retrace (docs/LEDGER_*.md
    // WEB-98).
    assertTrue(mail.getText().contains("/profile/privacy"), "the text names the privacy URL");
    assertTrue(
        mail.getHtml().contains("/profile/privacy\">"), "the HTML links the privacy setting");
    // The buyer is not copied: they wrote the message, and a copy would be one more place the
    // author's address could leak into.
    assertTrue(mailbox.getMailsSentTo(user2.getEmail()).isEmpty(), "the sender is not copied");
  }

  @Test
  void contact_neverExposesEitherAddressInTheResponse() {
    String body =
        as(USER2)
            .when()
            .post("/api/teams/" + team1Slug + "/classifieds/" + adSlug + "/contact")
            .then()
            .statusCode(204)
            .extract()
            .asString();
    assertTrue(body.isEmpty(), "204 carries no body");

    // Nor does the ad itself, which is the point of relaying rather than publishing.
    String ad =
        given()
            .auth()
            .oauth2(getAccessToken(USER2))
            .when()
            .get("/api/teams/" + team1Slug + "/classifieds/" + adSlug)
            .then()
            .statusCode(200)
            .extract()
            .asString();
    assertFalse(ad.contains(user1.getEmail()), "the ad must not carry the author's address");
    assertFalse(ad.contains(user2.getEmail()), "nor anyone else's");
  }

  @Test
  void contact_ownAd_isRejected() {
    as(USER1)
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds/" + adSlug + "/contact")
        .then()
        .statusCode(400)
        .body("code", Matchers.equalTo("AD_CONTACT_SELF"));

    assertEquals(0, mailbox.getTotalMessagesSent(), "nothing is relayed when the call is refused");
  }

  @Test
  void contact_whenAuthorOptedOut_isRejectedAndSendsNothing() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .contentType("application/json")
        .body("{\"contactableByMembers\": false}")
        .when()
        .patch("/api/users/me/preferences")
        .then()
        .statusCode(200)
        .body("contactableByMembers", Matchers.is(false));

    as(USER2)
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds/" + adSlug + "/contact")
        .then()
        .statusCode(400)
        .body("code", Matchers.equalTo("AD_CONTACT_OPTED_OUT"));

    assertTrue(
        mailbox.getMailsSentTo(user1.getEmail()).isEmpty(),
        "opting out silences the relay rather than merely hiding the button");
  }

  @Test
  void contact_anonymously_isUnauthorized() {
    given()
        .contentType("application/json")
        .body(new AdContactRequest("Bonjour, est-ce toujours disponible ?"))
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds/" + adSlug + "/contact")
        .then()
        .statusCode(401);

    assertEquals(0, mailbox.getTotalMessagesSent(), "nothing is relayed when the call is refused");
  }

  @Test
  void contact_asNonMember_cannotReachTheSellersOfATeamTheyCannotRead() {
    // team2 is the private fixture team; USER1's ad lives in team1, so use a caller with no
    // membership at all rather than a team-specific one.
    String privateAd =
        given()
            .auth()
            .oauth2(getAccessToken(USER1))
            .contentType("application/json")
            .body(
                new AdRequest(
                    "Roues carbone",
                    MediaDto.builder().markdown("Peu servies").build(),
                    Status.PUBLISHED,
                    AdType.SALE,
                    BigDecimal.valueOf(400),
                    null,
                    null,
                    null))
            .when()
            .post("/api/teams/" + team2Slug + "/classifieds")
            .then()
            .statusCode(201)
            .extract()
            .path("slug");
    mailbox.clear();

    as(USER5)
        .when()
        .post("/api/teams/" + team2Slug + "/classifieds/" + privateAd + "/contact")
        .then()
        .statusCode(Matchers.anyOf(Matchers.is(403), Matchers.is(404)));

    assertEquals(0, mailbox.getTotalMessagesSent(), "nothing is relayed when the call is refused");
  }

  @Test
  void contact_withTooShortAMessage_isRejected() {
    given()
        .auth()
        .oauth2(getAccessToken(USER2))
        .contentType("application/json")
        .body(new AdContactRequest("?"))
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds/" + adSlug + "/contact")
        .then()
        .statusCode(400)
        // Our ErrorResponse, not Quarkus's "Constraint Violation" report.
        .body("code", Matchers.equalTo("VALIDATION"))
        .body("errorDetails.type", Matchers.equalTo("VALIDATION"))
        .body("errorDetails.fieldErrors.field", Matchers.contains("message"))
        .body("errorDetails.fieldErrors[0]", Matchers.not(Matchers.hasKey("rejectedValue")));

    assertEquals(0, mailbox.getTotalMessagesSent(), "nothing is relayed when the call is refused");
  }

  @Test
  void contact_pastTheQuota_isRateLimitedPerSenderRatherThanPerAd() {
    // The limit is per sender across every ad, so spreading the messages over two ads must not
    // buy a second allowance.
    String secondAd = createAd();
    int limit = 10;

    for (int i = 0; i < limit; i++) {
      String target = i % 2 == 0 ? adSlug : secondAd;
      as(USER2)
          .when()
          .post("/api/teams/" + team1Slug + "/classifieds/" + target + "/contact")
          .then()
          .statusCode(204);
    }

    as(USER2)
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds/" + adSlug + "/contact")
        .then()
        .statusCode(429)
        .body("code", Matchers.equalTo("AD_CONTACT_RATE_LIMITED"))
        .header("Retry-After", Matchers.notNullValue());

    // Another member still has their own allowance: the quota is per sender, not global.
    as(USER3)
        .when()
        .post("/api/teams/" + team1Slug + "/classifieds/" + adSlug + "/contact")
        .then()
        .statusCode(204);
  }
}
