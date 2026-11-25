// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum WeatherStatus {
  @JsonValue('OK')
  ok('OK'),
  @JsonValue('STALE')
  stale('STALE'),
  @JsonValue('NOT_YET_AVAILABLE')
  notYetAvailable('NOT_YET_AVAILABLE'),
  @JsonValue('UNAVAILABLE')
  unavailable('UNAVAILABLE'),
  @JsonValue('NO_LOCATION')
  noLocation('NO_LOCATION'),
  @JsonValue('OUT_OF_RANGE')
  outOfRange('OUT_OF_RANGE'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const WeatherStatus(this.json);

  factory WeatherStatus.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<WeatherStatus> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
