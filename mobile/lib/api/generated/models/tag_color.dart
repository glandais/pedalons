// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum TagColor {
  @JsonValue('INDIGO')
  indigo('INDIGO'),
  @JsonValue('BLUE')
  blue('BLUE'),
  @JsonValue('GREEN')
  green('GREEN'),
  @JsonValue('RED')
  red('RED'),
  @JsonValue('YELLOW')
  yellow('YELLOW'),
  @JsonValue('ORANGE')
  orange('ORANGE'),
  @JsonValue('GRAPE')
  grape('GRAPE'),
  @JsonValue('TEAL')
  teal('TEAL'),
  @JsonValue('GRAY')
  gray('GRAY'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const TagColor(this.json);

  factory TagColor.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<TagColor> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
