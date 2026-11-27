// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_key_count_dto.freezed.dart';
part 'admin_key_count_dto.g.dart';

/// A count per key (a tier, a role, a client kind…) — counts only
@Freezed()
abstract class AdminKeyCountDto with _$AdminKeyCountDto {
  const factory AdminKeyCountDto({
    /// What is counted
    required String key,

    /// How many
    required int count,
  }) = _AdminKeyCountDto;

  factory AdminKeyCountDto.fromJson(Map<String, Object?> json) =>
      _$AdminKeyCountDtoFromJson(json);
}
