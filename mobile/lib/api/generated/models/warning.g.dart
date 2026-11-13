// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'warning.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Warning _$WarningFromJson(Map<String, dynamic> json) => _Warning(
  code: json['code'] as String?,
  message: json['message'] as String?,
  fromM: (json['from_m'] as num?)?.toDouble(),
  toM: (json['to_m'] as num?)?.toDouble(),
);

Map<String, dynamic> _$WarningToJson(_Warning instance) => <String, dynamic>{
  'code': instance.code,
  'message': instance.message,
  'from_m': instance.fromM,
  'to_m': instance.toM,
};
