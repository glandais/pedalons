// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'media_dto.dart';
import 'place_detail_dto.dart';
import 'post_dto.dart';
import 'public_user_dto.dart';
import 'publication_type.dart';
import 'ride_dto.dart';
import 'ride_group_dto.dart';
import 'ride_group_summary_dto.dart';
import 'ride_weather_summary_dto.dart';
import 'status.dart';
import 'surface_type.dart';
import 'tag_dto.dart';
import 'team_publication_dto.dart';
import 'trip_dto.dart';
import 'trip_stage_dto.dart';
import 'visibility.dart';

part 'publication_dto.freezed.dart';
part 'publication_dto.g.dart';

/// Publication data
@Freezed(unionKey: 'type')
sealed class PublicationDto with _$PublicationDto {
  @FreezedUnionValue('RIDE')
  const factory PublicationDto.ride({
    /// Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.
    required List<RideGroupSummaryDto> groupSummaries,

    /// Publication ID (TSID)
    required String id,

    /// Publication URL slug
    required String slug,

    /// Publication name
    required String name,

    /// Publication media
    required MediaDto media,

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

    /// Visibility level
    required String visibility,

    /// Team
    required TeamPublicationDto team,

    /// Number of participants
    required int participantCount,

    /// Number of groups
    required int groupCount,

    /// Ride groups
    required List<RideGroupDto> groups,

    /// Preview of first participants (max 5)
    required List<PublicUserDto> topParticipants,

    /// Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.
    required bool full,

    /// Whether the current user is registered in one of this ride's groups. False if anonymous.
    required bool registered,

    /// The team's RIDE tags the ride carries, sorted by label. Empty when it carries none.
    required List<TagDto> tags,

    /// Whether the ride is soft-deleted
    required bool deleted,

    /// Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.
    double? elevationGain,

    /// Surface type, from the same route as distance. Null when no route is set anywhere.
    String? surfaceType,

    /// Start place
    PlaceDetailDto? startPlace,

    /// End place
    PlaceDetailDto? endPlace,

    /// The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.
    RideWeatherSummaryDto? weather,

    /// Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailLightUrl,

    /// Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailDarkUrl,

    /// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailUrl,

    /// Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere.
    double? distance,

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

    /// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
    String? excerpt,

    /// Publication timestamp
    String? publishAt,
  }) = PublicationDtoRide;

  @FreezedUnionValue('POST')
  const factory PublicationDto.post({
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

    /// Publication date/time
    required String dateTime,

    /// IANA zone the post's times were entered in and read in: the team's at its last save. dateTime, publishAt are rendezvous in this zone.
    required String timezone,

    /// Publication status
    required String status,

    /// Visibility level
    required String visibility,

    /// Whether the post is soft-deleted
    required bool deleted,

    /// Whether the post is signed by the team rather than by its author. Readers are then not told who wrote it: createdBy is absent unless the caller administers the team or wrote the post.
    required bool signedAsTeam,

    /// The team's POST tags the post carries, sorted by label. Empty when it carries none.
    required List<TagDto> tags,

    /// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
    String? excerpt,

    /// URL template of the post's first image, the one a card shows. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailUrl,

    /// Publication timestamp
    String? publishAt,

    /// Creation timestamp
    String? createdAt,

    /// Number of comments, replies included. Absent when the caller may not read the comments of this post — comments are members-only, so an outsider is told nothing, not even zero.
    int? commentCount,

    /// Who wrote the post. Absent when the post is signed by the team (signedAsTeam) and the caller neither administers the team nor wrote it — render the team instead.
    PublicUserDto? createdBy,
  }) = PublicationDtoPost;

  @FreezedUnionValue('TRIP')
  const factory PublicationDto.trip({
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

    /// Trip start date/time
    required String dateTime,

    /// IANA zone the trip's times were entered in and read in: its first stage's, else its route's, else the team's. dateTime, endDate, endDateTime and publishAt are rendezvous in this zone.
    required String timezone,

    /// When the trip is over, computed by the server: the end of its latest stage — its departure plus its route's length at its average speed, or plus 3 hours when the stage has no speed or no route — or dateTime plus 3 hours for a trip with no stage. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read.
    required String endDateTime,

    /// Publication status
    required String status,

    /// Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.
    required bool finished,

    /// Visibility level
    required String visibility,

    /// Number of participants
    required int participantCount,

    /// Number of stages
    required int stageCount,

    /// Trip stages
    required List<TripStageDto> stages,

    /// The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants.
    required List<PublicUserDto> participants,

    /// Whether the trip is soft-deleted
    required bool deleted,

    /// Whether the current user is registered for this trip. False if anonymous.
    required bool registered,

    /// The team's TRIP tags the trip carries, sorted by label. Empty when it carries none.
    required List<TagDto> tags,

    /// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
    String? excerpt,

    /// Date of the last stage — the day the trip ends. Null when the trip has no stage, in which case it lasts a day and dateTime is both ends.
    String? endDate,

    /// Publication timestamp
    String? publishAt,

    /// Creation timestamp
    String? createdAt,

    /// Route slug
    String? routeSlug,

    /// Distance in metres over every stage that has a route. Null when no stage has one — an unrouted trip has no distance, which is not the same as a distance of zero.
    double? totalDistance,

    /// Elevation gain in metres over every stage that has a route. Null when no stage has one.
    double? totalElevationGain,

    /// Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailLightUrl,

    /// Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailDarkUrl,

    /// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailUrl,

    /// Number of comments, replies included. Absent when the caller may not read the comments of this trip — comments are members-only, so an outsider is told nothing, not even zero.
    int? commentCount,

    /// The weather line of a list card: that of the trip's next leg — its first stage still to leave, else the trip itself when it has no stage — at the start of its route, over the window from its departure to its estimated arrival. Absent when there is nothing to show — trip finished, draft or cancelled, next stage without a route, forecast not in cache yet — and on the trip's own detail, which reads getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE.
    RideWeatherSummaryDto? weather,
  }) = PublicationDtoTrip;

  factory PublicationDto.fromJson(Map<String, Object?> json) =>
      _$PublicationDtoFromJson(json);
}
