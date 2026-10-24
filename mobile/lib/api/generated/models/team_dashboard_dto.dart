// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'ad_list_response.dart';
import 'publication_list_response.dart';
import 'route_list_response.dart';
import 'team_dashboard_admin_dto.dart';
import 'team_dashboard_organizer_dto.dart';
import 'team_detail_dto.dart';
import 'team_role.dart';

part 'team_dashboard_dto.freezed.dart';
part 'team_dashboard_dto.g.dart';

/// A team's dashboard for one of its members, or its public part for a visitor. Each section is a short page (at most 5 rows) of the matching list, compact rows, deleted content left out; its total is what the full list holds. A section is null when its module is disabled for the team. The organizer block is null for a MEMBER, the admin block null below ADMIN. For a visitor (role null) only team, upcomingRides, latestPosts and newRoutes are filled.
@Freezed()
abstract class TeamDashboardDto with _$TeamDashboardDto {
  const factory TeamDashboardDto({
    /// The team, as GET /api/teams/{teamSlug} returns it — header, feature flags, memberCount; memberCountByRole is filled for an administrator.
    required TeamDetailDto team,

    /// The caller's real role in the team; null for a visitor, anonymous or not a member — a platform admin who is not a member included. The organizer and admin blocks are what a platform admin's rights add.
    String? role,

    /// « Vos prochaines sorties »: the team's rides and trips starting from now that the caller is registered to, soonest first (at most 3). A ride row's registeredGroup is the group joined, with its pace. Null when both rides and trips are disabled, and for a visitor.
    PublicationListResponse? myUpcoming,

    /// « Sorties à venir »: the team's published rides starting from now, soonest first (at most 3). Each row carries groupSummaries (fill per group), distance, elevationGain, surfaceType, registered and commentCount. Null when rides are disabled.
    PublicationListResponse? upcomingRides,

    /// « Dernières publications »: the team's latest published posts, newest first (at most 3). Null when posts are disabled.
    PublicationListResponse? latestPosts,

    /// « Nouveaux parcours »: the team's latest routes, newest first (at most 3). Null when routes are disabled.
    RouteListResponse? newRoutes,

    /// « Annonces »: the team's latest ads, newest first (at most 3). A null price reads « Prix à négocier »; the place is locationDescription, a sector — never a pin. Null when ads are disabled, and for a visitor.
    AdListResponse? latestAds,

    /// What organizers and administrators see on top. Null for a MEMBER and a visitor; filled for a platform admin, member or not.
    TeamDashboardOrganizerDto? organizer,

    /// The administration panel. Null below ADMIN, and for a visitor; filled for a platform admin, member or not.
    TeamDashboardAdminDto? admin,
  }) = _TeamDashboardDto;

  factory TeamDashboardDto.fromJson(Map<String, Object?> json) =>
      _$TeamDashboardDtoFromJson(json);
}
