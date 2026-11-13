// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_node_type.dart';

part 'json_node.freezed.dart';
part 'json_node.g.dart';

@Freezed()
abstract class JsonNode with _$JsonNode {
  const factory JsonNode({
    bool? empty,
    bool? valueNode,
    bool? containerNode,
    bool? missingNode,
    bool? array,
    @JsonKey(name: 'object') bool? objectField,
    JsonNodeType? nodeType,
    bool? pojo,
    bool? number,
    bool? integralNumber,
    bool? floatingPointNumber,
    bool? short,
    @JsonKey(name: 'int') bool? intField,
    bool? long,
    bool? float,
    @JsonKey(name: 'double') bool? doubleField,
    bool? bigDecimal,
    bool? bigInteger,
    bool? textual,
    bool? boolean,
    @JsonKey(name: 'null') bool? nullField,
    bool? binary,
  }) = _JsonNode;

  factory JsonNode.fromJson(Map<String, Object?> json) =>
      _$JsonNodeFromJson(json);
}
