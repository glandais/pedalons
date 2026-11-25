// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum TeamSortBy {
  @JsonValue('NAME')
  name('NAME'),
  @JsonValue('MEMBER_COUNT')
  memberCount('MEMBER_COUNT'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const TeamSortBy(this.json);

  factory TeamSortBy.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<TeamSortBy> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
