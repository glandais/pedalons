package fr.pedalons.service.page;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.TeamPage;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.pages.request.ReorderPagesRequest;
import fr.pedalons.dto.pages.request.TeamPageRequest;
import fr.pedalons.dto.pages.response.TeamPageDto;
import fr.pedalons.dto.pages.response.TeamPageSummaryDto;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.exception.NotFoundException;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

@QuarkusTest
class TeamPageServiceTest extends AbstractBaseTest {

  @Inject TeamPageService teamPageService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;

  private Domain domain;
  private Team team;
  private User admin;
  private User organizer;
  private User member;
  private User nonMember;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    admin = dataService.createUser("admin@example.com", "Admin");
    team = dataService.createTeam(admin, "Test Team", "test-team", Visibility.PUBLIC);
    organizer = dataService.createUser("organizer@example.com", "Organizer");
    member = dataService.createUser("member@example.com", "Member");
    nonMember = dataService.createUser("nonmember@example.com", "NonMember");
    dataService.addUserToTeam(organizer, team, TeamRole.ORGANIZER);
    dataService.addUserToTeam(member, team, TeamRole.MEMBER);
  }

  @Nested
  class GetPage {

    @Test
    void shouldReturnPageForMember() {
      TeamPage page = dataService.createAdditionalPage(team, admin, "Test Page", 1);

      queryContext.setUserForTest(member);
      TeamPageDto result = teamPageService.getDto(team.getSlug(), page.getSlug());

      assertNotNull(result);
      assertEquals("Test Page", result.title());
    }

    @Test
    void shouldReturnPublicPageForAnonymous() {
      TeamPage page =
          dataService.createAdditionalPage(team, admin, "Public Page", 1, Visibility.PUBLIC);

      queryContext.setUserForTest(null);
      TeamPageDto result = teamPageService.getDto(team.getSlug(), page.getSlug());

      assertNotNull(result);
      assertEquals("Public Page", result.title());
    }

    @Test
    void shouldThrowForNonexistentPage() {
      queryContext.setUserForTest(member);
      assertThrows(
          NotFoundException.class,
          () -> teamPageService.getDto(team.getSlug(), "nonexistent-page"));
    }
  }

  @Nested
  class ListPages {

    @Test
    void shouldReturnPagesForAdmin() {
      dataService.createAdditionalPage(team, admin, "Page 1", 1);
      dataService.createAdditionalPage(team, admin, "Page 2", 2);

      queryContext.setUserForTest(admin);
      List<TeamPageSummaryDto> result = teamPageService.listPages(team.getSlug());

      assertEquals(2, result.size());
    }

    @Test
    void shouldReturnPagesSortedByOrder() {
      dataService.createAdditionalPage(team, admin, "Page B", 2);
      dataService.createAdditionalPage(team, admin, "Page A", 1);
      dataService.createAdditionalPage(team, admin, "Page C", 3);

      queryContext.setUserForTest(admin);
      List<TeamPageSummaryDto> result = teamPageService.listPages(team.getSlug());

      assertEquals("Page A", result.get(0).title());
      assertEquals("Page B", result.get(1).title());
      assertEquals("Page C", result.get(2).title());
    }

    @Test
    void shouldThrowForNonAdmin() {
      queryContext.setUserForTest(member);
      assertThrows(ForbiddenException.class, () -> teamPageService.listPages(team.getSlug()));
    }

    @Test
    void shouldThrowForOrganizer() {
      queryContext.setUserForTest(organizer);
      assertThrows(ForbiddenException.class, () -> teamPageService.listPages(team.getSlug()));
    }
  }

  @Nested
  class CreatePage {

    @Test
    void shouldCreatePageForAdmin() {
      TeamPageRequest request =
          new TeamPageRequest(
              "New Page", MediaDto.builder().markdown("Content").build(), Visibility.PUBLIC);

      queryContext.setUserForTest(admin);
      TeamPageDto result = teamPageService.createPage(team.getSlug(), request);

      assertNotNull(result);
      assertEquals("New Page", result.title());
      assertEquals("new-page", result.slug());
    }

    @Test
    void shouldGenerateUniqueSlug() {
      dataService.createAdditionalPage(team, admin, "Test Page", 1);
      TeamPageRequest request =
          new TeamPageRequest("Test Page", MediaDto.builder().build(), Visibility.PUBLIC);

      queryContext.setUserForTest(admin);
      TeamPageDto result = teamPageService.createPage(team.getSlug(), request);

      assertNotEquals("test-page", result.slug());
      assertTrue(result.slug().startsWith("test-page-"));
    }

    @Test
    void shouldThrowForNonAdmin() {
      TeamPageRequest request =
          new TeamPageRequest("New Page", MediaDto.builder().build(), Visibility.PUBLIC);

      queryContext.setUserForTest(member);
      assertThrows(
          ForbiddenException.class, () -> teamPageService.createPage(team.getSlug(), request));
    }

    @Test
    void shouldThrowWhenExceedingMaxPages() {
      // Create max pages (3)
      dataService.createAdditionalPage(team, admin, "Page 1", 1);
      dataService.createAdditionalPage(team, admin, "Page 2", 2);
      dataService.createAdditionalPage(team, admin, "Page 3", 3);

      TeamPageRequest request =
          new TeamPageRequest("Page 4", MediaDto.builder().build(), Visibility.PUBLIC);

      queryContext.setUserForTest(admin);
      assertThrows(
          BusinessException.class, () -> teamPageService.createPage(team.getSlug(), request));
    }
  }

  @Nested
  class UpdatePage {

    @Test
    void shouldUpdatePageForAdmin() {
      TeamPage page = dataService.createAdditionalPage(team, admin, "Original", 1);
      TeamPageRequest request =
          new TeamPageRequest(
              "Updated", MediaDto.builder().markdown("New content").build(), Visibility.TEAM);

      queryContext.setUserForTest(admin);
      TeamPageDto result = teamPageService.updatePage(team.getSlug(), page.getSlug(), request);

      assertEquals("Updated", result.title());
      assertEquals(Visibility.TEAM, result.visibility());
    }

    @Test
    void shouldThrowForNonAdmin() {
      TeamPage page = dataService.createAdditionalPage(team, admin, "Original", 1);
      TeamPageRequest request =
          new TeamPageRequest("Updated", MediaDto.builder().build(), Visibility.PUBLIC);

      queryContext.setUserForTest(member);
      assertThrows(
          ForbiddenException.class,
          () -> teamPageService.updatePage(team.getSlug(), page.getSlug(), request));
    }

    @Test
    void shouldThrowForAboutPage() {
      // About page is created automatically with team
      TeamPageRequest request =
          new TeamPageRequest("Updated", MediaDto.builder().build(), Visibility.PUBLIC);

      queryContext.setUserForTest(admin);
      assertThrows(
          ForbiddenException.class,
          () -> teamPageService.updatePage(team.getSlug(), "about", request));
    }
  }

  @Nested
  class UpdateSlug {

    @Test
    void shouldUpdateSlugForAdmin() {
      TeamPage page = dataService.createAdditionalPage(team, admin, "Test Page", 1);

      queryContext.setUserForTest(admin);
      TeamPageDto result = teamPageService.updateSlug(team.getSlug(), page.getSlug(), "new-slug");

      assertEquals("new-slug", result.slug());
    }

    @Test
    void shouldThrowForNonAdmin() {
      TeamPage page = dataService.createAdditionalPage(team, admin, "Test Page", 1);

      queryContext.setUserForTest(member);
      assertThrows(
          ForbiddenException.class,
          () -> teamPageService.updateSlug(team.getSlug(), page.getSlug(), "new-slug"));
    }
  }

  @Nested
  class DeletePage {

    @Test
    void shouldDeletePageForAdmin() {
      TeamPage page = dataService.createAdditionalPage(team, admin, "To Delete", 1);

      queryContext.setUserForTest(admin);
      teamPageService.deletePage(team.getSlug(), page.getSlug());

      queryContext.setUserForTest(member);
      assertThrows(
          NotFoundException.class, () -> teamPageService.getDto(team.getSlug(), page.getSlug()));
    }

    @Test
    void shouldThrowForNonAdmin() {
      TeamPage page = dataService.createAdditionalPage(team, admin, "Test Page", 1);

      queryContext.setUserForTest(member);
      assertThrows(
          ForbiddenException.class,
          () -> teamPageService.deletePage(team.getSlug(), page.getSlug()));
    }

    @Test
    void shouldThrowForAboutPage() {
      queryContext.setUserForTest(admin);
      assertThrows(
          ForbiddenException.class, () -> teamPageService.deletePage(team.getSlug(), "about"));
    }
  }

  @Nested
  class UndeletePage {

    @Test
    void shouldRestoreDeletedPage() {
      TeamPage page = dataService.createAdditionalPage(team, admin, "To Restore", 1);

      queryContext.setUserForTest(admin);
      teamPageService.deletePage(team.getSlug(), page.getSlug());

      queryContext.setUserForTest(admin);
      TeamPageDto result = teamPageService.undeletePage(team.getSlug(), page.getSlug());

      assertFalse(result.deleted());
      assertEquals(page.getSlug(), result.slug());
    }

    @Test
    void shouldThrowWhenRestoringPastMaxPages() {
      TeamPage binned = dataService.createAdditionalPage(team, admin, "In The Bin", 1);
      queryContext.setUserForTest(admin);
      teamPageService.deletePage(team.getSlug(), binned.getSlug());
      dataService.createAdditionalPage(team, admin, "Page 1", 2);
      dataService.createAdditionalPage(team, admin, "Page 2", 3);
      dataService.createAdditionalPage(team, admin, "Page 3", 4);

      queryContext.setUserForTest(admin);
      BusinessException e =
          assertThrows(
              BusinessException.class,
              () -> teamPageService.undeletePage(team.getSlug(), binned.getSlug()));
      assertEquals(ErrorCode.TOO_MANY_TEAM_PAGES, e.getErrorCode());
    }

    @Test
    void shouldThrowForNonAdmin() {
      TeamPage page = dataService.createAdditionalPage(team, admin, "Test Page", 1);

      queryContext.setUserForTest(admin);
      teamPageService.deletePage(team.getSlug(), page.getSlug());

      queryContext.setUserForTest(member);
      assertThrows(
          PedalonsException.class,
          () -> teamPageService.undeletePage(team.getSlug(), page.getSlug()));
    }
  }

  @Nested
  class ReorderPages {

    @Test
    void shouldReorderPagesForAdmin() {
      TeamPage page1 = dataService.createAdditionalPage(team, admin, "Page A", 1);
      TeamPage page2 = dataService.createAdditionalPage(team, admin, "Page B", 2);
      TeamPage page3 = dataService.createAdditionalPage(team, admin, "Page C", 3);

      // Reverse order
      ReorderPagesRequest request =
          new ReorderPagesRequest(
              List.of(
                  TsidUtils.toString(page3.getId()),
                  TsidUtils.toString(page2.getId()),
                  TsidUtils.toString(page1.getId())));

      queryContext.setUserForTest(admin);
      List<TeamPageSummaryDto> result = teamPageService.reorderPages(team.getSlug(), request);

      assertEquals("Page C", result.get(0).title());
      assertEquals("Page B", result.get(1).title());
      assertEquals("Page A", result.get(2).title());
    }

    @Test
    void shouldThrowForNonAdmin() {
      TeamPage page = dataService.createAdditionalPage(team, admin, "Page", 1);
      ReorderPagesRequest request =
          new ReorderPagesRequest(List.of(TsidUtils.toString(page.getId())));

      queryContext.setUserForTest(member);
      assertThrows(
          ForbiddenException.class, () -> teamPageService.reorderPages(team.getSlug(), request));
    }

    @Test
    void shouldThrowForNonexistentPage() {
      ReorderPagesRequest request = new ReorderPagesRequest(List.of("0000000000000"));

      queryContext.setUserForTest(admin);
      assertThrows(
          NotFoundException.class, () -> teamPageService.reorderPages(team.getSlug(), request));
    }

    @Test
    void shouldThrowWhenIncludingAboutPage() {
      TeamPage page = dataService.createAdditionalPage(team, admin, "Page", 1);
      // Get about page ID - it's created with the team
      TeamPage aboutPage = team.getAboutPage();
      ReorderPagesRequest request =
          new ReorderPagesRequest(
              List.of(TsidUtils.toString(aboutPage.getId()), TsidUtils.toString(page.getId())));

      queryContext.setUserForTest(admin);
      assertThrows(
          BusinessException.class, () -> teamPageService.reorderPages(team.getSlug(), request));
    }
  }
}
