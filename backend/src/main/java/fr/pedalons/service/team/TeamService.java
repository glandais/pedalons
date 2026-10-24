package fr.pedalons.service.team;

import static fr.pedalons.dto.error.ErrorCode.*;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.ConflictException;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.TeamSlugRedirect;
import fr.pedalons.domain.team.UserTeam;
import fr.pedalons.domain.trip.Trip;
import fr.pedalons.domain.trip.TripStage;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.common.PedalonsPage;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.dto.teams.request.TeamRequest;
import fr.pedalons.dto.teams.response.MemberCountByRoleDto;
import fr.pedalons.dto.teams.response.TeamDetailDto;
import fr.pedalons.dto.teams.response.TeamListResponse;
import fr.pedalons.dto.teams.response.TeamTimezoneChangeItemDto;
import fr.pedalons.dto.teams.response.TeamTimezoneChangePreviewDto;
import fr.pedalons.dto.teams.response.TeamTimezoneDto;
import fr.pedalons.dto.teams.response.TimezoneChangeEntityType;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.SortDirection;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.TeamSortBy;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.exception.*;
import fr.pedalons.repository.migration.BiketeamMigrationMapRepository;
import fr.pedalons.repository.team.TeamQuery;
import fr.pedalons.repository.team.TeamRepository;
import fr.pedalons.repository.team.TeamStatsRepository;
import fr.pedalons.repository.team.UserTeamRepository;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.common.SlugService;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.team.request.MinRole;
import fr.pedalons.service.team.response.TeamAndRole;
import fr.pedalons.service.team.response.TeamStats;
import fr.pedalons.service.timezone.EventTimezoneResolver;
import fr.pedalons.service.timezone.TeamTimezoneChange;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class TeamService {

  private static final int MAX_ADMIN_TEAMS_PER_USER = 1;

  @Inject UserTeamRepository userTeamRepository;

  @Inject BiketeamMigrationMapRepository biketeamMigrationMapRepository;

  @Inject protected TeamRepository teamRepository;

  @Inject TeamStatsRepository teamStatsRepository;

  @Inject protected AssetService assetService;

  @Inject protected SlugService slugService;

  @Inject PedalonsQueryContext pedalonsContext;

  @Inject EntityManager em;

  @Inject EventTimezoneResolver eventTimezoneResolver;

  @Inject TeamTimezoneChange teamTimezoneChange;

  /**
   * Resolves a team by slug.
   *
   * <p>Deliberately NOT memoized per request, even though a team-scoped endpoint resolves the same
   * slug two or three times (the {@code @CheckAccess} interceptor, then the service method). Caching
   * it broke two invariants the tests pin down: {@link #requirePinnedTeam} is an authorization guard
   * that must run on every resolution, not just the first, and a team mutated through a different
   * transaction mid-request (see {@code TripServiceTest.shouldThrowOnLeaveWhenTripsDisabled}) must
   * be re-read rather than served stale. One extra indexed SELECT is the cheaper trade.
   */
  public Team getTeam(String teamSlug) {
    Long domainId = pedalonsContext.getDomainId();
    Team team =
        teamRepository
            .findBySlugAndDomain(domainId, teamSlug)
            .or(
                () ->
                    slugService
                        .resolveTeamRedirect(domainId, teamSlug)
                        .map(TeamSlugRedirect::getTeam))
            .orElseThrow(() -> new NotFoundException(EntityType.TEAM, teamSlug));
    // A pinned alias host serves only its team; every other team of the parent domain is invisible,
    // even after a slug redirect. Checked here so all team-scoped endpoints inherit it.
    requirePinnedTeam(team.getId(), () -> new NotFoundException(EntityType.TEAM, teamSlug));
    return team;
  }

  protected TeamAndRole getTeamAndRole(Long id) {
    boolean platformAdmin = isPlatformAdmin();
    requirePinnedTeam(id, () -> new NotFoundException(EntityType.TEAM, id));
    return teamRepository
        .findOne(
            pedalonsContext.getDomainId(), id, pedalonsContext.getUserIdNullable(), platformAdmin)
        .orElseThrow(() -> new NotFoundException(EntityType.TEAM, id));
  }

  private void requirePinnedTeam(Long teamId, Supplier<RuntimeException> notFound) {
    Long pinnedTeamId = pedalonsContext.getPinnedTeamIdNullable();
    if (pinnedTeamId != null && !pinnedTeamId.equals(teamId)) {
      throw notFound.get();
    }
  }

  private boolean isPlatformAdmin() {
    return pedalonsContext.isPlatformAdmin();
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.CREATE)
  public TeamDetailDto createTeam(TeamRequest request) {
    Domain domain = pedalonsContext.getDomain();
    if (domain.isSingleTeam() && teamRepository.existsByDomain(domain.getId())) {
      throw new BusinessException(TEAM_CREATION_DISABLED);
    }
    User creator = pedalonsContext.getUser();
    Long domainId = domain.getId();
    if (!creator.isPlatformAdmin()) {
      long existingAdminTeams =
          userTeamRepository.countAdminTeamsByUserAndDomain(creator.getId(), domainId);
      if (existingAdminTeams >= MAX_ADMIN_TEAMS_PER_USER) {
        throw new BusinessException(USER_TEAM_LIMIT_REACHED);
      }
    }
    String slug =
        slugService.generateSlug(
            request.name(),
            s ->
                teamRepository.existsBySlugAndDomain(domainId, s)
                    || slugService.isReservedTeamSlug(s));
    slugService.clearTeamRedirect(domainId, slug);

    if (request.visibility() != Visibility.TEAM) {
      throw new BusinessException(INVALID_VISIBILITY);
    }
    Team team = new Team(domain, creator, request.name(), slug, Visibility.TEAM);
    team.setVisibilityEditable(false);
    team.setJoinable(false);
    team.setAddMemberAllowed(false);
    applyFeatureFlags(team, request);
    team.setGeometry(request.geometry());
    String timezone = request.timezone();
    if (timezone != null) {
      team.setTimezone(validZone(timezone).getId());
      // Built by the constructor, with the default zone.
      team.getAboutPage().setTimezone(team.getTimezone());
    }

    teamRepository.persistAndFlush(team);
    assetService.updateAssets(team.getAboutPage(), request.media());
    teamRepository.persist(team);

    UserTeam membership = new UserTeam(creator, creator, team, TeamRole.ADMIN);
    userTeamRepository.persist(membership);

    return TeamDetailDto.from(new TeamAndRole(team, TeamRole.ADMIN, 1L), assetService, false);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.LIST)
  public TeamListResponse listTeams(
      @Nullable MinRole minRole, @Nullable String search, int page, int size) {
    return listTeams(minRole, search, null, null, null, page, size);
  }

  /**
   * @param joinable restricts to teams that do (or do not) accept join requests — the "discover a
   *     team" screen. Null keeps both.
   * @param sortBy null keeps the name order; the team id always ends the key
   */
  @Transactional
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.LIST)
  public TeamListResponse listTeams(
      @Nullable MinRole minRole,
      @Nullable String search,
      @Nullable Boolean joinable,
      @Nullable TeamSortBy sortBy,
      @Nullable SortDirection sortDir,
      int page,
      int size) {
    // A platform admin's directory of every team is the plain listing; "my teams" (minRole) and
    // discovery (joinable) are personal views and apply the real membership (docs/LEDGER_*.md
    // API-137).
    boolean allTeams = isPlatformAdmin() && minRole == null && joinable == null;
    PedalonsPage<TeamAndRole> teams =
        teamRepository.find(
            TeamQuery.builder()
                .domainId(pedalonsContext.getDomainId())
                .pinnedTeamId(pedalonsContext.getPinnedTeamIdNullable())
                .userId(pedalonsContext.getUserIdNullable())
                .minRole(minRole)
                .search(search)
                .joinable(joinable)
                .sortBy(sortBy)
                .sortDir(sortDir)
                .page(page)
                .size(size)
                .platformAdmin(allTeams)
                .build());
    // A team card counts what the caller's real role shows: explicit, since a one-row page would
    // otherwise be a team-scoped query, where the platform admin's bypass applies.
    Map<Long, TeamStats> stats =
        loadStats(teams.items().stream().map(t -> t.team().getId()).toList(), false);
    List<TeamDetailDto> dtos =
        teams.items().stream()
            .map(
                teamAndRole ->
                    TeamDetailDto.from(
                        teamAndRole,
                        assetService,
                        false,
                        stats.getOrDefault(teamAndRole.team().getId(), TeamStats.EMPTY)))
            .toList();
    return new TeamListResponse(dtos, teams.total(), page, size);
  }

  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.READ)
  public TeamDetailDto getTeamDetailDto(String teamSlug) {
    Team team = getTeam(teamSlug);
    TeamAndRole teamAndRole = getTeamAndRole(team.getId());
    boolean platformAdmin = isPlatformAdmin();
    // The header of a team the caller opened: a platform admin counts what its lists show them.
    TeamStats stats =
        loadStats(List.of(team.getId()), platformAdmin).getOrDefault(team.getId(), TeamStats.EMPTY);
    // The split per role is the administration panel's: one more query, for administrators only.
    boolean admin =
        platformAdmin || (teamAndRole.teamRole() != null && teamAndRole.teamRole().isAdmin());
    MemberCountByRoleDto memberCountByRole =
        admin
            ? MemberCountByRoleDto.from(teamStatsRepository.countMembersByRole(team.getId()))
            : null;
    return TeamDetailDto.from(teamAndRole, assetService, platformAdmin, stats, memberCountByRole);
  }

  /**
   * Content counters for a whole page of teams: two queries, whatever the page size.
   *
   * <p>The obvious implementation — ask each team for its rides and its routes — is two queries per
   * row, and it is the reason this indirection exists at all.
   */
  private Map<Long, TeamStats> loadStats(List<Long> teamIds, boolean platformAdmin) {
    return teamStatsRepository.load(
        teamIds,
        pedalonsContext.getDomainId(),
        pedalonsContext.getUserIdNullable(),
        pedalonsContext.getPinnedTeamIdNullable(),
        platformAdmin);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.UPDATE)
  public TeamDetailDto updateTeam(String teamSlug, TeamRequest request) {
    Team team = getTeam(teamSlug);

    team.setName(request.name());
    boolean isPlatformAdmin = isPlatformAdmin();
    if (team.isVisibilityEditable() || isPlatformAdmin) {
      if (team.getVisibility() != Visibility.TEAM && request.visibility() == Visibility.TEAM) {
        makeContentTeamOnly(team);
      }
      team.setVisibility(request.visibility());
    } else if (request.visibility() != team.getVisibility()) {
      throw new BusinessException(INVALID_VISIBILITY);
    }
    applyFeatureFlags(team, request);
    team.setGeometry(request.geometry());
    String timezone = request.timezone();
    if (timezone != null) {
      changeTimezone(team, validZone(timezone));
    }
    assetService.updateAssets(team.getAboutPage(), request.media());

    teamRepository.persist(team);
    return getTeamDetailDto(teamSlug);
  }

  /**
   * A new zone for the team, and for its upcoming content that no place locates, at constant wall
   * time (plan §9). The team's own pages, ads and routes follow at their next save: their dates
   * are timestamps, not rendezvous (docs/LEDGER_*.md API-60).
   */
  private void changeTimezone(Team team, ZoneId zone) {
    ZoneId previous = EventTimezoneResolver.teamZone(team);
    if (previous.equals(zone)) {
      return;
    }
    // Before the team's zone moves: an entity without a stored zone reads the team's.
    teamTimezoneChange.apply(team, previous, zone);
    team.setTimezone(zone.getId());
  }

  /**
   * What {@link #changeTimezone} would rewrite for {@code timezone}, without writing anything: the
   * settings screen shows it before the admin confirms (docs/LEDGER_*.md API-60, plan §9). Shares
   * {@link TeamTimezoneChange#plan} with the change itself, so that the two cannot diverge.
   */
  @Transactional
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.UPDATE)
  public TeamTimezoneChangePreviewDto previewTimezoneChange(String teamSlug, String timezone) {
    Team team = getTeam(teamSlug);
    ZoneId from = EventTimezoneResolver.teamZone(team);
    ZoneId to = validZone(timezone);
    Instant now = Instant.now();
    List<TeamEntity> plan = teamTimezoneChange.plan(team, from, to);
    List<TeamEntity> upcoming =
        plan.stream()
            .filter(entity -> !entity.getDateTime().isBefore(now))
            .sorted(Comparator.comparing(TeamEntity::getDateTime))
            .toList();
    return new TeamTimezoneChangePreviewDto(
        from.getId(),
        to.getId(),
        upcoming.size(),
        plan.size() - upcoming.size(),
        upcoming.stream()
            .limit(TeamTimezoneChangePreviewDto.MAX_ITEMS)
            .map(TeamService::previewItem)
            .toList());
  }

  private static TeamTimezoneChangeItemDto previewItem(TeamEntity entity) {
    TimezoneChangeEntityType type =
        switch (entity) {
          case Ride ignored -> TimezoneChangeEntityType.RIDE;
          case TripStage ignored -> TimezoneChangeEntityType.TRIP_STAGE;
          case Trip ignored -> TimezoneChangeEntityType.TRIP;
          default -> TimezoneChangeEntityType.POST;
        };
    String tripTitle = entity instanceof TripStage stage ? stage.getTrip().getName() : null;
    return new TeamTimezoneChangeItemDto(
        type,
        TsidUtils.toString(entity.getId()),
        entity.getSlug(),
        entity.getName(),
        tripTitle,
        entity.getDateTime());
  }

  private static ZoneId validZone(String timezone) {
    try {
      return ZoneId.of(timezone);
    } catch (DateTimeException e) {
      throw new BadRequestException(ErrorCode.INVALID_TIMEZONE, e);
    }
  }

  /**
   * The zone of a point for the team's editors, else the team's: what the editors label their
   * date fields with while a start place or a route is being chosen (docs/LEDGER_*.md API-60). The
   * same rule as a saved entity, which is resolved by the backend alone.
   */
  @CheckAccess(entityType = EntityType.PLACE, action = ActionType.LIST)
  public TeamTimezoneDto getTimezone(String teamSlug, @Nullable Double lat, @Nullable Double lon) {
    Team team = getTeam(teamSlug);
    if (lat == null || lon == null) {
      return new TeamTimezoneDto(EventTimezoneResolver.teamZone(team).getId());
    }
    return new TeamTimezoneDto(
        eventTimezoneResolver
            .locate(lat, lon)
            .orElseGet(() -> EventTimezoneResolver.teamZone(team))
            .getId());
  }

  /**
   * A team going private takes its content with it. A private team only accepts team-only content
   * (see {@code validateVisibility}): left public, a ride would stay listed and indexed as public
   * content of a team nobody can open, and could no longer be saved as it is — every edit would be
   * refused until someone changed its visibility by hand. Deleted content too, so that restoring it
   * does not bring it back public. The reverse move changes nothing: making content public is a
   * decision per item.
   */
  private void makeContentTeamOnly(Team team) {
    for (String entity : List.of("TeamEntity", "RideTemplate")) {
      em.createQuery(
              "update "
                  + entity
                  + " e set e.visibility = :team where e.team.id = :teamId"
                  + " and e.visibility <> :team")
          .setParameter("team", Visibility.TEAM)
          .setParameter("teamId", team.getId())
          .executeUpdate();
    }
    // A managed entity the bulk update bypassed: brought in line so no later flush writes it back.
    team.getAboutPage().setVisibility(Visibility.TEAM);
  }

  /** The modules a team opts into — the same on creation as on every later edit. */
  private static void applyFeatureFlags(Team team, TeamRequest request) {
    team.setEnableTrips(request.enableTrips());
    team.setEnableAds(request.enableAds());
    team.setEnablePosts(request.enablePosts());
    team.setEnableRides(request.enableRides());
    team.setEnableRoutes(request.enableRoutes());
    team.setEnableMemberDirectory(request.enableMemberDirectory());
    if (request.postsAsTeamByDefault() != null) {
      team.setPostsAsTeamByDefault(request.postsAsTeamByDefault());
    }
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.DELETE)
  public void deleteTeam(String teamSlug) {
    delete(getTeam(teamSlug));
  }

  /**
   * Deletes a team the caller has already resolved and authorized — the one deletion shared by
   * {@code DELETE /teams/{slug}} and the erasure of an account that was alone in its teams. A soft
   * delete: the team and everything it holds stay in the database, invisible.
   *
   * <p>Takes the entity, not a slug: the erasure spans the whole domain, and {@link #getTeam} would
   * refuse any team but the pinned one on a pinned alias host.
   *
   * <p><b>Refused for a team migrated from biketeam</b>, whoever asks, platform admins included:
   * biketeam redirects the team's old addresses here and would send them to a 404. The way out is
   * cancelling the switch-over on biketeam, whose reset trashes the team itself — it does not come
   * through here (docs/LEDGER_*.md MIG-5).
   *
   * @throws BusinessException {@code MIGRATED_TEAM} for a migrated team
   */
  @Transactional
  public void delete(Team team) {
    if (biketeamMigrationMapRepository.isMigratedTeam(team.getId())) {
      throw new BusinessException(MIGRATED_TEAM);
    }
    team.setDeleted(true);
    teamRepository.persist(team);
  }

  @Transactional
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.UPDATE)
  public TeamDetailDto updateSlug(String teamSlug, String newSlug) {
    Long domainId = pedalonsContext.getDomainId();
    Team team = getTeam(teamSlug);
    String currentSlug = team.getSlug();
    // Validate new slug format
    if (!slugService.isValidSlug(newSlug)) {
      throw new BusinessException(INVALID_SLUG);
    }

    // No change needed
    if (currentSlug.equals(newSlug)) {
      return getTeamDetailDto(teamSlug);
    }

    // Check if new slug is already taken in this domain, deleted teams included — or by a web page
    if (teamRepository.existsBySlugAndDomain(domainId, newSlug)
        || slugService.isReservedTeamSlug(newSlug)) {
      throw new ConflictException(SLUG_TAKEN);
    }

    // Clear any existing redirect TO this new slug (reuse scenario)
    slugService.clearTeamRedirect(domainId, newSlug);

    // Create redirect from old slug to this team
    slugService.createTeamRedirect(team, currentSlug);

    // Update the slug
    team.setSlug(newSlug);
    teamRepository.persist(team);

    return getTeamDetailDto(teamSlug);
  }
}
