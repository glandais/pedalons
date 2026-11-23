package fr.pedalons.infrastructure.routedetails;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException.Kind;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorGateway.Call;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorGateway.Exchange;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.io.IOException;
import java.time.Duration;
import java.util.Optional;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;

/**
 * The point to point engine of osm-route-details (api 1.15, {@code POST /v1/router/route}) for the
 * route planner (plan docs/plans/2026-11-23-itineraire-velo-osm.md, lot 3). It rides on {@link
 * RouteGeneratorGateway}: same url, same namespace key, same problems of RFC 9457, same {@code
 * Ord-Team} header. A call without a team carries neither header (the engine then routes on the
 * common taste); the key is only read when there is a team.
 *
 * <p>Faked in tests by overriding {@link #send} and {@link #offered}, as the generator is.
 * Never logs the key, a team or a coordinate.
 */
@ApplicationScoped
public class RouterEngineGateway {

  @ConfigProperty(name = "pedalons.router-engine.enabled", defaultValue = "true")
  boolean enabled;

  @ConfigProperty(name = "pedalons.router-engine.timeout", defaultValue = "PT6S")
  Duration timeout;

  @ConfigProperty(name = "pedalons.router-engine.cursor", defaultValue = "0.25")
  double cursor;

  @Inject ObjectMapper mapper;
  @Inject RouteDetailsGateway routeDetails;
  @Inject RouteGeneratorGateway generator;

  /** The kill switch of the configuration. */
  public boolean switchedOn() {
    return enabled;
  }

  /**
   * The longest leg, as the crow flies in metres, the engine calculates ({@code
   * capabilities.router.crow_m_max}); empty when it does not say. Read from the cached
   * capabilities, never afresh.
   */
  public Optional<Double> crowMaxM() {
    return routeDetails
        .capabilities()
        .map(RouteDetailsCapabilities::router)
        .map(RouteDetailsCapabilities.RouterSection::crowMMax);
  }

  /**
   * Whether the engine can be asked: switched on, a namespace key configured, and the cached
   * capabilities announce {@code router.enabled}. Never calls the service afresh, never throws.
   */
  public boolean offered() {
    if (!enabled || !generator.configured()) {
      return false;
    }
    Optional<RouteDetailsCapabilities> capabilities = routeDetails.capabilities();
    return capabilities.isPresent() && capabilities.get().routerEnabled();
  }

  /**
   * {@code POST /v1/router/route}.
   *
   * @param team the team's TSID, or null for a planner without a team
   * @param rideType {@code road}, {@code gravel} or {@code mtb}
   * @throws RouteGeneratorException the service's refusal, no answer, or an unreadable answer
   */
  public RouterEngineV1.Response route(
      @Nullable String team,
      double fromLat,
      double fromLon,
      double toLat,
      double toLon,
      String rideType) {
    byte[] body;
    try {
      body =
          mapper.writeValueAsBytes(
              new RouterEngineV1.Request(
                  new RouterEngineV1.Point(fromLat, fromLon),
                  new RouterEngineV1.Point(toLat, toLon),
                  rideType,
                  cursor));
    } catch (IOException e) {
      throw RouteGeneratorException.of(Kind.UNEXPECTED, e);
    }
    return read(
        send(
            new Call(
                "POST", "/v1/router/route", generator.routerHeaders(team), body, null, timeout)));
  }

  /** The seam the test fake overrides: one call, an error answer thrown as a classified exception. */
  Exchange send(Call call) {
    return generator.call(call);
  }

  private RouterEngineV1.Response read(Exchange answer) {
    try {
      RouterEngineV1.Response value =
          mapper.readValue(answer.body(), RouterEngineV1.Response.class);
      if (value == null) {
        throw RouteGeneratorException.of(Kind.UNEXPECTED, null);
      }
      return value;
    } catch (IOException e) {
      throw RouteGeneratorException.of(Kind.UNEXPECTED, e);
    }
  }
}
