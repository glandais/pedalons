// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/min_role.dart';
import '../models/slug_change_request.dart';
import '../models/sort_direction.dart';
import '../models/team_dashboard_dto.dart';
import '../models/team_detail_dto.dart';
import '../models/team_list_response.dart';
import '../models/team_request.dart';
import '../models/team_sort_by.dart';
import '../models/team_timezone_change_preview_dto.dart';
import '../models/team_timezone_dto.dart';

part 'teams_client.g.dart';

@RestApi()
abstract class TeamsClient {
  factory TeamsClient(Dio dio, {String? baseUrl}) = _TeamsClient;

  /// List public teams.
  ///
  /// Get a paginated list of public teams with optional search.
  ///
  /// [joinable] - Keep only teams that accept a join request from any domain user (true), or only those that do not (false). Omitted keeps both. A filter on top of the visibility rules, never instead of them.
  ///
  /// [minRole] - Minimum role in team.
  ///
  /// [page] - Page number (0-indexed).
  ///
  /// [search] - Search query to filter teams by name.
  ///
  /// [size] - Page size.
  ///
  /// [sortBy] - Sort column (default: name ascending). MEMBER_COUNT orders by the memberCount the rows carry. The team id always ends the key, so the order is total.
  ///
  /// [sortDir] - Sort direction when sortBy is set (default: DESC).
  @GET('/api/teams')
  Future<TeamListResponse> listTeams({
    @Query('page') int? page = 0,
    @Query('size') int? size = 20,
    @Query('joinable') bool? joinable,
    @Query('minRole') MinRole? minRole,
    @Query('search') String? search,
    @Query('sortBy') TeamSortBy? sortBy,
    @Query('sortDir') SortDirection? sortDir,
  });

  /// Create team.
  ///
  /// Create a new team. The current user will be set as the team owner.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/teams')
  Future<TeamDetailDto> createTeam({
    @Body() required TeamRequest body,
  });

  /// Update team.
  ///
  /// Update team information. Requires ADMIN role.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @PUT('/api/teams/{teamSlug}')
  Future<TeamDetailDto> updateTeam({
    @Path('teamSlug') required String teamSlug,
    @Body() required TeamRequest body,
  });

  /// Get team by slug.
  ///
  /// Get detailed team information by URL slug.
  ///
  /// [teamSlug] - Team URL slug.
  @GET('/api/teams/{teamSlug}')
  Future<TeamDetailDto> getTeam({
    @Path('teamSlug') required String teamSlug,
  });

  /// Delete team.
  ///
  /// Soft delete a team. Requires OWNER role.
  ///
  /// [teamSlug] - Team URL slug.
  @DELETE('/api/teams/{teamSlug}')
  Future<void> deleteTeam({
    @Path('teamSlug') required String teamSlug,
  });

  /// Get the team dashboard.
  ///
  /// Everything a « Tableau de bord » shows, in one call, graded by the caller's role. A visitor (anonymous, or signed in without belonging to the team) gets the public part only: upcoming rides, latest posts and new routes, under the usual visibility rules (PUBLIC entities only), with role, myUpcoming, latestAds, organizer and admin null. A member gets the member sections, an organizer the organizer block too, an administrator the admin block too. Each section is a short page of the matching list, and is null when the team has disabled its module. The teams switcher, the unread notification count and the calendar token are not part of it.
  ///
  /// [teamSlug] - Team URL slug.
  @GET('/api/teams/{teamSlug}/dashboard')
  Future<TeamDashboardDto> getTeamDashboard({
    @Path('teamSlug') required String teamSlug,
  });

  /// Change team slug.
  ///
  /// Change team URL slug. Requires ADMIN role.
  ///
  /// [teamSlug] - Current team URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @PATCH('/api/teams/{teamSlug}/slug')
  Future<TeamDetailDto> changeTeamSlug({
    @Path('teamSlug') required String teamSlug,
    @Body() required SlugChangeRequest body,
  });

  /// Zone of a point for the team.
  ///
  /// The IANA zone of the given point, else the team's own: the zone the backend will read an event's wall times in once that point is its start (docs/LEDGER_*.md API-60). For the editors' field labels only — the backend resolves the zone of a saved entity itself. Organisers and above.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [lat] - Latitude of the point; omitted with lon: the team's zone.
  ///
  /// [lon] - Longitude of the point; omitted with lat: the team's zone.
  @GET('/api/teams/{teamSlug}/timezone')
  Future<TeamTimezoneDto> getTeamTimezone({
    @Path('teamSlug') required String teamSlug,
    @Query('lat') double? lat,
    @Query('lon') double? lon,
  });

  /// Preview a change of the team's zone.
  ///
  /// What saving the team with this zone would do, without writing anything (docs/LEDGER_*.md API-60, plan §9): its upcoming rides, trips, stages and posts that no place or route locates keep their wall time in the new zone, the past ones keep their instant. Team admins only.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [timezone] - IANA zone the team would move to.
  @GET('/api/teams/{teamSlug}/timezone/change-preview')
  Future<TeamTimezoneChangePreviewDto> previewTeamTimezoneChange({
    @Path('teamSlug') required String teamSlug,
    @Query('timezone') required String timezone,
  });
}
