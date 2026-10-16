// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum GpsAutoSyncState {
  @JsonValue('OFF')
  off('OFF'),
  @JsonValue('UP_TO_DATE')
  upToDate('UP_TO_DATE'),
  @JsonValue('PENDING')
  pending('PENDING'),
  @JsonValue('FAILING')
  failing('FAILING'),
  @JsonValue('RECONNECT_REQUIRED')
  reconnectRequired('RECONNECT_REQUIRED'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const GpsAutoSyncState(this.json);

  factory GpsAutoSyncState.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<GpsAutoSyncState> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
