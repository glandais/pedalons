package fr.pedalons.service.migration.live;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;

/** Signs biketeam request tokens the way biketeam does (§3.2 of the plan), for the tests. */
public final class BiketeamTestTokens {

  /** Bytes 0x00…0x1f, the key of the §3.2 test vector. */
  public static final String KEY_BASE64 = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=";

  /** {@code %test.pedalons.biketeam.public-url} of application.properties. */
  public static final String PUBLIC_URL = "https://biketeam.example";

  /** {@code %test.pedalons.biketeam.trigger-secret} of application.properties. */
  public static final String TRIGGER_SECRET = "test-trigger-secret";

  public static final String HS256_HEADER = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";

  private BiketeamTestTokens() {}

  public static byte[] key() {
    return Base64.getDecoder().decode(KEY_BASE64);
  }

  public static String b64(String json) {
    return Base64.getUrlEncoder()
        .withoutPadding()
        .encodeToString(json.getBytes(StandardCharsets.UTF_8));
  }

  /** {@code header64.payload64.signature64}, signed with {@link #key()}. */
  public static String sign(String headerJson, String payloadJson) {
    String signingInput = b64(headerJson) + "." + b64(payloadJson);
    byte[] sig = BiketeamRequestTokenVerifier.hmac(key(), signingInput);
    return signingInput + "." + Base64.getUrlEncoder().withoutPadding().encodeToString(sig);
  }

  public static String sign(String payloadJson) {
    return sign(HS256_HEADER, payloadJson);
  }

  /** A fresh, valid request for {@code teamId}, expiring in 15 minutes. */
  public static Request request(String teamId) {
    return request(UUID.randomUUID().toString(), teamId, Instant.now());
  }

  public static Request request(String requestId, String teamId, Instant issuedAt) {
    return request(requestId, teamId, issuedAt, "");
  }

  /**
   * A request as a biketeam not yet updated signs it: with the {@code dryRun} and {@code reset}
   * claims Pédalons no longer reads.
   */
  public static Request legacyRequest(String teamId, boolean dryRun, boolean reset) {
    return request(
        UUID.randomUUID().toString(),
        teamId,
        Instant.now(),
        "\"dryRun\":" + dryRun + ",\"reset\":" + reset + ",");
  }

  /**
   * @param legacyClaims JSON members written between {@code requestedBy} and {@code returnUrl},
   *     where the former contract had its options; empty for a request of the current contract
   */
  private static Request request(
      String requestId, String teamId, Instant issuedAt, String legacyClaims) {
    long iat = issuedAt.getEpochSecond();
    String returnUrl = PUBLIC_URL + "/" + teamId + "/admin/pedalons/callback";
    String payload =
        "{\"iss\":\"biketeam\",\"aud\":\"pedalons:biketeam-migration\",\"ver\":1,"
            + "\"jti\":\""
            + requestId
            + "\",\"iat\":"
            + iat
            + ",\"exp\":"
            + (iat + 900)
            + ",\"teamId\":\""
            + teamId
            + "\",\"teamName\":\"Team "
            + teamId
            + "\",\"requestedBy\":\"Jane D.\","
            + legacyClaims
            + "\"returnUrl\":\""
            + returnUrl
            + "\",\"summary\":{\"places\":1,\"routes\":2,\"rides\":3,\"rideTemplates\":0,"
            + "\"trips\":1,\"tripStages\":2,\"publications\":4,\"faqPage\":true,\"logo\":false}}";
    return new Request(requestId, teamId, returnUrl, sign(payload));
  }

  public record Request(String requestId, String teamId, String returnUrl, String token) {}
}
