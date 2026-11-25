// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'geo_point.dart';

part 'straight_line.freezed.dart';
part 'straight_line.g.dart';

@Freezed()
abstract class StraightLine with _$StraightLine {
  const factory StraightLine({
    required GeoPoint from,
    required GeoPoint to,
  }) = _StraightLine;

  factory StraightLine.fromJson(Map<String, Object?> json) =>
      _$StraightLineFromJson(json);
}
