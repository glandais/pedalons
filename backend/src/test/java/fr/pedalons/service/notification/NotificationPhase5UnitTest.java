package fr.pedalons.service.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.enums.NotificationChange;
import fr.pedalons.enums.NotificationSubjectType;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.enums.TeamWebhookKind;
import fr.pedalons.infrastructure.webhook.WebhookHttpClient;
import java.net.URI;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

/** The pure parts of phase 5: digest time, webhook format and address checks, texts. */
class NotificationPhase5UnitTest {

  private final NotificationTexts texts = new NotificationTexts();

  @Test
  void nextDigest_isTheNextSevenOClock_inTheRecipientsZone() {
    // 05:00 UTC = 07:00 in Paris (summer): exactly on time is not "after", so tomorrow.
    assertEquals(
        Instant.parse("2026-09-22T05:00:00Z"),
        NotificationDispatchService.nextDigest(Instant.parse("2026-09-21T05:00:00Z"), null));
    assertEquals(
        Instant.parse("2026-09-21T05:00:00Z"),
        NotificationDispatchService.nextDigest(
            Instant.parse("2026-09-20T22:00:00Z"), "Europe/Paris"));
    assertEquals(
        Instant.parse("2026-09-21T11:00:00Z"),
        NotificationDispatchService.nextDigest(
            Instant.parse("2026-09-21T06:00:00Z"), "America/New_York"));
  }

  @Test
  void webhookKind_isReadFromTheUrl() {
    assertEquals(
        TeamWebhookKind.SLACK,
        TeamWebhookKind.of(URI.create("https://hooks.slack.com/services/a")));
    assertEquals(
        TeamWebhookKind.DISCORD,
        TeamWebhookKind.of(URI.create("https://discord.com/api/webhooks/1/abc")));
    assertEquals(
        TeamWebhookKind.GENERIC, TeamWebhookKind.of(URI.create("https://discord.com/channels/1")));
    assertEquals(TeamWebhookKind.GENERIC, TeamWebhookKind.of(URI.create("https://example.org/h")));
    assertEquals(
        TeamWebhookKind.MATTERMOST,
        TeamWebhookKind.of(URI.create("https://chat.club.fr/hooks/xjh4mk3ow7fg5edtcz8bdcfr1e")));
    assertEquals(
        TeamWebhookKind.GENERIC,
        TeamWebhookKind.of(URI.create("https://example.org/hooks/not-a-mattermost-id")));
  }

  @Test
  void mattermostText_cannotPingTheChannel_norBreakTheMarkdown() {
    String escaped = TeamWebhookMessages.mattermostEscape("Sortie *rapide* @channel <b>");
    assertFalse(escaped.contains("@channel"), escaped);
    assertTrue(escaped.contains("@\u200Bchannel"), escaped);
    assertTrue(escaped.contains("\\*rapide\\*"), escaped);
    assertTrue(escaped.contains("&lt;b&gt;"), escaped);
  }

  @Test
  void webhookUrl_mustBeHttpsToAPublicHost() {
    assertTrue(WebhookHttpClient.isAcceptable(URI.create("https://example.org/hook")));
    assertFalse(WebhookHttpClient.isAcceptable(URI.create("http://example.org/hook")));
    assertFalse(WebhookHttpClient.isAcceptable(URI.create("https://localhost/hook")));
    assertFalse(WebhookHttpClient.isAcceptable(URI.create("https://127.0.0.1/hook")));
    assertFalse(WebhookHttpClient.isAcceptable(URI.create("https://192.168.1.10/hook")));
    assertFalse(WebhookHttpClient.isAcceptable(URI.create("https://100.64.0.1/hook")));
    assertFalse(WebhookHttpClient.isAcceptable(URI.create("https://[::1]/hook")));
    assertFalse(WebhookHttpClient.isAcceptable(URI.create("https://[fd00::1]/hook")));
    assertFalse(WebhookHttpClient.isAcceptable(URI.create("https://user:pw@example.org/hook")));
  }

  @Test
  void slackControlCharacters_areEscaped() {
    assertEquals("a &lt;b&gt; &amp; c", TeamWebhookMessages.slackEscape("a <b> & c"));
  }

  @Test
  void rideUpdated_saysWhatChanged() {
    NotificationTexts.Rendered rendered =
        texts.render(
            NotificationType.RIDE_UPDATED,
            "fr",
            NotificationTexts.Zones.forReader("Europe/Paris", "Europe/Paris"),
            "Alice",
            "Le Club",
            "Col du Galibier",
            Instant.parse("2026-09-20T06:30:00Z"),
            null,
            "Pédalons",
            List.of(NotificationChange.DATE_TIME, NotificationChange.START_PLACE));
    assertTrue(rendered.body().contains("08:30"), rendered.body());
    assertTrue(rendered.body().contains("point de départ"), rendered.body());
  }

  @Test
  void frameTexts_areCompleteInEveryLanguage() {
    for (String language : NotificationTexts.languages()) {
      assertTrue(NotificationTexts.isFrameComplete(texts.bundle(language)), language);
    }
  }

  @Test
  void teamSubject_opensTheTeamList() {
    assertEquals(
        "/teams", NotificationLinks.subjectPath(NotificationSubjectType.TEAM, "club", "club"));
  }
}
