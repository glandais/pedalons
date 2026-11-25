// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/blocked_users_response.dart';
import '../models/moderation_decision_request.dart';
import '../models/moderation_queue_response.dart';
import '../models/report_queue_status.dart';
import '../models/report_request.dart';

part 'moderation_client.g.dart';

@RestApi()
abstract class ModerationClient {
  factory ModerationClient(Dio dio, {String? baseUrl}) = _ModerationClient;

  /// Report content or a member.
  ///
  /// Files a report in a team, about a comment, a publication, an ad, a route or a member the caller can read there. Idempotent: reporting the same target again changes nothing. The target disappears from the caller's lists at once; the team's organizers and administrators are notified, without the caller's name.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/reports')
  Future<void> reportContent({
    @Body() required ReportRequest body,
  });

  /// List the team's moderation queue.
  ///
  /// Reports grouped by target, without the reporters' identities. OPEN lists every target waiting for a decision; RESOLVED the 100 most recently decided. Reports about the caller — their content, or themselves — are left out.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [status] - OPEN (default) or RESOLVED.
  @GET('/api/teams/{teamSlug}/reports')
  Future<ModerationQueueResponse> listTeamReports({
    @Path('teamSlug') required String teamSlug,
    @Query('status') ReportQueueStatus? status,
  });

  /// Decide about a reported target.
  ///
  /// Applies the decision to every open report of the target. REMOVE_CONTENT deletes the content (not allowed on a member); DISMISS keeps it, and shows it again if reports had hidden it.
  ///
  /// [teamSlug] - Team URL slug.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/teams/{teamSlug}/reports/resolve')
  Future<void> resolveTeamReports({
    @Path('teamSlug') required String teamSlug,
    @Body() required ModerationDecisionRequest body,
  });

  /// List the members I blocked.
  ///
  /// Most recent first.
  @GET('/api/users/me/blocks')
  Future<BlockedUsersResponse> listMyBlockedUsers();

  /// Unblock a member.
  ///
  /// Idempotent.
  ///
  /// [userId] - User ID (TSID).
  @DELETE('/api/users/me/blocks/{userId}')
  Future<void> unblockUser({
    @Path('userId') required String userId,
  });

  /// Block a member.
  ///
  /// Hides the member's comments, posts and ads from the caller, and the comment notifications they cause. Idempotent.
  ///
  /// [userId] - User ID (TSID).
  @PUT('/api/users/me/blocks/{userId}')
  Future<void> blockUser({
    @Path('userId') required String userId,
  });
}
