package fr.pedalons.repository.team;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.team.request.MinRole;
import fr.pedalons.service.team.response.TeamAndRole;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TeamRepositoryTest extends AbstractBaseTest {

  @Inject TeamRepository teamRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;

  private Domain domain;
  private User user1;
  private User user2;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    user1 = dataService.createUser("user1@example.com", "User One");
    user2 = dataService.createUser("user2@example.com", "User Two");
  }

  @Test
  void findBySlugAndDomain_shouldReturnTeamWhenExists() {
    dataService.createTeam(user1, "Test Team", "test-team", Visibility.PUBLIC);

    Optional<Team> result = teamRepository.findBySlugAndDomain(domain.getId(), "test-team");

    assertTrue(result.isPresent());
    assertEquals("Test Team", result.get().getName());
    assertEquals("test-team", result.get().getSlug());
  }

  @Test
  void findBySlugAndDomain_shouldReturnEmptyWhenNotExists() {
    Optional<Team> result = teamRepository.findBySlugAndDomain(domain.getId(), "nonexistent");

    assertTrue(result.isEmpty());
  }

  @Test
  void findBySlugAndDomain_shouldIgnoreDeletedTeams() {
    Team team = dataService.createTeam(user1, "Deleted Team", "deleted-team", Visibility.PUBLIC);
    dataService.deleteTeam(team);

    Optional<Team> result = teamRepository.findBySlugAndDomain(domain.getId(), "deleted-team");

    assertTrue(result.isEmpty());
  }

  @Test
  void existsBySlugAndDomain_shouldReturnTrueWhenExists() {
    dataService.createTeam(user1, "Test Team", "test-team", Visibility.PUBLIC);

    boolean exists = teamRepository.existsBySlugAndDomain(domain.getId(), "test-team");

    assertTrue(exists);
  }

  @Test
  void existsBySlugAndDomain_shouldReturnFalseWhenNotExists() {
    boolean exists = teamRepository.existsBySlugAndDomain(domain.getId(), "nonexistent");

    assertFalse(exists);
  }

  @Test
  void existsBySlugAndDomain_shouldCountDeletedTeams() {
    Team team = dataService.createTeam(user1, "Deleted Team", "deleted-team", Visibility.PUBLIC);
    dataService.deleteTeam(team);

    boolean exists = teamRepository.existsBySlugAndDomain(domain.getId(), "deleted-team");

    assertTrue(exists);
  }

  @Test
  void existsByDomain_shouldReturnTrueWhenTeamExists() {
    dataService.createTeam(user1, "Test Team", "test-team", Visibility.PUBLIC);

    boolean exists = teamRepository.existsByDomain(domain.getId());

    assertTrue(exists);
  }

  @Test
  void existsByDomain_shouldReturnFalseWhenNoTeams() {
    boolean exists = teamRepository.existsByDomain(domain.getId());

    assertFalse(exists);
  }

  @Test
  void existsByDomain_shouldIgnoreDeletedTeams() {
    Team team = dataService.createTeam(user1, "Deleted Team", "deleted-team", Visibility.PUBLIC);
    dataService.deleteTeam(team);

    boolean exists = teamRepository.existsByDomain(domain.getId());

    assertFalse(exists);
  }

  @Test
  void existsByDomain_shouldReturnFalseForDifferentDomain() {
    dataService.createTeam(user1, "Test Team", "test-team", Visibility.PUBLIC);
    Domain otherDomain =
        dataService.createDomain("other.example.com", "Other Domain", "https://other.example.com");

    boolean exists = teamRepository.existsByDomain(otherDomain.getId());

    assertFalse(exists);
  }

  @Test
  void find_shouldReturnPublicTeamsForAnonymous() {
    dataService.createTeam(user1, "Public Team", "public-team", Visibility.PUBLIC);
    dataService.createTeam(user1, "Private Team", "private-team", Visibility.TEAM);

    TeamQuery query = TeamQuery.builder().domainId(domain.getId()).page(0).size(10).build();
    PedalonsPage<TeamAndRole> result = teamRepository.find(query);

    assertEquals(1, result.items().size());
    assertEquals("public-team", result.items().getFirst().team().getSlug());
  }

  @Test
  void find_shouldFilterById() {
    Team team1 = dataService.createTeam(user1, "Team 1", "team-1", Visibility.PUBLIC);
    dataService.createTeam(user1, "Team 2", "team-2", Visibility.PUBLIC);

    TeamQuery query =
        new TeamQuery(
            0, 10, domain.getId(), null, team1.getId(), null, null, null, null, null, null, false);
    PedalonsPage<TeamAndRole> result = teamRepository.find(query);

    assertEquals(1, result.items().size());
    assertEquals("team-1", result.items().getFirst().team().getSlug());
  }

  @Test
  void find_shouldFilterBySearch() {
    Team team1 = dataService.createTeam(user1, "Cycling Club", "cycling-club", Visibility.PUBLIC);
    team1.getAboutPage().setMarkdown("A great cycling team");
    dataService.updateTeam(team1);

    dataService.createTeam(user1, "Running Club", "running-club", Visibility.PUBLIC);

    TeamQuery query =
        new TeamQuery(
            0, 10, domain.getId(), null, null, null, null, "cycling", null, null, null, false);
    PedalonsPage<TeamAndRole> result = teamRepository.find(query);

    assertEquals(1, result.items().size());
    assertEquals("cycling-club", result.items().getFirst().team().getSlug());
  }

  /** docs/LEDGER_*.md SEC-22: a typed {@code %} is a character to find, not a wildcard. */
  @Test
  void find_searchTreatsPercentAsALiteral() {
    dataService.createTeam(user1, "Cycling Club", "cycling-club", Visibility.PUBLIC);
    dataService.createTeam(user1, "Running Club", "running-club", Visibility.PUBLIC);

    TeamQuery query =
        new TeamQuery(0, 10, domain.getId(), null, null, null, null, "%", null, null, null, false);

    assertEquals(0, teamRepository.find(query).items().size());
  }

  @Test
  void find_shouldShowUserTeamsWhenMemberFilterTrue() {
    Team team1 = dataService.createTeam(user1, "My Team", "my-team", Visibility.TEAM);
    Team team2 = dataService.createTeam(user1, "Other Team", "other-team", Visibility.PUBLIC);

    dataService.addUserToTeam(user2, team1, TeamRole.MEMBER);

    TeamQuery query =
        new TeamQuery(
            0,
            10,
            domain.getId(),
            null,
            null,
            user2.getId(),
            MinRole.MEMBER,
            null,
            null,
            null,
            null,
            false);
    PedalonsPage<TeamAndRole> result = teamRepository.find(query);

    assertEquals(1, result.items().size());
    assertEquals("my-team", result.items().getFirst().team().getSlug());
    assertEquals(TeamRole.MEMBER, result.items().getFirst().teamRole());
  }

  @Test
  void find_shouldShowPublicAndMemberTeamsWhenMemberFilterNull() {
    Team publicTeam =
        dataService.createTeam(user1, "Public Team", "public-team", Visibility.PUBLIC);
    Team privateTeam =
        dataService.createTeam(user1, "Private Team", "private-team", Visibility.TEAM);

    dataService.addUserToTeam(user2, privateTeam, TeamRole.MEMBER);

    TeamQuery query =
        new TeamQuery(
            0, 10, domain.getId(), null, null, user2.getId(), null, null, null, null, null, false);
    PedalonsPage<TeamAndRole> result = teamRepository.find(query);

    assertEquals(2, result.items().size());
  }

  @Test
  void find_shouldIgnoreDeletedTeams() {
    dataService.createTeam(user1, "Visible Team", "visible", Visibility.PUBLIC);
    Team deletedTeam = dataService.createTeam(user1, "Deleted Team", "deleted", Visibility.PUBLIC);
    dataService.deleteTeam(deletedTeam);

    TeamQuery query =
        new TeamQuery(0, 10, domain.getId(), null, null, null, null, null, null, null, null, false);
    PedalonsPage<TeamAndRole> result = teamRepository.find(query);

    assertEquals(1, result.items().size());
    assertEquals("visible", result.items().getFirst().team().getSlug());
  }

  @Test
  void findOne_shouldReturnTeamAndRoleWhenExists() {
    Team team = dataService.createTeam(user1, "Test Team", "test-team", Visibility.PUBLIC);
    dataService.addUserToTeam(user2, team, TeamRole.ADMIN);

    Optional<TeamAndRole> result =
        teamRepository.findOne(domain.getId(), team.getId(), user2.getId(), false);

    assertTrue(result.isPresent());
    assertEquals("test-team", result.get().team().getSlug());
    assertEquals(TeamRole.ADMIN, result.get().teamRole());
  }

  @Test
  void findOne_shouldReturnEmptyWhenNotExists() {
    Optional<TeamAndRole> result =
        teamRepository.findOne(domain.getId(), -1L, user1.getId(), false);

    assertTrue(result.isEmpty());
  }

  @Test
  void findOne_shouldReturnTeamWithNullRoleWhenNotMember() {
    Team publicTeam =
        dataService.createTeam(user1, "Public Team", "public-team", Visibility.PUBLIC);

    Optional<TeamAndRole> result =
        teamRepository.findOne(domain.getId(), publicTeam.getId(), user2.getId(), false);

    assertTrue(result.isPresent());
    assertEquals("public-team", result.get().team().getSlug());
    assertNull(result.get().teamRole());
  }

  @Test
  void findOne_shouldReturnEmptyForDeletedTeamWhenIncludeDeletedFalse() {
    Team team = dataService.createTeam(user1, "Deleted Team", "deleted-team", Visibility.PUBLIC);
    dataService.deleteTeam(team);

    Optional<TeamAndRole> result =
        teamRepository.findOne(domain.getId(), team.getId(), user1.getId(), false);

    assertTrue(result.isEmpty());
  }

  // ==================== Platform admin (ledger API-137) ====================

  @Test
  void find_platformAdmin_minRoleTakesPrecedence() {
    User admin = dataService.createPlatformAdminUser("root@example.com", "Root");
    Team joined = dataService.createTeam(user1, "Joined", "joined", Visibility.TEAM);
    dataService.addUserToTeam(admin, joined, TeamRole.MEMBER);
    dataService.createTeam(user1, "Foreign Private", "foreign-private", Visibility.TEAM);
    dataService.createTeam(user2, "Foreign Public", "foreign-public", Visibility.PUBLIC);
    Team trashed = dataService.createTeam(admin, "Trashed", "trashed", Visibility.TEAM);
    dataService.softDeleteTeam(trashed);

    PedalonsPage<TeamAndRole> mine =
        teamRepository.find(
            TeamQuery.builder()
                .domainId(domain.getId())
                .userId(admin.getId())
                .minRole(MinRole.MEMBER)
                .platformAdmin(true)
                .page(0)
                .size(10)
                .build());

    assertEquals(1, mine.total());
    assertEquals("joined", mine.items().getFirst().team().getSlug());
    assertEquals(TeamRole.MEMBER, mine.items().getFirst().teamRole());

    PedalonsPage<TeamAndRole> all =
        teamRepository.find(
            TeamQuery.builder()
                .domainId(domain.getId())
                .userId(admin.getId())
                .platformAdmin(true)
                .page(0)
                .size(10)
                .build());

    // Every live team of the domain, the trashed one excluded.
    assertEquals(3, all.total());
    assertTrue(all.items().stream().noneMatch(t -> t.team().getSlug().equals("trashed")));
  }

  @Test
  void findOne_platformAdmin_deletedTeam_isNotFound() {
    User admin = dataService.createPlatformAdminUser("root@example.com", "Root");
    Team team = dataService.createTeam(user1, "Trashed", "trashed", Visibility.TEAM);
    dataService.softDeleteTeam(team);

    assertTrue(teamRepository.findOne(domain.getId(), team.getId(), admin.getId(), true).isEmpty());
  }
}
