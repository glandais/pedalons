// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'calendar_event_type.dart';
import 'instant.dart';
import 'status.dart';

part 'calendar_event_dto.freezed.dart';
part 'calendar_event_dto.g.dart';

/// Calendar event data
@Freezed()
abstract class CalendarEventDto with _$CalendarEventDto {
  const factory CalendarEventDto({
    /// Event ID (TSID)
    required String id,

    /// Event title
    required String title,

    /// Event start date/time
    required String start,

    /// Is all-day event
    required bool allDay,

    /// Event type
    required String type,

    /// Team slug
    required String teamSlug,

    /// Team name
    required String teamName,

    /// Entity slug (ride or stage)
    required String entitySlug,

    /// Whether the current user is registered to this ride, or to the trip this stage belongs to. False for an anonymous caller.
    required bool registered,

    /// Publication status of the ride or stage
    required String status,

    /// IANA zone of the ride or stage, as RideDto.timezone / TripStageDto.timezone: start and end are rendezvous in it. The calendar grid itself stays in the reader's zone.
    required String timezone,

    /// Whether the ride or stage is over, computed by the server when the response is built: its end (or its start, when it has no end) has passed. Independent of status.
    required bool finished,

    /// Event end date/time: the end the server computes for a ride (its latest group at its pace, 3 hours when nothing tells) or for a trip stage (its route at its pace, likewise) — the same as RideDto.endDateTime. On an all-day stage it is still that instant: the stage occupies every day up to it.
    String? end,

    /// Parent trip slug (for stages only)
    String? tripSlug,

    /// Name of the meeting place, null when the ride or stage has no start place
    String? startPlaceName,

    /// Distance in meters of the attached route, null when there is no route
    double? distance,

    /// Total elevation gain in meters of the attached route, null when there is no route
    double? elevationGain,

    /// Thumbnail image URL template (contains a {size} placeholder), light variant preferred. Falls back to the route's thumbnail when the ride or stage has none of its own. For a client that renders one picture and does not follow a colour scheme; prefer thumbnailLightUrl/thumbnailDarkUrl otherwise. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailUrl,

    /// Light-scheme thumbnail image URL template (contains a {size} placeholder). Null when the event's picture exists only in a dark variant. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailLightUrl,

    /// Dark-scheme thumbnail image URL template (contains a {size} placeholder). Null when the event's picture exists only in a light variant. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailDarkUrl,

    /// Name of the ride group the current user joined. Null when not registered, and always null for trip stages, which have no groups.
    String? groupName,
  }) = _CalendarEventDto;

  factory CalendarEventDto.fromJson(Map<String, Object?> json) =>
      _$CalendarEventDtoFromJson(json);
}
