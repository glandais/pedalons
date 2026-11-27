// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_key_count_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminKeyCountDto _$AdminKeyCountDtoFromJson(Map<String, dynamic> json) =>
    _AdminKeyCountDto(
      key: json['key'] as String,
      count: (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$AdminKeyCountDtoToJson(_AdminKeyCountDto instance) =>
    <String, dynamic>{'key': instance.key, 'count': instance.count};
