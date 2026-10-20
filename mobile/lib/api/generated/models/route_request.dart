// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'geo_point.dart';
import 'media_dto.dart';
import 'planner_state.dart';
import 'surface_type.dart';
import 'visibility.dart';
import 'waypoint_request.dart';

part 'route_request.freezed.dart';
part 'route_request.g.dart';

/// Route update request
@Freezed()
abstract class RouteRequest with _$RouteRequest {
  const factory RouteRequest({
    /// Route name
    required String name,

    /// Media
    required MediaDto media,

    /// Surface type
    required String surfaceType,

    /// Whether the route is publicly visible
    required String visibility,

    /// Points from frontend routing
    List<GeoPoint>? points,

    /// IDs (TSID) of the team's ROUTE tags the route carries, replacing the whole set — at most 10, each a tag of this team and of kind ROUTE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
    List<String>? tagIds,

    /// Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it
    PlannerState? plannerState,

    /// The complete list of the route's waypoints, replacing them. Omitted: they stay as they are (placed again on the new track when the track changes, and a new GPX file replaces the imported ones and keeps the author's). When present it wins over the waypoints of a GPX file sent with it
    List<WaypointRequest>? waypoints,
  }) = _RouteRequest;

  factory RouteRequest.fromJson(Map<String, Object?> json) =>
      _$RouteRequestFromJson(json);
}
