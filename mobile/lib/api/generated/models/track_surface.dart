// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum TrackSurface {
  @JsonValue('PAVED')
  paved('PAVED'),
  @JsonValue('PAVED_ROUGH')
  pavedRough('PAVED_ROUGH'),
  @JsonValue('GRAVEL')
  gravel('GRAVEL'),
  @JsonValue('DIRT')
  dirt('DIRT'),
  @JsonValue('PATH')
  path('PATH'),
  @JsonValue('UNKNOWN')
  unknown('UNKNOWN'),
  @JsonValue('OFF_NETWORK')
  offNetwork('OFF_NETWORK'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const TrackSurface(this.json);

  factory TrackSurface.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<TrackSurface> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
