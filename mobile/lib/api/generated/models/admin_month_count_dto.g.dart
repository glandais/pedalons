// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_month_count_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminMonthCountDto _$AdminMonthCountDtoFromJson(Map<String, dynamic> json) =>
    _AdminMonthCountDto(
      month: json['month'] as String,
      count: (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$AdminMonthCountDtoToJson(_AdminMonthCountDto instance) =>
    <String, dynamic>{'month': instance.month, 'count': instance.count};
