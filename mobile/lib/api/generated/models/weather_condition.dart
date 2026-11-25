// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum WeatherCondition {
  @JsonValue('CLEAR')
  clear('CLEAR'),
  @JsonValue('MOSTLY_CLEAR')
  mostlyClear('MOSTLY_CLEAR'),
  @JsonValue('PARTLY_CLOUDY')
  partlyCloudy('PARTLY_CLOUDY'),
  @JsonValue('OVERCAST')
  overcast('OVERCAST'),
  @JsonValue('FOG')
  fog('FOG'),
  @JsonValue('DRIZZLE')
  drizzle('DRIZZLE'),
  @JsonValue('RAIN')
  rain('RAIN'),
  @JsonValue('HEAVY_RAIN')
  heavyRain('HEAVY_RAIN'),
  @JsonValue('FREEZING_RAIN')
  freezingRain('FREEZING_RAIN'),
  @JsonValue('SHOWERS')
  showers('SHOWERS'),
  @JsonValue('SNOW')
  snow('SNOW'),
  @JsonValue('THUNDERSTORM')
  thunderstorm('THUNDERSTORM'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const WeatherCondition(this.json);

  factory WeatherCondition.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<WeatherCondition> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
