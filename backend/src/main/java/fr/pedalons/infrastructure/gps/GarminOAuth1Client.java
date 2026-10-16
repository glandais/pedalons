package fr.pedalons.infrastructure.gps;

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
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * Garmin Connect over OAuth 1.0a — the protocol of applications declared before Garmin's OAuth 2.0
 * programme, which still admits none of ours (docs/LEDGER_*.md API-61, API-62). The domain's Garmin
 * credential then holds the consumer key ({@code clientId}) and consumer secret.
 *
 * <p>Three legs: a request token, the user's consent on Garmin Connect, then the access token in
 * exchange for the verifier the callback brings. The access token neither expires nor refreshes.
 */
@ApplicationScoped
public class GarminOAuth1Client {

  private static final Logger LOG = Logger.getLogger(GarminOAuth1Client.class);

  /** As the route calls': a token request never hangs. */
  private static final Duration CALL_TIMEOUT = Duration.ofSeconds(30);

  private static final String REQUEST_TOKEN_URL =
      "https://connectapi.garmin.com/oauth-service/oauth/request_token";
  private static final String AUTHORIZE_URL = "https://connect.garmin.com/oauthConfirm";
  private static final String ACCESS_TOKEN_URL =
      "https://connectapi.garmin.com/oauth-service/oauth/access_token";

  @Inject DomainGpsCredentialService credentialService;

  @Inject HttpClient httpClient;

  @Inject GarminClient garminClient;

  /** A token and its secret: the request token of the first leg, or the access token. */
  public record Token(String token, String secret) {}

  /** First leg: a request token whose consent will be redirected to {@code callbackUrl}. */
  public Token requestToken(String callbackUrl) {
    return postForToken(REQUEST_TOKEN_URL, null, null, Map.of("oauth_callback", callbackUrl));
  }

  /** Second leg: where to send the user to consent. */
  public String authorizationUrl(String requestToken) {
    return AUTHORIZE_URL
        + "?oauth_token="
        + URLEncoder.encode(requestToken, StandardCharsets.UTF_8);
  }

  /** Third leg: the access token, against the verifier the callback brought. */
  public Token accessToken(String requestToken, String requestTokenSecret, String verifier) {
    return postForToken(
        ACCESS_TOKEN_URL, requestToken, requestTokenSecret, Map.of("oauth_verifier", verifier));
  }

  /** Creates a course on Garmin Connect, signed with the user's access token. */
  public RouteUploadResult uploadRoute(
      String accessToken, String accessTokenSecret, byte[] gpxContent, String routeName) {
    Consumer consumer = consumer();
    GpsAuth auth =
        new GpsAuth.OAuth1(consumer.key(), consumer.secret(), accessToken, accessTokenSecret);
    return garminClient.createRoute(auth, gpxContent, RouteMeta.manual(routeName)).toUploadResult();
  }

  /**
   * The signing authorization of a connection made over OAuth 1.0a, with an explicit credential:
   * for the route calls of {@link GarminClient} ({@code createRoute}, {@code updateRoute}, {@code
   * deleteRoute}), which sign their own method and URL with it.
   */
  public static GpsAuth auth(
      DomainGpsCredential credential,
      String consumerSecret,
      String accessToken,
      String accessTokenSecret) {
    return new GpsAuth.OAuth1(
        credential.getClientId(), consumerSecret, accessToken, accessTokenSecret);
  }

  private Token postForToken(
      String url,
      @Nullable String token,
      @Nullable String tokenSecret,
      Map<String, String> extraOAuthParams) {
    Consumer consumer = consumer();
    String authorization =
        OAuth1Signer.authorizationHeader(
            "POST", url, consumer.key(), consumer.secret(), token, tokenSecret, extraOAuthParams);
    try {
      HttpRequest request =
          HttpRequest.newBuilder()
              .uri(URI.create(url))
              .header("Authorization", authorization)
              .timeout(CALL_TIMEOUT)
              .POST(HttpRequest.BodyPublishers.noBody())
              .build();
      HttpResponse<String> response =
          httpClient.send(request, HttpResponse.BodyHandlers.ofString());
      if (response.statusCode() != 200) {
        LOG.errorf(
            "Garmin OAuth 1.0a token request failed: %d %s",
            response.statusCode(), response.body());
        throw new InternalException(
            ErrorCode.GPS_TOKEN_EXCHANGE_FAILED,
            new IOException("Garmin OAuth 1.0a token request failed: " + response.statusCode()));
      }
      Map<String, String> fields = parseForm(response.body());
      String oauthToken = fields.get("oauth_token");
      String oauthTokenSecret = fields.get("oauth_token_secret");
      if (oauthToken == null || oauthTokenSecret == null) {
        throw new InternalException(
            ErrorCode.GPS_TOKEN_EXCHANGE_FAILED,
            new IOException("Garmin OAuth 1.0a response without a token"));
      }
      return new Token(oauthToken, oauthTokenSecret);
    } catch (IOException | InterruptedException e) {
      throw new InternalException(ErrorCode.GPS_TOKEN_EXCHANGE_FAILED, e);
    }
  }

  /** The token endpoints answer {@code application/x-www-form-urlencoded}. */
  static Map<String, String> parseForm(String body) {
    Map<String, String> fields = new HashMap<>();
    for (String pair : body.trim().split("&")) {
      int eq = pair.indexOf('=');
      if (eq > 0) {
        fields.put(
            URLDecoder.decode(pair.substring(0, eq), StandardCharsets.UTF_8),
            URLDecoder.decode(pair.substring(eq + 1), StandardCharsets.UTF_8));
      }
    }
    return fields;
  }

  private record Consumer(String key, String secret) {}

  private Consumer consumer() {
    DomainGpsCredential credential =
        credentialService
            .getCredentials(GpsServiceType.GARMIN)
            .orElseThrow(() -> new BusinessException(ErrorCode.GPS_SERVICE_NOT_CONFIGURED));
    String secret = credentialService.getDecryptedClientSecret(credential);
    if (secret == null) {
      throw new BusinessException(ErrorCode.GPS_SERVICE_NOT_CONFIGURED);
    }
    return new Consumer(credential.getClientId(), secret);
  }
}
