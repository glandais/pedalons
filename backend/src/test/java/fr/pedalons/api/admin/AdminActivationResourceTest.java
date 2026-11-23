package fr.pedalons.api.admin;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.path.json.JsonPath;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Activation of new accounts (docs/LEDGER_*.md API-213): per sign-up week and domain, counts of
 * accounts created, verified, that joined a team and signed up to a ride within 7 days. Counts
 * only, for the platform administration only.
 *
 * <p>The accounts live on a domain of their own: the base fixture's users are created now too,
 * on the default domain, and would land in the same week.
 */
@QuarkusTest
class AdminActivationResourceTest extends AbstractResourceTest {

  @Inject EntityManager em;

  private User platformAdmin;
  private Domain other;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    platformAdmin = dataService.createPlatformAdminUser("admin@example.com", "Platform Admin");
    other = dataService.createDomain("activation.example.com", "Activation", "https://x.test");
  }

  /** Moves the account's creation back by [age]: the rows written for it keep their own dates. */
  private void createdAgo(User user, Duration age) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            em.createNativeQuery("update users set created_at = :at where id = :id")
                .setParameter(
                    "at", OffsetDateTime.ofInstant(Instant.now().minus(age), ZoneOffset.UTC))
                .setParameter("id", user.getId())
                .executeUpdate());
  }

  private void markDeleted(User user) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            em.createNativeQuery("update users set deleted = true where id = :id")
                .setParameter("id", user.getId())
                .executeUpdate());
  }

  private List<Map<String, Object>> rowsOfOtherDomain() {
    JsonPath body =
        given()
            .auth()
            .oauth2(jwtService.generateAccessToken(platformAdmin))
            .queryParam("weeks", 4)
            .when()
            .get("/api/admin/domains/activation")
            .then()
            .statusCode(200)
            .extract()
            .jsonPath();
    assertEquals(4, body.getInt("weeksBack"));
    String domainId = TsidUtils.toString(other.getId());
    return body.<Map<String, Object>>getList("weeks").stream()
        .filter(row -> domainId.equals(row.get("domainId")))
        .toList();
  }

  @Test
  void countsTheWeeksAccountsAndWhatTheyDidWithinSevenDays() {
    // This week: one account that created a team and signed up to a ride, one that only
    // verified its address, and one deleted since — left out.
    User active = dataService.createUser(other, "active@activation.test", "Active");
    Team team =
        dataService.createTeam(active, "Équipe activation", "equipe-activation", Visibility.PUBLIC);
    Ride ride =
        dataService.createRide(
            team, active, "Sortie", "sortie", Instant.now().plus(Duration.ofDays(3)));
    RideGroup group = dataService.createRideGroup(active, ride, "A");
    dataService.createParticipation(group, active);
    dataService.createVerifiedUser(other, "verified@activation.test", "Verified");
    markDeleted(dataService.createUser(other, "gone@activation.test", "Gone"));

    // Ten days ago, an account that joined a team only now: past its 7 days, so not counted.
    User late = dataService.createUser(other, "late@activation.test", "Late");
    createdAgo(late, Duration.ofDays(10));
    dataService.addUserToTeam(late, team, TeamRole.MEMBER);

    List<Map<String, Object>> rows = rowsOfOtherDomain();
    assertEquals(2, rows.size());

    Map<String, Object> thisWeek = rows.get(0);
    assertEquals("Activation", thisWeek.get("domainName"));
    assertEquals(false, thisWeek.get("complete"));
    assertEquals(2, thisWeek.get("signedUp"));
    assertEquals(1, thisWeek.get("verified"));
    assertEquals(1, thisWeek.get("joinedTeam"));
    assertEquals(1, thisWeek.get("joinedRide"));

    Map<String, Object> earlier = rows.get(1);
    assertTrue(
        ((String) earlier.get("weekStart")).compareTo((String) thisWeek.get("weekStart")) < 0);
    assertEquals(1, earlier.get("signedUp"));
    assertEquals(0, earlier.get("joinedTeam"));
    assertEquals(0, earlier.get("joinedRide"));
  }

  @Test
  void aWeekIsCompleteOnceItsLastAccountHadItsSevenDays() {
    createdAgo(dataService.createUser(other, "old@activation.test", "Old"), Duration.ofDays(21));

    List<Map<String, Object>> rows = rowsOfOtherDomain();

    assertEquals(1, rows.size());
    assertEquals(true, rows.get(0).get("complete"));
  }

  @Test
  void namesNobody() {
    dataService.createUser(other, "someone@activation.test", "Someone");

    String body =
        given()
            .auth()
            .oauth2(jwtService.generateAccessToken(platformAdmin))
            .when()
            .get("/api/admin/domains/activation")
            .then()
            .statusCode(200)
            .extract()
            .asString();

    assertFalse(body.contains("someone@activation.test"));
    assertFalse(body.contains("Someone"));
  }

  @Test
  void refusedToAnyoneButThePlatformAdministration() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/admin/domains/activation")
        .then()
        .statusCode(403);
  }
}
