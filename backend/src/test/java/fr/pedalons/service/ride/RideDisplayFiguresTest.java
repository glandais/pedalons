package fr.pedalons.service.ride;

import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.service.ride.RideDisplayFigures.Figures;
import fr.pedalons.service.ride.RideDisplayFigures.GroupRoute;
import fr.pedalons.service.ride.RideDisplayFigures.RouteFigures;
import java.util.List;
import org.junit.jupiter.api.Test;

/** The rule of docs/LEDGER_*.md API-178, without a database. */
class RideDisplayFiguresTest {

  private static final RouteFigures RIDE = new RouteFigures(1L, 70000f, 800f);
  private static final RouteFigures FIFTY = new RouteFigures(2L, 50000f, 500f);
  private static final RouteFigures NINETY = new RouteFigures(3L, 90000f, 1500f);

  private static Figures figures(RouteFigures route) {
    return new Figures(route.distance(), route.elevationGain());
  }

  @Test
  void registered_getsTheirGroupsOwnRoute() {
    List<GroupRoute> groups = List.of(new GroupRoute(10L, FIFTY), new GroupRoute(11L, NINETY));
    assertEquals(figures(NINETY), RideDisplayFigures.resolve(null, groups, 11L));
  }

  @Test
  void registered_inAGroupWithoutRoute_getsTheRidesRoute() {
    List<GroupRoute> groups = List.of(new GroupRoute(10L, NINETY), new GroupRoute(11L, null));
    assertEquals(figures(RIDE), RideDisplayFigures.resolve(RIDE, groups, 11L));
  }

  @Test
  void registered_withNoRouteAnywhere_getsNothing() {
    List<GroupRoute> groups = List.of(new GroupRoute(10L, null));
    assertEquals(Figures.NONE, RideDisplayFigures.resolve(null, groups, 10L));
  }

  @Test
  void notRegistered_rideRouteAndGroupsWithout_getsTheRidesRoute() {
    List<GroupRoute> groups = List.of(new GroupRoute(10L, null), new GroupRoute(11L, null));
    assertEquals(figures(RIDE), RideDisplayFigures.resolve(RIDE, groups, null));
  }

  @Test
  void notRegistered_noGroup_getsTheRidesRoute() {
    assertEquals(figures(RIDE), RideDisplayFigures.resolve(RIDE, List.of(), null));
  }

  @Test
  void notRegistered_everyGroupOnTheSameRoute_getsIt() {
    List<GroupRoute> groups = List.of(new GroupRoute(10L, FIFTY), new GroupRoute(11L, FIFTY));
    assertEquals(figures(FIFTY), RideDisplayFigures.resolve(null, groups, null));
  }

  /** A group whose own route is the ride's rides the same route as one without any. */
  @Test
  void notRegistered_groupRepeatingTheRidesRoute_stillShared() {
    List<GroupRoute> groups = List.of(new GroupRoute(10L, RIDE), new GroupRoute(11L, null));
    assertEquals(figures(RIDE), RideDisplayFigures.resolve(RIDE, groups, null));
  }

  @Test
  void notRegistered_groupsOnDifferentRoutes_getsNothing() {
    List<GroupRoute> groups = List.of(new GroupRoute(10L, FIFTY), new GroupRoute(11L, NINETY));
    assertEquals(Figures.NONE, RideDisplayFigures.resolve(null, groups, null));
  }

  /** The ride's route is not shared once one group rides another. */
  @Test
  void notRegistered_oneGroupOffTheRidesRoute_getsNothing() {
    List<GroupRoute> groups = List.of(new GroupRoute(10L, null), new GroupRoute(11L, NINETY));
    assertEquals(Figures.NONE, RideDisplayFigures.resolve(RIDE, groups, null));
  }

  @Test
  void notRegistered_oneGroupRidingNothing_getsNothing() {
    List<GroupRoute> groups = List.of(new GroupRoute(10L, FIFTY), new GroupRoute(11L, null));
    assertEquals(Figures.NONE, RideDisplayFigures.resolve(null, groups, null));
  }

  @Test
  void noRouteAtAll_getsNothing() {
    assertEquals(Figures.NONE, RideDisplayFigures.resolve(null, List.of(), null));
    assertEquals(
        Figures.NONE, RideDisplayFigures.resolve(null, List.of(new GroupRoute(10L, null)), null));
  }

  /** A registration in a group the list does not hold falls back on the not-registered rule. */
  @Test
  void registeredGroupUnknown_fallsBackOnTheSharedRoute() {
    List<GroupRoute> groups = List.of(new GroupRoute(10L, null));
    assertEquals(figures(RIDE), RideDisplayFigures.resolve(RIDE, groups, 99L));
  }
}
