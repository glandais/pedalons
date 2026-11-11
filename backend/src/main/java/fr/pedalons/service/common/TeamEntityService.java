package fr.pedalons.service.common;

import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ConflictException;
import fr.pedalons.common.exception.ForbiddenException;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.common.TeamEntitySlugRedirect;
import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.common.request.WithVisibility;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.infrastructure.exception.*;
import fr.pedalons.repository.common.TeamEntityRepository;
import fr.pedalons.repository.moderation.ContentReportRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.team.TeamService;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.validation.Valid;
import java.util.Optional;
import org.jboss.logging.Logger;

public abstract class TeamEntityService<
    T extends TeamEntity, R extends TeamEntityRepository<T, ?>, D> {

  private static final Logger LOG = Logger.getLogger(TeamEntityService.class);

  @Inject protected AssetService assetService;

  @Inject protected SlugService slugService;

  @Inject protected TeamService teamService;

  @Inject protected PedalonsQueryContext pedalonsContext;

  @Inject protected IncludeDeletedService includeDeletedService;

  @Inject protected ContentReportRepository contentReportRepository;

  @Inject protected ContentVisibilityRules contentVisibilityRules;

  protected abstract R getRepository();

  protected abstract D toDto(T entity);

  protected D getDto(Team team, String entitySlug) {
    T entity = findBySlug(team, entitySlug);
    return toDto(entity);
  }

  protected void updateMedia(TeamEntity teamEntity, @Valid MediaDto mediaDto) {
    assetService.updateAssets(teamEntity, mediaDto);
  }

  /**
   * Refuses a visibility the team does not accept for this kind of entity — the single rule of
   * {@link ContentVisibilityRules} (docs/LEDGER_*.md API-176).
   */
  protected void validateVisibility(Team team, WithVisibility request) {
    contentVisibilityRules.requireAllowed(
        team, getRepository().getAllEntityType(), request.visibility());
  }

  protected T findBySlug(Team team, String entitySlug) {
    Long domainId = pedalonsContext.getDomainId();
    Long userId = pedalonsContext.getUserIdNullable();
    boolean includeDeleted = isIncludeDeleted(team);
    boolean platformAdmin = isPlatformAdmin();
    Optional<T> byTeamAndSlug =
        getRepository()
            .findByTeamAndSlug(
                domainId, team.getId(), userId, entitySlug, includeDeleted, platformAdmin);
    return byTeamAndSlug.orElseGet(() ->
        slugService
            .resolveEntityRedirect(team.getId(), getRepository().getEntityType(), entitySlug)
            .map(TeamEntitySlugRedirect::getEntityId)
            .flatMap(id ->
                getRepository()
                    .findByTeamAndId(
                        domainId, team.getId(), userId, id, includeDeleted, platformAdmin))
            .orElseThrow(
                () -> new NotFoundException(getRepository().getAllEntityType(), entitySlug)));
  }

  protected T findBySlugIncludeDeleted(Team team, String entitySlug) {
    Long domainId = pedalonsContext.getDomainId();
    Long userId = pedalonsContext.getUserIdNullable();
    Optional<T> byTeamAndSlug =
        getRepository().findByTeamAndSlug(domainId, team.getId(), userId, entitySlug, true, false);
    return byTeamAndSlug.orElseGet(() ->
        slugService
            .resolveEntityRedirect(team.getId(), getRepository().getEntityType(), entitySlug)
            .map(TeamEntitySlugRedirect::getEntityId)
            .flatMap(id ->
                getRepository().findByTeamAndId(domainId, team.getId(), userId, id, true, false))
            .orElseThrow(
                () -> new NotFoundException(getRepository().getAllEntityType(), entitySlug)));
  }

  /**
   * Refuses to undelete a publication that a moderator removed from the reports queue. Such a removal
   * is the same soft delete as the author's, but it is a decision on the reports: letting the
   * {@code undelete*} of the services undo it would let a team administrator put their own reported
   * content back, reports still closed. Only a platform administrator may reverse it.
   */
  protected void requireNotRemovedByModeration(T entity) {
    if (!isPlatformAdmin() && contentReportRepository.isRemovedByModeration(entity.getId())) {
      throw new ForbiddenException();
    }
  }

  protected boolean isIncludeDeleted(Team team) {
    return includeDeletedService.isTeamEntityIncludeDeleted(team);
  }

  protected boolean isPlatformAdmin() {
    return pedalonsContext.isPlatformAdmin();
  }

  @Transactional
  protected D updateSlug(Team team, String slug, String newSlug) {
    T entity = findBySlug(team, slug);

    String oldSlug = entity.getSlug();

    if (!slugService.isValidSlug(newSlug)) {
      throw new BusinessException(ErrorCode.INVALID_SLUG);
    }

    if (oldSlug.equals(newSlug)) {
      return toDto(entity);
    }

    // A reserved slug is well-formed but permanently unavailable — same "taken" shape as a
    // genuine uniqueness conflict, see SlugService.isReservedSlug.
    if (slugService.isReservedSlug(getRepository().getEntityType(), newSlug)
        || getRepository().existsByTeamAndSlug(entity.getTeam().getId(), newSlug)) {
      throw new ConflictException(ErrorCode.SLUG_TAKEN);
    }

    slugService.clearEntityRedirect(
        entity.getTeam().getId(), getRepository().getEntityType(), newSlug);
    slugService.createEntityRedirect(entity, oldSlug);

    entity.setSlug(newSlug);
    getRepository().persist(entity);

    LOG.infov(
        "Slug changed from {0} to {1} by user {2}",
        oldSlug, newSlug, pedalonsContext.getUserIdNullable());
    return toDto(entity);
  }
}
