// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum ModerationAction {
  @JsonValue('REMOVE_CONTENT')
  removeContent('REMOVE_CONTENT'),
  @JsonValue('DISMISS')
  dismiss('DISMISS'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ModerationAction(this.json);

  factory ModerationAction.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<ModerationAction> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
