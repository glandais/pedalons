// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'trip_stage_weather_dto.dart';
import 'weather_attribution_dto.dart';
import 'weather_status.dart';

part 'trip_weather_dto.freezed.dart';
part 'trip_weather_dto.g.dart';

/// A trip's weather, stage by stage: each stage's route at its estimated passages. Read from the server's cache only — the forecast is refreshed in the background, never on request.
@Freezed()
abstract class TripWeatherDto with _$TripWeatherDto {
  const factory TripWeatherDto({
    /// Overall state, over the stages not over yet. OK and STALE (shown, flagged as old) carry a forecast for at least one stage; NOT_YET_AVAILABLE (every stage with a route is beyond the horizon) comes with availableFrom; UNAVAILABLE (nothing in cache yet, or the provider failing) offers to retry; NO_LOCATION (no stage not over yet has a route) is worth a word to the organisers only; OUT_OF_RANGE (finished, cancelled, draft) shows nothing. Each stage also has its own, in its leg.
    required String status,

    /// One per live stage, in stage order (as TripDto.stages), stages already over (their estimated end passed) included with leg.status OUT_OF_RANGE; a stage under way keeps its forecast; a single one without stageId for a trip without stages. Empty when the trip is not published.
    required List<TripStageWeatherDto> stages,

    /// The credit the forecast's licence asks for
    required WeatherAttributionDto attribution,

    /// For NOT_YET_AVAILABLE: when the first forecast opens, seven days before the first stage with a route leaves
    String? availableFrom,

    /// The oldest fetch among the forecasts read
    String? fetchedAt,
  }) = _TripWeatherDto;

  factory TripWeatherDto.fromJson(Map<String, Object?> json) =>
      _$TripWeatherDtoFromJson(json);
}
