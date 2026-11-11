package fr.pedalons.service.sitemap;

import static org.junit.jupiter.api.Assertions.assertEquals;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.sitemap.SitemapEntryDto;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.Visibility;
import fr.pedalons.repository.common.TeamEntityRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * {@link TeamEntityRepository#isIndexable}, the {@code indexable} of the permissions block, says
 * exactly what the sitemap lists (docs/LEDGER_*.md API-176): the Java rule and the SQL of {@code
 * findIndexable} are written twice, and this is what keeps them in step. Every entity below is
 * either in the sitemap and indexable, or neither.
 */
@QuarkusTest
class ContentIndexingTest extends AbstractBaseTest {

  @Inject SitemapService sitemapService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;

  private User owner;
  private final List<TeamEntity> entities = new ArrayList<>();

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    Domain domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    owner = dataService.createUser("owner@example.com", "Owner");
  }

  /** The entity's key in the sitemap, "TYPE team/[trip/]slug". */
  private static String key(TeamEntity entity) {
    String trip = entity instanceof TripStage stage ? stage.getTrip().getSlug() + "/" : "";
    return entity.getEntityType()
        + " "
        + entity.getTeam().getSlug()
        + "/"
        + trip
        + entity.getSlug();
  }

  private static String key(SitemapEntryDto e) {
    return e.type()
        + " "
        + e.teamSlug()
        + "/"
        + (e.tripSlug() != null ? e.tripSlug() + "/" : "")
        + e.slug();
  }

  /** Everything a team may hold, in every state the rule distinguishes. */
  private void fill(Team team) {
    Instant now = Instant.now();
    String p = team.getSlug() + "-";
    for (Visibility visibility : Visibility.values()) {
      String v = visibility.name().toLowerCase().replace('_', '-');
      entities.add(dataService.createRide(team, owner, "R", p + "ride-" + v, now, visibility));
      entities.add(dataService.createPost(team, owner, p + "post " + v, now, visibility));
      entities.add(dataService.createAdditionalPage(team, owner, p + "page " + v, 0, visibility));
      Trip trip = dataService.createTrip(team, owner, p + "trip " + v, now, visibility);
      entities.add(trip);
      entities.add(dataService.createTripStage(owner, trip, p + "stage " + v));
    }
    for (Status status : List.of(Status.DRAFT, Status.CANCELLED)) {
      String s = status.name().toLowerCase();
      entities.add(
          dataService.createRide(
              team, owner, "R", p + "ride-" + s, now, Visibility.PUBLIC, status));
      Trip trip =
          dataService.createTrip(
              team, owner, p + "trip " + s, now, Visibility.PUBLIC, status, null);
      entities.add(trip);
      entities.add(dataService.createTripStage(owner, trip, p + "stage " + s));
    }
    Ride hidden =
        dataService.createRide(team, owner, "R", p + "ride-hidden", now, Visibility.PUBLIC);
    dataService.hideForModeration(hidden);
    hidden.setModerationHiddenAt(now);
    entities.add(hidden);
    Ride deleted =
        dataService.createRide(team, owner, "R", p + "ride-deleted", now, Visibility.PUBLIC);
    dataService.deleteRide(deleted);
    deleted.setDeleted(true);
    entities.add(deleted);
  }

  @Test
  void indexable_isExactlyWhatTheSitemapLists() {
    Team publicTeam = dataService.createTeam(owner, "Public", "public-team", Visibility.PUBLIC);
    Team unlisted =
        dataService.createTeam(owner, "Unlisted", "unlisted", Visibility.PUBLIC_UNLISTED);
    Team linkOnly = dataService.createTeam(owner, "Link", "link-only", Visibility.TEAM);
    dataService.setTeamPublicContentAllowed(linkOnly, true);
    linkOnly.setPublicContentAllowed(true);
    Team noPosts = dataService.createTeam(owner, "No posts", "no-posts", Visibility.PUBLIC);
    dataService.setTeamModules(noPosts, true, false);
    noPosts.setEnablePosts(false);
    for (Team team : List.of(publicTeam, unlisted, linkOnly, noPosts)) {
      fill(team);
    }

    Set<String> sitemap =
        sitemapService.getSitemap().entries().stream()
            .filter(e -> e.slug() != null)
            .map(ContentIndexingTest::key)
            .collect(Collectors.toSet());
    int indexable = 0;
    for (TeamEntity entity : entities) {
      boolean expected = sitemap.contains(key(entity));
      assertEquals(expected, TeamEntityRepository.isIndexable(entity), key(entity) + " " + sitemap);
      if (expected) {
        indexable++;
      }
    }
    // Rides, posts, pages, trips and stages of the public team, cancelled ones included.
    assertEquals(true, indexable >= 5, "the fixture must index something: " + sitemap);
  }
}
