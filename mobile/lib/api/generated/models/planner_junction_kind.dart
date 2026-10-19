// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum PlannerJunctionKind {
  @JsonValue('CONTROL')
  control('CONTROL'),
  @JsonValue('JOIN')
  join('JOIN'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const PlannerJunctionKind(this.json);

  factory PlannerJunctionKind.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<PlannerJunctionKind> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
