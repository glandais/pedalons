package fr.pedalons.infrastructure.gps;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.InternalException;
import fr.pedalons.domain.gps.DomainGpsCredential;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.infrastructure.gpx.FitExporter;
import fr.pedalons.service.gps.DomainGpsCredentialService;
import io.github.glandais.engine.gpx.GpxDocument;
import io.github.glandais.engine.gpx.GpxParserJvm;
import io.github.glandais.engine.gpx.GpxToPathJvm;
import io.github.glandais.engine.path.Path;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.jboss.logging.Logger;

/**
 * Wahoo Cloud API GPS device integration client.
 *
 * <p>Implements OAuth 2.0 (confidential client, no PKCE) and route upload via the Wahoo Cloud API.
 * Unlike Hammerhead (which accepts raw GPX as a multipart part), Wahoo's {@code POST /v1/routes} is
 * an ordinary form post carrying a FIT file base64-encoded into a {@code data:} URI, plus the
 * route's start point, distance and ascent as separate required fields. The GPX is therefore parsed
 * once here and used twice: exported as FIT through {@link FitExporter}, and measured for those
 * fields.
 *
 * <p>Wahoo has no companion device application: the route is pushed to the user's Wahoo account and
 * syncs to their ELEMNT head unit from the cloud. Wahoo's own docs note that Cloud API routes reach
 * the Wahoo app and the head unit, but not the older ELEMNT app.
 */
@ApplicationScoped
public class WahooClient implements GpsServiceClient {

  private static final Logger LOG = Logger.getLogger(WahooClient.class);

  private static final String AUTH_URL = "https://api.wahooligan.com/oauth/authorize";
  private static final String TOKEN_URL = "https://api.wahooligan.com/oauth/token";
  private static final String ROUTE_UPLOAD_URL = "https://api.wahooligan.com/v1/routes";
  // routes_write carries the upload; user_read is mandatory on every call — without it the API
  // answers 403 whatever the other scopes say.
  private static final String SCOPE = "user_read routes_write";
  // The media type Wahoo's data: URI expects, which is not the ANT type the rest of the app
  // serves FIT files as.
  private static final String FIT_CONTENT_TYPE = "application/vnd.fit";
  // Wahoo workout type family 0 — BIKING.
  private static final int WORKOUT_TYPE_FAMILY_BIKING = 0;
  private static final DateTimeFormatter PROVIDER_UPDATED_AT =
      DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneOffset.UTC);

  @Inject DomainGpsCredentialService credentialService;

  @Inject HttpClient httpClient;

  @Inject ObjectMapper objectMapper;

  private DomainGpsCredential getCredential() {
    return credentialService
        .getCredentials(GpsServiceType.WAHOO)
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
    return GpsServiceType.WAHOO;
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
    String body =
        "grant_type=refresh_token"
            + "&refresh_token="
            + urlEncode(refreshToken)
            + "&client_id="
            + urlEncode(getClientId())
            + "&client_secret="
            + urlEncode(getClientSecret());

    return requestToken(body);
  }

  private TokenResponse requestToken(String body) {
    try {
      HttpRequest request =
          HttpRequest.newBuilder()
              .uri(URI.create(TOKEN_URL))
              .header("Content-Type", "application/x-www-form-urlencoded")
              .POST(HttpRequest.BodyPublishers.ofString(body))
              .build();

      HttpResponse<String> response =
          httpClient.send(request, HttpResponse.BodyHandlers.ofString());

      if (response.statusCode() != 200) {
        LOG.errorf("Wahoo token request failed: %d %s", response.statusCode(), response.body());
        throw new InternalException(
            ErrorCode.GPS_TOKEN_EXCHANGE_FAILED,
            new IOException("Wahoo token request failed: " + response.statusCode()));
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
      // Wahoo's token response carries no user id, so this resolves to null and the connection
      // keeps no external user id — read the same way as Hammerhead's, which does return one.
      String userId = jsonString(root, "user_id");

      return new TokenResponse(accessToken, refreshToken, expiresIn, userId);
    } catch (JsonProcessingException e) {
      throw new InternalException(ErrorCode.GPS_TOKEN_EXCHANGE_FAILED, e);
    }
  }

  @Override
  public RouteUploadResult uploadRoute(String accessToken, byte[] gpxContent, String routeName) {
    try {
      List<Path> paths = parsePaths(gpxContent);
      byte[] fitContent = FitExporter.toFitBytes(paths, routeName);

      String body = buildRouteForm(paths, gpxContent, fitContent, routeName);

      HttpRequest request =
          HttpRequest.newBuilder()
              .uri(URI.create(ROUTE_UPLOAD_URL))
              .header("Authorization", "Bearer " + accessToken)
              .header("Content-Type", "application/x-www-form-urlencoded")
              .POST(HttpRequest.BodyPublishers.ofString(body))
              .build();

      HttpResponse<String> response =
          httpClient.send(request, HttpResponse.BodyHandlers.ofString());

      if (response.statusCode() >= 200 && response.statusCode() < 300) {
        String routeId = jsonString(objectMapper.readTree(response.body()), "id");
        LOG.infof("Successfully uploaded route to Wahoo: %s", routeId);
        return RouteUploadResult.success(routeId);
      } else {
        LOG.errorf("Wahoo route upload failed: %d %s", response.statusCode(), response.body());
        return RouteUploadResult.failure("Upload failed: " + response.statusCode());
      }
    } catch (IOException | InterruptedException e) {
      LOG.error("Failed to upload route to Wahoo", e);
      return RouteUploadResult.failure("Upload failed: " + e.getMessage());
    }
  }

  /**
   * The tracks of {@code gpxContent} as vcyclist paths, derived data included — the FIT export and
   * the form's distance/ascent fields both read them, so parsing happens once.
   */
  private static List<Path> parsePaths(byte[] gpxContent) throws IOException {
    try {
      GpxDocument doc = GpxParserJvm.parse(decodeGpx(gpxContent));
      return GpxToPathJvm.tracksAsPaths(doc);
    } catch (RuntimeException e) {
      throw new IOException("Failed to parse GPX", e);
    }
  }

  /**
   * vcyclist's parser takes a {@code String}, so the encoding has to be decided here — UTF-8 first,
   * ISO-8859-1 as a fallback, exactly as route import does. Routes inherited from biketeam are
   * frequently latin-1, and a route that imported fine must stay uploadable.
   */
  private static String decodeGpx(byte[] gpxContent) {
    try {
      return StandardCharsets.UTF_8
          .newDecoder()
          .onMalformedInput(CodingErrorAction.REPORT)
          .onUnmappableCharacter(CodingErrorAction.REPORT)
          .decode(ByteBuffer.wrap(gpxContent))
          .toString();
    } catch (CharacterCodingException e) {
      LOG.debug("GPX is not valid UTF-8, retrying as ISO-8859-1");
      return new String(gpxContent, StandardCharsets.ISO_8859_1);
    }
  }

  /**
   * Builds the {@code application/x-www-form-urlencoded} body of {@code POST /v1/routes}. Wahoo
   * takes the FIT file as a base64 {@code data:} URI in {@code route[file]} rather than as a
   * multipart part, and requires the route's start point, distance and ascent alongside it — none
   * of which the FIT payload is read for. They are recomputed here from the same parsed GPX.
   *
   * <p>{@code external_id} is the SHA-256 of the GPX bytes: Wahoo deduplicates on it, so sending
   * the same route twice updates the one record instead of stacking copies in the user's library.
   * Editing the route changes the hash and therefore creates a new entry, which is the safe way
   * round — an upload can never overwrite a different route.
   */
  private String buildRouteForm(
      List<Path> paths, byte[] gpxContent, byte[] fitContent, String routeName) throws IOException {
    if (paths.isEmpty() || paths.getFirst().getSize() == 0) {
      throw new IOException("GPX holds no track point");
    }
    Path first = paths.getFirst();
    double distance = paths.stream().mapToDouble(Path::getTotalDistance).sum();
    double ascent = paths.stream().mapToDouble(Path::getElevationGain).sum();
    double descent = paths.stream().mapToDouble(Path::getElevationLoss).sum();

    String dataUri =
        "data:" + FIT_CONTENT_TYPE + ";base64," + Base64.getEncoder().encodeToString(fitContent);

    Map<String, String> params = new LinkedHashMap<>();
    params.put("route[file]", dataUri);
    params.put("route[filename]", sanitiseFileName(routeName) + ".fit");
    params.put("route[name]", routeName);
    params.put("route[external_id]", sha256Hex(gpxContent));
    params.put("route[provider_updated_at]", PROVIDER_UPDATED_AT.format(Instant.now()));
    params.put("route[workout_type_family_id]", Integer.toString(WORKOUT_TYPE_FAMILY_BIKING));
    params.put("route[start_lat]", Double.toString(first.latitudeDeg(0)));
    params.put("route[start_lng]", Double.toString(first.longitudeDeg(0)));
    params.put("route[distance]", Double.toString(distance));
    params.put("route[ascent]", Double.toString(ascent));
    params.put("route[descent]", Double.toString(descent));

    return params.entrySet().stream()
        .map(e -> urlEncode(e.getKey()) + "=" + urlEncode(e.getValue()))
        .collect(Collectors.joining("&"));
  }

  private static String sanitiseFileName(String routeName) {
    return routeName.replaceAll("[^a-zA-Z0-9_-]", "_");
  }

  private static String sha256Hex(byte[] content) throws IOException {
    try {
      byte[] digest = MessageDigest.getInstance("SHA-256").digest(content);
      return HexFormat.of().formatHex(digest);
    } catch (NoSuchAlgorithmException e) {
      throw new IOException("SHA-256 unavailable", e);
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
