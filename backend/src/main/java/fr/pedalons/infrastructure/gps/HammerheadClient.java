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
import java.text.Normalizer;
import java.time.Duration;
import java.util.UUID;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Hammerhead GPS device integration client.
 * Implements OAuth 2.0 and route upload via Hammerhead API.
 */
@ApplicationScoped
public class HammerheadClient implements GpsServiceClient {

  private static final Logger LOG = Logger.getLogger(HammerheadClient.class);

  private static final String AUTH_URL = "https://api.hammerhead.io/v1/auth/oauth/authorize";
  private static final String TOKEN_URL = "https://api.hammerhead.io/v1/auth/oauth/token";
  private static final String ROUTE_UPLOAD_URL = "https://api.hammerhead.io/v1/api/routes/file";
  static final String ROUTES_URL = "https://api.hammerhead.io/v1/api/routes";
  private static final Duration CALL_TIMEOUT = Duration.ofSeconds(30);
  private static final String SCOPE = "route:write";

  @Inject DomainGpsCredentialService credentialService;

  @Inject HttpClient httpClient;

  @Inject ObjectMapper objectMapper;

  private DomainGpsCredential getCredential() {
    return credentialService
        .getCredentials(GpsServiceType.HAMMERHEAD)
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
    return GpsServiceType.HAMMERHEAD;
  }

  @Override
  public String getAuthorizationUrl(String state, String redirectUri) {
    return AUTH_URL
        + "?response_type=code"
        + "&client_id="
        + urlEncode(getClientId())
        + "&redirect_uri="
        + urlEncode(redirectUri)
        + "&scope="
        + urlEncode(SCOPE)
        + "&state="
        + urlEncode(state);
  }

  @Override
  public TokenResponse exchangeCode(String code, String redirectUri) {
    String body =
        "grant_type=authorization_code"
            + "&code="
            + urlEncode(code)
            + "&redirect_uri="
            + urlEncode(redirectUri)
            + "&client_id="
            + urlEncode(getClientId())
            + "&client_secret="
            + urlEncode(getClientSecret());

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
        LOG.errorf(
            "Hammerhead token request failed: %d %s", response.statusCode(), response.body());
        if (GpsTokenRefusedException.isRefusal(response.statusCode())) {
          throw new GpsTokenRefusedException("Hammerhead", response.statusCode());
        }
        throw new InternalException(
            ErrorCode.GPS_TOKEN_EXCHANGE_FAILED,
            new IOException("Hammerhead token request failed: " + response.statusCode()));
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
      String userId = jsonString(root, "user_id");

      return new TokenResponse(accessToken, refreshToken, expiresIn, userId);
    } catch (JsonProcessingException e) {
      throw new InternalException(ErrorCode.GPS_TOKEN_EXCHANGE_FAILED, e);
    }
  }

  @Override
  public GpsCallResult createRoute(GpsAuth auth, byte[] gpxContent, RouteMeta meta) {
    return sendFile("POST", ROUTE_UPLOAD_URL, auth, gpxContent, meta, null);
  }

  /** {@code PUT /v1/api/routes/{id}/file}: same multipart as the creation, the name included. */
  @Override
  public GpsCallResult updateRoute(
      GpsAuth auth, String externalId, byte[] gpxContent, RouteMeta meta) {
    return sendFile("PUT", routeUrl(externalId) + "/file", auth, gpxContent, meta, externalId);
  }

  /** {@code DELETE /v1/api/routes/{id}}: only routes created by our client may be deleted. */
  @Override
  public GpsCallResult deleteRoute(GpsAuth auth, String externalId) {
    String url = routeUrl(externalId);
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
      LOG.warnf("Hammerhead route delete failed: %d %s", response.statusCode(), response.body());
      return GpsCallResult.ofFailure(response);
    } catch (IOException e) {
      LOG.warn("Failed to delete route on Hammerhead", e);
      return new GpsCallResult.Failed(0, e.getMessage() != null ? e.getMessage() : "I/O error");
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      return new GpsCallResult.Failed(0, "Interrupted");
    }
  }

  static String routeUrl(String externalId) {
    return ROUTES_URL
        + "/"
        + URLEncoder.encode(externalId, StandardCharsets.UTF_8).replace("+", "%20");
  }

  private GpsCallResult sendFile(
      String method,
      String url,
      GpsAuth auth,
      byte[] gpxContent,
      RouteMeta meta,
      @Nullable String knownId) {
    try {
      String boundary = "----" + UUID.randomUUID().toString().replace("-", "");

      byte[] multipartBody = buildMultipartBody(boundary, gpxContent, meta.name());

      HttpRequest request =
          HttpRequest.newBuilder()
              .uri(URI.create(url))
              .timeout(CALL_TIMEOUT)
              .header("Authorization", auth.authorizationHeader(method, url))
              .header("Content-Type", "multipart/form-data; boundary=" + boundary)
              .method(method, HttpRequest.BodyPublishers.ofByteArray(multipartBody))
              .build();

      HttpResponse<String> response =
          httpClient.send(request, HttpResponse.BodyHandlers.ofString());

      if (GpsCallResult.isSuccess(response)) {
        String routeId = readId(response.body());
        LOG.infof(
            "Route %s on Hammerhead: %s", "POST".equals(method) ? "created" : "updated", routeId);
        return new GpsCallResult.Ok(routeId != null ? routeId : knownId);
      }
      LOG.errorf(
          "Hammerhead route %s failed: %d %s", method, response.statusCode(), response.body());
      return GpsCallResult.ofFailure(response);
    } catch (IOException e) {
      LOG.error("Failed to send route to Hammerhead", e);
      return new GpsCallResult.Failed(0, e.getMessage() != null ? e.getMessage() : "I/O error");
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      return new GpsCallResult.Failed(0, "Interrupted");
    }
  }

  private @Nullable String readId(@Nullable String body) {
    if (body == null || body.isBlank()) {
      return null;
    }
    try {
      return jsonString(objectMapper.readTree(body), "id");
    } catch (JsonProcessingException e) {
      return null;
    }
  }

  private byte[] buildMultipartBody(String boundary, byte[] gpxContent, String routeName) {
    StringBuilder sb = new StringBuilder();

    // File part. Hammerhead has no name field: the route is named after the file.
    sb.append("--").append(boundary).append("\r\n");
    sb.append("Content-Disposition: form-data; name=\"file\"; filename=\"")
        .append(fileName(routeName))
        .append(".gpx\"\r\n");
    sb.append("Content-Type: application/gpx+xml\r\n\r\n");

    byte[] header = sb.toString().getBytes(StandardCharsets.UTF_8);
    byte[] footer = ("\r\n--" + boundary + "--\r\n").getBytes(StandardCharsets.UTF_8);

    byte[] result = new byte[header.length + gpxContent.length + footer.length];
    System.arraycopy(header, 0, result, 0, header.length);
    System.arraycopy(gpxContent, 0, result, header.length, gpxContent.length);
    System.arraycopy(footer, 0, result, header.length + gpxContent.length, footer.length);

    return result;
  }

  /**
   * The route's name as a file name, which is what Hammerhead shows: accents dropped, then
   * anything but ASCII letters, digits, spaces, dots, dashes and underscores replaced — no quote
   * can break the header, no character a filesystem refuses. The « · » separator of the
   * synchronised names (docs/LEDGER_*.md API-120 §3.5) becomes a dash.
   */
  static String fileName(String routeName) {
    String ascii =
        Normalizer.normalize(routeName.replace('·', '-'), Normalizer.Form.NFD)
            .replaceAll("\\p{M}", "");
    String cleaned = ascii.replaceAll("[^A-Za-z0-9 ._-]", "_").trim();
    return cleaned.isEmpty() ? "route" : cleaned;
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
