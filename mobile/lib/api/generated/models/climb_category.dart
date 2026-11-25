// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum ClimbCategory {
  @JsonValue('HC')
  hc('HC'),
  @JsonValue('CAT1')
  cat1('CAT1'),
  @JsonValue('CAT2')
  cat2('CAT2'),
  @JsonValue('CAT3')
  cat3('CAT3'),
  @JsonValue('CAT4')
  cat4('CAT4'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ClimbCategory(this.json);

  factory ClimbCategory.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<ClimbCategory> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
