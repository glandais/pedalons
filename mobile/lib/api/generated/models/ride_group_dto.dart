// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'local_time.dart';
import 'public_user_dto.dart';

part 'ride_group_dto.freezed.dart';
part 'ride_group_dto.g.dart';

/// Ride group information
@Freezed()
abstract class RideGroupDto with _$RideGroupDto {
  const factory RideGroupDto({
    /// Group ID (TSID)
    required String id,

    /// Group name
    required String name,

    /// When the group leaves: its time on the ride's local date in the ride's zone, the ride's dateTime when it has no time of its own.
    required String startAt,

    /// Current number of participants
    required int countParticipants,

    /// The first participants of the group (at most 8), earliest registrations first — enough to draw avatars. countParticipants is the total; the whole list is paginated and searched by GET …/rides/{rideSlug}/participants?groupId=.
    required List<PublicUserDto> participants,

    /// Sort order
    required int sortOrder,

    /// Whether the current user is registered in THIS group. False if anonymous.
    required bool registered,

    /// Whether the group has reached maxParticipants. False when maxParticipants is not set.
    required bool full,

    /// Deprecated in favour of startAt, for display: the group's start as a wall time of the ride's zone, null when it leaves with the ride. What an editor sends back as GroupRequest.time.
    String? time,

    /// Route slug
    String? routeSlug,

    /// Average speed in km/h
    double? averageSpeed,

    /// Maximum participants
    int? maxParticipants,

    /// Distance in meters of the group route, if it has one
    double? distance,

    /// Total elevation gain in meters of the group route, if it has one
    double? elevationGain,

    /// The member who leads this group, when one is designated. Null means no leader was designated — render nothing rather than falling back on the ride's creator, who is the same person on every group of the ride.
    PublicUserDto? leader,

    /// Thumbnail URL (light) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailLightUrl,

    /// Thumbnail URL (dark) of the group route, if it has one. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailDarkUrl,

    /// The one thumbnail of the group route to show when the client does not theme its cards: the light variant if there is one, else the dark one. Null when the group has no route or its route has no thumbnail — the ride's own thumbnail is then the one to fall back on. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailUrl,
  }) = _RideGroupDto;

  factory RideGroupDto.fromJson(Map<String, Object?> json) =>
      _$RideGroupDtoFromJson(json);
}
