package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.fasterxml.jackson.databind.ObjectMapper;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorException;
import fr.pedalons.infrastructure.routedetails.RouteGeneratorProblems;
import fr.pedalons.service.route.network.RouteRetouchErrors.EditReason;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Every answer of the engine to a retouch as an error code (plan lot 7c §5), from the problem up. */
class RouteRetouchErrorsTest {

  /** The reasons of the contract of api 1.17 (osm-route-details 1.18.0), copied. */
  private static final List<String> CONTRACT_REASONS =
      List.of(
          "change_too_small",
          "change_too_large",
          "route_off_coverage",
          "route_mismatch",
          "route_not_matched",
          "order_anomaly",
          "no_seam",
          "end_too_far",
          "end_unreachable",
          "junction_cut",
          "no_economy",
          "no_window",
          "no_candidate",
          "checker_rejected",
          "off_target",
          "budget");

  private static final ObjectMapper JSON = new ObjectMapper();

  private static RouteGeneratorException problem(int status, String code, String reason) {
    String body =
        "{\"status\":"
            + status
            + ",\"code\":\""
            + code
            + "\""
            + (reason == null ? "" : ",\"details\":{\"reason\":\"" + reason + "\"}")
            + "}";
    return RouteGeneratorProblems.classify(
        status, body.getBytes(StandardCharsets.UTF_8), null, JSON);
  }

  private static PedalonsException failed(String reason, boolean shortening) {
    return RouteRetouchErrors.of(problem(422, "generation_failed", reason), shortening);
  }

  @Test
  void everyReasonOfTheContractIsKnown() {
    for (String reason : CONTRACT_REASONS) {
      assertFalse(EditReason.of(reason) == EditReason.UNKNOWN, reason);
    }
    assertEquals(CONTRACT_REASONS.size() + 1, EditReason.values().length);
    assertEquals(EditReason.UNKNOWN, EditReason.of(null));
    assertEquals(EditReason.UNKNOWN, EditReason.of("something_new"));
  }

  @Test
  void aShorteningThatFindsNothingIsAnormalAnswerWhateverTheReason() {
    for (String reason :
        List.of(
            "no_economy",
            "no_window",
            "no_candidate",
            "checker_rejected",
            "off_target",
            "budget",
            "no_seam",
            "junction_cut",
            "end_unreachable",
            "something_new")) {
      PedalonsException e = failed(reason, true);
      assertInstanceOf(BusinessException.class, e);
      assertEquals(ErrorCode.ROUTE_RETOUCH_NO_SHORTER, e.getErrorCode(), reason);
    }
  }

  @Test
  void theOrderAnomalyKeepsItsOwnCodeWhateverTheOperation() {
    assertEquals(
        ErrorCode.ROUTE_RETOUCH_ORDER_ANOMALY, failed("order_anomaly", true).getErrorCode());
    assertEquals(
        ErrorCode.ROUTE_RETOUCH_ORDER_ANOMALY, failed("order_anomaly", false).getErrorCode());
  }

  @Test
  void otherOperationsHaveNoProposalOrTheirOwnCode() {
    for (String reason :
        List.of(
            "no_window",
            "no_candidate",
            "checker_rejected",
            "off_target",
            "budget",
            "something_new")) {
      assertEquals(
          ErrorCode.ROUTE_RETOUCH_NO_PROPOSAL, failed(reason, false).getErrorCode(), reason);
    }
    assertEquals(ErrorCode.ROUTE_RETOUCH_NO_SHORTER, failed("no_economy", false).getErrorCode());
    assertEquals(ErrorCode.ROUTE_RETOUCH_UNSUPPORTED, failed("no_seam", false).getErrorCode());
    assertEquals(
        ErrorCode.ROUTE_RETOUCH_END_UNREACHABLE, failed("end_unreachable", false).getErrorCode());
    assertEquals(
        ErrorCode.ROUTE_RETOUCH_END_UNREACHABLE, failed("junction_cut", false).getErrorCode());
  }

  @Test
  void theInputRefusals() {
    for (boolean shortening : new boolean[] {true, false}) {
      assertEquals(
          ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_SMALL,
          failed("change_too_small", shortening).getErrorCode());
      assertEquals(
          ErrorCode.ROUTE_RETOUCH_CHANGE_TOO_LARGE,
          failed("change_too_large", shortening).getErrorCode());
      assertEquals(
          ErrorCode.ROUTE_RETOUCH_UNSUPPORTED,
          failed("route_not_matched", shortening).getErrorCode());
      assertEquals(
          ErrorCode.ROUTE_RETOUCH_UNSUPPORTED, failed("route_mismatch", shortening).getErrorCode());
      assertEquals(
          ErrorCode.GENERATOR_OUT_OF_COVERAGE,
          failed("route_off_coverage", shortening).getErrorCode());
      assertEquals(
          ErrorCode.GENERATOR_END_TOO_FAR, failed("end_too_far", shortening).getErrorCode());
    }
  }

  @Test
  void theKindsOfFailureAreTheGeneratorsOwn() {
    assertEquals(
        ErrorCode.GENERATOR_OUT_OF_COVERAGE,
        RouteRetouchErrors.of(problem(422, "out_of_coverage", null), false).getErrorCode());
    for (String code : List.of("overloaded", "timeout")) {
      PedalonsException e = RouteRetouchErrors.of(problem(503, code, null), false);
      assertInstanceOf(ServiceUnavailableException.class, e);
      assertEquals(ErrorCode.ROUTE_GENERATOR_BUSY, e.getErrorCode());
    }
    for (int status : new int[] {500, 503}) {
      PedalonsException e = RouteRetouchErrors.of(problem(status, "other", null), false);
      assertInstanceOf(ServiceUnavailableException.class, e);
      assertEquals(ErrorCode.GENERATOR_UNAVAILABLE, e.getErrorCode(), "status " + status);
    }
    // a request the engine refuses as it is would be refused again: not worth a retry
    for (int status : new int[] {400, 413}) {
      PedalonsException e = RouteRetouchErrors.of(problem(status, "other", null), false);
      assertEquals(ErrorCode.ROUTE_RETOUCH_UNSUPPORTED, e.getErrorCode(), "status " + status);
    }
  }

  @Test
  void driftAndStaleDocumentsAreToldApart() {
    assertTrue(RouteRetouchErrors.isDrift(problem(400, "invalid_input", null)));
    assertFalse(RouteRetouchErrors.isDrift(problem(422, "generation_failed", "no_economy")));
    assertTrue(
        RouteRetouchErrors.isStaleDocument(problem(422, "generation_failed", "route_mismatch")));
    assertFalse(RouteRetouchErrors.isStaleDocument(problem(422, "generation_failed", "no_seam")));
    assertEquals(
        "no_economy", RouteRetouchErrors.outcome(problem(422, "generation_failed", "no_economy")));
    assertEquals("overloaded", RouteRetouchErrors.outcome(problem(503, "overloaded", null)));
  }
}
