// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'event_date_time.dart';
import 'media_dto.dart';
import 'stage_request.dart';
import 'status.dart';
import 'visibility.dart';

part 'trip_request.freezed.dart';
part 'trip_request.g.dart';

/// Trip request
@Freezed()
abstract class TripRequest with _$TripRequest {
  const factory TripRequest({
    /// Trip name
    required String name,

    /// Trip media
    required MediaDto media,

    /// Trip start date/time: a wall time without offset, read in the trip's zone (first stage, else route, else team).
    required String dateTime,

    /// Trip status
    required String status,

    /// Visibility level
    required String visibility,

    /// Trip stages to create
    required List<StageRequest> stages,

    /// Overall route slug for the trip
    String? routeSlug,

    /// Publication time (for scheduled publishing), a wall time in the trip's zone like dateTime.
    String? publishAt,

    /// IDs (TSID) of the team's TRIP tags the trip carries, replacing the whole set — at most 10, each a tag of this team and of kind TRIP, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
    List<String>? tagIds,

    /// When the trip is not TEAM and uses TEAM routes (its own, its stages'), the save is refused with INCOMPATIBLE_VISIBILITY, listing them. Replayed with true, it raises those routes to PUBLIC_UNLISTED in the same transaction, then saves. Omitted or false: refused as before.
    bool? alignVisibility,
  }) = _TripRequest;

  factory TripRequest.fromJson(Map<String, Object?> json) =>
      _$TripRequestFromJson(json);
}
