// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum CompassPoint {
  @JsonValue('N')
  n('N'),
  @JsonValue('NE')
  ne('NE'),
  @JsonValue('E')
  e('E'),
  @JsonValue('SE')
  se('SE'),
  @JsonValue('S')
  s('S'),
  @JsonValue('SW')
  sw('SW'),
  @JsonValue('W')
  w('W'),
  @JsonValue('NW')
  nw('NW'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const CompassPoint(this.json);

  factory CompassPoint.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<CompassPoint> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
