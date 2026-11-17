package fr.pedalons.infrastructure.email;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import io.quarkus.mailer.MockMailbox;
import io.quarkus.qute.Engine;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Covers the rendering of {@link EmailService}, which the per-feature mail tests only exercise in
 * French. The mock mailbox receives exactly what the Scaleway SMTP relay would.
 */
@QuarkusTest
class EmailServiceTest extends AbstractBaseTest {

  private static final List<String> TEMPLATE_NAMES =
      List.of(
          EmailService.EMAIL_VERIFICATION,
          EmailService.OTP,
          EmailService.PASSWORD_RESET,
          EmailService.DATA_EXPORT,
          EmailService.AD_CONTACT,
          EmailService.TEAM_INVITATION,
          EmailService.TEAM_INVITATION_SIGNUP);

  /** The union of every template's params, so one map drives all seven. */
  private static final Map<String, Object> ALL_PARAMS =
      Map.ofEntries(
          Map.entry("appName", "Pedalons"),
          Map.entry("displayName", "Test User"),
          Map.entry("verifyUrl", "https://example.test/verify-email?token=tok"),
          Map.entry("resetUrl", "https://example.test/reset-password?token=tok"),
          Map.entry("code", "123456"),
          Map.entry("downloadUrl", "https://example.test/api/export/download/tok"),
          Map.entry("expiresAt", "01/01/2027 12:00"),
          Map.entry("fileSize", "1,2 Mo"),
          Map.entry("recipientName", "Recipient"),
          Map.entry("senderName", "Sender"),
          Map.entry("adName", "Vélo de route"),
          Map.entry("adUrl", "https://example.test/teams/t/classifieds/a"),
          Map.entry("privacyUrl", "https://example.test/profile/privacy"),
          Map.entry("message", "Bonjour, votre annonce m'intéresse."),
          Map.entry("inviterName", "Inviter"),
          Map.entry("teamName", "Team"),
          Map.entry("invitationUrl", "https://example.test/invitation?token=tok"),
          Map.entry("expiresInDays", "7"));

  @Inject EmailService emailService;
  @Inject MockMailbox mailbox;
  @Inject Engine engine;

  @BeforeEach
  void setUp() {
    mailbox.clear();
  }

  /** Every template exists in both languages and both formats, or sending it throws. */
  @Test
  void everyTemplateExistsInBothLanguagesAndBothFormats() {
    for (String name : TEMPLATE_NAMES) {
      for (String language : List.of("fr", "en")) {
        String path = "mail/" + name + "." + language;
        assertNotNull(engine.getTemplate(path + ".txt"), path + ".txt is missing");
        assertNotNull(engine.getTemplate(path + ".html"), path + ".html is missing");
      }
    }
  }

  @Test
  void everyTemplateRendersBothPartsAndASubject() {
    for (String name : TEMPLATE_NAMES) {
      for (String language : List.of("fr", "en")) {
        String to = name + "-" + language + "@example.com";
        emailService.sendEmail(to, name, language, ALL_PARAMS);

        var mail = mailbox.getMailsSentTo(to).getFirst();
        assertFalse(mail.getSubject().isBlank(), name + "/" + language + " has no subject");
        assertFalse(mail.getText().isBlank(), name + "/" + language + " has no text part");
        assertNotNull(mail.getHtml(), name + "/" + language + " has no HTML part");
        assertTrue(
            mail.getHtml().contains("<html>"), name + "/" + language + " HTML is not a page");
        // The subject fragment must not leak into the body.
        assertFalse(
            mail.getText().contains("#fragment"), name + "/" + language + " leaks fragment");
      }
    }
  }

  @Test
  void englishRequestGetsEnglishContent() {
    emailService.sendEmail("en@example.com", EmailService.OTP, "en", ALL_PARAMS);

    var mail = mailbox.getMailsSentTo("en@example.com").getFirst();
    assertEquals("Your login code - Pedalons", mail.getSubject());
    assertTrue(mail.getText().contains("Your login code for Pedalons"));
    assertTrue(mail.getHtml().contains("123456"));
  }

  /** An unknown language falls back to French rather than failing to send at all. */
  @Test
  void unknownLanguageFallsBackToFrench() {
    emailService.sendEmail("de@example.com", EmailService.OTP, "de", ALL_PARAMS);

    var mail = mailbox.getMailsSentTo("de@example.com").getFirst();
    assertEquals("Votre code de connexion - Pedalons", mail.getSubject());
  }

  /** The ad message is the one value a stranger writes; Qute escapes it in the HTML part. */
  @Test
  void userWrittenMessageIsEscapedInTheHtmlPart() {
    var params = new java.util.HashMap<>(ALL_PARAMS);
    params.put("message", "<script>alert('xss')</script>");
    emailService.sendEmail("ad@example.com", EmailService.AD_CONTACT, "fr", params);

    var mail = mailbox.getMailsSentTo("ad@example.com").getFirst();
    assertFalse(mail.getHtml().contains("<script>"));
    assertTrue(mail.getHtml().contains("&lt;script&gt;"));
  }

  /**
   * A name with a line break in it still gets its mail, on one subject line: the mail client
   * refuses a subject holding CR or LF, and the API accepts names that do (SEC-33).
   */
  @Test
  void lineBreaksInANameBecomeSpacesInTheSubject() {
    var params = new java.util.HashMap<>(ALL_PARAMS);
    params.put("senderName", "Sender\nX-Injected: yes");
    params.put("adName", "Vélo\r\nBcc: victim@example.com fin");
    emailService.sendEmail("crlf@example.com", EmailService.AD_CONTACT, "fr", params);

    var mail = mailbox.getMailsSentTo("crlf@example.com").getFirst();
    assertEquals(
        "Sender X-Injected: yes vous écrit au sujet de « Vélo Bcc: victim@example.com fin »",
        mail.getSubject());
  }

  @Test
  void unknownTemplateIsRejected() {
    assertThrows(
        IllegalArgumentException.class,
        () -> emailService.sendEmail("x@example.com", "does-not-exist", "fr", ALL_PARAMS));
  }
}
