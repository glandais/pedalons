package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNull;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.error.RouteGeneratorNetworkDetails;
import fr.pedalons.service.route.generator.GeneratorFailure;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

class RouteGeneratorErrorsTest {

  private static final TeamNetworkSummary SUMMARY = new TeamNetworkSummary(3, 2, 1, 4200, 0);

  @ParameterizedTest
  @EnumSource(GeneratorFailure.class)
  void everyFailure_hasItsCode(GeneratorFailure failure) {
    BusinessException e = RouteGeneratorErrors.of(failure, SUMMARY);
    ErrorCode expected =
        switch (failure) {
          case START_TOO_FAR -> ErrorCode.GENERATOR_START_TOO_FAR;
          case END_TOO_FAR -> ErrorCode.GENERATOR_END_TOO_FAR;
          case DISTANCE_TOO_SHORT -> ErrorCode.GENERATOR_DISTANCE_TOO_SHORT;
          case NETWORK_TOO_SMALL -> ErrorCode.GENERATOR_NETWORK_TOO_SMALL;
          case NO_ROUTE -> ErrorCode.GENERATOR_NO_ROUTE;
        };
    assertEquals(expected, e.getErrorCode());
    assertEquals(400, e.getStatus().getStatusCode());
  }

  @Test
  void onlyTheSmallNetworkCarriesDetails() {
    for (GeneratorFailure f : GeneratorFailure.values()) {
      BusinessException e = RouteGeneratorErrors.of(f, SUMMARY);
      if (f == GeneratorFailure.NETWORK_TOO_SMALL) {
        RouteGeneratorNetworkDetails d =
            assertInstanceOf(RouteGeneratorNetworkDetails.class, e.getErrorDetails());
        assertEquals(3, d.getRouteCount());
        assertEquals(2, d.getPendingRouteCount());
        assertEquals(1, d.getExcludedRouteCount());
        assertEquals(4200, d.getTotalLengthM());
        assertEquals(true, d.isIncomplete());
      } else {
        assertNull(e.getErrorDetails());
      }
    }
  }
}
