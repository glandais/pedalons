// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'geo_json_line_string.dart';
import 'unpaved_span.dart';

part 'router_response.freezed.dart';
part 'router_response.g.dart';

@Freezed()
abstract class RouterResponse with _$RouterResponse {
  const factory RouterResponse({
    required GeoJsonLineString route,
    double? dist,
    double? ascend,

    /// Runs of unpaved edges of route (compacted surface or worse, from the router's own maneuvers), half-open, ascending and disjoint; edge i joins route points i and i + 1. Absent when the router gave no surface; empty when all paved
    List<UnpavedSpan>? unpaved,
  }) = _RouterResponse;

  factory RouterResponse.fromJson(Map<String, Object?> json) =>
      _$RouterResponseFromJson(json);
}
