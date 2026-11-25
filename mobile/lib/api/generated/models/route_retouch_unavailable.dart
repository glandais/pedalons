// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum RouteRetouchUnavailable {
  @JsonValue('NOT_ALLOWED')
  notAllowed('NOT_ALLOWED'),
  @JsonValue('ENGINE_UNAVAILABLE')
  engineUnavailable('ENGINE_UNAVAILABLE'),
  @JsonValue('NOT_READY')
  notReady('NOT_READY'),
  @JsonValue('UNSUPPORTED')
  unsupported('UNSUPPORTED'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const RouteRetouchUnavailable(this.json);

  factory RouteRetouchUnavailable.fromJson(String json) =>
      values.firstWhere((e) => e.json == json, orElse: () => $unknown);

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<RouteRetouchUnavailable> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
