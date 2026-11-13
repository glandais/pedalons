// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

@JsonEnum()
enum JsonNodeType {
  @JsonValue('ARRAY')
  array('ARRAY'),
  @JsonValue('BINARY')
  binary('BINARY'),
  @JsonValue('BOOLEAN')
  boolean('BOOLEAN'),
  @JsonValue('MISSING')
  missing('MISSING'),

  /// The name has been replaced because it contains a keyword. Original name: `NULL`.
  @JsonValue('NULL')
  valueNull('NULL'),
  @JsonValue('NUMBER')
  number('NUMBER'),

  /// The name has been replaced because it contains a keyword. Original name: `OBJECT`.
  @JsonValue('OBJECT')
  valueObject('OBJECT'),
  @JsonValue('POJO')
  pojo('POJO'),
  @JsonValue('STRING')
  string('STRING'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const JsonNodeType(this.json);

  factory JsonNodeType.fromJson(String json) => values.firstWhere(
    (e) => e.json == json,
    orElse: () => $unknown,
  );

  final String? json;

  String toJson() => json ?? 'null';

  @override
  String toString() => json ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<JsonNodeType> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
