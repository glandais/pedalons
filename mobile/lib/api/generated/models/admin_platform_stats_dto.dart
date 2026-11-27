// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'admin_auth_method_stats_dto.dart';
import 'admin_calendar_stats_dto.dart';
import 'admin_gps_service_stats_dto.dart';
import 'admin_key_count_dto.dart';
import 'admin_month_count_dto.dart';
import 'admin_passkey_stats_dto.dart';
import 'admin_push_platform_stats_dto.dart';
import 'admin_team_stats_dto.dart';
import 'admin_user_stats_dto.dart';
import 'instant.dart';

part 'admin_platform_stats_dto.freezed.dart';
part 'admin_platform_stats_dto.g.dart';

/// Usage statistics of the platform or of one domain, for the platform administration. Counts only: no row names or identifies anyone. Deleted accounts and deleted domains are left out unless a field says otherwise.
@Freezed()
abstract class AdminPlatformStatsDto with _$AdminPlatformStatsDto {
  const factory AdminPlatformStatsDto({
    /// When the figures were computed
    required String generatedAt,
    required AdminUserStatsDto users,
    required AdminAuthMethodStatsDto authMethods,
    required AdminPasskeyStatsDto passkeys,

    /// Accounts created per calendar month (UTC), the last 12 months, the current one included, oldest first, months without any included
    required List<AdminMonthCountDto> signupsByMonth,
    required AdminTeamStatsDto teams,
    required List<AdminGpsServiceStatsDto> gpsServices,

    /// Accounts with a connection to any GPS service
    required int usersWithGpsService,
    required List<AdminPushPlatformStatsDto> pushDevices,

    /// Distinct accounts per kind of client among the sessions used during the last 30 days. Keys: MOBILE_APP (the Pédalons app), OAUTH (a third-party application authorised through OAuth), the lowercase device client of a paired device (garmin, karoo), WEB_MOBILE (a browser on a phone or tablet), WEB_DESKTOP (any other browser). An account counts once per kind, so the total can exceed the number of accounts.
    required List<AdminKeyCountDto> clientsLast30Days,
    required AdminCalendarStatsDto calendarFeeds,

    /// The domain the figures are limited to; absent: all domains
    String? domainId,
  }) = _AdminPlatformStatsDto;

  factory AdminPlatformStatsDto.fromJson(Map<String, Object?> json) =>
      _$AdminPlatformStatsDtoFromJson(json);
}
