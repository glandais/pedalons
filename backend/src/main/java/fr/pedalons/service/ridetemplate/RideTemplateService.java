package fr.pedalons.service.ridetemplate;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.ridetemplate.RideTemplate;
import fr.pedalons.domain.ridetemplate.RideTemplateGroup;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.ridetemplates.request.RideTemplateGroupRequest;
import fr.pedalons.dto.ridetemplates.request.RideTemplateRequest;
import fr.pedalons.dto.ridetemplates.response.RideTemplateDto;
import fr.pedalons.dto.ridetemplates.response.RideTemplateListResponse;
import fr.pedalons.dto.tags.response.ContentTags;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.exception.NotFoundException;
import fr.pedalons.repository.ridetemplate.RideTemplateGroupRepository;
import fr.pedalons.repository.ridetemplate.RideTemplateRepository;
import fr.pedalons.service.common.SlugService;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.tag.TagLookup;
import fr.pedalons.service.tag.TagService;
import fr.pedalons.service.team.TeamService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class RideTemplateService {

  @Inject RideTemplateRepository templateRepository;

  @Inject RideTemplateGroupRepository groupRepository;

  @Inject SlugService slugService;

  @Inject PedalonsQueryContext pedalonsContext;

  @Inject TeamService teamService;

  @Inject TagService tagService;

  @Inject TagLookup tagLookup;

  @CheckAccess(entityType = EntityType.RIDE_TEMPLATE, action = ActionType.LIST)
  public RideTemplateListResponse listTemplates(
      String teamSlug, @Nullable String search, int page, int size) {
    Team team = teamService.getTeam(teamSlug);
    PedalonsPage<RideTemplate> templates =
        templateRepository.findByTeam(team.getId(), search, page, size);
    // One query for the tags of the whole page, none for an empty one.
    ContentTags tags =
        tagLookup.forTemplates(templates.items().stream().map(RideTemplate::getId).toList());
    var dtos = templates.items().stream().map(t -> RideTemplateDto.from(t, tags)).toList();
    return new RideTemplateListResponse(dtos, templates.total(), page, size);
  }

  @CheckAccess(entityType = EntityType.RIDE_TEMPLATE, action = ActionType.READ)
  public RideTemplateDto getTemplate(String teamSlug, String templateSlug) {
    Team team = teamService.getTeam(teamSlug);
    RideTemplate template =
        templateRepository
            .findByTeamAndSlug(team.getId(), templateSlug)
            .orElseThrow(() -> new NotFoundException(EntityType.RIDE_TEMPLATE, templateSlug));

    return toDto(template);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.RIDE_TEMPLATE, action = ActionType.CREATE)
  public RideTemplateDto createTemplate(String teamSlug, RideTemplateRequest request) {
    Team team = teamService.getTeam(teamSlug);
    User creator = pedalonsContext.getUser();
    // Validate visibility: private teams can only have team-only templates
    Visibility visibility = request.visibility();
    if (team.getVisibility() == Visibility.TEAM && visibility != Visibility.TEAM) {
      throw new BusinessException(ErrorCode.INVALID_VISIBILITY);
    }

    // Generate slug from name, ensure unique within team. RideTemplate is a plain BaseEntity, not
    // a TeamEntity, so it has no TeamEntityType and can never be a SlugService.RESERVED_SLUGS key
    // — the reserved-slug check the TeamEntityType-aware overload adds does not apply here.
    Long teamId = team.getId();
    String slug =
        slugService.generateSlug(
            request.name(), s -> templateRepository.existsByTeamAndSlug(teamId, s));

    RideTemplate template =
        new RideTemplate(
            creator, team, request.name(), slug, request.markdown(), visibility, request.status());
    template.setNextNumber(request.nextNumber());

    templateRepository.persistAndFlush(template);

    int sortOrder = 0;
    for (RideTemplateGroupRequest groupRequest : request.groups()) {
      createTemplateGroup(creator, template, groupRequest, sortOrder);
      sortOrder++;
    }
    tagService.replaceTemplateTags(template, request.tagIds());

    return toDto(template);
  }

  private void createTemplateGroup(
      User user, RideTemplate template, RideTemplateGroupRequest groupRequest, int sortOrder) {
    RideTemplateGroup group = new RideTemplateGroup(user, template, groupRequest.name());
    group.setTime(groupRequest.time());
    group.setAverageSpeed(groupRequest.averageSpeed());
    group.setMaxParticipants(groupRequest.maxParticipants());
    group.setSortOrder(sortOrder);
    template.addGroup(group);
    groupRepository.persist(group);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.RIDE_TEMPLATE, action = ActionType.UPDATE)
  public RideTemplateDto updateTemplate(
      String teamSlug, String templateSlug, RideTemplateRequest request) {
    Team team = teamService.getTeam(teamSlug);
    User user = pedalonsContext.getUser();
    RideTemplate template =
        templateRepository
            .findByTeamAndSlug(team.getId(), templateSlug)
            .orElseThrow(() -> new NotFoundException(EntityType.RIDE_TEMPLATE, templateSlug));

    // Validate visibility: private teams can only have team-only templates
    if (team.getVisibility() == Visibility.TEAM && request.visibility() != Visibility.TEAM) {
      throw new BusinessException(ErrorCode.INVALID_VISIBILITY);
    }

    template.setName(request.name());
    template.setMarkdown(request.markdown());
    template.setVisibility(request.visibility());
    template.setStatus(request.status());
    template.setNextNumber(request.nextNumber());

    // Update groups - clear and re-add existing or create new
    Map<Long, RideTemplateGroup> existingGroups =
        template.getGroups().stream()
            .collect(Collectors.toMap(RideTemplateGroup::getId, Function.identity()));

    template.getGroups().clear();

    int sortOrder = 0;
    for (RideTemplateGroupRequest groupRequest : request.groups()) {
      Long groupId = TsidUtils.toLongNullable(groupRequest.id());
      if (groupId == null) {
        createTemplateGroup(user, template, groupRequest, sortOrder);
      } else {
        RideTemplateGroup existingGroup = existingGroups.remove(groupId);
        if (existingGroup != null) {
          existingGroup.setName(groupRequest.name());
          existingGroup.setTime(groupRequest.time());
          existingGroup.setAverageSpeed(groupRequest.averageSpeed());
          existingGroup.setMaxParticipants(groupRequest.maxParticipants());
          existingGroup.setSortOrder(sortOrder);
          template.getGroups().add(existingGroup);
        } else {
          throw new NotFoundException(EntityType.RIDE_TEMPLATE_GROUP, groupRequest.id());
        }
      }
      sortOrder++;
    }

    tagService.replaceTemplateTags(template, request.tagIds());
    templateRepository.persist(template);

    return toDto(template);
  }

  private RideTemplateDto toDto(RideTemplate template) {
    return RideTemplateDto.from(template, tagLookup.forTemplates(List.of(template.getId())));
  }

  @Transactional
  @CheckAccess(entityType = EntityType.RIDE_TEMPLATE, action = ActionType.DELETE)
  public void deleteTemplate(String teamSlug, String templateSlug) {
    Team team = teamService.getTeam(teamSlug);
    RideTemplate template =
        templateRepository
            .findByTeamAndSlug(team.getId(), templateSlug)
            .orElseThrow(() -> new NotFoundException(EntityType.RIDE_TEMPLATE, templateSlug));
    templateRepository.delete(template);
  }
}
