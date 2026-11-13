// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'json_node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JsonNode _$JsonNodeFromJson(Map<String, dynamic> json) => _JsonNode(
  empty: json['empty'] as bool?,
  valueNode: json['valueNode'] as bool?,
  containerNode: json['containerNode'] as bool?,
  missingNode: json['missingNode'] as bool?,
  array: json['array'] as bool?,
  objectField: json['object'] as bool?,
  nodeType: json['nodeType'] == null
      ? null
      : JsonNodeType.fromJson(json['nodeType'] as String),
  pojo: json['pojo'] as bool?,
  number: json['number'] as bool?,
  integralNumber: json['integralNumber'] as bool?,
  floatingPointNumber: json['floatingPointNumber'] as bool?,
  short: json['short'] as bool?,
  intField: json['int'] as bool?,
  long: json['long'] as bool?,
  float: json['float'] as bool?,
  doubleField: json['double'] as bool?,
  bigDecimal: json['bigDecimal'] as bool?,
  bigInteger: json['bigInteger'] as bool?,
  textual: json['textual'] as bool?,
  boolean: json['boolean'] as bool?,
  nullField: json['null'] as bool?,
  binary: json['binary'] as bool?,
);

Map<String, dynamic> _$JsonNodeToJson(_JsonNode instance) => <String, dynamic>{
  'empty': instance.empty,
  'valueNode': instance.valueNode,
  'containerNode': instance.containerNode,
  'missingNode': instance.missingNode,
  'array': instance.array,
  'object': instance.objectField,
  'nodeType': instance.nodeType?.toJson(),
  'pojo': instance.pojo,
  'number': instance.number,
  'integralNumber': instance.integralNumber,
  'floatingPointNumber': instance.floatingPointNumber,
  'short': instance.short,
  'int': instance.intField,
  'long': instance.long,
  'float': instance.float,
  'double': instance.doubleField,
  'bigDecimal': instance.bigDecimal,
  'bigInteger': instance.bigInteger,
  'textual': instance.textual,
  'boolean': instance.boolean,
  'null': instance.nullField,
  'binary': instance.binary,
};
