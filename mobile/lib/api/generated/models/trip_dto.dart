// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'media_dto.dart';
import 'public_user_dto.dart';
import 'publication_dto.dart';
import 'publication_type.dart';
import 'ride_weather_summary_dto.dart';
import 'status.dart';
import 'tag_dto.dart';
import 'team_publication_dto.dart';
import 'trip_stage_dto.dart';
import 'visibility.dart';

part 'trip_dto.freezed.dart';
part 'trip_dto.g.dart';

/// Trip data
@Freezed()
abstract class TripDto with _$TripDto {
  const factory TripDto({
    /// Type
    required String type,

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
  }) = _TripDto;

  factory TripDto.fromJson(Map<String, Object?> json) =>
      _$TripDtoFromJson(json);
}
