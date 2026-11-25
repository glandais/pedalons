// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'geo_point.freezed.dart';
part 'geo_point.g.dart';

@Freezed()
abstract class GeoPoint with _$GeoPoint {
  const factory GeoPoint({
    required double lng,
    required double lat,
  }) = _GeoPoint;

  factory GeoPoint.fromJson(Map<String, Object?> json) =>
      _$GeoPointFromJson(json);
}
