// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_passkey_stats_dto.freezed.dart';
part 'admin_passkey_stats_dto.g.dart';

/// Passkeys of accounts that are not deleted
@Freezed()
abstract class AdminPasskeyStatsDto with _$AdminPasskeyStatsDto {
  const factory AdminPasskeyStatsDto({
    /// Passkeys registered
    required int total,

    /// Passkeys used during the last 30 days
    required int usedLast30Days,
  }) = _AdminPasskeyStatsDto;

  factory AdminPasskeyStatsDto.fromJson(Map<String, Object?> json) =>
      _$AdminPasskeyStatsDtoFromJson(json);
}
