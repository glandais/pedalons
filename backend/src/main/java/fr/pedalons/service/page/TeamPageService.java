package fr.pedalons.service.page;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.TeamPage;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.pages.request.ReorderPagesRequest;
import fr.pedalons.dto.pages.request.TeamPageRequest;
import fr.pedalons.dto.pages.response.TeamPageDto;
import fr.pedalons.dto.pages.response.TeamPageSummaryDto;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.infrastructure.exception.NotFoundException;
import fr.pedalons.repository.team.TeamPageQuery;
import fr.pedalons.repository.team.TeamPageRepository;
import fr.pedalons.service.common.TeamEntityService;
import fr.pedalons.service.security.annotation.CheckAccess;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.Set;

@ApplicationScoped
public class TeamPageService extends TeamEntityService<TeamPage, TeamPageRepository, TeamPageDto> {

  private static final int MAX_ADDITIONAL_PAGES = 3;

  @Inject TeamPageRepository teamPageRepository;

  @Override
  protected TeamPageRepository getRepository() {
    return teamPageRepository;
  }

  @Override
  protected TeamPageDto toDto(TeamPage entity) {
    return TeamPageDto.from(entity, assetService, detailPermissions(entity));
  }

  @Override
  protected TeamPage findBySlug(Team team, String entitySlug) {
    return super.findBySlug(team, entitySlug);
  }

  @CheckAccess(entityType = EntityType.TEAM_PAGE, action = ActionType.READ)
  public TeamPageDto getDto(String teamSlug, String entitySlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.getDto(team, entitySlug);
  }

  @CheckAccess(entityType = EntityType.TEAM_PAGE, action = ActionType.LIST)
  public List<TeamPageSummaryDto> listPages(String teamSlug) {
    Team team = teamService.getTeam(teamSlug);
    PedalonsPage<TeamPage> teamPages =
        teamPageRepository.find(
            TeamPageQuery.builder()
                .domainId(pedalonsContext.getDomainId())
                .userId(pedalonsContext.getUserIdNullable())
                .teamIds(Set.of(team.getId()))
                .includeAbout(false)
                .page(0)
                .size(100)
                .includeDeleted(isIncludeDeleted(team))
                .platformAdmin(isPlatformAdmin())
                .build());
    return teamPages.items().stream()
        .sorted(Comparator.comparing(t -> t.getPageOrder() == null ? 0 : t.getPageOrder()))
        .map(TeamPageSummaryDto::from)
        .toList();
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TEAM_PAGE, action = ActionType.CREATE)
  public TeamPageDto createPage(String teamSlug, TeamPageRequest request) {
    Team team = teamService.getTeam(teamSlug);
    // Check max pages limit
    long currentCount = teamPageRepository.countAdditionalPages(team.getId());
    if (currentCount >= MAX_ADDITIONAL_PAGES) {
      throw new BusinessException(ErrorCode.TOO_MANY_TEAM_PAGES);
    }

    validateVisibility(team, request);

    // Generate slug from title
    String slug = slugService.generateSlug(request.title(), team.getId(), teamPageRepository);

    int order = teamPageRepository.getNextPageOrder(team.getId());

    TeamPage page =
        TeamPage.createAdditionalPage(
            pedalonsContext.getUser(), team, request.title(), slug, request.visibility(), order);

    teamPageRepository.persistAndFlush(page);

    updateMedia(page, request.media());

    teamPageRepository.persist(page);

    return TeamPageDto.from(page, assetService, detailPermissions(page));
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TEAM_PAGE, action = ActionType.UPDATE)
  public TeamPageDto updatePage(String teamSlug, String pageSlug, TeamPageRequest request) {
    Team team = teamService.getTeam(teamSlug);
    TeamPage page = findBySlug(team, pageSlug);

    // Don't allow editing the about page through this endpoint
    if (page.isAboutPage()) {
      throw new ForbiddenException();
    }

    validateVisibility(team, request);

    page.setName(request.title());
    page.setVisibility(request.visibility());

    updateMedia(page, request.media());

    teamPageRepository.persist(page);

    return TeamPageDto.from(page, assetService, detailPermissions(page));
  }

  @CheckAccess(entityType = EntityType.TEAM_PAGE, action = ActionType.UPDATE)
  @Transactional
  public TeamPageDto updateSlug(String teamSlug, String slug, String newSlug) {
    Team team = teamService.getTeam(teamSlug);
    return super.updateSlug(team, slug, newSlug);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TEAM_PAGE, action = ActionType.DELETE)
  public void deletePage(String teamSlug, String pageSlug) {
    Team team = teamService.getTeam(teamSlug);
    TeamPage page = findBySlug(team, pageSlug);

    // Don't allow deleting the about page
    if (page.isAboutPage()) {
      throw new ForbiddenException();
    }

    page.setDeleted(true);
    teamPageRepository.persist(page);
  }

  @CheckAccess(entityType = EntityType.TEAM_PAGE, action = ActionType.DELETE)
  @Transactional
  public TeamPageDto undeletePage(String teamSlug, String pageSlug) {
    Team team = teamService.getTeam(teamSlug);
    TeamPage page = findBySlugIncludeDeleted(team, pageSlug);
    page.setDeleted(false);
    teamPageRepository.persist(page);
    return TeamPageDto.from(page, assetService, detailPermissions(page));
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TEAM_PAGE, action = ActionType.CREATE)
  public List<TeamPageSummaryDto> reorderPages(String teamSlug, ReorderPagesRequest request) {
    Team team = teamService.getTeam(teamSlug);
    List<String> pageIds = request.pageIds();
    for (int i = 0; i < pageIds.size(); i++) {
      Long pageId = TsidUtils.toLong(pageIds.get(i));
      Optional<TeamPage> pageOptional = teamPageRepository.findByIdOptional(pageId);
      if (pageOptional.isPresent()) {
        TeamPage page = pageOptional.get();
        if (!page.getTeam().getId().equals(team.getId()) || page.isAboutPage()) {
          throw new BusinessException(ErrorCode.UNKNOWN);
        }
        page.setPageOrder(i);
        teamPageRepository.persist(page);
      } else {
        throw new NotFoundException(EntityType.TEAM_PAGE, pageId);
      }
    }

    return listPages(teamSlug);
  }
}
