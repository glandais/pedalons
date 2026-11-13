// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'enums.freezed.dart';
part 'enums.g.dart';

@Freezed()
abstract class Enums with _$Enums {
  const factory Enums({
    List<String>? profiles,
    @JsonKey(name: 'surface_detail') List<String>? surfaceDetail,
  }) = _Enums;

  factory Enums.fromJson(Map<String, Object?> json) => _$EnumsFromJson(json);
}
