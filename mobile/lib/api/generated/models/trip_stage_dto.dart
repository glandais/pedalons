// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'media_dto.dart';
import 'place_detail_dto.dart';
import 'route_dto.dart';

part 'trip_stage_dto.freezed.dart';
part 'trip_stage_dto.g.dart';

/// Trip stage information
@Freezed()
abstract class TripStageDto with _$TripStageDto {
  const factory TripStageDto({
    /// Stage ID (TSID)
    required String id,

    /// Stage slug
    required String slug,

    /// Stage name
    required String name,

    /// Stage date/time
    required String dateTime,

    /// IANA zone the stage's time was entered in and is read in: its start place's, else its route's, else the previous stage's, else the trip route's, else the team's. A stage may differ from its trip.
    required String timezone,

    /// Stage media
    required MediaDto media,

    /// Sort order
    required int sortOrder,

    /// Position of this stage among the trip's live stages, 1-based — the 'Day 2' of a stage header. Unlike sortOrder, which is a persisted rank that may have gaps, this is a rank a client can print.
    required int stageIndex,

    /// How many live stages the trip has — the '/ 5' of 'Day 2 / 5'.
    required int stageCount,

    /// Average speed in km/h
    double? averageSpeed,

    /// Route
    RouteDto? route,

    /// Start place
    PlaceDetailDto? startPlace,

    /// End place
    PlaceDetailDto? endPlace,

    /// Number of comments on the stage's own thread. Absent when the caller cannot read comments (not a member of the team), like TripDto.commentCount.
    int? commentCount,

    /// When the stage is expected to end: dateTime plus its route's length at its averageSpeed. Absent when it has no route or no averageSpeed — no default speed here. Known whatever the forecast window, unlike WeatherLegDto.arrivalTime.
    String? estimatedArrival,

    /// Minutes from dateTime to estimatedArrival, rounded. Absent when estimatedArrival is.
    int? estimatedDurationMinutes,
  }) = _TripStageDto;

  factory TripStageDto.fromJson(Map<String, Object?> json) =>
      _$TripStageDtoFromJson(json);
}
