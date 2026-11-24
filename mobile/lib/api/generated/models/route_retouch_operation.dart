// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum RouteRetouchOperation {
  @JsonValue('RESIZE')
  resize('RESIZE'),
  @JsonValue('MOVE_END')
  moveEnd('MOVE_END'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const RouteRetouchOperation(this.json);

  factory RouteRetouchOperation.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<RouteRetouchOperation> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
