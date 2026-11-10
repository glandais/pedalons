// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'departure_weather_dto.dart';
import 'ride_weather_summary_dto.dart';
import 'weather_leg_dto.dart';

part 'trip_stage_weather_dto.freezed.dart';
part 'trip_stage_weather_dto.g.dart';

/// One stage of a trip: its weather in one line, and along its route
@Freezed()
abstract class TripStageWeatherDto with _$TripStageWeatherDto {
  const factory TripStageWeatherDto({
    /// The stage's route, at its estimated passages (stage speed, else 25 km/h)
    required WeatherLegDto leg,

    /// The weather when the stage leaves, at its first forecast point: conditions, sunrise and sunset, as RideWeatherDto.departure for a ride. OUT_OF_RANGE once the stage is over (its estimated end passed), NO_LOCATION without a route, NOT_YET_AVAILABLE beyond the horizon.
    required DepartureWeatherDto departure,

    /// The stage (TSID), as TripStageDto.id. Absent for the single leg of a trip without stages, which rides the trip's own route at its own time.
    String? stageId,

    /// The stage's weather in one line, for its card: the first checkpoint's hour, the extremes over the checkpoints, the rain alert. Present when leg.status is OK, STALE or NOT_YET_AVAILABLE (then status and availableFrom only).
    RideWeatherSummaryDto? summary,
  }) = _TripStageWeatherDto;

  factory TripStageWeatherDto.fromJson(Map<String, Object?> json) =>
      _$TripStageWeatherDtoFromJson(json);
}
