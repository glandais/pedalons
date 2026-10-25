package fr.pedalons.service.migration.live;

import fr.pedalons.common.TokenUtils;
import fr.pedalons.common.UrlUtils;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.migration.BiketeamMigrationSummaryDto;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.time.Instant;
import java.util.Base64;
import java.util.regex.Pattern;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.jboss.logging.Logger;
import tools.jackson.core.JacksonException;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;

/**
 * Verifies the request token biketeam signs and sends through the browser — a compact JWS, HS256,
 * written and checked by hand rather than through a JWT library, so that exactly the rules of
 * docs/plans/2026-09-22-biketeam-live-migration.md §3.2 apply and nothing else:
 *
 * <ol>
 *   <li>three segments, a header whose {@code alg} is {@code HS256} — {@code none} and every other
 *       algorithm are refused;
 *   <li>the HMAC recomputed over the segments <em>as received</em> (never over re-serialised JSON)
 *       and compared in constant time;
 *   <li>{@code iss}, {@code aud}, {@code ver} as expected, strict claim types, a lifetime of at most
 *       an hour;
 *   <li>expiry, with 60 s of clock skew — the only failure reported as {@code
 *       BIKETEAM_REQUEST_EXPIRED};
 *   <li>{@code returnUrl} equal, to the letter, to {@code {public-url}/{teamId}/admin/pedalons/callback}
 *       — what keeps the grant from being sent anywhere but biketeam, on top of the signature.
 * </ol>
 *
 * Every other failure is {@code BIKETEAM_REQUEST_INVALID}, without saying which check it failed.
 */
@ApplicationScoped
public class BiketeamRequestTokenVerifier {

  private static final Logger LOG = Logger.getLogger(BiketeamRequestTokenVerifier.class);

  static final String ISSUER = "biketeam";
  static final String AUDIENCE = "pedalons:biketeam-migration";
  static final int VERSION = 1;
  static final long MAX_LIFETIME_SECONDS = 3600;
  static final long CLOCK_SKEW_SECONDS = 60;

  private static final Pattern LOWER_UUID =
      Pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$");

  /**
   * The biketeam team ids this migration accepts — the id becomes the Pédalons team slug, and a
   * path segment of every URL built from it: lower-case ASCII letters and digits, then {@code _ . -}
   * as well. Biketeam's own permalinks are wider ({@code Strings.normalizePermalink} keeps {@code ’},
   * {@code œ}, {@code °}… and may lead with {@code _ - .}); such a team is not migrable, and biketeam
   * checks the same rule before redirecting (docs/plans/2026-09-22-biketeam-live-migration.md,
   * « Écarts d'implémentation »).
   */
  private static final Pattern TEAM_ID = Pattern.compile("^[a-z0-9][a-z0-9_.-]{0,254}$");

  /** Its own mapper: a duplicated claim is an error here, not "last one wins". */
  private static final ObjectMapper JSON =
      JsonMapper.builder().enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION).build();

  @Inject BiketeamLiveMigrationConfig config;

  /** Verifies {@code token} against the configured key and public URL, now. */
  public BiketeamRequestToken verify(String token) {
    return verify(token, config.requestKeyBytes(), config.publicUrl(), Instant.now());
  }

  /**
   * The whole check, with every input explicit — what the tests drive with the §3.2 vector.
   *
   * @param publicUrl biketeam's public {@code site.url}, without a trailing slash
   */
  public static BiketeamRequestToken verify(
      String token, byte[] key, String publicUrl, Instant now) {
    // 1. Shape and header.
    String[] parts = token.trim().split("\\.", -1);
    if (parts.length != 3 || parts[0].isEmpty() || parts[1].isEmpty() || parts[2].isEmpty()) {
      throw invalid();
    }
    JsonNode header = parseJson(parts[0]);
    JsonNode alg = header.get("alg");
    if (alg == null || !alg.isString() || !"HS256".equals(alg.stringValue())) {
      throw invalid();
    }

    // 2. Signature, over the received segments.
    byte[] signature = decode(parts[2]);
    byte[] expected = hmac(key, parts[0] + "." + parts[1]);
    if (!TokenUtils.constantTimeEquals(signature, expected)) {
      throw invalid();
    }

    // 3. Claims.
    JsonNode payload = parseJson(parts[1]);
    if (!ISSUER.equals(text(payload, "iss"))
        || !AUDIENCE.equals(text(payload, "aud"))
        || integer(payload, "ver") != VERSION) {
      throw invalid();
    }
    long iat = integer(payload, "iat");
    long exp = integer(payload, "exp");
    if (exp - iat > MAX_LIFETIME_SECONDS) {
      throw invalid();
    }
    String requestId = text(payload, "jti");
    String teamId = text(payload, "teamId");
    String teamName = text(payload, "teamName");
    String requestedBy = text(payload, "requestedBy");
    boolean dryRun = bool(payload, "dryRun");
    boolean reset = bool(payload, "reset");
    String returnUrl = text(payload, "returnUrl");
    BiketeamMigrationSummaryDto summary = summary(payload.get("summary"));
    if (!TEAM_ID.matcher(teamId).matches()) {
      // Signed by biketeam, so not a forgery: a team whose id cannot become a Pédalons slug. The
      // visitor only sees "request invalid"; say why where an operator will look.
      LOG.warnf(
          "Biketeam migration request %s refused: team id '%s' is not migrable", requestId, teamId);
      throw invalid();
    }
    if (!LOWER_UUID.matcher(requestId).matches() || teamName.isBlank()) {
      throw invalid();
    }

    // 4. Expiry.
    if (now.getEpochSecond() > exp + CLOCK_SKEW_SECONDS) {
      throw new BadRequestException(ErrorCode.BIKETEAM_REQUEST_EXPIRED);
    }

    // 5. Return URL, to the letter.
    if (!returnUrl.equals(callbackUrl(publicUrl, teamId))) {
      throw invalid();
    }

    return new BiketeamRequestToken(
        requestId,
        Instant.ofEpochSecond(iat),
        Instant.ofEpochSecond(exp),
        teamId,
        teamName,
        requestedBy,
        dryRun,
        reset,
        returnUrl,
        summary);
  }

  /** {@code {public-url}/{teamId}/admin/pedalons/callback}, the only acceptable return URL. */
  static String callbackUrl(String publicUrl, String teamId) {
    return UrlUtils.stripTrailingSlash(publicUrl) + "/" + teamId + "/admin/pedalons/callback";
  }

  private static BiketeamMigrationSummaryDto summary(JsonNode node) {
    if (node == null || !node.isObject()) {
      throw invalid();
    }
    return new BiketeamMigrationSummaryDto(
        count(node, "places"),
        count(node, "routes"),
        count(node, "rides"),
        count(node, "rideTemplates"),
        count(node, "trips"),
        count(node, "tripStages"),
        count(node, "publications"),
        bool(node, "faqPage"),
        bool(node, "logo"));
  }

  private static int count(JsonNode node, String field) {
    long value = integer(node, field);
    if (value < 0 || value > Integer.MAX_VALUE) {
      throw invalid();
    }
    return (int) value;
  }

  private static String text(JsonNode node, String field) {
    JsonNode value = node.get(field);
    if (value == null || !value.isString()) {
      throw invalid();
    }
    return value.stringValue();
  }

  private static long integer(JsonNode node, String field) {
    JsonNode value = node.get(field);
    if (value == null || !value.isIntegralNumber() || !value.canConvertToLong()) {
      throw invalid();
    }
    return value.longValue();
  }

  private static boolean bool(JsonNode node, String field) {
    JsonNode value = node.get(field);
    if (value == null || !value.isBoolean()) {
      throw invalid();
    }
    return value.booleanValue();
  }

  private static JsonNode parseJson(String segment) {
    try {
      JsonNode node = JSON.readTree(decode(segment));
      if (node == null || !node.isObject()) {
        throw invalid();
      }
      return node;
    } catch (JacksonException e) {
      throw invalid();
    }
  }

  private static byte[] decode(String segment) {
    try {
      return Base64.getUrlDecoder().decode(segment);
    } catch (IllegalArgumentException e) {
      throw invalid();
    }
  }

  static byte[] hmac(byte[] key, String signingInput) {
    try {
      Mac mac = Mac.getInstance("HmacSHA256");
      mac.init(new SecretKeySpec(key, "HmacSHA256"));
      return mac.doFinal(signingInput.getBytes(StandardCharsets.US_ASCII));
    } catch (GeneralSecurityException e) {
      throw new IllegalStateException("HmacSHA256 unavailable", e);
    }
  }

  private static BadRequestException invalid() {
    return new BadRequestException(ErrorCode.BIKETEAM_REQUEST_INVALID);
  }
}
