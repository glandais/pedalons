// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'geo_point.dart';
import 'waypoint_origin.dart';
import 'waypoint_type.dart';

part 'waypoint_request.freezed.dart';
part 'waypoint_request.g.dart';

/// A waypoint of a route, as sent by the editor
@Freezed()
abstract class WaypointRequest with _$WaypointRequest {
  const factory WaypointRequest({
    /// Where the waypoint is
    required GeoPoint position,

    /// What the waypoint is
    required String type,

    /// Name, possibly empty (the type's label then shows on a device). The editor limits it to 40 characters; the API accepts what an import can bring, up to 250
    required String name,

    /// Identifier of an existing waypoint, as returned by the API: it keeps its origin. Omitted or unknown: a new waypoint. Malformed or repeated: 400
    String? id,

    /// Free text, at most 500 characters
    String? description,

    /// The distance in metres the editor shows the waypoint at. Only used to pick which passage of a route that goes by twice the waypoint belongs to: the server recomputes the distance itself
    double? distance,

    /// Origin of a new waypoint, AUTHOR by default. Ignored for a waypoint that exists: it keeps its own
    String? origin,
  }) = _WaypointRequest;

  factory WaypointRequest.fromJson(Map<String, Object?> json) =>
      _$WaypointRequestFromJson(json);
}
