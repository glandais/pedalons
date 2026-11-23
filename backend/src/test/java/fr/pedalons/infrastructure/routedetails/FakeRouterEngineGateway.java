package fr.pedalons.infrastructure.routedetails;

import fr.pedalons.infrastructure.routedetails.RouteGeneratorGateway.Call;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorGateway.Exchange;
import io.quarkus.test.Mock;
import jakarta.enterprise.context.ApplicationScoped;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Supplier;
import org.jspecify.annotations.Nullable;

/**
 * Replaces {@link RouterEngineGateway} in every {@code @QuarkusTest} (plan
 * docs/plans/2026-11-23-itineraire-velo-osm.md, lot 3): no backend test reaches osm-route-details.
 * It overrides the two seams, {@link #offered} (the capabilities) and {@link #send} (the bytes), so
 * that the JSON, the headers and the problems of RFC 9457 still run as in production.
 *
 * <p>Not offered by default, so that a test of the planner meets Stadia alone; a test that wants
 * the engine sets {@link #offered}. The switches are static, the bean being one: {@link #reset()}
 * in the {@code @BeforeEach} of a test that touches them.
 */
@Mock
@ApplicationScoped
public class FakeRouterEngineGateway extends RouterEngineGateway {

  /** Whether the capabilities announce the engine. */
  public static volatile boolean offered = false;

  /** Whether the capabilities announce {@code router.use_roads} (api 1.16). */
  public static volatile boolean acceptsUseRoads = false;

  /** Whether the capabilities announce {@code router.avoid_main_roads} (api 1.16). */
  public static volatile boolean acceptsAvoidMainRoads = false;

  /** What the engine answers to a call; null: a 200 with {@link #okBody}. */
  public static volatile @Nullable Supplier<Reply> responder = null;

  /** What a call carried. */
  public record Seen(Map<String, String> headers, byte[] body) {}

  /** An answer of the engine: a status, a content type and a body. */
  public record Reply(int status, String contentType, String body) {}

  /** Every call that reached the engine. */
  public static final List<Seen> CALLS = new CopyOnWriteArrayList<>();

  public static void reset() {
    offered = false;
    acceptsUseRoads = false;
    acceptsAvoidMainRoads = false;
    responder = null;
    CALLS.clear();
  }

  /** A 200 with a polyline and the unpaved ranges ({@code [[i, j]]}, as JSON text). */
  public static String okBody(String polyline, String unpavedJson) {
    return "{\"graph_id\":\"g\",\"mode\":\"discovery\",\"polyline\":\""
        + polyline
        + "\",\"distance_m\":1000,\"team_m\":0,\"team_share\":0,\"offroad_m\":0,\"unpaved\":"
        + unpavedJson
        + ",\"start_snap_m\":1,\"end_snap_m\":1,\"sharp_relaxed\":false,\"overlay\":null}";
  }

  /** A reply of the given status. */
  public static Reply answer(int status, String contentType, String body) {
    return new Reply(status, contentType, body);
  }

  /** An error answer as the service sends it (RFC 9457). */
  public static Reply problem(int status, String code, @Nullable String reason) {
    String details = reason == null ? "" : ",\"details\":{\"reason\":\"" + reason + "\"}";
    return answer(
        status,
        "application/problem+json",
        "{\"type\":\"about:blank\",\"title\":\"x\",\"status\":"
            + status
            + ",\"code\":\""
            + code
            + "\""
            + details
            + "}");
  }

  @Override
  public boolean offered() {
    return offered;
  }

  @Override
  public boolean acceptsUseRoads() {
    return acceptsUseRoads;
  }

  @Override
  public boolean acceptsAvoidMainRoads() {
    return acceptsAvoidMainRoads;
  }

  @Override
  Exchange send(Call call) {
    CALLS.add(new Seen(call.headers(), call.body()));
    Supplier<Reply> answer = responder;
    if (answer == null) {
      throw new IllegalStateException("FakeRouterEngineGateway: no responder set");
    }
    Reply reply = answer.get();
    Exchange exchange =
        new Exchange(
            reply.status(),
            reply.contentType(),
            null,
            reply.body().getBytes(StandardCharsets.UTF_8));
    if (exchange.status() >= 200 && exchange.status() < 300) {
      return exchange;
    }
    throw RouteGeneratorProblems.classify(
        exchange.status(), exchange.body(), exchange.retryAfter(), mapper);
  }
}
