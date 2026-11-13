// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'elevation.freezed.dart';
part 'elevation.g.dart';

@Freezed()
abstract class Elevation with _$Elevation {
  const factory Elevation({
    @JsonKey(name: 'smoothing_m') double? smoothingM,
  }) = _Elevation;

  factory Elevation.fromJson(Map<String, Object?> json) =>
      _$ElevationFromJson(json);
}
