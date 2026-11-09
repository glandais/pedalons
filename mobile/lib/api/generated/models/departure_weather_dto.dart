// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'weather_conditions_dto.dart';
import 'weather_status.dart';

part 'departure_weather_dto.freezed.dart';
part 'departure_weather_dto.g.dart';

/// The weather at the departure point when the ride, or a trip stage, leaves
@Freezed()
abstract class DepartureWeatherDto with _$DepartureWeatherDto {
  const factory DepartureWeatherDto({
    /// State of the departure forecast. conditions is present for OK and STALE only.
    required String status,

    /// The forecast of the departure hour, for OK and STALE
    WeatherConditionsDto? conditions,

    /// Sunrise at the meeting point, on the departure's local date
    String? sunrise,

    /// Sunset at the meeting point, on the departure's local date
    String? sunset,

    /// When the forecast of the meeting point was last fetched
    String? fetchedAt,
  }) = _DepartureWeatherDto;

  factory DepartureWeatherDto.fromJson(Map<String, Object?> json) =>
      _$DepartureWeatherDtoFromJson(json);
}
