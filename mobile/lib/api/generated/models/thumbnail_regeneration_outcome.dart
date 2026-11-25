// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum ThumbnailRegenerationOutcome {
  @JsonValue('PENDING')
  pending('PENDING'),
  @JsonValue('REGENERATED')
  regenerated('REGENERATED'),
  @JsonValue('FAILED')
  failed('FAILED'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ThumbnailRegenerationOutcome(this.json);

  factory ThumbnailRegenerationOutcome.fromJson(String json) =>
      values.firstWhere(
        (e) => e.json == json,
        orElse: () => $unknown,
      );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<ThumbnailRegenerationOutcome> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
