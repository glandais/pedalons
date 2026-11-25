// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum TeamWebhookKind {
  @JsonValue('SLACK')
  slack('SLACK'),
  @JsonValue('DISCORD')
  discord('DISCORD'),
  @JsonValue('MATTERMOST')
  mattermost('MATTERMOST'),
  @JsonValue('GENERIC')
  generic('GENERIC'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const TeamWebhookKind(this.json);

  factory TeamWebhookKind.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<TeamWebhookKind> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
