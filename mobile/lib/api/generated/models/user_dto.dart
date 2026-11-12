// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'gps_service_connection_dto.dart';
import 'instant.dart';
import 'planner_quota_dto.dart';
import 'platform_role.dart';
import 'theme_preference.dart';
import 'unit_system.dart';

part 'user_dto.freezed.dart';
part 'user_dto.g.dart';

/// User profile data
@Freezed()
abstract class UserDto with _$UserDto {
  const factory UserDto({
    /// User ID (TSID)
    required String id,

    /// User email address
    required String email,

    /// User display name
    required String displayName,

    /// Whether team members may reach this user through the classified-ad relay. True unless they explicitly opted out, so an account that predates the preference is contactable.
    required bool contactableByMembers,

    /// Whether the account's email has been verified
    required bool emailVerified,

    /// Where the user's personal route planner quota stands this month: the saves of a track drawn on the map in the GPX tools (docs/LEDGER_*.md BILL-10). limit is null — unlimited — for a member of an unlocked team of this site. Clients show no counter; they close « create a route » in the GPX tools when used >= limit already.
    required PlannerQuotaDto plannerQuota,

    /// User avatar URL
    String? avatarUrl,

    /// Account creation timestamp
    String? createdAt,

    /// Preferred unit system (metric or imperial)
    String? unitSystem,

    /// Preferred colour scheme. Null means the user never chose one — distinct from SYSTEM, which they did choose — so a client is free to follow the device.
    String? theme,

    /// Preferred language as a BCP-47 tag. Null means the user never chose one; the client then follows the device or the domain.
    String? language,

    /// Preferred IANA timezone (e.g. 'Europe/Paris'). Null means the user never chose one; the client then follows the browser.
    String? timezone,

    /// Platform role (null if regular user)
    String? platformRole,

    /// Connected GPS services
    List<GpsServiceConnectionDto>? connectedServices,
  }) = _UserDto;

  factory UserDto.fromJson(Map<String, Object?> json) =>
      _$UserDtoFromJson(json);
}
