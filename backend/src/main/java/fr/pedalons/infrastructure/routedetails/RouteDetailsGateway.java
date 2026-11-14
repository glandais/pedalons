package fr.pedalons.infrastructure.routedetails;

import fr.pedalons.infrastructure.routedetails.RouteDetailsException.Kind;
import io.quarkus.rest.client.reactive.QuarkusRestClientBuilder;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.locks.ReentrantLock;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

/**
 * The way to osm-route-details for the rest of the backend, and what the tests mock (nothing here
 * may reach the network from a test). {@code GpxPipeline} calls it for every elevation profile:
 * docs/LEDGER_*.md API-150.
 *
 * <p><b>Two clients, one per profile.</b> A {@code fast} call answers in a few seconds, a {@code
 * full} one may take up to the service's 90 s budget: a single read timeout would either cut the
 * {@code full} calls or leave a {@code fast} caller hanging for 100 s on a stuck service. A
 * {@code @RestClient} injection takes one timeout per config key, so both instances are built here
 * with {@link QuarkusRestClientBuilder} from the {@code osm-route-details} key's url and connect
 * timeout and the two {@code pedalons.route-details.*-timeout}. A programmatic build does not read
 * the key's other properties: the response decompression is switched on here too. Built on first
 * use, in {@link #client}.
 *
 * <p><b>Faked in tests by overriding {@link #client}.</b> Since no {@code RouteDetailsClient} bean
 * is ever injected, a {@code @Mock @RestClient} replacement would be silently ignored and the tests
 * would open real connections. The test fake ({@code FakeRouteDetailsGateway}, a {@code @Mock}
 * subclass) answers {@link #client} with an in-memory client instead, so the slicing, the
 * stitching and the error classification still run in tests, off the network.
 *
 * <p><b>Capabilities, cached.</b> The input bounds come from {@code /v1/capabilities}, fetched on
 * first use and kept an hour; a failed fetch is tried again a minute later at the earliest, and in
 * between {@link #limits()} answers the last bounds fetched, else the fallback ones. One fetch runs
 * at a time; the callers that arrive meanwhile do not wait for it. Never fetched at startup: the backend
 * starts whether or not the service is up.
 *
 * <p><b>A pause after no answer.</b> The read timeout bounds one call, and a caller with a user
 * waiting makes one per line or per track: 50 straight lines on a stuck service would add up to 12
 * minutes. So a call that gets no answer at all (refused, timed out) suspends the {@code fast} calls
 * for {@link #FAST_PAUSE}: they fail at once as a transient failure, which every caller already
 * survives with the file's elevations. An error status does not count, it came back quickly.
 * {@code full} is left alone: its calls run one at a time in a worker, which has a retry of its own.
 */
@ApplicationScoped
public class RouteDetailsGateway {

  private static final Logger LOG = Logger.getLogger(RouteDetailsGateway.class);

  static final Duration CAPABILITIES_TTL = Duration.ofHours(1);
  static final Duration CAPABILITIES_RETRY = Duration.ofMinutes(1);
  static final Duration FAST_PAUSE = Duration.ofSeconds(30);

  /** The api {@code surface.detail} came with, which the surface projection needs (plan §2.3). */
  static final int MIN_MAJOR = 1;

  static final int MIN_MINOR = 6;

  @ConfigProperty(name = "quarkus.rest-client.osm-route-details.url")
  String url;

  @ConfigProperty(
      name = "quarkus.rest-client.osm-route-details.connect-timeout",
      defaultValue = "3000")
  long connectTimeoutMs;

  @ConfigProperty(name = "pedalons.route-details.fast-timeout", defaultValue = "PT15S")
  Duration fastTimeout;

  @ConfigProperty(name = "pedalons.route-details.full-timeout", defaultValue = "PT100S")
  Duration fullTimeout;

  /** The switch of the edges: only read here to say once that the service cannot serve them. */
  @ConfigProperty(name = "pedalons.network-edges.enabled", defaultValue = "true")
  boolean networkEdgesEnabled;

  private final AtomicBoolean edgesMissingLogged = new AtomicBoolean();

  /** Package-private so that a test against a local server can set its own. */
  volatile @Nullable RouteDetailsClient fastClient;

  volatile @Nullable RouteDetailsClient fullClient;

  private volatile @Nullable RouteDetailsCapabilities capabilities;
  private volatile @Nullable Instant capabilitiesFetchedAt;
  private volatile @Nullable Instant capabilitiesFailedAt;
  private final ReentrantLock capabilitiesLock = new ReentrantLock();

  /** Until when {@code fast} calls are skipped; package-private so that a test can end it. */
  volatile @Nullable Instant fastPausedUntil;

  /**
   * The details of {@code request}, on the client of its profile ({@code full} when none is set).
   * Blocking: a {@code full} call runs in a worker, and within an HTTP request only when {@code
   * pedalons.elevation.async-hd.enabled} is off.
   *
   * @throws RouteDetailsException on any failure, classified
   */
  public RouteDetailsResponse details(RouteDetailsRequest request) {
    RouteDetailsProfile profile = request.effectiveProfile();
    Instant pausedUntil = fastPausedUntil;
    if (profile == RouteDetailsProfile.FAST
        && pausedUntil != null
        && Instant.now().isBefore(pausedUntil)) {
      throw new RouteDetailsException(
          Kind.TRANSIENT, 0, null, "fast calls paused after a call without answer", null, null);
    }
    RouteDetailsClient client = client(profile);
    RouteDetailsResponse response;
    try {
      response = client.routeDetails(request);
    } catch (WebApplicationException e) {
      RouteDetailsException failure = fromWebApplication(e);
      if (failure.status() == 400 && request.options() != null && request.options().wantsEdges()) {
        // Sent to a service that does not know the option, whatever the capabilities said (rolled
        // back to an older image within the cache hour): ask them again before the next call
        LOG.warnf("osm-route-details refused a request with edges (400), capabilities dropped");
        capabilitiesFetchedAt = null;
      }
      throw paused(failure, profile);
    } catch (ProcessingException e) {
      throw paused(RouteDetailsErrors.noAnswer(e), profile);
    }
    if (response == null) {
      // A 200 with an empty body: the client reads it as null, the same answer would come back.
      throw new RouteDetailsException(Kind.BUG, 200, null, "empty answer", null, null);
    }
    return response;
  }

  /**
   * The details of a whole line, in as many calls as its length and points need: the line is
   * thinned and sliced under the published bounds ({@link RouteSlicer}), the slices go out <b>in
   * sequence</b> — never a burst on the service's {@code full} queue — and their answers come back
   * as one ({@link RouteDetailsStitcher}). The indices of the answer are those of {@code lat} /
   * {@code lon}; a point the thinning dropped (closer than 5 m to the previous one sent) has no
   * point of its own. A sliced call always asks for the elevation section, in {@code
   * input_with_breakpoints} or {@code input} sampling: its points carry the anchors of the stitching,
   * which must be the input points themselves ({@code distance} stations start again at each slice).
   *
   * @throws RouteDetailsException on the first slice that fails: nothing partial is returned
   * @throws IllegalArgumentException with fewer than two points
   */
  public RouteDetailsResponse details(double[] lat, double[] lon, RouteDetailsOptions options) {
    RouteSlicer.Plan plan = RouteSlicer.plan(lat, lon, limits());
    RouteDetailsOptions asked =
        options.wantsEdges() && !supportsEdges() ? options.withEdges(false) : options;
    RouteDetailsOptions sent = plan.isSliced() ? forSlicing(asked) : asked;
    List<RouteDetailsResponse> responses = new ArrayList<>(plan.slices().size());
    for (RouteSlicer.Slice slice : plan.slices()) {
      responses.add(
          details(
              RouteDetailsRequest.ofSlice(plan.lat(), plan.lon(), slice.from(), slice.to(), sent)));
    }
    return RouteDetailsStitcher.reindex(
        RouteDetailsStitcher.stitch(plan.slices(), responses), plan.sent());
  }

  /** {@code failure}, having suspended the {@code fast} calls when it is a call without answer. */
  private RouteDetailsException paused(RouteDetailsException failure, RouteDetailsProfile profile) {
    if (profile == RouteDetailsProfile.FAST) {
      pauseIfNoAnswer(failure);
    }
    return failure;
  }

  private void pauseIfNoAnswer(RouteDetailsException failure) {
    if (failure.kind() == Kind.TRANSIENT && failure.status() == 0) {
      fastPausedUntil = Instant.now().plus(FAST_PAUSE);
    }
  }

  /** The options of a sliced call: the elevation section, and points anchored on the input. */
  static RouteDetailsOptions forSlicing(RouteDetailsOptions options) {
    RouteDetailsOptions sent = options;
    List<RouteDetailsSection> sections = sent.sections();
    // No list: the service's default, all three sections
    if (sections != null && !sections.contains(RouteDetailsSection.ELEVATION)) {
      List<RouteDetailsSection> withElevation = new ArrayList<>(sections);
      withElevation.add(RouteDetailsSection.ELEVATION);
      sent = sent.withSections(withElevation);
    }
    String mode = sent.sampling() == null ? null : sent.sampling().mode();
    // No mode: the service's default, input_with_breakpoints
    if (mode != null
        && !RouteDetailsOptions.INPUT_WITH_BREAKPOINTS.equals(mode)
        && !RouteDetailsOptions.INPUT.equals(mode)) {
      sent =
          new RouteDetailsOptions(
              sent.profile(),
              sent.sections(),
              new RouteDetailsOptions.Sampling(RouteDetailsOptions.INPUT_WITH_BREAKPOINTS),
              sent.elevation(),
              sent.acceptPartial(),
              sent.edges());
    }
    return sent;
  }

  /**
   * The service's capabilities, empty while it cannot be reached. Cached; never throws.
   */
  public Optional<RouteDetailsCapabilities> capabilities() {
    RouteDetailsCapabilities cached = capabilities;
    Instant fetchedAt = capabilitiesFetchedAt;
    Instant now = Instant.now();
    if (cached != null && fetchedAt != null && now.isBefore(fetchedAt.plus(CAPABILITIES_TTL))) {
      return Optional.of(cached);
    }
    Instant failedAt = capabilitiesFailedAt;
    if (failedAt != null && now.isBefore(failedAt.plus(CAPABILITIES_RETRY))) {
      // A stale copy is better than the fallback bounds.
      return Optional.ofNullable(cached);
    }
    return Optional.ofNullable(fetchCapabilities());
  }

  /**
   * Whether the service answers {@code options.edges} (api 1.7 with {@code data.edges}), on the
   * cached capabilities: false while they are unknown or the service is unreachable. Never throws.
   * {@link #details(double[], double[], RouteDetailsOptions)} takes the option out of a request
   * when this is false, so that no caller can make an older service answer a 400.
   */
  public boolean supportsEdges() {
    return capabilities().map(RouteDetailsCapabilities::supportsEdges).orElse(false);
  }

  /** The input bounds a request must stay under: the published ones, else 200 km / 16 000 points. */
  public RouteDetailsCapabilities.Limits limits() {
    return capabilities()
        .map(RouteDetailsCapabilities::effectiveLimits)
        .orElse(RouteDetailsCapabilities.FALLBACK_LIMITS);
  }

  /**
   * One fetch at a time, on a lock of its own (not the monitor {@link #client} builds under): a
   * caller that finds a fetch under way takes the cached copy, or the fallback bounds, at once
   * rather than queue behind a stuck service's read timeout.
   */
  private @Nullable RouteDetailsCapabilities fetchCapabilities() {
    if (!capabilitiesLock.tryLock()) {
      return capabilities;
    }
    try {
      // Another thread may have fetched them, or failed to, just before this one took the lock.
      Instant now = Instant.now();
      Instant fetchedAt = capabilitiesFetchedAt;
      if (capabilities != null
          && fetchedAt != null
          && now.isBefore(fetchedAt.plus(CAPABILITIES_TTL))) {
        return capabilities;
      }
      Instant failedAt = capabilitiesFailedAt;
      if (failedAt != null && now.isBefore(failedAt.plus(CAPABILITIES_RETRY))) {
        return capabilities;
      }
      return doFetchCapabilities();
    } finally {
      capabilitiesLock.unlock();
    }
  }

  private @Nullable RouteDetailsCapabilities doFetchCapabilities() {
    try {
      // The fast client: a short read timeout, the capabilities are static.
      RouteDetailsCapabilities fetched = client(RouteDetailsProfile.FAST).capabilities();
      if (fetched == null) {
        // A 200 with an empty body
        LOG.warn("osm-route-details capabilities unavailable, empty answer");
        capabilitiesFailedAt = Instant.now();
        return capabilities;
      }
      check(fetched);
      checkEdges(fetched);
      capabilities = fetched;
      capabilitiesFetchedAt = Instant.now();
      capabilitiesFailedAt = null;
      return fetched;
    } catch (WebApplicationException | ProcessingException e) {
      RouteDetailsException failure =
          e instanceof WebApplicationException w
              ? fromWebApplication(w)
              : RouteDetailsErrors.noAnswer(e);
      LOG.warnf("osm-route-details capabilities unavailable, %s", failure.getMessage());
      capabilitiesFailedAt = Instant.now();
      // Asked first, on the fast client: no answer here would otherwise cost a second timeout
      pauseIfNoAnswer(failure);
      return capabilities;
    }
  }

  private void checkEdges(RouteDetailsCapabilities fetched) {
    if (networkEdgesEnabled
        && !fetched.supportsEdges()
        && edgesMissingLogged.compareAndSet(false, true)) {
      LOG.infof(
          "osm-route-details api %s serves no edges: network edges not asked",
          fetched.apiVersion());
    }
  }

  private static void check(RouteDetailsCapabilities fetched) {
    if (!fetched.supportsFast()) {
      LOG.errorf(
          "osm-route-details api %s has no fast profile: every call must run in full",
          fetched.apiVersion());
    }
    if (!fetched.apiAtLeast(MIN_MAJOR, MIN_MINOR) || !fetched.supportsSurfaceDetail()) {
      LOG.errorf(
          "osm-route-details api %s is older than %d.%d or serves no surface.detail",
          fetched.apiVersion(), MIN_MAJOR, MIN_MINOR);
    }
  }

  private static RouteDetailsException fromWebApplication(WebApplicationException e) {
    Response response = e.getResponse();
    if (response == null) {
      return RouteDetailsErrors.noAnswer(e);
    }
    return RouteDetailsErrors.fromResponse(response, e);
  }

  /** The client of a profile, built on first use; the seam the test fake overrides. */
  RouteDetailsClient client(RouteDetailsProfile profile) {
    RouteDetailsClient client = profile == RouteDetailsProfile.FAST ? fastClient : fullClient;
    if (client != null) {
      return client;
    }
    synchronized (this) {
      if (profile == RouteDetailsProfile.FAST) {
        RouteDetailsClient fast = fastClient;
        if (fast == null) {
          fast = build(fastTimeout);
          fastClient = fast;
        }
        return fast;
      }
      RouteDetailsClient full = fullClient;
      if (full == null) {
        full = build(fullTimeout);
        fullClient = full;
      }
      return full;
    }
  }

  private RouteDetailsClient build(Duration readTimeout) {
    return QuarkusRestClientBuilder.newBuilder()
        .baseUri(URI.create(url))
        .connectTimeout(connectTimeoutMs, TimeUnit.MILLISECONDS)
        .readTimeout(readTimeout.toMillis(), TimeUnit.MILLISECONDS)
        .enableCompression(true)
        .build(RouteDetailsClient.class);
  }
}
