package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class TeamNetworkSummaryTest {

  @Test
  void countsCountedPendingAndExcludedRoutes() {
    TeamNetworkSummary.Tally tally = new TeamNetworkSummary.Tally();
    // route 1: two current tracks, counted
    tally.track(1, false, true);
    tally.track(1, false, true);
    // route 2: one track without a current document, pending
    tally.track(2, false, false);
    // route 3: one current and one not, still pending
    tally.track(3, false, true);
    tally.track(3, false, false);
    // route 4: excluded, whether or not analysed
    tally.track(4, true, true);
    tally.track(5, true, false);
    // route 6 has no track: it never shows up
    TeamNetworkSummary s = tally.build(12_345, 2);
    assertEquals(1, s.routeCount());
    assertEquals(2, s.pendingRouteCount());
    assertEquals(2, s.excludedRouteCount());
    assertEquals(12_345, s.totalLengthM());
    assertEquals(2, s.droppedEdges());
    assertTrue(s.incomplete());
  }

  @Test
  void aTeamWithoutRoutes_isComplete() {
    TeamNetworkSummary s = new TeamNetworkSummary.Tally().build(0, 0);
    assertEquals(0, s.routeCount());
    assertFalse(s.incomplete());
  }
}
