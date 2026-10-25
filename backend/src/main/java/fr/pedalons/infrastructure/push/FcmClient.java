package fr.pedalons.infrastructure.push;

import fr.pedalons.enums.PushPlatform;
import io.smallrye.jwt.algorithm.SignatureAlgorithm;
import io.smallrye.jwt.build.Jwt;
import io.smallrye.jwt.util.KeyUtils;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.core.Response;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * Sends one message to one device through FCM HTTP v1, and mints the access token that needs.
 *
 * <p>Configuration is all-or-nothing: without a service account the client reports itself
 * unconfigured, {@code PushNotificationSender} then reports the channel unavailable, and the
 * pipeline creates no push delivery at all. A half-configured push channel would queue rows that
 * can never leave.
 */
@ApplicationScoped
public class FcmClient {

  private static final Logger LOG = Logger.getLogger(FcmClient.class);

  private static final String SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
  private static final String DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";

  /** Renew a little early: a token that expires in flight would fail a whole batch. */
  private static final Duration EXPIRY_MARGIN = Duration.ofMinutes(2);

  private static final Duration ASSERTION_LIFETIME = Duration.ofMinutes(60);

  /**
   * How long a browser's push service keeps a web push for a browser that is offline. A day: a ride
   * reminder or a cancellation read later than that is noise, and the inbox still has it.
   */
  private static final String WEB_TTL_SECONDS = "86400";

  @ConfigProperty(name = "pedalons.push.enabled", defaultValue = "false")
  boolean enabled;

  /**
   * The service-account JSON: either the document itself, or a path to it. A path is what a
   * deployment mounts as a secret; the inline form is there for a container that only has env vars.
   */
  @ConfigProperty(name = "pedalons.push.fcm.credentials")
  Optional<String> credentials;

  /** Overrides the {@code project_id} of the credentials, which is normally right. */
  @ConfigProperty(name = "pedalons.push.fcm.project-id")
  Optional<String> configuredProjectId;

  @Inject ObjectMapper objectMapper;
  @Inject @RestClient GoogleOAuthRestClient oauth;
  @Inject @RestClient FcmRestClient fcm;

  private @Nullable FcmServiceAccount account;

  private @Nullable String accessToken;
  private Instant accessTokenExpiry = Instant.EPOCH;

  @PostConstruct
  void init() {
    if (!enabled || credentials.isEmpty() || credentials.get().isBlank()) {
      return;
    }
    try {
      account = parse(credentials.get());
      LOG.infof("Push notifications enabled — FCM project %s", account.projectId());
    } catch (Exception e) {
      // Not fatal: the application must still start. The channel stays unavailable, which is
      // visible both in the log and in the empty channel list of GET /notifications/preferences.
      LOG.error("Push notifications disabled: the FCM service account could not be read", e);
    }
  }

  /** Whether a push can be sent right now — switched on, and with usable credentials. */
  public boolean isConfigured() {
    return account != null;
  }

  /**
   * The Firebase project messages go through, or null when push is not configured. The web client
   * must obtain its tokens from this same project, so {@code ConfigService} hands it to the site.
   */
  public @Nullable String projectId() {
    FcmServiceAccount serviceAccount = account;
    return serviceAccount == null ? null : serviceAccount.projectId();
  }

  private FcmServiceAccount parse(String raw)
      throws IOException, java.security.GeneralSecurityException {
    String json = raw.trim().startsWith("{") ? raw : Files.readString(Path.of(raw.trim()));
    JsonNode node = objectMapper.readTree(json);
    String projectId = configuredProjectId.orElseGet(() -> node.path("project_id").asString());
    String clientEmail = node.path("client_email").asString();
    String privateKey = node.path("private_key").asString();
    if (projectId.isEmpty() || clientEmail.isEmpty() || privateKey.isEmpty()) {
      throw new IOException("Incomplete service account: project_id, client_email, private_key");
    }
    String tokenUri = node.path("token_uri").asString(DEFAULT_TOKEN_URI);
    return new FcmServiceAccount(
        projectId, clientEmail, KeyUtils.decodePrivateKey(privateKey), tokenUri);
  }

  /**
   * Delivers one notification to one device.
   *
   * @throws FcmException with {@link FcmException#tokenInvalid()} when the token is dead and the
   *     caller must purge it, and without it when another attempt is worth making
   */
  public void send(
      String token, PushPlatform platform, String title, String body, Map<String, String> data)
      throws FcmException {
    FcmServiceAccount serviceAccount = account;
    if (serviceAccount == null) {
      throw new FcmException("Push is not configured", false);
    }
    Response response;
    try {
      response =
          fcm.send(
              serviceAccount.projectId(),
              "Bearer " + accessToken(serviceAccount),
              Map.of("message", message(token, platform, title, body, data)));
    } catch (FcmException e) {
      throw e;
    } catch (Exception e) {
      throw new FcmException("FCM call failed", e);
    }
    try (response) {
      if (response.getStatus() / 100 == 2) {
        return;
      }
      String payload = readBody(response);
      throw new FcmException(
          "FCM returned " + response.getStatus() + ": " + truncate(payload),
          isTokenInvalid(response.getStatus(), payload));
    }
  }

  static Map<String, Object> message(
      String token, PushPlatform platform, String title, String body, Map<String, String> data) {
    Map<String, Object> message = new HashMap<>();
    message.put("token", token);
    if (platform == PushPlatform.WEB) {
      // Data only: the site's service worker (frontend/public/sw.js) shows the notification itself,
      // from the title and body carried here. A top-level notification block would make the browser
      // — or the Firebase SDK — display it as well, and the member would see it twice.
      Map<String, String> webData = new LinkedHashMap<>(data);
      webData.put("title", title);
      webData.put("body", body);
      message.put("data", webData);
      message.put("webpush", Map.of("headers", Map.of("Urgency", "high", "TTL", WEB_TTL_SECONDS)));
      return message;
    }
    message.put("notification", Map.of("title", title, "body", body));
    message.put("data", data);
    if (platform == PushPlatform.ANDROID) {
      message.put(
          "android",
          Map.of("priority", "high", "notification", Map.of("channel_id", "pedalons_default")));
    } else {
      // No content-available: nothing in the app uses a background wake (the iOS badge was ruled
      // out), and the wake is harmful — it relaunches a killed app before the tap, and
      // firebase_messaging then withholds the tap from getInitialMessage() at launch. See the
      // iOS pitfalls in docs/LEDGER_*.md NOTIF-9.
      message.put(
          "apns",
          Map.of(
              "headers",
              Map.of("apns-priority", "10"),
              "payload",
              Map.of("aps", Map.of("sound", "default"))));
    }
    return message;
  }

  /**
   * {@code UNREGISTERED} is the app uninstalled or the token rotated; {@code INVALID_ARGUMENT} on a
   * send is, in practice, a malformed token. Both mean the row must go — retrying them until
   * {@code max-attempts} would only delay the purge.
   */
  private static boolean isTokenInvalid(int status, String payload) {
    if (status == 404) {
      return true;
    }
    return status == 400 && payload.contains("INVALID_ARGUMENT");
  }

  private static String readBody(Response response) {
    try {
      String payload = response.readEntity(String.class);
      return payload == null ? "" : payload;
    } catch (Exception e) {
      return "";
    }
  }

  /** Bodies end up in {@code notification_deliveries.error_message}, which is 500 characters. */
  private static String truncate(String payload) {
    return payload.length() <= 400 ? payload : payload.substring(0, 400);
  }

  /** The cached access token, minted on first use and renewed shortly before it expires. */
  private synchronized String accessToken(FcmServiceAccount serviceAccount) throws FcmException {
    String current = accessToken;
    if (current != null && Instant.now().isBefore(accessTokenExpiry)) {
      return current;
    }
    String assertion =
        Jwt.issuer(serviceAccount.clientEmail())
            .audience(serviceAccount.tokenUri())
            .claim("scope", SCOPE)
            .issuedAt(Instant.now())
            .expiresAt(Instant.now().plus(ASSERTION_LIFETIME))
            .jws()
            .algorithm(SignatureAlgorithm.RS256)
            .sign(serviceAccount.privateKey());

    try (Response response = oauth.token(GoogleOAuthRestClient.JWT_BEARER, assertion)) {
      String payload = readBody(response);
      if (response.getStatus() / 100 != 2) {
        throw new FcmException(
            "Google token endpoint returned " + response.getStatus() + ": " + truncate(payload),
            false);
      }
      JsonNode node = objectMapper.readTree(payload);
      String token = node.path("access_token").asString();
      if (token.isEmpty()) {
        throw new FcmException("Google token endpoint returned no access_token", false);
      }
      long expiresIn = node.path("expires_in").asLong(3600);
      accessToken = token;
      accessTokenExpiry = Instant.now().plusSeconds(expiresIn).minus(EXPIRY_MARGIN);
      return token;
    } catch (FcmException e) {
      throw e;
    } catch (Exception e) {
      throw new FcmException("Could not mint an FCM access token", e);
    }
  }
}
