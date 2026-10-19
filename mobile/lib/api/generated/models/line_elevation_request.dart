// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'straight_line.dart';

part 'line_elevation_request.freezed.dart';
part 'line_elevation_request.g.dart';

@Freezed()
abstract class LineElevationRequest with _$LineElevationRequest {
  const factory LineElevationRequest({
    /// Straight lines to read the relief of, 1 to 50, at most 100 km each and 200 km together
    required List<StraightLine> lines,

    /// Slug of the team the route is being drawn for. When present, the team must have the route planner enabled and the caller must be allowed to create routes in it. When absent, the domain's GPX planner must be enabled.
    String? teamSlug,
  }) = _LineElevationRequest;

  factory LineElevationRequest.fromJson(Map<String, Object?> json) =>
      _$LineElevationRequestFromJson(json);
}
