// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum RouterEngineOption {
  @JsonValue('USE_ROADS')
  useRoads('USE_ROADS'),
  @JsonValue('AVOID_MAIN_ROADS')
  avoidMainRoads('AVOID_MAIN_ROADS'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const RouterEngineOption(this.json);

  factory RouterEngineOption.fromJson(String json) =>
      values.firstWhere((e) => e.json == json, orElse: () => $unknown);

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<RouterEngineOption> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
