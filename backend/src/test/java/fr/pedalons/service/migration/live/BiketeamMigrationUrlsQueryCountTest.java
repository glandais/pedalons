package fr.pedalons.service.migration.live;

import static fr.pedalons.service.migration.BiketeamMigrationService.T_POST;
import static fr.pedalons.service.migration.BiketeamMigrationService.T_RIDE;
import static fr.pedalons.service.migration.BiketeamMigrationService.T_ROUTE;
import static fr.pedalons.service.migration.BiketeamMigrationService.T_TRIP;
import static fr.pedalons.service.migration.BiketeamMigrationService.T_TRIP_STAGE;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.migration.BiketeamModel.BtMap;
import fr.pedalons.service.migration.BiketeamModel.BtPublication;
import fr.pedalons.service.migration.BiketeamModel.BtRide;
import fr.pedalons.service.migration.BiketeamModel.BtTeam;
import fr.pedalons.service.migration.BiketeamModel.BtTrip;
import fr.pedalons.service.migration.BiketeamModel.BtTripStage;
import fr.pedalons.service.migration.BiketeamSource;
import fr.pedalons.util.QueryStats;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.stream.IntStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The URL table costs the same few statements whatever the size of the team: per kind, one lookup
 * of the mapping rows and one of the slugs — never two per entity, as it once did.
 */
@QuarkusTest
class BiketeamMigrationUrlsQueryCountTest extends AbstractResourceTest {

  static final int SMALL = 3;
  static final int LARGE = 30;
  static final String BT_TEAM = "urls-team";

  /** Team slug, FAQ mapping; then mapping rows and slugs for routes, rides, trips, stages, posts. */
  static final long MAX_STATEMENTS = 2 + 5 * 2;

  @Inject BiketeamMigrationUrls urls;
  @Inject BiketeamTestData biketeamData;

  Team team;

  @BeforeEach
  void setUpTest() {
    setUp();
    team = dataService.createTeam(domain, user4, "Urls", BT_TEAM, Visibility.PUBLIC);
    Instant at = Instant.parse("2026-06-01T08:00:00Z");
    for (int i = 0; i < LARGE; i++) {
      biketeamData.map(
          T_ROUTE, "map-" + i, dataService.createRoute(team, user4, "Route " + i).getId());
      biketeamData.map(
          T_RIDE,
          "ride-" + i,
          dataService.createRide(team, user4, "Ride " + i, "ride-" + i, at).getId());
      biketeamData.map(
          T_POST, "pub-" + i, dataService.createPost(team, user4, "Post " + i, at).getId());
      Trip trip = dataService.createTrip(team, user4, "Trip " + i, at);
      biketeamData.map(T_TRIP, "trip-" + i, trip.getId());
      biketeamData.map(
          T_TRIP_STAGE,
          "stage-" + i,
          dataService.createTripStage(user4, trip, "Stage " + i).getId());
    }
  }

  /** The first {@code n} of everything seeded, as the snapshot lists it. */
  private static BiketeamSource source(int n) {
    BiketeamSource source = mock(BiketeamSource.class);
    when(source.team()).thenReturn(new BtTeam(BT_TEAM, "Urls", null, null, null, null, false));
    when(source.maps())
        .thenReturn(
            ids(n, "map-")
                .map(id ->
                    new BtMap(
                        id, BT_TEAM, "Route", null, 0, null, 0, 0, null, null, null, null, null,
                        null, false, List.of()))
                .toList());
    when(source.rides())
        .thenReturn(
            ids(n, "ride-")
                .map(id ->
                    new BtRide(
                        id, BT_TEAM, null, null, "Ride", null, null, null, null, null, null, true,
                        false))
                .toList());
    when(source.trips())
        .thenReturn(
            ids(n, "trip-")
                .map(id ->
                    new BtTrip(
                        id, BT_TEAM, null, null, null, null, null, null, null, "Trip", null, null,
                        null, null, true, false))
                .toList());
    when(source.tripStages())
        .thenReturn(
            IntStream.range(0, n)
                .mapToObj(i -> new BtTripStage("stage-" + i, "trip-" + i, null, "S", null, false))
                .toList());
    when(source.publications())
        .thenReturn(
            ids(n, "pub-")
                .map(id -> new BtPublication(id, BT_TEAM, null, "Post", null, null, false, false))
                .toList());
    return source;
  }

  private static java.util.stream.Stream<String> ids(int n, String prefix) {
    return IntStream.range(0, n).mapToObj(i -> prefix + i);
  }

  private QueryStats.Counters measure(int n, Map<String, Map<String, String>>[] out) {
    BiketeamSource source = source(n);
    return queryStats.measureAll(
        "biketeam urlMap [" + n + " of each]",
        () -> out[0] = urls.build(source, team.getId(), domain.getBaseUrl()));
  }

  @Test
  @SuppressWarnings("unchecked")
  void theUrlTable_costsTheSameStatements_forTenTimesTheEntities() {
    Map<String, Map<String, String>>[] small = new Map[1];
    Map<String, Map<String, String>>[] large = new Map[1];

    QueryStats.Counters s = measure(SMALL, small);
    QueryStats.Counters l = measure(LARGE, large);

    assertEquals(SMALL, small[0].get(BiketeamMigrationUrls.ROUTE).size());
    for (String kind :
        List.of(
            BiketeamMigrationUrls.ROUTE,
            BiketeamMigrationUrls.RIDE,
            BiketeamMigrationUrls.TRIP,
            BiketeamMigrationUrls.TRIP_STAGE,
            BiketeamMigrationUrls.POST)) {
      assertEquals(LARGE, large[0].get(kind).size(), kind + ": " + large[0].get(kind));
    }
    String base = domain.getBaseUrl() + "/equipes/" + BT_TEAM;
    assertEquals(
        base + "/voyages/trip-7/etapes/stage-7",
        large[0].get(BiketeamMigrationUrls.TRIP_STAGE).get("stage-7"));
    assertEquals(base + "/sorties/ride-7", large[0].get(BiketeamMigrationUrls.RIDE).get("ride-7"));

    assertEquals(
        s.statements(),
        l.statements(),
        () ->
            "statements grow with the team: "
                + s
                + " vs "
                + l
                + "\n"
                + queryStats.queryBreakdown(15));
    assertTrue(l.statements() <= MAX_STATEMENTS, () -> "statements: " + l);
    assertEquals(s.entityLoads(), l.entityLoads(), () -> "entities hydrated: " + s + " vs " + l);
  }
}
