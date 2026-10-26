// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'media_dto.dart';
import 'place_detail_dto.dart';
import 'public_user_dto.dart';
import 'publication_dto.dart';
import 'publication_type.dart';
import 'ride_group_dto.dart';
import 'ride_group_summary_dto.dart';
import 'ride_weather_summary_dto.dart';
import 'status.dart';
import 'surface_type.dart';
import 'tag_dto.dart';
import 'team_publication_dto.dart';
import 'visibility.dart';

part 'ride_dto.freezed.dart';
part 'ride_dto.g.dart';

/// Ride summary data
@Freezed()
abstract class RideDto with _$RideDto {
  const factory RideDto({
    /// Ride groups
    required List<RideGroupDto> groups,

    /// Team
    required TeamPublicationDto team,

    /// Publication ID (TSID)
    required String id,

    /// Publication URL slug
    required String slug,

    /// Publication name
    required String name,

    /// Publication media
    required MediaDto media,

    /// Visibility level
    required String visibility,

    /// Publication date/time
    required String dateTime,

    /// IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone.
    required String timezone,

    /// When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read.
    required String endDateTime,

    /// Publication status
    required String status,

    /// Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.
    required bool finished,

    /// Type
    required String type,

    /// Number of participants
    required int participantCount,

    /// Number of groups
    required int groupCount,

    /// Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.
    required List<RideGroupSummaryDto> groupSummaries,

    /// The team's RIDE tags the ride carries, sorted by label. Empty when it carries none.
    required List<TagDto> tags,

    /// Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.
    required bool full,

    /// Whether the ride is soft-deleted
    required bool deleted,

    /// Whether the current user is registered in one of this ride's groups. False if anonymous.
    required bool registered,

    /// Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.
    required List<PublicUserDto> topParticipants,

    /// Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.
    double? elevationGain,

    /// Surface type, from the same route as distance. Null when no route is set anywhere.
    String? surfaceType,

    /// Start place
    PlaceDetailDto? startPlace,

    /// The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.
    RideWeatherSummaryDto? weather,

    /// Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere.
    double? distance,

    /// Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailLightUrl,

    /// Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailDarkUrl,

    /// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailUrl,

    /// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
    String? excerpt,

    /// Route slug
    String? routeSlug,

    /// ID (TSID) of the group the current user joined, null if not registered
    String? registeredGroupId,

    /// The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group's own, null when none was designated.
    RideGroupDto? registeredGroup,

    /// Creation timestamp
    String? createdAt,

    /// Capacity of the whole ride: the sum of its groups' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty.
    int? maxParticipants,

    /// Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.
    int? commentCount,

    /// Publication timestamp
    String? publishAt,

    /// End place
    PlaceDetailDto? endPlace,
  }) = _RideDto;

  factory RideDto.fromJson(Map<String, Object?> json) =>
      _$RideDtoFromJson(json);
}
