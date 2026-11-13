// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'limits.freezed.dart';
part 'limits.g.dart';

@Freezed()
abstract class Limits with _$Limits {
  const factory Limits({
    @JsonKey(name: 'max_points') int? maxPoints,
    @JsonKey(name: 'max_length_m') double? maxLengthM,
  }) = _Limits;

  factory Limits.fromJson(Map<String, Object?> json) => _$LimitsFromJson(json);
}
