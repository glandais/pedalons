// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'admin_key_count_dto.dart';

part 'admin_team_stats_dto.freezed.dart';
part 'admin_team_stats_dto.g.dart';

/// Teams and memberships
@Freezed()
abstract class AdminTeamStatsDto with _$AdminTeamStatsDto {
  const factory AdminTeamStatsDto({
    /// Teams that are not deleted
    required int active,

    /// Teams deleted
    required int deleted,

    /// Active teams per plan (FREE, UNLOCKED…)
    required List<AdminKeyCountDto> byTier,

    /// Memberships per role (MEMBER, ORGANIZER, ADMIN), active teams and accounts that are not deleted
    required List<AdminKeyCountDto> membershipsByRole,

    /// Accounts that are not deleted per number of active teams they belong to: keys "0", "1", "2", "3+"
    required List<AdminKeyCountDto> usersByTeamCount,
  }) = _AdminTeamStatsDto;

  factory AdminTeamStatsDto.fromJson(Map<String, Object?> json) =>
      _$AdminTeamStatsDtoFromJson(json);
}
