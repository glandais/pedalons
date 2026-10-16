package fr.pedalons.infrastructure.gps;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.InternalException;
import fr.pedalons.domain.gps.DomainGpsCredential;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.service.gps.DomainGpsCredentialService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Garmin Connect GPS device integration client.
 * Implements OAuth 2.0 with PKCE and course upload via Garmin Training API. A domain whose Garmin
 * credential is OAuth 1.0a goes through {@link GarminOAuth1Client} instead, which reuses the upload.
 */
@ApplicationScoped
public class GarminClient implements GpsServiceClient {

  private static final Logger LOG = Logger.getLogger(GarminClient.class);

  private static final String AUTH_URL = "https://connect.garmin.com/oauth2Confirm";
  private static final String TOKEN_URL = "https://diauth.garmin.com/di-oauth2-service/oauth/token";
  static final String COURSE_UPLOAD_URL = "https://apis.garmin.com/training-api/courses/v1/course";
  private static final Duration CALL_TIMEOUT = Duration.ofSeconds(30);

  @Inject DomainGpsCredentialService credentialService;

  @Inject HttpClient httpClient;

  @Inject GarminCourseConverter courseConverter;

  @Inject ObjectMapper objectMapper;

  private DomainGpsCredential getCredential() {
    return credentialService
        .getCredentials(GpsServiceType.GARMIN)
        .orElseThrow(() -> new BusinessException(ErrorCode.GPS_SERVICE_NOT_CONFIGURED));
  }

  private String getClientId() {
    return getCredential().getClientId();
  }

  private String getClientSecret() {
    DomainGpsCredential credential = getCredential();
    String secret = credentialService.getDecryptedClientSecret(credential);
    if (secret == null) {
      throw new BusinessException(ErrorCode.GPS_SERVICE_NOT_CONFIGURED);
    }
    return secret;
  }

  @Override
  public GpsServiceType getServiceType() {
    return GpsServiceType.GARMIN;
  }

  @Override
  public boolean supportsPkce() {
    return true;
  }

  @Override
  public String getAuthorizationUrl(String state, String redirectUri) {
    // This should not be called for PKCE clients
    throw new UnsupportedOperationException("Garmin requires PKCE flow");
  }

  @Override
  public String getAuthorizationUrl(String state, String redirectUri, String codeChallenge) {
    return AUTH_URL
        + "?response_type=code"
        + "&client_id="
        + urlEncode(getClientId())
        + "&redirect_uri="
        + urlEncode(redirectUri)
        + "&state="
        + urlEncode(state)
        + "&code_challenge="
        + urlEncode(codeChallenge)
        + "&code_challenge_method=S256";
  }

  @Override
  public TokenResponse exchangeCode(String code, String redirectUri) {
    // This should not be called for PKCE clients
    throw new UnsupportedOperationException("Garmin requires PKCE flow");
  }

  @Override
  public TokenResponse exchangeCode(String code, String redirectUri, String codeVerifier) {
    String body =
        "grant_type=authorization_code"
            + "&code="
            + urlEncode(code)
            + "&redirect_uri="
            + urlEncode(redirectUri)
            + "&client_id="
            + urlEncode(getClientId())
            + "&client_secret="
            + urlEncode(getClientSecret())
            + "&code_verifier="
            + urlEncode(codeVerifier);

    return requestToken(body);
  }

  @Override
  public TokenResponse refreshToken(String refreshToken) {
    return refreshToken(getCredential(), refreshToken);
  }

  @Override
  public TokenResponse refreshToken(DomainGpsCredential credential, String refreshToken) {
    String secret = credentialService.getDecryptedClientSecret(credential);
    if (secret == null) {
      throw new BusinessException(ErrorCode.GPS_SERVICE_NOT_CONFIGURED);
    }
    String body =
        "grant_type=refresh_token"
            + "&refresh_token="
            + urlEncode(refreshToken)
            + "&client_id="
            + urlEncode(credential.getClientId())
            + "&client_secret="
            + urlEncode(secret);

    return requestToken(body);
  }

  private TokenResponse requestToken(String body) {
    try {
      HttpRequest request =
          HttpRequest.newBuilder()
              .uri(URI.create(TOKEN_URL))
              .header("Content-Type", "application/x-www-form-urlencoded")
              // Bounded like the route calls: the route sync's lease counts on it (API-120).
              .timeout(CALL_TIMEOUT)
              .POST(HttpRequest.BodyPublishers.ofString(body))
              .build();

      HttpResponse<String> response =
          httpClient.send(request, HttpResponse.BodyHandlers.ofString());

      if (response.statusCode() != 200) {
        LOG.errorf("Garmin token request failed: %d %s", response.statusCode(), response.body());
        if (GpsTokenRefusedException.isRefusal(response.statusCode())) {
          throw new GpsTokenRefusedException("Garmin", response.statusCode());
        }
        throw new InternalException(
            ErrorCode.GPS_TOKEN_EXCHANGE_FAILED,
            new IOException("Garmin token request failed: " + response.statusCode()));
      }

      return parseTokenResponse(response.body());
    } catch (IOException | InterruptedException e) {
      throw new InternalException(ErrorCode.GPS_TOKEN_EXCHANGE_FAILED, e);
    }
  }

  private TokenResponse parseTokenResponse(String json) {
    try {
      JsonNode root = objectMapper.readTree(json);
      String accessToken = jsonString(root, "access_token");
      String refreshToken = jsonString(root, "refresh_token");
      Long expiresIn = jsonLong(root, "expires_in");
      // Garmin may return user info differently
      String userId = jsonString(root, "user_id");

      return new TokenResponse(accessToken, refreshToken, expiresIn, userId);
    } catch (JsonProcessingException e) {
      throw new InternalException(ErrorCode.GPS_TOKEN_EXCHANGE_FAILED, e);
    }
  }

  /**
   * Creates a course on Garmin Connect. The authorization is all that differs between OAuth 2.0 (a
   * bearer token) and OAuth 1.0a (a signature, see {@link GarminOAuth1Client}).
   */
  @Override
  public GpsCallResult createRoute(GpsAuth auth, byte[] gpxContent, RouteMeta meta) {
    return sendCourse("POST", COURSE_UPLOAD_URL, auth, gpxContent, meta, null);
  }

  /**
   * {@code PUT …/course/{courseId}}: a full replacement, the whole course JSON again. Garmin answers
   * 204 with no body.
   */
  @Override
  public GpsCallResult updateRoute(
      GpsAuth auth, String externalId, byte[] gpxContent, RouteMeta meta) {
    return sendCourse("PUT", courseUrl(externalId), auth, gpxContent, meta, externalId);
  }

  /** {@code DELETE …/course/{courseId}} → 204. */
  @Override
  public GpsCallResult deleteRoute(GpsAuth auth, String externalId) {
    String url = courseUrl(externalId);
    try {
      HttpRequest request =
          HttpRequest.newBuilder()
              .uri(URI.create(url))
              .timeout(CALL_TIMEOUT)
              .header("Authorization", auth.authorizationHeader("DELETE", url))
              .DELETE()
              .build();
      HttpResponse<String> response =
          httpClient.send(request, HttpResponse.BodyHandlers.ofString());
      if (GpsCallResult.isSuccess(response)) {
        return new GpsCallResult.Ok(externalId);
      }
      LOG.warnf("Garmin course delete failed: %d %s", response.statusCode(), response.body());
      return GpsCallResult.ofFailure(response);
    } catch (IOException e) {
      LOG.warn("Failed to delete course on Garmin", e);
      return new GpsCallResult.Failed(0, e.getMessage() != null ? e.getMessage() : "I/O error");
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      return new GpsCallResult.Failed(0, "Interrupted");
    }
  }

  static String courseUrl(String externalId) {
    return COURSE_UPLOAD_URL
        + "/"
        + URLEncoder.encode(externalId, StandardCharsets.UTF_8).replace("+", "%20");
  }

  private GpsCallResult sendCourse(
      String method,
      String url,
      GpsAuth auth,
      byte[] gpxContent,
      RouteMeta meta,
      @Nullable String knownId) {
    try {
      // Convert GPX to Garmin course JSON format
      String courseJson = courseConverter.convertToGarminCourse(gpxContent, meta.name());

      HttpRequest request =
          HttpRequest.newBuilder()
              .uri(URI.create(url))
              .timeout(CALL_TIMEOUT)
              .header("Authorization", auth.authorizationHeader(method, url))
              .header("Content-Type", "application/json")
              .method(
                  method, HttpRequest.BodyPublishers.ofString(courseJson, StandardCharsets.UTF_8))
              .build();

      HttpResponse<String> response =
          httpClient.send(request, HttpResponse.BodyHandlers.ofString());

      if (GpsCallResult.isSuccess(response)) {
        String courseId = readCourseId(response.body());
        LOG.infof(
            "Course %s on Garmin: %s",
            "POST".equals(method) ? "created" : "updated", courseId != null ? courseId : knownId);
        return new GpsCallResult.Ok(courseId != null ? courseId : knownId);
      }
      LOG.errorf("Garmin course %s failed: %d %s", method, response.statusCode(), response.body());
      return GpsCallResult.ofFailure(response);
    } catch (IOException e) {
      LOG.error("Failed to send course to Garmin", e);
      return new GpsCallResult.Failed(0, e.getMessage() != null ? e.getMessage() : "I/O error");
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      return new GpsCallResult.Failed(0, "Interrupted");
    }
  }

  /** The id in a creation's answer; null for the empty body of a 204. */
  private @Nullable String readCourseId(@Nullable String body) {
    if (body == null || body.isBlank()) {
      return null;
    }
    try {
      JsonNode root = objectMapper.readTree(body);
      String courseId = jsonString(root, "courseId");
      return courseId != null ? courseId : jsonString(root, "id");
    } catch (JsonProcessingException e) {
      return null;
    }
  }

  private String urlEncode(String value) {
    return URLEncoder.encode(value, StandardCharsets.UTF_8);
  }

  private static String jsonString(JsonNode root, String key) {
    JsonNode node = root.path(key);
    return node.isMissingNode() || node.isNull() ? null : node.asText();
  }

  private static Long jsonLong(JsonNode root, String key) {
    JsonNode node = root.path(key);
    if (node.isMissingNode() || node.isNull()) {
      return null;
    }
    if (node.canConvertToLong()) {
      return node.asLong();
    }
    // Some providers return numeric fields as JSON strings (e.g. "3600").
    try {
      return Long.parseLong(node.asText().trim());
    } catch (NumberFormatException e) {
      return null;
    }
  }
}
