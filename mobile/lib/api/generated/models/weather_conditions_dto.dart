// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'weather_condition.dart';
import 'wind_dto.dart';

part 'weather_conditions_dto.freezed.dart';
part 'weather_conditions_dto.g.dart';

/// The forecast of one hour at one place
@Freezed()
abstract class WeatherConditionsDto with _$WeatherConditionsDto {
  const factory WeatherConditionsDto({
    /// The forecast hour used: the one nearest the moment asked about
    required String time,

    /// WMO weather interpretation code, as the model gives it. condition is its folding; a client reads condition, this is for the curious.
    required int weatherCode,

    /// weatherCode folded into what a rider decides on. WMO code → condition: 0 CLEAR; 1 MOSTLY_CLEAR; 2 PARTLY_CLOUDY; 3 OVERCAST; 45, 48 FOG; 51, 53, 55 DRIZZLE; 56, 57, 66, 67 FREEZING_RAIN; 61, 63 RAIN; 65 HEAVY_RAIN; 71, 73, 75, 77, 85, 86 SNOW; 80, 81, 82 SHOWERS; 95, 96, 99 THUNDERSTORM; any other OVERCAST. A client meeting a value it does not know shows a plain cloud.
    required String condition,

    /// Whether the moment asked about (the departure, the checkpoint's passage) falls between sunrise and sunset at that place — not time, the round model hour. Picks the day or night icon
    required bool daylight,

    /// Air temperature at 2 m, °C
    required double temperature,

    /// Felt temperature (wind chill, humidity), °C
    required double apparentTemperature,

    /// Precipitation over the hour (rain, showers, snow), mm
    required double precipitation,

    /// Wind of that hour
    required WindDto wind,

    /// Probability of precipitation, % (0–100). Absent when the model gives none.
    int? precipitationProbability,
  }) = _WeatherConditionsDto;

  factory WeatherConditionsDto.fromJson(Map<String, Object?> json) =>
      _$WeatherConditionsDtoFromJson(json);
}
