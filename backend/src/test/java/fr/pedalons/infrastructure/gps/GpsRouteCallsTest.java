package fr.pedalons.infrastructure.gps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.net.URLDecoder;
import java.net.http.HttpClient;
import java.net.http.HttpHeaders;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The requests the clients build for the route sync (docs/LEDGER_*.md API-120 §4.5): method, URL,
 * authorization — the OAuth 1.0a signature of a {@code PUT} and a {@code DELETE} covering the URL
 * with the course id — and the fields Wahoo's {@code PUT} requires. No network: the {@link
 * HttpClient} is a mock that records the request.
 */
class GpsRouteCallsTest {

  private static final String GPX =
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
        <trk><name>t</name><trkseg>
          <trkpt lat="48.0000" lon="-1.6000"><ele>40</ele></trkpt>
          <trkpt lat="48.0100" lon="-1.6100"><ele>60</ele></trkpt>
          <trkpt lat="48.0200" lon="-1.6200"><ele>50</ele></trkpt>
        </trkseg></trk>
      </gpx>
      """;

  private HttpClient http;
  private final AtomicReference<HttpRequest> sent = new AtomicReference<>();

  @BeforeEach
  void setUp() {
    http = mock(HttpClient.class);
  }

  @SuppressWarnings("unchecked")
  private void answer(int status, String body, Map<String, List<String>> headers) throws Exception {
    HttpResponse<String> response = mock(HttpResponse.class);
    when(response.statusCode()).thenReturn(status);
    when(response.body()).thenReturn(body);
    when(response.headers()).thenReturn(HttpHeaders.of(headers, (a, b) -> true));
    when(http.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
        .thenAnswer(
            i -> {
              sent.set(i.getArgument(0));
              return response;
            });
  }

  private void answer(int status, String body) throws Exception {
    answer(status, body, Map.of());
  }

  private HammerheadClient hammerhead() {
    HammerheadClient client = new HammerheadClient();
    client.httpClient = http;
    client.objectMapper = new ObjectMapper();
    return client;
  }

  private WahooClient wahoo() {
    WahooClient client = new WahooClient();
    client.httpClient = http;
    client.objectMapper = new ObjectMapper();
    return client;
  }

  private GarminClient garmin() {
    GarminClient client = new GarminClient();
    client.httpClient = http;
    client.objectMapper = new ObjectMapper();
    client.courseConverter = mock(GarminCourseConverter.class);
    when(client.courseConverter.convertToGarminCourse(any(), anyString())).thenReturn("{}");
    return client;
  }

  private static final GpsAuth BEARER = new GpsAuth.Bearer("tok");

  // ------------------------------------------------------------------ Hammerhead

  @Test
  void hammerhead_update_putsTheFileOnTheRoute() throws Exception {
    answer(200, "{\"id\":\"r-1\"}");

    GpsCallResult result =
        hammerhead()
            .updateRoute(
                BEARER, "r-1", GPX.getBytes(), new RouteMeta("2026-10-18 · A · Boucle", null));

    assertEquals(new GpsCallResult.Ok("r-1"), result);
    assertEquals("PUT", sent.get().method());
    assertEquals("https://api.hammerhead.io/v1/api/routes/r-1/file", sent.get().uri().toString());
    assertEquals("Bearer tok", sent.get().headers().firstValue("Authorization").orElseThrow());
    assertTrue(
        sent.get().headers().firstValue("Content-Type").orElseThrow().startsWith("multipart/"));
  }

  @Test
  void hammerhead_delete() throws Exception {
    answer(204, "");

    GpsCallResult result = hammerhead().deleteRoute(BEARER, "r-1");

    assertEquals(new GpsCallResult.Ok("r-1"), result);
    assertEquals("DELETE", sent.get().method());
    assertEquals("https://api.hammerhead.io/v1/api/routes/r-1", sent.get().uri().toString());
  }

  @Test
  void hammerhead_fileName_keepsTheNameReadable() {
    assertEquals(
        "2026-10-18 - Groupe A - Boucle des etangs",
        HammerheadClient.fileName("2026-10-18 · Groupe A · Boucle des étangs"));
    assertEquals("a_b", HammerheadClient.fileName("a\"b"));
    assertEquals("route", HammerheadClient.fileName("  "));
  }

  @Test
  void statuses_mapToResults() throws Exception {
    answer(404, "");
    assertInstanceOf(GpsCallResult.NotFound.class, hammerhead().deleteRoute(BEARER, "x"));
    answer(401, "");
    assertInstanceOf(GpsCallResult.Unauthorized.class, hammerhead().deleteRoute(BEARER, "x"));
    answer(412, "");
    assertInstanceOf(GpsCallResult.PermissionRevoked.class, hammerhead().deleteRoute(BEARER, "x"));
    answer(500, "");
    assertEquals(new GpsCallResult.Failed(500, "HTTP 500"), hammerhead().deleteRoute(BEARER, "x"));
    answer(429, "", Map.of("Retry-After", List.of("120")));
    GpsCallResult limited = hammerhead().deleteRoute(BEARER, "x");
    GpsCallResult.RateLimited rl = assertInstanceOf(GpsCallResult.RateLimited.class, limited);
    assertTrue(rl.retryAt().isAfter(Instant.now().plusSeconds(100)));
  }

  @Test
  void retryAt_fallsBackOnTheDefaultPause() {
    Instant retryAt = GpsCallResult.retryAt(Optional.of("Wed, 21 Oct 2026 07:28:00 GMT"));
    assertTrue(
        retryAt.isAfter(
            Instant.now().plus(GpsCallResult.DEFAULT_RATE_LIMIT_PAUSE).minusSeconds(5)));
  }

  // ------------------------------------------------------------------ Wahoo

  @Test
  void wahoo_create_sendsTheStableExternalId() throws Exception {
    answer(200, "{\"id\":123}");

    GpsCallResult result =
        wahoo().createRoute(BEARER, GPX.getBytes(), new RouteMeta("Sortie", "pedalons-1-2"));

    assertEquals(new GpsCallResult.Ok("123"), result);
    assertEquals("POST", sent.get().method());
    assertEquals("https://api.wahooligan.com/v1/routes", sent.get().uri().toString());
  }

  @Test
  void wahoo_update_putsEveryRequiredFieldButTheExternalId() throws Exception {
    String form =
        WahooClient.buildRouteForm(
            WahooClient.parsePaths(GPX.getBytes()), new byte[] {1, 2}, "Sortie", null);
    Map<String, String> fields = parseForm(form);

    for (String required :
        List.of(
            "route[file]",
            "route[provider_updated_at]",
            "route[name]",
            "route[start_lat]",
            "route[start_lng]",
            "route[distance]",
            "route[ascent]")) {
      assertTrue(fields.containsKey(required), required);
    }
    assertFalse(fields.containsKey("route[external_id]"));
    assertEquals("Sortie", fields.get("route[name]"));

    String create =
        WahooClient.buildRouteForm(
            WahooClient.parsePaths(GPX.getBytes()), new byte[] {1, 2}, "Sortie", "pedalons-1-2");
    assertEquals("pedalons-1-2", parseForm(create).get("route[external_id]"));
  }

  @Test
  void wahoo_update_onTheRouteUrl() throws Exception {
    answer(200, "{\"id\":123}");

    GpsCallResult result =
        wahoo().updateRoute(BEARER, "123", GPX.getBytes(), new RouteMeta("Sortie", "x"));

    assertEquals(new GpsCallResult.Ok("123"), result);
    assertEquals("PUT", sent.get().method());
    assertEquals("https://api.wahooligan.com/v1/routes/123", sent.get().uri().toString());
  }

  @Test
  void wahoo_deletedRoute_isNotFound() throws Exception {
    answer(200, "{\"id\":123,\"deleted\":true}");

    GpsCallResult result =
        wahoo().updateRoute(BEARER, "123", GPX.getBytes(), new RouteMeta("Sortie", null));

    assertInstanceOf(GpsCallResult.NotFound.class, result);
  }

  // ------------------------------------------------------------------ Garmin

  @Test
  void garmin_update_answers204WithNoBody() throws Exception {
    answer(204, "");

    GpsCallResult result =
        garmin().updateRoute(BEARER, "987", GPX.getBytes(), new RouteMeta("Sortie", null));

    assertEquals(new GpsCallResult.Ok("987"), result);
    assertEquals("PUT", sent.get().method());
    assertEquals(
        "https://apis.garmin.com/training-api/courses/v1/course/987", sent.get().uri().toString());
  }

  @Test
  void garmin_oauth1_signsTheMethodAndTheUrlWithTheCourseId() throws Exception {
    answer(204, "");
    GpsAuth auth = new GpsAuth.OAuth1("ckey", "csecret", "atoken", "asecret");

    garmin().deleteRoute(auth, "987");

    String url = "https://apis.garmin.com/training-api/courses/v1/course/987";
    String header = sent.get().headers().firstValue("Authorization").orElseThrow();
    Map<String, String> params = parseOAuthHeader(header);
    String signature = params.remove("oauth_signature");
    assertEquals("atoken", params.get("oauth_token"));
    assertEquals(OAuth1Signer.signature("DELETE", url, params, "csecret", "asecret"), signature);
    // The same parameters signed for another method or URL do not match.
    assertFalse(
        OAuth1Signer.signature("POST", url, params, "csecret", "asecret").equals(signature));
    assertFalse(
        OAuth1Signer.signature(
                "DELETE", GarminClient.COURSE_UPLOAD_URL, params, "csecret", "asecret")
            .equals(signature));
  }

  @Test
  void auth_neverPrintsATokenInLogs() {
    assertFalse(new GpsAuth.Bearer("secret-token").toString().contains("secret-token"));
    assertFalse(new GpsAuth.OAuth1("k", "s", "t", "ts").toString().contains("ts"));
  }

  // ------------------------------------------------------------------ helpers

  private static Map<String, String> parseForm(String form) {
    Map<String, String> fields = new LinkedHashMap<>();
    for (String pair : form.split("&")) {
      int eq = pair.indexOf('=');
      fields.put(
          URLDecoder.decode(pair.substring(0, eq), StandardCharsets.UTF_8),
          URLDecoder.decode(pair.substring(eq + 1), StandardCharsets.UTF_8));
    }
    return fields;
  }

  private static Map<String, String> parseOAuthHeader(String header) {
    Map<String, String> params = new LinkedHashMap<>();
    Matcher m = Pattern.compile("([a-z_]+)=\"([^\"]*)\"").matcher(header);
    while (m.find()) {
      params.put(m.group(1), URLDecoder.decode(m.group(2), StandardCharsets.UTF_8));
    }
    return params;
  }
}
