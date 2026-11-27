// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_push_platform_stats_dto.freezed.dart';
part 'admin_push_platform_stats_dto.g.dart';

/// Push notification devices of one platform
@Freezed()
abstract class AdminPushPlatformStatsDto with _$AdminPushPlatformStatsDto {
  const factory AdminPushPlatformStatsDto({
    /// The platform (ANDROID, IOS…)
    required String platform,

    /// Devices registered
    required int devices,

    /// Accounts with at least one device
    required int users,

    /// Devices seen during the last 7 days
    required int seenLast7Days,
  }) = _AdminPushPlatformStatsDto;

  factory AdminPushPlatformStatsDto.fromJson(Map<String, Object?> json) =>
      _$AdminPushPlatformStatsDtoFromJson(json);
}
