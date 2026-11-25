// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum NotificationChannel {
  @JsonValue('IN_APP')
  inApp('IN_APP'),
  @JsonValue('EMAIL')
  email('EMAIL'),
  @JsonValue('PUSH')
  push('PUSH'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const NotificationChannel(this.json);

  factory NotificationChannel.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<NotificationChannel> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
