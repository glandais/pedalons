// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum WindDirection {
  @JsonValue('NORTH')
  north('NORTH'),
  @JsonValue('NORTH_EAST')
  northEast('NORTH_EAST'),
  @JsonValue('EAST')
  east('EAST'),
  @JsonValue('SOUTH_EAST')
  southEast('SOUTH_EAST'),
  @JsonValue('SOUTH')
  south('SOUTH'),
  @JsonValue('SOUTH_WEST')
  southWest('SOUTH_WEST'),
  @JsonValue('WEST')
  west('WEST'),
  @JsonValue('NORTH_WEST')
  northWest('NORTH_WEST'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const WindDirection(this.json);

  factory WindDirection.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<WindDirection> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
