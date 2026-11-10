// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'departure_weather_dto.dart';
import 'instant.dart';
import 'weather_attribution_dto.dart';
import 'weather_leg_dto.dart';
import 'weather_status.dart';

part 'ride_weather_dto.freezed.dart';
part 'ride_weather_dto.g.dart';

/// A ride's weather, for its detail page: the meeting point at departure, then one leg per group. Read from the server's cache only — the forecast is refreshed in the background, never on request.
@Freezed()
abstract class RideWeatherDto with _$RideWeatherDto {
  const factory RideWeatherDto({
    /// Overall state. OK and STALE (shown, flagged as old) carry the forecast; NOT_YET_AVAILABLE comes with availableFrom; UNAVAILABLE (nothing in cache yet, or the provider failing) offers to retry; NO_LOCATION is worth a word to the organisers only; OUT_OF_RANGE (over — its last group back, the ride's estimated end —, cancelled) shows nothing. A ride that has left but whose groups are still out, or still to leave, keeps its forecast.
    required String status,

    /// The meeting point when the ride leaves (its dateTime). Each leg carries its own, at the group's start.
    required DepartureWeatherDto departure,

    /// One per group, in group order; a single one without groupId for a ride without groups. Empty for OUT_OF_RANGE, NO_LOCATION and NOT_YET_AVAILABLE.
    required List<WeatherLegDto> legs,

    /// The credit the forecast's licence asks for
    required WeatherAttributionDto attribution,

    /// For NOT_YET_AVAILABLE: when the forecast opens, seven days before the departure
    String? availableFrom,

    /// The oldest fetch among the forecasts read
    String? fetchedAt,
  }) = _RideWeatherDto;

  factory RideWeatherDto.fromJson(Map<String, Object?> json) =>
      _$RideWeatherDtoFromJson(json);
}
