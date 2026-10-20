// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'geo_point.dart';
import 'planner_state.dart';
import 'waypoint_request.dart';

part 'gpx_preview_update_request.freezed.dart';
part 'gpx_preview_update_request.g.dart';

/// GPX preview update request
@Freezed()
abstract class GpxPreviewUpdateRequest with _$GpxPreviewUpdateRequest {
  const factory GpxPreviewUpdateRequest({
    /// Preview name
    required String name,

    /// Points from frontend routing
    List<GeoPoint>? points,

    /// Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it
    PlannerState? plannerState,

    /// The complete list of the waypoints, replacing them. Omitted: they stay as they are (placed again when the track changes)
    List<WaypointRequest>? waypoints,
  }) = _GpxPreviewUpdateRequest;

  factory GpxPreviewUpdateRequest.fromJson(Map<String, Object?> json) =>
      _$GpxPreviewUpdateRequestFromJson(json);
}
