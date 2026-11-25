// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum RetouchKind {
  @JsonValue('SHORTEN')
  shorten('SHORTEN'),
  @JsonValue('LENGTHEN')
  lengthen('LENGTHEN'),
  @JsonValue('MOVE_END')
  moveEnd('MOVE_END'),
  @JsonValue('TRUNCATE')
  truncate('TRUNCATE'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const RetouchKind(this.json);

  factory RetouchKind.fromJson(String json) =>
      values.firstWhere((e) => e.json == json, orElse: () => $unknown);

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<RetouchKind> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
