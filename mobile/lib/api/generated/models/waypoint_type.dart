// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum WaypointType {
  @JsonValue('REGROUP')
  regroup('REGROUP'),
  @JsonValue('SUPPLY')
  supply('SUPPLY'),
  @JsonValue('WATER')
  water('WATER'),
  @JsonValue('CAFE')
  cafe('CAFE'),
  @JsonValue('TOILETS')
  toilets('TOILETS'),
  @JsonValue('DANGER')
  danger('DANGER'),
  @JsonValue('SUMMIT')
  summit('SUMMIT'),
  @JsonValue('VIEWPOINT')
  viewpoint('VIEWPOINT'),
  @JsonValue('BIKE_SHOP')
  bikeShop('BIKE_SHOP'),
  @JsonValue('REAL_START')
  realStart('REAL_START'),
  @JsonValue('SPLIT')
  split('SPLIT'),
  @JsonValue('INFO')
  info('INFO'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const WaypointType(this.json);

  factory WaypointType.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<WaypointType> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
