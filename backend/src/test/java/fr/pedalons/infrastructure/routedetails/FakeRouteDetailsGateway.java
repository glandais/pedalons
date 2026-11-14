package fr.pedalons.infrastructure.routedetails;

import io.quarkus.test.Mock;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.Optional;

/**
 * Replaces {@link RouteDetailsGateway} in every {@code @QuarkusTest} (plan §8, docs/LEDGER_*.md
 * API-150), so that no backend test reaches osm-route-details. The gateway builds its two REST
 * clients itself (one read timeout per profile), so a {@code @Mock @RestClient} bean would never be
 * used: the fake overrides the seam {@link RouteDetailsGateway#client} instead, and everything
 * above it — slicing, stitching, error classification — runs as in production on {@link
 * FakeRouteDetailsClient}.
 *
 * <p>A plain unit test may also build one with {@code new}: nothing it needs is injected.
 */
@Mock
@ApplicationScoped
public class FakeRouteDetailsGateway extends RouteDetailsGateway {

  private final FakeRouteDetailsClient client = new FakeRouteDetailsClient();

  @Override
  RouteDetailsClient client(RouteDetailsProfile profile) {
    return client;
  }

  /** The fake's current capabilities, never cached: a test that changes its api sees it at once. */
  @Override
  public Optional<RouteDetailsCapabilities> capabilities() {
    return Optional.of(client.capabilities());
  }

  /** The fake's current bounds, never cached: a test that lowers them sees them at once. */
  @Override
  public RouteDetailsCapabilities.Limits limits() {
    return FakeRouteDetailsClient.limits;
  }
}
