// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum ReportStatus {
  @JsonValue('OPEN')
  open('OPEN'),
  @JsonValue('REMOVED')
  removed('REMOVED'),
  @JsonValue('DISMISSED')
  dismissed('DISMISSED'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ReportStatus(this.json);

  factory ReportStatus.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<ReportStatus> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
