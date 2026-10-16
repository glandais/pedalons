// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'weather_condition.dart';
import 'weather_rain_alert_dto.dart';
import 'weather_status.dart';
import 'wind_dto.dart';

part 'ride_weather_summary_dto.freezed.dart';
part 'ride_weather_summary_dto.g.dart';

/// A ride's weather on a card, at the meeting point, over the window from the departure to the estimated arrival of the last group — or a trip stage's, over its checkpoints. Only OK, STALE and NOT_YET_AVAILABLE are ever sent; for NOT_YET_AVAILABLE only status and availableFrom are set.
@Freezed()
abstract class RideWeatherSummaryDto with _$RideWeatherSummaryDto {
  const factory RideWeatherSummaryDto({
    /// OK, STALE or NOT_YET_AVAILABLE
    required String status,

    /// For NOT_YET_AVAILABLE: when the forecast opens, seven days before the departure
    String? availableFrom,

    /// WMO code at the departure hour
    int? weatherCode,

    /// weatherCode folded into a condition, same table as WeatherConditionsDto.condition
    String? condition,

    /// Whether the departure itself (not the round model hour read for it) is between sunrise and sunset
    bool? daylight,

    /// Air temperature at the departure hour, °C
    double? temperature,

    /// Lowest temperature over the window, °C
    double? temperatureMin,

    /// Highest temperature over the window, °C
    double? temperatureMax,

    /// Highest probability of precipitation over the window, %. Absent when the model gives none.
    int? maxPrecipitationProbability,

    /// Wind at the departure hour
    WindDto? wind,

    /// The first hour of the window with rain likely (50 % or more). Its distance is absent on a ride's summary, present on a trip stage's (the checkpoint's)
    WeatherRainAlertDto? rainAlert,

    /// IANA zone the times of this summary (rain alert) are read in, as rendezvous with no zone mention. Set on a trip's card, where it is its next stage's zone — not TripDto.timezone, the first stage's. Absent elsewhere: the owner's timezone (RideDto, TripStageDto) applies.
    String? timezone,
  }) = _RideWeatherSummaryDto;

  factory RideWeatherSummaryDto.fromJson(Map<String, Object?> json) =>
      _$RideWeatherSummaryDtoFromJson(json);
}
