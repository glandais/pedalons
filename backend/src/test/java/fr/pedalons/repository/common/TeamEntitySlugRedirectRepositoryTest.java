package fr.pedalons.repository.common;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.common.TeamEntitySlugRedirect;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TeamEntitySlugRedirectRepositoryTest extends AbstractBaseTest {

  @Inject TeamEntitySlugRedirectRepository repository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;

  private Team team;
  private User user;
  private Ride ride;
  private Post post;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    user = dataService.createUser("test@example.com", "Test User");
    team = dataService.createTeam(user, "Test Team", "test-team", Visibility.PUBLIC);
    ride = dataService.createRide(team, user, "Test Ride", "test-ride", Instant.now());
    post = dataService.createPost(team, user, "Test Post", Instant.now());
  }

  @Nested
  @DisplayName("findByTeamAndEntityTypeAndOldSlug")
  class FindByTeamAndEntityTypeAndOldSlug {

    @Test
    void shouldReturnRedirectWhenExists() {
      dataService.createTeamEntitySlugRedirect(
          "old-ride-slug", team, EntityType.RIDE.getStableOrdinal(), ride.getId());

      Optional<TeamEntitySlugRedirect> result =
          repository.findByTeamAndEntityTypeAndOldSlug(
              team.getId(), EntityType.RIDE.getStableOrdinal(), "old-ride-slug");

      assertTrue(result.isPresent());
      assertEquals("old-ride-slug", result.get().getOldSlug());
      assertEquals(ride.getId(), result.get().getEntityId());
    }

    @Test
    void shouldReturnEmptyWhenOldSlugNotExists() {
      Optional<TeamEntitySlugRedirect> result =
          repository.findByTeamAndEntityTypeAndOldSlug(
              team.getId(), EntityType.RIDE.getStableOrdinal(), "non-existent-slug");

      assertTrue(result.isEmpty());
    }

    @Test
    void shouldReturnEmptyWhenTeamNotMatches() {
      dataService.createTeamEntitySlugRedirect(
          "old-slug", team, EntityType.RIDE.getStableOrdinal(), ride.getId());
      Team otherTeam = dataService.createTeam(user, "Other Team", "other-team", Visibility.PUBLIC);

      Optional<TeamEntitySlugRedirect> result =
          repository.findByTeamAndEntityTypeAndOldSlug(
              otherTeam.getId(), EntityType.RIDE.getStableOrdinal(), "old-slug");

      assertTrue(result.isEmpty());
    }

    @Test
    void shouldReturnEmptyWhenEntityTypeNotMatches() {
      dataService.createTeamEntitySlugRedirect(
          "old-slug", team, EntityType.RIDE.getStableOrdinal(), ride.getId());

      Optional<TeamEntitySlugRedirect> result =
          repository.findByTeamAndEntityTypeAndOldSlug(
              team.getId(), EntityType.POST.getStableOrdinal(), "old-slug");

      assertTrue(result.isEmpty());
    }

    @Test
    void shouldFindCorrectRedirectAmongMultiple() {
      dataService.createTeamEntitySlugRedirect(
          "old-ride-slug", team, EntityType.RIDE.getStableOrdinal(), ride.getId());
      dataService.createTeamEntitySlugRedirect(
          "old-post-slug", team, EntityType.POST.getStableOrdinal(), post.getId());

      Optional<TeamEntitySlugRedirect> result =
          repository.findByTeamAndEntityTypeAndOldSlug(
              team.getId(), EntityType.POST.getStableOrdinal(), "old-post-slug");

      assertTrue(result.isPresent());
      assertEquals("old-post-slug", result.get().getOldSlug());
      assertEquals(post.getId(), result.get().getEntityId());
    }

    @Test
    void shouldAllowSameSlugForDifferentEntityTypes() {
      dataService.createTeamEntitySlugRedirect(
          "same-slug", team, EntityType.RIDE.getStableOrdinal(), ride.getId());
      dataService.createTeamEntitySlugRedirect(
          "same-slug", team, EntityType.POST.getStableOrdinal(), post.getId());

      Optional<TeamEntitySlugRedirect> rideResult =
          repository.findByTeamAndEntityTypeAndOldSlug(
              team.getId(), EntityType.RIDE.getStableOrdinal(), "same-slug");
      Optional<TeamEntitySlugRedirect> postResult =
          repository.findByTeamAndEntityTypeAndOldSlug(
              team.getId(), EntityType.POST.getStableOrdinal(), "same-slug");

      assertTrue(rideResult.isPresent());
      assertTrue(postResult.isPresent());
      assertEquals(ride.getId(), rideResult.get().getEntityId());
      assertEquals(post.getId(), postResult.get().getEntityId());
    }

    @Test
    void shouldAllowSameSlugForDifferentTeams() {
      Team otherTeam = dataService.createTeam(user, "Other Team", "other-team", Visibility.PUBLIC);
      Ride otherRide =
          dataService.createRide(otherTeam, user, "Other Ride", "other-ride", Instant.now());
      dataService.createTeamEntitySlugRedirect(
          "same-slug", team, EntityType.RIDE.getStableOrdinal(), ride.getId());
      dataService.createTeamEntitySlugRedirect(
          "same-slug", otherTeam, EntityType.RIDE.getStableOrdinal(), otherRide.getId());

      Optional<TeamEntitySlugRedirect> team1Result =
          repository.findByTeamAndEntityTypeAndOldSlug(
              team.getId(), EntityType.RIDE.getStableOrdinal(), "same-slug");
      Optional<TeamEntitySlugRedirect> team2Result =
          repository.findByTeamAndEntityTypeAndOldSlug(
              otherTeam.getId(), EntityType.RIDE.getStableOrdinal(), "same-slug");

      assertTrue(team1Result.isPresent());
      assertTrue(team2Result.isPresent());
      assertEquals(ride.getId(), team1Result.get().getEntityId());
      assertEquals(otherRide.getId(), team2Result.get().getEntityId());
    }

    @Test
    void shouldBeCaseSensitive() {
      dataService.createTeamEntitySlugRedirect(
          "old-slug", team, EntityType.RIDE.getStableOrdinal(), ride.getId());

      Optional<TeamEntitySlugRedirect> result =
          repository.findByTeamAndEntityTypeAndOldSlug(
              team.getId(), EntityType.RIDE.getStableOrdinal(), "Old-Slug");

      assertTrue(result.isEmpty());
    }
  }

  @Test
  @Transactional
  void shouldDeleteRedirect() {
    dataService.createTeamEntitySlugRedirect(
        "slug-to-delete", team, EntityType.RIDE.getStableOrdinal(), ride.getId());

    repository.deleteByTeamAndEntityTypeAndOldSlug(
        team.getId(), EntityType.RIDE.getStableOrdinal(), "slug-to-delete");

    Optional<TeamEntitySlugRedirect> result =
        repository.findByTeamAndEntityTypeAndOldSlug(
            team.getId(), EntityType.RIDE.getStableOrdinal(), "slug-to-delete");
    assertTrue(result.isEmpty());
  }

  @Test
  @Transactional
  void shouldNotThrowWhenDeletingNonExistent() {
    assertDoesNotThrow(() ->
        repository.deleteByTeamAndEntityTypeAndOldSlug(
            team.getId(), EntityType.RIDE.getStableOrdinal(), "non-existent-slug"));
  }

  @Test
  @Transactional
  void shouldOnlyDeleteMatchingRedirect() {
    dataService.createTeamEntitySlugRedirect(
        "slug-1", team, EntityType.RIDE.getStableOrdinal(), ride.getId());
    dataService.createTeamEntitySlugRedirect(
        "slug-2", team, EntityType.RIDE.getStableOrdinal(), ride.getId());
    dataService.createTeamEntitySlugRedirect(
        "slug-1", team, EntityType.POST.getStableOrdinal(), post.getId());

    repository.deleteByTeamAndEntityTypeAndOldSlug(
        team.getId(), EntityType.RIDE.getStableOrdinal(), "slug-1");

    assertTrue(
        repository
            .findByTeamAndEntityTypeAndOldSlug(
                team.getId(), EntityType.RIDE.getStableOrdinal(), "slug-1")
            .isEmpty());
    assertTrue(
        repository
            .findByTeamAndEntityTypeAndOldSlug(
                team.getId(), EntityType.RIDE.getStableOrdinal(), "slug-2")
            .isPresent());
    assertTrue(
        repository
            .findByTeamAndEntityTypeAndOldSlug(
                team.getId(), EntityType.POST.getStableOrdinal(), "slug-1")
            .isPresent());
  }

  @Test
  @Transactional
  void shouldNotDeleteFromOtherTeams() {
    Team otherTeam = dataService.createTeam(user, "Other Team", "other-team", Visibility.PUBLIC);
    Ride otherRide =
        dataService.createRide(otherTeam, user, "Other Ride", "other-ride", Instant.now());
    dataService.createTeamEntitySlugRedirect(
        "same-slug", team, EntityType.RIDE.getStableOrdinal(), ride.getId());
    dataService.createTeamEntitySlugRedirect(
        "same-slug", otherTeam, EntityType.RIDE.getStableOrdinal(), otherRide.getId());

    repository.deleteByTeamAndEntityTypeAndOldSlug(
        team.getId(), EntityType.RIDE.getStableOrdinal(), "same-slug");

    assertTrue(
        repository
            .findByTeamAndEntityTypeAndOldSlug(
                team.getId(), EntityType.RIDE.getStableOrdinal(), "same-slug")
            .isEmpty());
    assertTrue(
        repository
            .findByTeamAndEntityTypeAndOldSlug(
                otherTeam.getId(), EntityType.RIDE.getStableOrdinal(), "same-slug")
            .isPresent());
  }

  @Test
  @Transactional
  void shouldBeCaseSensitiveWhenDeleting() {
    dataService.createTeamEntitySlugRedirect(
        "case-sensitive-slug", team, EntityType.RIDE.getStableOrdinal(), ride.getId());

    repository.deleteByTeamAndEntityTypeAndOldSlug(
        team.getId(), EntityType.RIDE.getStableOrdinal(), "Case-Sensitive-Slug");

    assertTrue(
        repository
            .findByTeamAndEntityTypeAndOldSlug(
                team.getId(), EntityType.RIDE.getStableOrdinal(), "case-sensitive-slug")
            .isPresent());
  }
}
