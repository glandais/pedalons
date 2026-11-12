package fr.pedalons.api.admin;

import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.api.AbstractResourceTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Visibility;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The platform administration lists ({@code /api/admin/teams}, {@code /users}, {@code /domains})
 * read newest first, then by id descending: rows created at the same instant — what a biketeam
 * import leaves behind — come back in one fixed order on every page, so paging one row at a time
 * neither repeats nor skips one. Without the id at the end of the key PostgreSQL meets the tied
 * rows in heap order, which is ascending id here, against the expected descending one.
 */
@QuarkusTest
class AdminListTotalOrderResourceTest extends AbstractResourceTest {

  @Inject EntityManager em;

  private User platformAdmin;

  @Override
  @BeforeEach
  public void setUp() {
    super.setUp();
    platformAdmin = dataService.createPlatformAdminUser("admin@example.com", "Platform Admin");
  }

  @Test
  void teams_tiedOnCreation_isTotalAcrossPages() {
    dataService.createTeam(user1, "Tri A", "tri-a", Visibility.PUBLIC);
    dataService.createTeam(user1, "Tri B", "tri-b", Visibility.PUBLIC);
    sameCreatedAt("teams");

    assertNewestFirstThenIdDescending("/api/admin/teams", "teams");
  }

  @Test
  void users_tiedOnCreation_isTotalAcrossPages() {
    sameCreatedAt("users");

    assertNewestFirstThenIdDescending("/api/admin/users", "users");
  }

  @Test
  void domains_tiedOnCreation_isTotalAcrossPages() {
    dataService.createDomain("tri-a.example.com", "Tri A", "https://tri-a.example.com");
    dataService.createDomain("tri-b.example.com", "Tri B", "https://tri-b.example.com");
    dataService.createDomain("tri-c.example.com", "Tri C", "https://tri-c.example.com");
    sameCreatedAt("domains");

    assertNewestFirstThenIdDescending("/api/admin/domains", "domains");
  }

  private void assertNewestFirstThenIdDescending(String path, String listKey) {
    List<Long> all = page(path, listKey, 0, 100);
    assertTrue(all.size() >= 3, "fixture too small: " + all);

    List<Long> paged = new ArrayList<>();
    for (int page = 0; page < all.size(); page++) {
      List<Long> rows = page(path, listKey, page, 1);
      assertEquals(1, rows.size(), "page " + page);
      paged.addAll(rows);
    }
    assertEquals(all.size(), new HashSet<>(paged).size(), "a row came back twice: " + paged);
    assertEquals(all.stream().sorted(Comparator.reverseOrder()).toList(), paged);
  }

  private List<Long> page(String path, String listKey, int page, int size) {
    return given()
        .auth()
        .oauth2(jwtService.generateAccessToken(platformAdmin))
        .queryParam("page", page)
        .queryParam("size", size)
        .when()
        .get(path)
        .then()
        .statusCode(200)
        .extract()
        .jsonPath()
        .getList(listKey + ".id", String.class)
        .stream()
        .map(TsidUtils::toLong)
        .toList();
  }

  /** Every row of the table created at the same instant. */
  private void sameCreatedAt(String table) {
    QuarkusTransaction.requiringNew()
        .run(() ->
            em.createNativeQuery("update " + table + " set created_at = :at")
                .setParameter("at", Instant.now().minus(1, ChronoUnit.HOURS))
                .executeUpdate());
  }
}
