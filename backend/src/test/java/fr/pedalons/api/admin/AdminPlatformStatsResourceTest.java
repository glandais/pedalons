package fr.pedalons.api.admin;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.auth.Passkey;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.util.GpsSyncTestData;
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
 * Usage statistics of the platform administration: counts only, for the platform administration
 * only. The accounts live on domains of their own, filtered by {@code domainId}: the base
 * fixture's users sit on the default domain.
 */
@QuarkusTest
class AdminPlatformStatsResourceTest extends AbstractResourceTest {

  @Inject EntityManager em;
  @Inject GpsSyncTestData gpsData;

  private User platformAdmin;
  private Domain stats;
  private Domain other;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    platformAdmin = dataService.createPlatformAdminUser("admin@example.com", "Platform Admin");
    stats = dataService.createDomain("stats.example.com", "Stats", "https://stats.test");
    other = dataService.createDomain("stats-other.example.com", "Other", "https://other.test");
  }

  private void update(String sql, User user, Object... params) {
    QuarkusTransaction.requiringNew()
        .run(() -> {
          var query = em.createNativeQuery(sql).setParameter("id", user.getId());
          for (int i = 0; i < params.length; i += 2) {
            query.setParameter((String) params[i], params[i + 1]);
          }
          query.executeUpdate();
        });
  }

  private void passwordAndLogin(User user, boolean password, Duration loginAgo) {
    update(
        "update users set password_hash = :pw, last_login_at = :at where id = :id",
        user,
        "pw",
        password ? "hash" : null,
        "at",
        loginAgo == null
            ? null
            : OffsetDateTime.ofInstant(Instant.now().minus(loginAgo), ZoneOffset.UTC));
  }

  private void passkey(User user, int seed) {
    Long userId = user.getId();
    QuarkusTransaction.requiringNew()
        .run(() -> {
          User ref = em.getReference(User.class, userId);
          Passkey passkey = new Passkey(ref, new byte[] {(byte) seed, 1, 2}, new byte[] {3, 4});
          passkey.setSignCount(0);
          em.persist(passkey);
        });
  }

  private JsonPath stats(User caller, String domainId) {
    var request = given().auth().oauth2(jwtService.generateAccessToken(caller));
    if (domainId != null) {
      request = request.queryParam("domainId", domainId);
    }
    return request
        .when()
        .get("/api/admin/domains/platform-stats")
        .then()
        .statusCode(200)
        .extract()
        .jsonPath();
  }

  private static long count(List<Map<String, Object>> rows, String key) {
    return rows.stream()
        .filter(r -> key.equals(r.get("key")))
        .mapToLong(r -> ((Number) r.get("count")).longValue())
        .sum();
  }

  @Test
  void countsAccountsMethodsTeamsAndServicesOfADomain() {
    User alice = dataService.createVerifiedUser(stats, "alice@stats.test", "Alice");
    User bob = dataService.createUser(stats, "bob@stats.test", "Bob");
    User carol = dataService.createUser(stats, "carol@stats.test", "Carol");
    User dave = dataService.createUser(stats, "dave@stats.test", "Dave");
    User eve = dataService.createUser(stats, "eve@stats.test", "Eve");
    update("update users set deleted = true where id = :id", eve);
    dataService.createUser(other, "frank@other.test", "Frank");

    passwordAndLogin(alice, false, Duration.ofHours(1));
    passwordAndLogin(bob, true, Duration.ofDays(40));
    passwordAndLogin(carol, true, null);
    passwordAndLogin(dave, false, null);
    passkey(alice, 1);
    passkey(carol, 2);

    Team team = dataService.createTeam(alice, "Équipe stats", "equipe-stats", Visibility.PUBLIC);
    dataService.addUserToTeam(carol, team, TeamRole.MEMBER);
    gpsData.connect(alice, GpsServiceType.GARMIN, true);

    JsonPath body = stats(platformAdmin, TsidUtils.toString(stats.getId()));

    assertEquals(TsidUtils.toString(stats.getId()), body.getString("domainId"));
    assertEquals(4, body.getInt("users.total"));
    assertEquals(1, body.getInt("users.deleted"));
    assertEquals(1, body.getInt("users.emailVerified"));
    assertEquals(2, body.getInt("users.neverLoggedIn"));
    assertEquals(1, body.getInt("users.activeLast7Days"));
    assertEquals(1, body.getInt("users.activeLast30Days"));
    assertEquals(2, body.getInt("users.activeLast90Days"));

    assertEquals(1, body.getInt("authMethods.passwordOnly"));
    assertEquals(1, body.getInt("authMethods.passkeyOnly"));
    assertEquals(1, body.getInt("authMethods.passwordAndPasskey"));
    assertEquals(1, body.getInt("authMethods.neither"));
    assertEquals(2, body.getInt("passkeys.total"));

    List<Map<String, Object>> months = body.getList("signupsByMonth");
    assertEquals(12, months.size());
    assertEquals(java.time.YearMonth.now(ZoneOffset.UTC).toString(), months.get(11).get("month"));
    assertEquals(4, ((Number) months.get(11).get("count")).intValue());
    assertEquals(0, ((Number) months.get(0).get("count")).intValue());

    assertEquals(1, body.getInt("teams.active"));
    assertEquals(0, body.getInt("teams.deleted"));
    assertEquals(1, count(body.getList("teams.byTier"), "FREE"));
    assertEquals(1, count(body.getList("teams.membershipsByRole"), "ADMIN"));
    assertEquals(1, count(body.getList("teams.membershipsByRole"), "MEMBER"));
    List<Map<String, Object>> byCount = body.getList("teams.usersByTeamCount");
    assertEquals(2, count(byCount, "0"));
    assertEquals(2, count(byCount, "1"));
    assertEquals(0, count(byCount, "3+"));

    assertEquals(1, body.getInt("usersWithGpsService"));
    assertEquals("GARMIN", body.getString("gpsServices[0].service"));
    assertEquals(1, body.getInt("gpsServices[0].connections"));
    assertEquals(1, body.getInt("gpsServices[0].autoSync"));
    assertEquals(0, body.getInt("gpsServices[0].routeSyncs"));
    assertEquals(0, body.getInt("calendarFeeds.tokens"));
  }

  @Test
  void withoutFilterCoversEveryDomainAndNamesNobody() {
    dataService.createUser(stats, "someone@stats.test", "Someone Secret");
    dataService.createUser(other, "another@other.test", "Another Secret");

    JsonPath json = stats(platformAdmin, null);
    assertEquals(null, json.getString("domainId"));
    assertEquals(true, json.getInt("users.total") >= 2);

    String body =
        given()
            .auth()
            .oauth2(jwtService.generateAccessToken(platformAdmin))
            .when()
            .get("/api/admin/domains/platform-stats")
            .then()
            .statusCode(200)
            .extract()
            .asString();
    assertFalse(body.contains("someone@stats.test"));
    assertFalse(body.contains("Someone Secret"));
    assertFalse(body.contains("admin@example.com"));
    assertFalse(body.contains("Platform Admin"));
  }

  @Test
  void unknownDomainIsNotFound() {
    given()
        .auth()
        .oauth2(jwtService.generateAccessToken(platformAdmin))
        .queryParam("domainId", "0000000000000")
        .when()
        .get("/api/admin/domains/platform-stats")
        .then()
        .statusCode(404);
  }

  @Test
  void refusedToAnyoneButThePlatformAdministration() {
    given()
        .auth()
        .oauth2(getAccessToken(USER1))
        .when()
        .get("/api/admin/domains/platform-stats")
        .then()
        .statusCode(403);
  }
}
