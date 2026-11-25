// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum GpsOAuthVersion {
  @JsonValue('OAUTH1')
  oauth1('OAUTH1'),
  @JsonValue('OAUTH2')
  oauth2('OAUTH2'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const GpsOAuthVersion(this.json);

  factory GpsOAuthVersion.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<GpsOAuthVersion> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
