// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_auth_method_stats_dto.freezed.dart';
part 'admin_auth_method_stats_dto.g.dart';

/// How the accounts that are not deleted can sign in; the four add up to total
@Freezed()
abstract class AdminAuthMethodStatsDto with _$AdminAuthMethodStatsDto {
  const factory AdminAuthMethodStatsDto({
    /// A password and no passkey
    required int passwordOnly,

    /// A passkey and no password
    required int passkeyOnly,

    /// A password and a passkey
    required int passwordAndPasskey,

    /// Neither: one-time code sent by e-mail only
    required int neither,
  }) = _AdminAuthMethodStatsDto;

  factory AdminAuthMethodStatsDto.fromJson(Map<String, Object?> json) =>
      _$AdminAuthMethodStatsDtoFromJson(json);
}
