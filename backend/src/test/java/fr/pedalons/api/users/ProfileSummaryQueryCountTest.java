package fr.pedalons.api.users;

import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractQueryCountTest;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Visibility;
import fr.pedalons.util.QueryStats;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Database-cost budget for the profile overview's summary. It has no page size: what grows is the
 * user's data — teams, passkeys, paired devices, blocks. The same request is
 * measured with {@link #SMALL_PAGE} of each, then with {@link #LARGE_PAGE}, and must cost the same
 * number of statements.
 *
 * <p>Entities: the teams (membership and team) and the paired devices are returned row by row, so
 * they are hydrated — three entities per added row of each kind. Anything beyond that means a count
 * was computed by loading a list (a block and its user…).
 *
 * <p>See {@link AbstractQueryCountTest} for why the assertion is a shape rather than a bound.
 */
@QuarkusTest
class ProfileSummaryQueryCountTest extends AbstractQueryCountTest {

  private static final String PATH = "/api/users/me/profile-summary";

  /** Per added row: a membership and its team, and a paired device's session. */
  private static final long ENTITIES_PER_ROW = 3;

  private int seeded;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    seeded = 0;
  }

  /** Brings user1's data up to {@code count} of each kind. */
  private void seedUpTo(int count) {
    for (int i = seeded; i < count; i++) {
      dataService.createTeam(
          user1, "Équipe " + i, "equipe-qc-" + i, i % 2 == 0 ? Visibility.PUBLIC : Visibility.TEAM);
      dataService.createPasskey(user1, ("cred-qc-" + i).getBytes(), ("key-" + i).getBytes());
      dataService.createPairedDevice(user1, i % 2 == 0 ? "karoo" : "garmin");
      User blocked = dataService.createUser(domain, "bloque-" + i + "@example.com", "Bloqué " + i);
      dataService.createBlock(user1, blocked);
    }
    seeded = count;
  }

  private QueryStats.Counters measure(String label) {
    return queryStats.measureAll(
        label, () -> asUser1().get().when().get(PATH).then().statusCode(200));
  }

  @Test
  void profileSummary_costDoesNotScaleWithTheUsersData() {
    seedUpTo(SMALL_PAGE);
    QueryStats.Counters small = measure("GET " + PATH + " [" + SMALL_PAGE + " of each]");
    seedUpTo(LARGE_PAGE);
    QueryStats.Counters large = measure("GET " + PATH + " [" + LARGE_PAGE + " of each]");

    long statementGrowth = large.statements() - small.statements();
    assertTrue(
        statementGrowth <= MAX_STATEMENT_GROWTH,
        () ->
            "N+1 queries on "
                + PATH
                + ": "
                + small.statements()
                + " statements with "
                + SMALL_PAGE
                + " of each, "
                + large.statements()
                + " with "
                + LARGE_PAGE
                + " (budget +"
                + MAX_STATEMENT_GROWTH
                + ").");
    long entityBudget = ENTITIES_PER_ROW * (LARGE_PAGE - SMALL_PAGE) + MAX_STATEMENT_GROWTH;
    long entityGrowth = large.entityLoads() - small.entityLoads();
    assertTrue(
        entityGrowth <= entityBudget,
        () ->
            "Entity hydration scales with the data on "
                + PATH
                + ": +"
                + entityGrowth
                + " entities (budget +"
                + entityBudget
                + "). A count is being computed by loading the rows it counts.");
  }
}
