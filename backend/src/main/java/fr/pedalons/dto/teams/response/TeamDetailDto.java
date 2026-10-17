package fr.pedalons.dto.teams.response;

import fr.pedalons.common.MarkdownExcerpt;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.team.TeamPage;
import fr.pedalons.dto.common.GeoJsonPoint;
import fr.pedalons.dto.common.asset.AssetDto;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.pages.response.TeamPageSummaryDto;
import fr.pedalons.dto.validation.ValidateSchema;
import fr.pedalons.enums.Status;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.asset.AssetService;
import fr.pedalons.service.team.response.TeamAndRole;
import fr.pedalons.service.team.response.TeamStats;
import java.time.Instant;
import java.util.List;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.geolatte.geom.G2D;
import org.geolatte.geom.Point;
import org.jspecify.annotations.Nullable;

@Schema(description = "Detailed team information")
@ValidateSchema
public record TeamDetailDto(
    @Schema(description = "Team ID (TSID)", examples = "0h4a8xzk8jv80", required = true) String id,
    @Schema(description = "Team name", required = true) String name,
    @Schema(description = "Team URL slug", required = true) String slug,
    @Schema(description = "About page content", required = true) MediaDto about,
    @Nullable
        @Schema(
            description =
                "Plain-text opening of the about page, flattened and cut on a word boundary at"
                    + " about 200 characters. Null when the about page holds no text. Lets a team"
                    + " card render its two lines without parsing the markdown client-side.")
        String excerpt,
    @Nullable
        @Schema(
            description =
                "URL template of the team's logo, when it has one. Same picture as"
                    + " about.assets.logo, hoisted so a card does not have to walk the asset"
                    + " inventory to find it. Opaque URL: may carry a query string; substitute"
                    + " {size} only.")
        String logoUrl,
    @Schema(description = "Additional team pages") List<TeamPageSummaryDto> pages,
    @Schema(description = "Whether the team is public", required = true) Visibility visibility,
    @Schema(description = "Trips enabled", required = true) boolean enableTrips,
    @Schema(description = "Ads enabled", required = true) boolean enableAds,
    @Schema(description = "Posts enabled", required = true) boolean enablePosts,
    @Schema(description = "Rides enabled", required = true) boolean enableRides,
    @Schema(description = "Routes enabled", required = true) boolean enableRoutes,
    @Schema(
            description =
                "Whether the member directory is readable by every member and not just by"
                    + " administrators. Clients use it to decide whether to offer the directory at"
                    + " all: an entry that always leads to a 403 is worse than no entry. Organisers"
                    + " see the directory whatever its value, but only get each member's role and"
                    + " join date when it is true.",
            required = true)
        boolean enableMemberDirectory,
    @Schema(
            description =
                "Whether a new post starts signed by the team rather than by its author — the"
                    + " initial value of the editor's « on behalf of the team » box.",
            required = true)
        boolean postsAsTeamByDefault,
    @Schema(description = "Whether visibility is editable by team admins", required = true)
        boolean visibilityEditable,
    @Schema(description = "Whether any domain user can join this team", required = true)
        boolean joinable,
    @Schema(description = "Whether team admins can add members", required = true)
        boolean addMemberAllowed,
    @Schema(
            description =
                "Whether the interactive route planner is open to this team. Unlike enableRoutes it"
                    + " never hides the routes section: when false the track can still be imported"
                    + " or replaced from a GPX file, only drawing is closed. Platform-admin only.",
            required = true)
        boolean enableRoutePlanner,
    @Schema(description = "Number of team members", required = true) long memberCount,
    @Schema(
            description =
                "Rides of this team dated in the future that the caller may open. Follows the same"
                    + " visibility rules as the ride listing, so it never announces more than the"
                    + " caller can actually see.",
            required = true)
        long upcomingRideCount,
    @Schema(
            description =
                "Routes of this team the caller may open, under the same visibility rules as the"
                    + " route listing.",
            required = true)
        long routeCount,
    @Schema(
            description =
                "Trips of this team starting in the future that the caller may open, under the"
                    + " same visibility rules as the trip listing. 0 when trips are disabled.",
            required = true)
        long upcomingTripCount,
    @Schema(
            description =
                "Published posts of this team dated within the last 7 days (and not in the"
                    + " future) that the caller may open, under the same visibility rules as the"
                    + " post listing. Feeds the activity line of a member's team card. 0 when"
                    + " posts are disabled.",
            required = true)
        long recentPostCount,
    @Nullable
        @Schema(
            description =
                "Members per role. Only for the team's administrators (platform admins included):"
                    + " null for everyone else, and in the team listings.")
        MemberCountByRoleDto memberCountByRole,
    @Nullable @Schema(description = "Current user's role (null if not a member)") TeamRole role,
    @Schema(description = "Team creation timestamp", required = true) Instant createdAt,
    @Nullable
        @Schema(
            description = "Team location coordinates [longitude, latitude]",
            implementation = GeoJsonPoint.class)
        Point<G2D> geometry,
    @Schema(
            description =
                "The team's IANA zone: the one its rides, trips and posts fall back on when no"
                    + " place locates them. Administrators change it through TeamRequest.timezone.",
            examples = "Europe/Paris",
            required = true)
        String timezone) {
  public static TeamDetailDto from(
      TeamAndRole teamAndRole, AssetService assetService, boolean platformAdmin) {
    return from(teamAndRole, assetService, platformAdmin, TeamStats.EMPTY);
  }

  /**
   * @param stats the content counters, bulk-loaded for the whole page by {@code TeamStatsRepository}
   *     — never fetched here, or a directory of thirty teams would run sixty queries
   */
  public static TeamDetailDto from(
      TeamAndRole teamAndRole, AssetService assetService, boolean platformAdmin, TeamStats stats) {
    return from(teamAndRole, assetService, platformAdmin, stats, null);
  }

  /**
   * @param memberCountByRole the split of the members per role, loaded only for an administrator;
   *     null leaves it out
   */
  public static TeamDetailDto from(
      TeamAndRole teamAndRole,
      AssetService assetService,
      boolean platformAdmin,
      TeamStats stats,
      @Nullable MemberCountByRoleDto memberCountByRole) {
    Team team = teamAndRole.team();
    List<TeamPageSummaryDto> pages =
        team.getAdditionalPages().stream()
            .filter(page -> isListed(page, team, teamAndRole.teamRole(), platformAdmin))
            .map(TeamPageSummaryDto::from)
            .toList();
    // Built once: the excerpt and the logo are read back out of it rather than re-walking the
    // about page and its assets.
    MediaDto about = MediaDto.from(team.getAboutPage(), assetService);
    AssetDto logo = about.assets().logo();
    return new TeamDetailDto(
        TsidUtils.toString(team.getId()),
        team.getName(),
        team.getSlug(),
        about,
        MarkdownExcerpt.of(about.markdown()),
        logo != null ? logo.imageUrl() : null,
        pages,
        team.getVisibility(),
        team.isEnableTrips(),
        team.isEnableAds(),
        team.isEnablePosts(),
        team.isEnableRides(),
        team.isEnableRoutes(),
        team.isEnableMemberDirectory(),
        team.isPostsAsTeamByDefault(),
        team.isVisibilityEditable(),
        team.isJoinable(),
        team.isAddMemberAllowed(),
        team.isEnableRoutePlanner(),
        teamAndRole.memberCount(),
        stats.upcomingRideCount(),
        stats.routeCount(),
        stats.upcomingTripCount(),
        stats.recentPostCount(),
        memberCountByRole,
        platformAdmin ? TeamRole.ADMIN : teamAndRole.teamRole(),
        team.getCreatedAt(),
        team.getGeometry(),
        team.getTimezone());
  }

  /**
   * Whether the caller may see this page in the team's menu — the rule of {@code
   * TeamPageService.listPages} (TeamEntityRepository's listing clauses), applied to the pages the
   * team already holds. Without it every visitor, anonymous included, received the title and slug
   * of the members-only pages and the drafts; only their content was guarded.
   */
  static boolean isListed(
      TeamPage page, Team team, @Nullable TeamRole role, boolean platformAdmin) {
    if (platformAdmin) {
      return true;
    }
    boolean moderator = role == TeamRole.ORGANIZER || role == TeamRole.ADMIN;
    if (page.getModerationHiddenAt() != null && !moderator) {
      return false;
    }
    boolean live = page.getStatus() == Status.PUBLISHED || page.getStatus() == Status.CANCELLED;
    if (role == TeamRole.ADMIN) {
      return true;
    }
    if (role != null) {
      return live;
    }
    return live
        && team.getVisibility() != Visibility.TEAM
        && page.getVisibility() == Visibility.PUBLIC;
  }
}
