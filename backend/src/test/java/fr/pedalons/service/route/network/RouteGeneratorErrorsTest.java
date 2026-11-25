package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException.Kind;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorProblems;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/** Every answer of the engine as an error code (lot 3b plan §3), from the problem body up. */
class RouteGeneratorErrorsTest {

  /** The ten reasons of {@code GenerationReason} in the contract of api 1.9, copied. */
  private static final List<String> CONTRACT_REASONS =
      List.of(
          "start_too_far",
          "end_too_far",
          "distance_too_short",
          "network_too_small",
          "end_unreachable",
          "no_way_back",
          "tail_too_long",
          "no_candidate",
          "budget",
          "checker_rejected");

  private static final ObjectMapper JSON = new ObjectMapper();

  private static RouteGeneratorException problem(int status, String body, String retryAfter) {
    return RouteGeneratorProblems.classify(
        status, body.getBytes(StandardCharsets.UTF_8), retryAfter, JSON);
  }

  private static PedalonsException of(int status, String code, String details) {
    String body =
        "{\"type\":\"urn:x\",\"title\":\"t\",\"status\":"
            + status
            + ",\"detail\":\"d\",\"code\":\""
            + code
            + "\""
            + (details == null ? "" : ",\"details\":" + details)
            + "}";
    return RouteGeneratorErrors.of(problem(status, body, null));
  }

  private static void assertBusiness(ErrorCode expected, PedalonsException e) {
    assertInstanceOf(BusinessException.class, e);
    assertEquals(expected, e.getErrorCode());
  }

  private static void assertUnavailable(ErrorCode expected, PedalonsException e) {
    assertInstanceOf(ServiceUnavailableException.class, e);
    assertEquals(expected, e.getErrorCode());
  }

  @Test
  void theCoverageRefusalHasItsOwnCode() {
    assertBusiness(
        ErrorCode.GENERATOR_OUT_OF_COVERAGE,
        of(422, "out_of_coverage", "{\"coverage\":\"graph\"}"));
  }

  @Test
  void theKeptReasonsKeepTheirCodes() {
    assertBusiness(
        ErrorCode.GENERATOR_START_TOO_FAR,
        of(422, "generation_failed", "{\"reason\":\"start_too_far\"}"));
    assertBusiness(
        ErrorCode.GENERATOR_END_TOO_FAR,
        of(422, "generation_failed", "{\"reason\":\"end_too_far\"}"));
    assertBusiness(
        ErrorCode.GENERATOR_DISTANCE_TOO_SHORT,
        of(422, "generation_failed", "{\"reason\":\"distance_too_short\"}"));
    assertBusiness(
        ErrorCode.GENERATOR_NETWORK_TOO_SMALL,
        of(422, "generation_failed", "{\"reason\":\"network_too_small\"}"));
  }

  @Test
  void everyOtherReasonOfTheContractIsNoRoute() {
    for (String reason : CONTRACT_REASONS) {
      PedalonsException e = of(422, "generation_failed", "{\"reason\":\"" + reason + "\"}");
      assertTrue(e.getErrorCode() != null, reason);
      if (List.of("start_too_far", "end_too_far", "distance_too_short", "network_too_small")
          .contains(reason)) {
        continue;
      }
      assertBusiness(ErrorCode.GENERATOR_NO_ROUTE, e);
    }
  }

  @Test
  void everyReasonOfTheContractIsKnownToTheEnum() {
    for (String reason : CONTRACT_REASONS) {
      assertFalse(
          RouteGeneratorErrors.Reason.of(reason) == RouteGeneratorErrors.Reason.UNKNOWN, reason);
    }
  }

  @Test
  void anUnknownReasonOrNoReasonIsNoRoute() {
    assertBusiness(
        ErrorCode.GENERATOR_NO_ROUTE,
        of(422, "generation_failed", "{\"reason\":\"a_future_reason\"}"));
    assertBusiness(ErrorCode.GENERATOR_NO_ROUTE, of(422, "generation_failed", null));
  }

  @Test
  void aMissingOverlayIsNotReady() {
    assertBusiness(
        ErrorCode.GENERATOR_NETWORK_NOT_READY,
        of(409, "overlay_required", "{\"state\":\"absent\"}"));
    assertBusiness(
        ErrorCode.GENERATOR_NETWORK_NOT_READY,
        of(409, "overlay_required", "{\"state\":\"stale\"}"));
  }

  @Test
  void overloadAndTimeoutsAreBusy() {
    assertUnavailable(ErrorCode.ROUTE_GENERATOR_BUSY, of(503, "overloaded", null));
    assertUnavailable(ErrorCode.ROUTE_GENERATOR_BUSY, of(504, "timeout", null));
    assertUnavailable(
        ErrorCode.ROUTE_GENERATOR_BUSY,
        RouteGeneratorErrors.of(RouteGeneratorException.of(Kind.READ_TIMEOUT, null)));
  }

  @Test
  void whatIsDownIsUnavailable() {
    assertUnavailable(
        ErrorCode.GENERATOR_UNAVAILABLE, of(503, "data_unavailable", "{\"source\":\"graph\"}"));
    assertUnavailable(
        ErrorCode.GENERATOR_UNAVAILABLE,
        RouteGeneratorErrors.of(RouteGeneratorException.of(Kind.NO_ANSWER, null)));
    assertUnavailable(
        ErrorCode.GENERATOR_UNAVAILABLE,
        RouteGeneratorErrors.of(RouteGeneratorException.of(Kind.NOT_CONFIGURED, null)));
    // a proxy's page: no problem body, the status decides
    assertUnavailable(
        ErrorCode.GENERATOR_UNAVAILABLE,
        RouteGeneratorErrors.of(problem(502, "<html>Bad gateway</html>", null)));
    assertUnavailable(
        ErrorCode.GENERATOR_UNAVAILABLE,
        RouteGeneratorErrors.of(problem(503, "<html>Maintenance</html>", null)));
    assertUnavailable(
        ErrorCode.ROUTE_GENERATOR_BUSY,
        RouteGeneratorErrors.of(problem(504, "<html>Gateway timeout</html>", null)));
  }

  @Test
  void whatTheContractDoesNotPromiseIsUnavailableAndADrift() {
    for (int status : new int[] {400, 404, 413, 415, 500}) {
      RouteGeneratorException e = problem(status, "{}", null);
      assertUnavailable(ErrorCode.GENERATOR_UNAVAILABLE, RouteGeneratorErrors.of(e));
      assertTrue(RouteGeneratorErrors.isDrift(e), "status " + status);
    }
    assertFalse(RouteGeneratorErrors.isDrift(problem(503, "{\"code\":\"overloaded\"}", null)));
  }

  @Test
  void retryAfterIsReadAndCapped() {
    assertEquals(
        Duration.ofSeconds(7), problem(503, "{\"code\":\"overloaded\"}", "7").retryAfter());
    assertEquals(
        Duration.ofSeconds(120), problem(503, "{\"code\":\"overloaded\"}", "9999").retryAfter());
    assertEquals(null, problem(503, "{\"code\":\"overloaded\"}", "soon").retryAfter());
    assertEquals(null, problem(503, "{\"code\":\"overloaded\"}", null).retryAfter());
  }

  @Test
  void theMessageNeverCarriesAKeyOrAReasonText() {
    RouteGeneratorException e =
        problem(
            422,
            "{\"code\":\"generation_failed\",\"detail\":\"secret-detail\","
                + "\"details\":{\"reason\":\"budget\"}}",
            null);
    assertFalse(e.getMessage().contains("secret-detail"));
  }

  @Test
  void freeTextFromTheEngineIsNeverKeptForTheLogs() {
    RouteGeneratorException e =
        problem(
            422,
            "{\"code\":\"generation_failed\",\"details\":{\"reason\":\"x\\nFORGED line\","
                + "\"state\":\"stale\"}}",
            null);
    assertEquals(RouteGeneratorException.Kind.GENERATION_FAILED, e.kind());
    assertNull(e.reason());
    assertFalse(e.getMessage().contains("FORGED"));
    RouteGeneratorException odd = problem(503, "{\"code\":\"overloaded\\r\\nINFO fake\"}", null);
    assertNull(odd.code());
    assertEquals(RouteGeneratorException.Kind.DATA_UNAVAILABLE, odd.kind());
  }
}
