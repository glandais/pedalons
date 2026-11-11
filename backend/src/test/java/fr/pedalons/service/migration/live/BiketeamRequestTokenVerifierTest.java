package fr.pedalons.service.migration.live;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.dto.error.ErrorCode;
import java.time.Instant;
import org.junit.jupiter.api.Test;

/**
 * The request token checks of docs/plans/2026-09-22-biketeam-live-migration.md §3.2, against the
 * plan's test vector — the same bytes biketeam's signer test reproduces — and the vector of the
 * contract before the options went, which stays accepted.
 */
class BiketeamRequestTokenVerifierTest {

  static final String PUBLIC_URL = "https://biketeam.example";

  static final String VECTOR_PAYLOAD =
      "{\"iss\":\"biketeam\",\"aud\":\"pedalons:biketeam-migration\",\"ver\":1,"
          + "\"jti\":\"6f1c2a3e-0000-4000-8000-000000000001\",\"iat\":1790000000,"
          + "\"exp\":1790000900,\"teamId\":\"n-peloton\",\"teamName\":\"N'Peloton\","
          + "\"requestedBy\":\"Jane D.\","
          + "\"returnUrl\":\"https://biketeam.example/n-peloton/admin/pedalons/callback\","
          + "\"summary\":{\"places\":1,\"routes\":2,\"rides\":3,\"rideTemplates\":0,\"trips\":1,"
          + "\"tripStages\":2,\"publications\":4,\"faqPage\":true,\"logo\":false}}";

  static final String VECTOR_TOKEN =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiaWtldGVhbSIsImF1ZCI6InBlZGFsb25zOmJpa2V0ZWFtLW1pZ3JhdGlvbiIsInZlciI6MSwianRpIjoiNmYxYzJhM2UtMDAwMC00MDAwLTgwMDAtMDAwMDAwMDAwMDAxIiwiaWF0IjoxNzkwMDAwMDAwLCJleHAiOjE3OTAwMDA5MDAsInRlYW1JZCI6Im4tcGVsb3RvbiIsInRlYW1OYW1lIjoiTidQZWxvdG9uIiwicmVxdWVzdGVkQnkiOiJKYW5lIEQuIiwicmV0dXJuVXJsIjoiaHR0cHM6Ly9iaWtldGVhbS5leGFtcGxlL24tcGVsb3Rvbi9hZG1pbi9wZWRhbG9ucy9jYWxsYmFjayIsInN1bW1hcnkiOnsicGxhY2VzIjoxLCJyb3V0ZXMiOjIsInJpZGVzIjozLCJyaWRlVGVtcGxhdGVzIjowLCJ0cmlwcyI6MSwidHJpcFN0YWdlcyI6MiwicHVibGljYXRpb25zIjo0LCJmYXFQYWdlIjp0cnVlLCJsb2dvIjpmYWxzZX19.GL7rqlMf1cehmTFcjN146SPsbzhNBsS2Ib5WhPbP4Z8";

  /**
   * The vector of the contract before 2026-11-11, with the {@code dryRun} and {@code reset} claims:
   * what a biketeam not yet updated still signs, and Pédalons still accepts.
   */
  static final String LEGACY_VECTOR_PAYLOAD =
      "{\"iss\":\"biketeam\",\"aud\":\"pedalons:biketeam-migration\",\"ver\":1,"
          + "\"jti\":\"6f1c2a3e-0000-4000-8000-000000000001\",\"iat\":1790000000,"
          + "\"exp\":1790000900,\"teamId\":\"n-peloton\",\"teamName\":\"N'Peloton\","
          + "\"requestedBy\":\"Jane D.\",\"dryRun\":true,\"reset\":false,"
          + "\"returnUrl\":\"https://biketeam.example/n-peloton/admin/pedalons/callback\","
          + "\"summary\":{\"places\":1,\"routes\":2,\"rides\":3,\"rideTemplates\":0,\"trips\":1,"
          + "\"tripStages\":2,\"publications\":4,\"faqPage\":true,\"logo\":false}}";

  static final String LEGACY_VECTOR_TOKEN =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiaWtldGVhbSIsImF1ZCI6InBlZGFsb25zOmJpa2V0ZWFtLW1pZ3JhdGlvbiIsInZlciI6MSwianRpIjoiNmYxYzJhM2UtMDAwMC00MDAwLTgwMDAtMDAwMDAwMDAwMDAxIiwiaWF0IjoxNzkwMDAwMDAwLCJleHAiOjE3OTAwMDA5MDAsInRlYW1JZCI6Im4tcGVsb3RvbiIsInRlYW1OYW1lIjoiTidQZWxvdG9uIiwicmVxdWVzdGVkQnkiOiJKYW5lIEQuIiwiZHJ5UnVuIjp0cnVlLCJyZXNldCI6ZmFsc2UsInJldHVyblVybCI6Imh0dHBzOi8vYmlrZXRlYW0uZXhhbXBsZS9uLXBlbG90b24vYWRtaW4vcGVkYWxvbnMvY2FsbGJhY2siLCJzdW1tYXJ5Ijp7InBsYWNlcyI6MSwicm91dGVzIjoyLCJyaWRlcyI6MywicmlkZVRlbXBsYXRlcyI6MCwidHJpcHMiOjEsInRyaXBTdGFnZXMiOjIsInB1YmxpY2F0aW9ucyI6NCwiZmFxUGFnZSI6dHJ1ZSwibG9nbyI6ZmFsc2V9fQ.-Fy6Ljdr2ChwKFIAAkH3lh8CIUynNQFNJm2Us2G-jlw";

  static final Instant BEFORE_EXPIRY = Instant.ofEpochSecond(1790000100);
  static final Instant AFTER_EXPIRY = Instant.ofEpochSecond(1790001000);

  private static BiketeamRequestToken verify(String token, Instant now) {
    return BiketeamRequestTokenVerifier.verify(token, BiketeamTestTokens.key(), PUBLIC_URL, now);
  }

  private static void assertRefused(ErrorCode expected, Runnable check) {
    BadRequestException e = assertThrows(BadRequestException.class, check::run);
    assertEquals(expected, e.getErrorCode());
  }

  @Test
  void ourSigner_reproducesTheVectorToTheByte() {
    assertEquals(VECTOR_TOKEN, BiketeamTestTokens.sign(VECTOR_PAYLOAD));
  }

  @Test
  void vector_isAccepted_beforeItsExpiry() {
    BiketeamRequestToken token = verify(VECTOR_TOKEN, BEFORE_EXPIRY);

    assertEquals("6f1c2a3e-0000-4000-8000-000000000001", token.requestId());
    assertEquals("n-peloton", token.teamId());
    assertEquals("N'Peloton", token.teamName());
    assertEquals("Jane D.", token.requestedBy());
    assertEquals(Instant.ofEpochSecond(1790000900), token.expiresAt());
    assertEquals("https://biketeam.example/n-peloton/admin/pedalons/callback", token.returnUrl());
    assertEquals(1, token.summary().places());
    assertEquals(2, token.summary().routes());
    assertEquals(3, token.summary().rides());
    assertEquals(0, token.summary().rideTemplates());
    assertEquals(1, token.summary().trips());
    assertEquals(2, token.summary().tripStages());
    assertEquals(4, token.summary().publications());
    assertTrue(token.summary().faqPage());
    assertFalse(token.summary().logo());
    assertEquals(
        "https://biketeam.example/n-peloton/admin/pedalons/callback"
            + "?request=6f1c2a3e-0000-4000-8000-000000000001&outcome=cancelled",
        token.cancelUrl());
  }

  @Test
  void ourSigner_reproducesTheLegacyVectorToTheByte() {
    assertEquals(LEGACY_VECTOR_TOKEN, BiketeamTestTokens.sign(LEGACY_VECTOR_PAYLOAD));
  }

  /** Pédalons is deployed first: the token of a biketeam not yet updated must still pass. */
  @Test
  void legacyVector_withDryRunAndReset_isStillAccepted_andReadsLikeTheNewOne() {
    assertEquals(verify(VECTOR_TOKEN, BEFORE_EXPIRY), verify(LEGACY_VECTOR_TOKEN, BEFORE_EXPIRY));
  }

  @Test
  void dryRunAndReset_areIgnored_whateverTheirValueOrType() {
    BiketeamRequestToken expected = verify(VECTOR_TOKEN, BEFORE_EXPIRY);
    for (String claims :
        new String[] {
          "\"dryRun\":false,\"reset\":true,",
          "\"dryRun\":\"true\",\"reset\":1,",
          "\"dryRun\":null,\"reset\":{\"a\":[]},",
          "\"reset\":true,",
        }) {
      String token =
          BiketeamTestTokens.sign(
              VECTOR_PAYLOAD.replace("\"returnUrl\"", claims + "\"returnUrl\""));
      assertEquals(expected, verify(token, BEFORE_EXPIRY), claims);
    }
  }

  @Test
  void vector_isRefusedAsExpired_pastItsExpiryAndSkew() {
    assertRefused(ErrorCode.BIKETEAM_REQUEST_EXPIRED, () -> verify(VECTOR_TOKEN, AFTER_EXPIRY));
  }

  @Test
  void expiry_toleratesSixtySecondsOfSkew() {
    verify(VECTOR_TOKEN, Instant.ofEpochSecond(1790000900 + 60));
    assertRefused(
        ErrorCode.BIKETEAM_REQUEST_EXPIRED,
        () -> verify(VECTOR_TOKEN, Instant.ofEpochSecond(1790000900 + 61)));
  }

  @Test
  void publicUrl_withATrailingSlash_isTheSameSite() {
    BiketeamRequestTokenVerifier.verify(
        VECTOR_TOKEN, BiketeamTestTokens.key(), PUBLIC_URL + "/", BEFORE_EXPIRY);
  }

  @Test
  void algNone_isRefused_evenWithTheOriginalSignature() {
    String[] parts = VECTOR_TOKEN.split("\\.");
    String forged =
        BiketeamTestTokens.b64("{\"alg\":\"none\",\"typ\":\"JWT\"}")
            + "."
            + parts[1]
            + "."
            + parts[2];
    assertRefused(ErrorCode.BIKETEAM_REQUEST_INVALID, () -> verify(forged, BEFORE_EXPIRY));

    String unsigned = BiketeamTestTokens.b64("{\"alg\":\"none\"}") + "." + parts[1] + ".";
    assertRefused(ErrorCode.BIKETEAM_REQUEST_INVALID, () -> verify(unsigned, BEFORE_EXPIRY));
  }

  @Test
  void anotherAlgorithm_isRefused_evenCorrectlySigned() {
    String token = BiketeamTestTokens.sign("{\"alg\":\"HS512\",\"typ\":\"JWT\"}", VECTOR_PAYLOAD);
    assertRefused(ErrorCode.BIKETEAM_REQUEST_INVALID, () -> verify(token, BEFORE_EXPIRY));
  }

  @Test
  void tamperedPayload_isRefused() {
    String[] parts = VECTOR_TOKEN.split("\\.");
    String tampered =
        parts[0]
            + "."
            + BiketeamTestTokens.b64(VECTOR_PAYLOAD.replace("n-peloton", "m-peloton"))
            + "."
            + parts[2];
    assertRefused(ErrorCode.BIKETEAM_REQUEST_INVALID, () -> verify(tampered, BEFORE_EXPIRY));
  }

  @Test
  void wrongKey_isRefused() {
    byte[] otherKey = new byte[32];
    assertRefused(
        ErrorCode.BIKETEAM_REQUEST_INVALID,
        () ->
            BiketeamRequestTokenVerifier.verify(VECTOR_TOKEN, otherKey, PUBLIC_URL, BEFORE_EXPIRY));
  }

  @Test
  void returnUrl_ofAnotherSite_isRefused_evenCorrectlySigned() {
    assertRefused(
        ErrorCode.BIKETEAM_REQUEST_INVALID,
        () ->
            BiketeamRequestTokenVerifier.verify(
                VECTOR_TOKEN, BiketeamTestTokens.key(), "https://evil.example", BEFORE_EXPIRY));

    String elsewhere =
        BiketeamTestTokens.sign(
            VECTOR_PAYLOAD.replace(
                "https://biketeam.example/n-peloton/admin/pedalons/callback",
                "https://biketeam.example/other-team/admin/pedalons/callback"));
    assertRefused(ErrorCode.BIKETEAM_REQUEST_INVALID, () -> verify(elsewhere, BEFORE_EXPIRY));
  }

  @Test
  void wrongIssuerAudienceOrVersion_isRefused() {
    for (String payload :
        new String[] {
          VECTOR_PAYLOAD.replace("\"iss\":\"biketeam\"", "\"iss\":\"someone\""),
          VECTOR_PAYLOAD.replace("pedalons:biketeam-migration", "pedalons:other"),
          VECTOR_PAYLOAD.replace("\"ver\":1", "\"ver\":2"),
          VECTOR_PAYLOAD.replace("\"ver\":1", "\"ver\":\"1\""),
          VECTOR_PAYLOAD.replace("\"faqPage\":true", "\"faqPage\":\"true\""),
        }) {
      String token = BiketeamTestTokens.sign(payload);
      assertRefused(ErrorCode.BIKETEAM_REQUEST_INVALID, () -> verify(token, BEFORE_EXPIRY));
    }
  }

  @Test
  void lifetimeOverAnHour_isRefused() {
    String token =
        BiketeamTestTokens.sign(VECTOR_PAYLOAD.replace("\"exp\":1790000900", "\"exp\":1790003601"));
    assertRefused(ErrorCode.BIKETEAM_REQUEST_INVALID, () -> verify(token, BEFORE_EXPIRY));
  }

  @Test
  void malformedTokens_areRefused() {
    for (String token :
        new String[] {
          "", "abc", "a.b", VECTOR_TOKEN + ".x", "!!!.???.***", VECTOR_TOKEN.replace('.', ',')
        }) {
      assertRefused(ErrorCode.BIKETEAM_REQUEST_INVALID, () -> verify(token, BEFORE_EXPIRY));
    }
  }

  @Test
  void duplicatedClaim_isRefused() {
    String token =
        BiketeamTestTokens.sign(VECTOR_PAYLOAD.replace("\"ver\":1", "\"ver\":1,\"ver\":1"));
    assertRefused(ErrorCode.BIKETEAM_REQUEST_INVALID, () -> verify(token, BEFORE_EXPIRY));
  }
}
