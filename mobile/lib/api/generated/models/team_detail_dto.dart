// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'content_visibilities_dto.dart';
import 'instant.dart';
import 'media_dto.dart';
import 'member_count_by_role_dto.dart';
import 'planner_quota_dto.dart';
import 'team_detail_dto_geometry.dart';
import 'team_page_summary_dto.dart';
import 'team_role.dart';
import 'team_tier.dart';
import 'visibility.dart';

part 'team_detail_dto.freezed.dart';
part 'team_detail_dto.g.dart';

/// Detailed team information
@Freezed()
abstract class TeamDetailDto with _$TeamDetailDto {
  const factory TeamDetailDto({
    /// Whether team admins can add members
    required bool addMemberAllowed,

    /// Team name
    required String name,

    /// Team URL slug
    required String slug,

    /// About page content
    required MediaDto about,

    /// The team's plan, set by a platform admin only. FREE caps the members and the route planner saves, UNLOCKED lifts both caps.
    required String tier,

    /// Routes enabled
    required bool enableRoutes,

    /// Whether a platform admin allowed this private team to publish content as public or unlisted, readable by link only and kept out of every listing and of the sitemap. Meaningless for a team that is not private. For the platform administration screen: editors read allowedContentVisibilities.
    required bool publicContentAllowed,

    /// Whether the team is public
    required String visibility,

    /// Trips enabled
    required bool enableTrips,

    /// Ads enabled
    required bool enableAds,

    /// Posts enabled
    required bool enablePosts,

    /// Rides enabled
    required bool enableRides,

    /// Team ID (TSID)
    required String id,

    /// Whether the member directory is readable by every member and not just by administrators. Clients use it to decide whether to offer the directory at all: an entry that always leads to a 403 is worse than no entry. Organisers see the directory whatever its value, but only get each member's role and join date when it is true.
    required bool enableMemberDirectory,

    /// Whether a new post starts signed by the team rather than by its author — the initial value of the editor's « on behalf of the team » box.
    required bool postsAsTeamByDefault,

    /// Whether visibility is editable by team admins
    required bool visibilityEditable,

    /// Whether any domain user can join this team
    required bool joinable,

    /// Trips of this team starting in the future that the caller may open, under the same visibility rules as the trip listing. 0 when trips are disabled.
    required int upcomingTripCount,

    /// Whether the interactive route planner is open to this team. Unlike enableRoutes it never hides the routes section: when false the track can still be imported or replaced from a GPX file, only drawing is closed. Platform-admin only.
    required bool enableRoutePlanner,

    /// Number of team members
    required int memberCount,

    /// Rides of this team dated in the future that the caller may open. Follows the same visibility rules as the ride listing, so it never announces more than the caller can actually see.
    required int upcomingRideCount,

    /// Routes of this team the caller may open, under the same visibility rules as the route listing.
    required int routeCount,

    /// The visibility a creation form starts from: the team's own, so TEAM for a private team, publicContentAllowed or not. Not for ads, which are always TEAM.
    required String defaultContentVisibility,

    /// Published posts of this team dated within the last 7 days (and not in the future) that the caller may open, under the same visibility rules as the post listing. Feeds the activity line of a member's team card. 0 when posts are disabled.
    required int recentPostCount,

    /// The team's IANA zone: the one its rides, trips and posts fall back on when no place locates them. Administrators change it through TeamRequest.timezone.
    required String timezone,

    /// Team creation timestamp
    required String createdAt,

    /// The visibilities the team accepts for each type of content: what a creation form offers. The same for every caller who may read the team — the server still decides who may write. A private team holds TEAM only, unless a platform admin set publicContentAllowed.
    required ContentVisibilitiesDto allowedContentVisibilities,

    /// Team location coordinates [longitude, latitude]
    TeamDetailDtoGeometry? geometry,

    /// Members per role. Only for the team's administrators (platform admins included): null for everyone else, and in the team listings.
    MemberCountByRoleDto? memberCountByRole,

    /// URL template of the team's logo, when it has one. Same picture as about.assets.logo, hoisted so a card does not have to walk the asset inventory to find it. Opaque URL: may carry a query string; substitute {size} only.
    String? logoUrl,

    /// Where the team's route planner quota stands this month: the saves of a track drawn on the map, against the plan's limit (null when unlimited). Only for a caller who may create routes in the team, and only when one team is read: null for everyone else and in the team listings. Clients show no counter; they close « draw on the map » when used >= limit already.
    PlannerQuotaDto? plannerQuota,

    /// Additional team pages
    List<TeamPageSummaryDto>? pages,

    /// Plain-text opening of the about page, flattened and cut on a word boundary at about 200 characters. Null when the about page holds no text. Lets a team card render its two lines without parsing the markdown client-side.
    String? excerpt,

    /// The most members the team may hold, pending invitations included; null when unlimited. Compare with memberCount.
    int? memberLimit,

    /// Current user's role (null if not a member). The real membership, platform admins included: their extra rights come from the platform role of /api/me, not from this field.
    String? role,
  }) = _TeamDetailDto;

  factory TeamDetailDto.fromJson(Map<String, Object?> json) =>
      _$TeamDetailDtoFromJson(json);
}
