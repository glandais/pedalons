package fr.pedalons.infrastructure.gps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

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
import tools.jackson.databind.ObjectMapper;

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
    when(client.courseConverter.convertToGarminCourse(any(), anyString(), anyList()))
        .thenReturn("{}");
    return client;
  }

  /** A Garmin client with the real converter, to read the course it sends. */
  private GarminClient garminWithRealConverter(boolean coursePoints) {
    GarminClient client = new GarminClient();
    client.httpClient = http;
    client.objectMapper = new ObjectMapper();
    client.courseConverter = new GarminCourseConverter();
    client.setCoursePointsEnabled(coursePoints);
    return client;
  }

  /** The body of the request the mocked client received. */
  private static byte[] body(HttpRequest request) throws Exception {
    java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
    java.util.concurrent.CompletableFuture<Void> done =
        new java.util.concurrent.CompletableFuture<>();
    request
        .bodyPublisher()
        .orElseThrow()
        .subscribe(
            new java.util.concurrent.Flow.Subscriber<java.nio.ByteBuffer>() {
              @Override
              public void onSubscribe(java.util.concurrent.Flow.Subscription subscription) {
                subscription.request(Long.MAX_VALUE);
              }

              @Override
              public void onNext(java.nio.ByteBuffer item) {
                byte[] bytes = new byte[item.remaining()];
                item.get(bytes);
                out.write(bytes, 0, bytes.length);
              }

              @Override
              public void onError(Throwable throwable) {
                done.completeExceptionally(throwable);
              }

              @Override
              public void onComplete() {
                done.complete(null);
              }
            });
    done.get();
    return out.toByteArray();
  }

  private static final String GPX_WITH_WAYPOINTS =
      """
      <?xml version="1.0" encoding="UTF-8"?>
      <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
        <wpt lat="48.0050" lon="-1.6050"><name>Source</name><desc>Eau potable</desc><sym>Drinking Water</sym><type>water</type></wpt>
        <wpt lat="48.0150" lon="-1.6150"><name>RDV</name><sym>Flag, Blue</sym><type>meeting_spot</type></wpt>
        <wpt lat="48.5000" lon="-1.0000"><name>Loin</name><sym>Danger Area</sym><type>danger</type></wpt>
        <trk><name>t</name><trkseg>
          <trkpt lat="48.0000" lon="-1.6000"><ele>40</ele></trkpt>
          <trkpt lat="48.0100" lon="-1.6100"><ele>60</ele></trkpt>
          <trkpt lat="48.0200" lon="-1.6200"><ele>50</ele></trkpt>
        </trkseg></trk>
      </gpx>
      """;

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

  // ------------------------------------------------------------------ Waypoints (WEB-100, C3c)

  @Test
  void hammerhead_sendsTheNineValues() throws Exception {
    answer(200, "{\"id\":\"r-1\"}");

    hammerhead()
        .createRoute(
            BEARER, GPX_WITH_WAYPOINTS.getBytes(StandardCharsets.UTF_8), new RouteMeta("S", null));

    String sentBody = new String(body(sent.get()), StandardCharsets.UTF_8);
    assertTrue(sentBody.contains("<sym>Water</sym>"), sentBody);
    assertTrue(sentBody.contains("<type>Water</type>"), sentBody);
    assertTrue(sentBody.contains("<sym>Danger</sym>"), "the point off the track is sent too");
    assertTrue(sentBody.contains("<sym>Generic</sym>"), sentBody);
    assertFalse(sentBody.contains("Drinking Water"), sentBody);
    assertFalse(sentBody.contains("meeting_spot"), sentBody);
    assertTrue(sentBody.contains("Eau potable"));
  }

  @Test
  void wahoo_fitCarriesTheCoursePoints() throws Exception {
    answer(200, "{\"id\":123}");
    List<fr.pedalons.infrastructure.gpx.CoursePoint> points =
        List.of(
            new fr.pedalons.infrastructure.gpx.CoursePoint(
                700, fr.pedalons.enums.WaypointType.WATER, "Source"));

    wahoo()
        .createRoute(
            BEARER, GPX.getBytes(StandardCharsets.UTF_8), new RouteMeta("Sortie", null, points));

    String form = new String(body(sent.get()), StandardCharsets.UTF_8);
    String dataUri = parseForm(form).get("route[file]");
    byte[] fit =
        java.util.Base64.getDecoder().decode(dataUri.substring(dataUri.indexOf("base64,") + 7));
    var coursePoints =
        new com.garmin.fit.FitDecoder(fit)
            .decode(new com.garmin.fit.DecodeOptions())
            .getMessages()
            .getCoursePointMesgs();
    assertEquals(1, coursePoints.size());
    assertEquals("Source", coursePoints.getFirst().getName());
  }

  private static final List<fr.pedalons.infrastructure.gpx.CoursePoint> ONE_POINT =
      List.of(
          new fr.pedalons.infrastructure.gpx.CoursePoint(
              1000, fr.pedalons.enums.WaypointType.WATER, "Source"));

  @Test
  void garmin_insertsInformationGeoPointAtItsDistance_whenEnabled() throws Exception {
    answer(200, "{\"courseId\":\"1\"}");

    garminWithRealConverter(true)
        .createRoute(
            BEARER, GPX.getBytes(StandardCharsets.UTF_8), new RouteMeta("Sortie", null, ONE_POINT));

    var course = new ObjectMapper().readTree(body(sent.get()));
    var geoPoints = course.get("geoPoints");
    assertEquals(4, geoPoints.size(), "the three points and the course point");
    var inserted = geoPoints.get(1);
    assertEquals("Source", inserted.get("information").get("name").asText());
    assertEquals("WATER", inserted.get("information").get("coursePointType").asText());
    assertEquals(1000.0, inserted.get("distance").asDouble(), 0.1);
    // 1 000 m along a track of about 1 500 m between the first and the second point
    assertTrue(
        inserted.get("latitude").asDouble() > 48.0
            && inserted.get("latitude").asDouble() < 48.0200);
  }

  @Test
  void garmin_sendsNoInformation_whenDisabled() throws Exception {
    answer(200, "{\"courseId\":\"1\"}");

    garminWithRealConverter(false)
        .createRoute(
            BEARER, GPX.getBytes(StandardCharsets.UTF_8), new RouteMeta("Sortie", null, ONE_POINT));

    var course = new ObjectMapper().readTree(body(sent.get()));
    assertEquals(3, course.get("geoPoints").size());
    assertFalse(new String(body(sent.get()), StandardCharsets.UTF_8).contains("information"));
  }

  @Test
  void garmin_distanceDoesNotJumpBetweenTracks() throws Exception {
    // Two tracks 100 km apart: the course is as long as the two tracks, not the gap
    String twoTracks =
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><name>a</name><trkseg>
            <trkpt lat="48.0000" lon="-1.6000"/><trkpt lat="48.0100" lon="-1.6000"/>
          </trkseg></trk>
          <trk><name>b</name><trkseg>
            <trkpt lat="49.0000" lon="-1.6000"/><trkpt lat="49.0100" lon="-1.6000"/>
          </trkseg></trk>
        </gpx>
        """;
    answer(200, "{\"courseId\":\"1\"}");

    garminWithRealConverter(true)
        .createRoute(
            BEARER, twoTracks.getBytes(StandardCharsets.UTF_8), new RouteMeta("Sortie", null));

    var course = new ObjectMapper().readTree(body(sent.get()));
    // 2 x 1.11 km
    assertEquals(2224, course.get("distance").asInt(), 5);
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
