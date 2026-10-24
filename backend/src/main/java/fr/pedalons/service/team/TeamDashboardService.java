package fr.pedalons.service.team;

import fr.pedalons.domain.team.Team;
import fr.pedalons.dto.ads.request.AdSearchParams;
import fr.pedalons.dto.ads.response.AdListResponse;
import fr.pedalons.dto.dashboard.response.TeamDashboardAdminDto;
import fr.pedalons.dto.dashboard.response.TeamDashboardDto;
import fr.pedalons.dto.dashboard.response.TeamDashboardOrganizerDto;
import fr.pedalons.dto.publications.response.PublicationListResponse;
import fr.pedalons.dto.publications.response.PublicationType;
import fr.pedalons.dto.ridetemplates.response.RideTemplateListResponse;
import fr.pedalons.dto.routes.response.RouteListResponse;
import fr.pedalons.dto.teams.response.TeamDetailDto;
import fr.pedalons.enums.ActionType;
import fr.pedalons.enums.EntityType;
import fr.pedalons.enums.ListViewMode;
import fr.pedalons.enums.MemberSortBy;
import fr.pedalons.enums.SortDirection;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.service.ad.AdService;
import fr.pedalons.service.common.PublicationService;
import fr.pedalons.service.moderation.ModerationService;
import fr.pedalons.service.notification.TeamWebhookService;
import fr.pedalons.service.ridetemplate.RideTemplateService;
import fr.pedalons.service.route.RouteService;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.CheckAccess;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Instant;
import org.jspecify.annotations.Nullable;

/**
 * A team's « Tableau de bord »: every section a member, an organizer or an administrator sees on
 * it, in one response.
 *
 * <p>Nothing is computed here that a list endpoint does not already compute: each section is a short
 * page of an existing listing, built by its own service with its own per-page lookups. The cost of
 * the dashboard is therefore a fixed number of queries per section, whatever the rows hold ({@code
 * TeamDashboardQueryCountTest}) — and a section shows exactly the rows its « Voir tout » opens.
 *
 * <p>A visitor — anonymous, or signed in without belonging to the team — gets the public part
 * (docs/LEDGER_*.md API-86): upcoming rides, latest posts, new routes, built by the very same
 * queries, so the same visibility rules apply row by row (a {@code TEAM} entity, a draft, an
 * unlisted entity never reaches them) and a {@code TEAM} team stays closed ({@code @CheckAccess}
 * TEAM READ, the rule of {@code GET /api/teams/{teamSlug}}). What belongs to members only — their
 * registrations, the ads, the organizer and admin blocks — is not built at all for a visitor,
 * rather than built and emptied.
 *
 * <p>Two departures from the plain listings, both deliberate: deleted content is left out even for
 * an administrator (the team lists show it to them, a dashboard is not where it gets restored), and
 * every row is {@link ListViewMode#COMPACT}.
 */
@ApplicationScoped
public class TeamDashboardService {

  /** « Vos prochaines sorties ». */
  static final int MY_UPCOMING_SIZE = 3;

  /** « Sorties à venir ». */
  static final int UPCOMING_RIDES_SIZE = 3;

  /** « Dernières publications », « Nouveaux parcours », « Annonces ». */
  static final int LATEST_SIZE = 3;

  /** The « À traiter » tiles and the templates panel: a figure and the first few names. */
  static final int TILE_SIZE = 5;

  /** « Nouveaux membres » of the administration panel. */
  static final int NEWEST_MEMBERS_SIZE = 3;

  @Inject PedalonsQueryContext pedalonsContext;
  @Inject TeamService teamService;
  @Inject TeamMembershipService membershipService;
  @Inject PublicationService publicationService;
  @Inject RouteService routeService;
  @Inject AdService adService;
  @Inject RideTemplateService rideTemplateService;
  @Inject ModerationService moderationService;
  @Inject TeamWebhookService teamWebhookService;

  /**
   * The dashboard of one team for the current caller, member or visitor.
   *
   * <p>{@code @CheckAccess} TEAM READ: anyone may read a team that is not {@code TEAM}-only, only
   * its members one that is — a 403 otherwise, as for the team itself.
   */
  @CheckAccess(entityType = EntityType.TEAM, action = ActionType.READ)
  @Transactional
  public TeamDashboardDto getDashboard(String teamSlug) {
    Team team = teamService.getTeam(teamSlug);
    // The caller's real role, null for a visitor — a platform admin included (docs/LEDGER_*.md
    // API-137): the member-only sections stay a member's, while the organizer and admin blocks
    // follow the platform admin's rights.
    @Nullable TeamRole role = pedalonsContext.getContext(team).teamRole();
    boolean platformAdmin = pedalonsContext.isPlatformAdmin();
    boolean member = role != null;
    TeamDetailDto detail = teamService.getTeamDetailDto(teamSlug);
    Instant now = Instant.now();

    // The same module rules as the publication query: a ride or a trip needs routes too.
    boolean rides = team.isEnableRides() && team.isEnableRoutes();
    boolean trips = team.isEnableTrips() && team.isEnableRoutes();

    // Members only: a visitor has no registrations, and the ads tab is offered to members only.
    PublicationListResponse myUpcoming =
        member && (rides || trips)
            ? publicationService.listTeamSection(
                team, MY_UPCOMING_SIZE, q -> q.participating(true).notEndedAt(now).ascending(true))
            : null;
    PublicationListResponse upcomingRides = rides ? upcomingRides(team, now, false, false) : null;
    PublicationListResponse latestPosts =
        team.isEnablePosts()
            ? publicationService.listTeamSection(
                team, LATEST_SIZE, q -> q.type(PublicationType.POST).status(Status.PUBLISHED))
            : null;
    RouteListResponse newRoutes =
        team.isEnableRoutes() ? routeService.listTeamSection(team, LATEST_SIZE) : null;
    AdListResponse latestAds =
        member && team.isEnableAds()
            ? adService.listAds(
                teamSlug, AdSearchParams.builder().build(), ListViewMode.COMPACT, 0, LATEST_SIZE)
            : null;

    TeamDashboardOrganizerDto organizer =
        platformAdmin || (role != null && role.isOrganizer())
            ? organizer(team, teamSlug, rides, now)
            : null;
    TeamDashboardAdminDto admin =
        platformAdmin || (role != null && role.isAdmin()) ? admin(teamSlug) : null;

    return new TeamDashboardDto(
        detail,
        role,
        myUpcoming,
        upcomingRides,
        latestPosts,
        newRoutes,
        latestAds,
        organizer,
        admin);
  }

  private TeamDashboardOrganizerDto organizer(
      Team team, String teamSlug, boolean rides, Instant now) {
    PublicationListResponse drafts =
        publicationService.listTeamSection(team, TILE_SIZE, q -> q.status(Status.DRAFT));
    RideTemplateListResponse templates =
        rides ? rideTemplateService.listTemplates(teamSlug, null, 0, TILE_SIZE) : null;
    return new TeamDashboardOrganizerDto(
        drafts,
        rides ? upcomingRides(team, now, true, false) : null,
        rides ? upcomingRides(team, now, false, true) : null,
        moderationService.teamOpenSummary(team),
        templates);
  }

  /**
   * The team's published rides not over yet — one under way stays (docs/LEDGER_*.md API-85) —
   * soonest first: all of them, or only those routed
   * nowhere, or only those with a full group.
   */
  private PublicationListResponse upcomingRides(
      Team team, Instant now, boolean withoutRoute, boolean withFullGroup) {
    return publicationService.listTeamSection(
        team,
        withoutRoute || withFullGroup ? TILE_SIZE : UPCOMING_RIDES_SIZE,
        q ->
            q.type(PublicationType.RIDE)
                .status(Status.PUBLISHED)
                .notEndedAt(now)
                .withoutRoute(withoutRoute)
                .withFullGroup(withFullGroup)
                .ascending(true));
  }

  private TeamDashboardAdminDto admin(String teamSlug) {
    return new TeamDashboardAdminDto(
        membershipService.getTeamMembers(
            teamSlug,
            0,
            NEWEST_MEMBERS_SIZE,
            null,
            null,
            MemberSortBy.JOINED_AT,
            SortDirection.DESC),
        teamWebhookService.get(teamSlug));
  }
}
