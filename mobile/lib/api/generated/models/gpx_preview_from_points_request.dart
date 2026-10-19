// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'geo_point.dart';
import 'planner_state.dart';

part 'gpx_preview_from_points_request.freezed.dart';
part 'gpx_preview_from_points_request.g.dart';

/// GPX preview creation request from planner points
@Freezed()
abstract class GpxPreviewFromPointsRequest with _$GpxPreviewFromPointsRequest {
  const factory GpxPreviewFromPointsRequest({
    /// Preview name
    required String name,

    /// Points from frontend routing; points or plannerState, never both (400 PLANNER_STATE_INVALID), and one of them (400 GPX_EMPTY)
    List<GeoPoint>? points,

    /// Editing state of the planner; the server derives the track from it. Not with points
    PlannerState? plannerState,
  }) = _GpxPreviewFromPointsRequest;

  factory GpxPreviewFromPointsRequest.fromJson(Map<String, Object?> json) =>
      _$GpxPreviewFromPointsRequestFromJson(json);
}
