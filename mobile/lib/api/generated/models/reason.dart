// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum Reason {
  @JsonValue('ABSENT')
  absent('ABSENT'),
  @JsonValue('STALE')
  stale('STALE'),
  @JsonValue('CHANGED')
  changed('CHANGED'),
  @JsonValue('EXPIRING')
  expiring('EXPIRING'),
  @JsonValue('FORCED')
  forced('FORCED'),
  @JsonValue('CURRENT')
  current('CURRENT'),
  @JsonValue('TEAM_GONE')
  teamGone('TEAM_GONE'),
  @JsonValue('PLANNER_OFF')
  plannerOff('PLANNER_OFF'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const Reason(this.json);

  factory Reason.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<Reason> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
