package fr.pedalons.repository.team;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.TeamSlugRedirect;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.Visibility;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TeamSlugRedirectRepositoryTest extends AbstractBaseTest {

  @Inject TeamSlugRedirectRepository teamSlugRedirectRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;

  private Domain domain;
  private Team team;
  private User user;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    user = dataService.createUser("test@example.com", "Test User");
    team = dataService.createTeam(user, "Test Team", "test-team", Visibility.PUBLIC);
  }

  @Nested
  @DisplayName("findByOldSlugAndDomain")
  class FindByOldSlugAndDomain {

    @Test
    void shouldReturnRedirectWhenOldSlugExists() {
      dataService.createTeamSlugRedirect("old-team-slug", team);

      Optional<TeamSlugRedirect> result =
          teamSlugRedirectRepository.findByOldSlugAndDomain(domain.getId(), "old-team-slug");

      assertTrue(result.isPresent());
      assertEquals("old-team-slug", result.get().getOldSlug());
      assertEquals(team.getId(), result.get().getTeam().getId());
    }

    @Test
    void shouldReturnEmptyWhenOldSlugNotExists() {
      Optional<TeamSlugRedirect> result =
          teamSlugRedirectRepository.findByOldSlugAndDomain(domain.getId(), "non-existent-slug");

      assertTrue(result.isEmpty());
    }

    @Test
    void shouldFindCorrectRedirectAmongMultiple() {
      Team team2 = dataService.createTeam(user, "Team 2", "team-2", Visibility.PUBLIC);
      dataService.createTeamSlugRedirect("old-slug-1", team);
      dataService.createTeamSlugRedirect("old-slug-2", team2);

      Optional<TeamSlugRedirect> result =
          teamSlugRedirectRepository.findByOldSlugAndDomain(domain.getId(), "old-slug-2");

      assertTrue(result.isPresent());
      assertEquals("old-slug-2", result.get().getOldSlug());
      assertEquals(team2.getId(), result.get().getTeam().getId());
    }

    @Test
    void shouldBeCaseSensitive() {
      dataService.createTeamSlugRedirect("old-team-slug", team);

      Optional<TeamSlugRedirect> result =
          teamSlugRedirectRepository.findByOldSlugAndDomain(domain.getId(), "Old-Team-Slug");

      assertTrue(result.isEmpty());
    }

    @Test
    void shouldReturnRedirectWithTeamAssociation() {
      TeamSlugRedirect redirect = dataService.createTeamSlugRedirect("previous-slug", team);

      Optional<TeamSlugRedirect> result =
          teamSlugRedirectRepository.findByOldSlugAndDomain(domain.getId(), "previous-slug");

      assertTrue(result.isPresent());
      assertEquals(redirect.getId(), result.get().getId());
      assertNotNull(result.get().getTeam());
      assertEquals("test-team", result.get().getTeam().getSlug());
    }
  }

  @Test
  @Transactional
  void shouldDeleteRedirectByOldSlugAndDomain() {
    dataService.createTeamSlugRedirect("slug-to-delete", team);

    teamSlugRedirectRepository.deleteByOldSlugAndDomain(domain.getId(), "slug-to-delete");

    Optional<TeamSlugRedirect> result =
        teamSlugRedirectRepository.findByOldSlugAndDomain(domain.getId(), "slug-to-delete");
    assertTrue(result.isEmpty());
  }

  @Test
  @Transactional
  void shouldNotThrowWhenDeletingNonExistentSlug() {
    assertDoesNotThrow(() ->
        teamSlugRedirectRepository.deleteByOldSlugAndDomain(domain.getId(), "non-existent-slug"));
  }

  @Test
  @Transactional
  void shouldOnlyDeleteSpecifiedSlug() {
    dataService.createTeamSlugRedirect("slug-1", team);
    dataService.createTeamSlugRedirect("slug-2", team);
    dataService.createTeamSlugRedirect("slug-3", team);

    teamSlugRedirectRepository.deleteByOldSlugAndDomain(domain.getId(), "slug-2");

    assertTrue(
        teamSlugRedirectRepository.findByOldSlugAndDomain(domain.getId(), "slug-1").isPresent());
    assertTrue(
        teamSlugRedirectRepository.findByOldSlugAndDomain(domain.getId(), "slug-2").isEmpty());
    assertTrue(
        teamSlugRedirectRepository.findByOldSlugAndDomain(domain.getId(), "slug-3").isPresent());
  }

  @Test
  @Transactional
  void shouldBeCaseSensitiveWhenDeleting() {
    dataService.createTeamSlugRedirect("case-sensitive-slug", team);

    teamSlugRedirectRepository.deleteByOldSlugAndDomain(domain.getId(), "Case-Sensitive-Slug");

    assertTrue(
        teamSlugRedirectRepository
            .findByOldSlugAndDomain(domain.getId(), "case-sensitive-slug")
            .isPresent());
  }
}
