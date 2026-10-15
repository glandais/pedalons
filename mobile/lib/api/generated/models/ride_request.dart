// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'event_date_time.dart';
import 'group_request.dart';
import 'media_dto.dart';
import 'status.dart';
import 'visibility.dart';

part 'ride_request.freezed.dart';
part 'ride_request.g.dart';

/// Ride request
@Freezed()
abstract class RideRequest with _$RideRequest {
  const factory RideRequest({
    /// Ride name
    required String name,

    /// Ride media
    required MediaDto media,

    /// Ride date/time: a wall time without offset, read in the ride's zone (start place, else route, else team).
    required String dateTime,

    /// Ride status
    required String status,

    /// Visibility level
    required String visibility,

    /// Ride groups to create
    required List<GroupRequest> groups,

    /// Route slug
    String? routeSlug,

    /// Start place ID (TSID)
    String? startPlaceId,

    /// End place ID (TSID)
    String? endPlaceId,

    /// Publication time (for scheduled publishing), a wall time in the ride's zone like dateTime.
    String? publishAt,

    /// IDs (TSID) of the team's RIDE tags the ride carries, replacing the whole set — at most 10, each a tag of this team and of kind RIDE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
    List<String>? tagIds,

    /// ID (TSID) of the team's template the ride is created from. On a creation, raises the template's nextNumber by one when it has one; ignored on an update, and when the template no longer exists.
    String? templateId,
  }) = _RideRequest;

  factory RideRequest.fromJson(Map<String, Object?> json) =>
      _$RideRequestFromJson(json);
}
