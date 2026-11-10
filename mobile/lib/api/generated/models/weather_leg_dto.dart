// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'departure_weather_dto.dart';
import 'instant.dart';
import 'ride_weather_summary_dto.dart';
import 'weather_checkpoint_dto.dart';
import 'weather_rain_alert_dto.dart';
import 'weather_status.dart';
import 'wind_dto.dart';
import 'wind_exposure_dto.dart';
import 'wind_segment_dto.dart';

part 'weather_leg_dto.freezed.dart';
part 'weather_leg_dto.g.dart';

/// The weather along one ridden route: a group of a ride, or a stage of a trip. Passages are estimated from startTime at averageSpeed.
@Freezed()
abstract class WeatherLegDto with _$WeatherLegDto {
  const factory WeatherLegDto({
    /// State of this leg's forecast. NO_LOCATION when the leg has no route to sample: then no checkpoint, no segment. NOT_YET_AVAILABLE when it leaves beyond the seven-day horizon: checkpoints and times without weather, and availableFrom. OUT_OF_RANGE for a trip stage already over (its estimated end passed): nothing to show.
    required String status,

    /// When the leg leaves
    required String startTime,

    /// Speed used for the passages, km/h
    required double averageSpeed,

    /// Whether averageSpeed is the 25 km/h default, the group or stage having none — to be said on screen
    required bool speedIsDefault,

    /// Length of the leg's route, metres
    required double distance,

    /// Estimated arrival
    required String arrivalTime,

    /// Forecast points, start to finish
    required List<WeatherCheckpointDto> checkpoints,

    /// The wind stretch by stretch, from one checkpoint to the next
    required List<WindSegmentDto> segments,

    /// Distance ridden against, across and with the wind
    required WindExposureDto windExposure,

    /// The ride group (TSID). Absent for a ride without groups — the leg rides the ride's own route — and for a trip's legs, which TripStageWeatherDto.stageId names.
    String? groupId,

    /// For NOT_YET_AVAILABLE: when this leg's forecast opens, seven days before it leaves
    String? availableFrom,

    /// The oldest fetch among the forecasts this leg reads
    String? fetchedAt,

    /// The leg's dominant wind: circular mean of the directions, mean speed, highest gust
    WindDto? prevailingWind,

    /// The first checkpoint where rain becomes likely, if any
    WeatherRainAlertDto? rainAlert,

    /// The leg's weather in one line, for its card: the first checkpoint's hour, the extremes over the checkpoints, the rain alert — as TripStageWeatherDto.summary for a stage. Present when status is OK, STALE or NOT_YET_AVAILABLE (then status and availableFrom only).
    RideWeatherSummaryDto? summary,

    /// For a ride's leg: the weather at the ride's meeting point when this group leaves (startTime), sunrise and sunset included — RideWeatherDto.departure is the same at the ride's own time. Same states: conditions for OK and STALE only, UNAVAILABLE when the cache has no hour near the group's start, NOT_YET_AVAILABLE when the group leaves beyond the horizon. Absent on a trip's legs, whose departure TripStageWeatherDto.departure carries.
    DepartureWeatherDto? departure,
  }) = _WeatherLegDto;

  factory WeatherLegDto.fromJson(Map<String, Object?> json) =>
      _$WeatherLegDtoFromJson(json);
}
