package fr.pedalons.infrastructure.push;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.enums.PushPlatform;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** The platform-specific shape of an FCM message — plain unit tests, no Quarkus. */
class FcmMessageTest {

  private static final Map<String, String> DATA = Map.of("path", "/teams/t/rides/r");
  private static final Instant NOW = Instant.parse("2026-11-17T10:00:00Z");
  private static final Instant IN_TWO_HOURS = NOW.plus(2, ChronoUnit.HOURS);

  @Test
  void web_isDataOnly_withTitleAndBodyInData() {
    Map<String, Object> message =
        FcmClient.message("token", PushPlatform.WEB, "Title", "Body", DATA, null, NOW);

    // The service worker shows the notification: a notification block would show it twice.
    assertFalse(message.containsKey("notification"));
    @SuppressWarnings("unchecked")
    Map<String, String> data = (Map<String, String>) message.get("data");
    assertEquals("Title", data.get("title"));
    assertEquals("Body", data.get("body"));
    assertEquals("/teams/t/rides/r", data.get("path"));
    assertTrue(message.containsKey("webpush"));
    assertFalse(message.containsKey("android"));
    assertFalse(message.containsKey("apns"));
  }

  @Test
  void android_keepsTheNotificationBlock() {
    Map<String, Object> message =
        FcmClient.message("token", PushPlatform.ANDROID, "Title", "Body", DATA, null, NOW);

    assertEquals(Map.of("title", "Title", "body", "Body"), message.get("notification"));
    assertEquals(DATA, message.get("data"));
    assertTrue(message.containsKey("android"));
  }

  // NOTIF-16: a phone switched back on after the ride left must not ring about it.

  @Test
  void android_withAnExpiry_isKeptUntilIt() {
    Map<String, Object> message =
        FcmClient.message("token", PushPlatform.ANDROID, "T", "B", DATA, IN_TWO_HOURS, NOW);

    assertEquals("7200s", android(message).get("ttl"));
    assertEquals("high", android(message).get("priority"));
  }

  @Test
  void android_withoutAnExpiry_keepsFcmsDefault() {
    Map<String, Object> message =
        FcmClient.message("token", PushPlatform.ANDROID, "T", "B", DATA, null, NOW);

    assertFalse(android(message).containsKey("ttl"));
  }

  @Test
  void android_farExpiry_isCappedAtFcmsCeiling() {
    Map<String, Object> message =
        FcmClient.message(
            "token", PushPlatform.ANDROID, "T", "B", DATA, NOW.plus(60, ChronoUnit.DAYS), NOW);

    assertEquals(FcmClient.ANDROID_MAX_TTL.toSeconds() + "s", android(message).get("ttl"));
  }

  @Test
  void ios_withAnExpiry_carriesItAsAnAbsoluteTime() {
    Map<String, Object> message =
        FcmClient.message("token", PushPlatform.IOS, "T", "B", DATA, IN_TWO_HOURS, NOW);

    assertEquals(
        Long.toString(IN_TWO_HOURS.getEpochSecond()), apnsHeaders(message).get("apns-expiration"));
    assertEquals("10", apnsHeaders(message).get("apns-priority"));
  }

  @Test
  void ios_withoutAnExpiry_setsNone() {
    Map<String, Object> message =
        FcmClient.message("token", PushPlatform.IOS, "T", "B", DATA, null, NOW);

    assertFalse(apnsHeaders(message).containsKey("apns-expiration"));
  }

  @Test
  void web_ttl_isTheSoonerOfTheExpiryAndADay() {
    assertEquals(
        "7200",
        webHeaders(FcmClient.message("t", PushPlatform.WEB, "T", "B", DATA, IN_TWO_HOURS, NOW))
            .get("TTL"));
    assertEquals(
        "86400",
        webHeaders(
                FcmClient.message(
                    "t", PushPlatform.WEB, "T", "B", DATA, NOW.plus(3, ChronoUnit.DAYS), NOW))
            .get("TTL"));
    assertEquals(
        "86400",
        webHeaders(FcmClient.message("t", PushPlatform.WEB, "T", "B", DATA, null, NOW)).get("TTL"));
  }

  /** Zero would mean "now or never" to FCM: an expiry already reached still gets a second. */
  @Test
  void anExpiryAlreadyReached_neverGivesAZeroTtl() {
    Map<String, Object> message =
        FcmClient.message("token", PushPlatform.ANDROID, "T", "B", DATA, NOW.minusSeconds(5), NOW);

    assertEquals("1s", android(message).get("ttl"));
  }

  @SuppressWarnings("unchecked")
  private static Map<String, Object> android(Map<String, Object> message) {
    return (Map<String, Object>) message.get("android");
  }

  @SuppressWarnings("unchecked")
  private static Map<String, String> apnsHeaders(Map<String, Object> message) {
    return (Map<String, String>) ((Map<String, Object>) message.get("apns")).get("headers");
  }

  @SuppressWarnings("unchecked")
  private static Map<String, String> webHeaders(Map<String, Object> message) {
    return (Map<String, String>) ((Map<String, Object>) message.get("webpush")).get("headers");
  }
}
