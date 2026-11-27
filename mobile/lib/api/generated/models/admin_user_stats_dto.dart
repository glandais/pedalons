// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_user_stats_dto.freezed.dart';
part 'admin_user_stats_dto.g.dart';

/// Accounts of the platform (or of one domain). Every field but total and deleted counts accounts that are not deleted; activity is based on the last sign-in date.
@Freezed()
abstract class AdminUserStatsDto with _$AdminUserStatsDto {
  const factory AdminUserStatsDto({
    /// Accounts that are not deleted
    required int total,

    /// Accounts deleted
    required int deleted,

    /// Accounts whose e-mail address is verified
    required int emailVerified,

    /// Accounts that accepted the terms
    required int termsAccepted,

    /// Platform administrators
    required int platformAdmins,

    /// Accounts with an avatar
    required int withAvatar,

    /// Accounts that never signed in
    required int neverLoggedIn,

    /// Accounts that signed in during the last 7 days
    required int activeLast7Days,

    /// Accounts that signed in during the last 30 days
    required int activeLast30Days,

    /// Accounts that signed in during the last 90 days
    required int activeLast90Days,
  }) = _AdminUserStatsDto;

  factory AdminUserStatsDto.fromJson(Map<String, Object?> json) =>
      _$AdminUserStatsDtoFromJson(json);
}
