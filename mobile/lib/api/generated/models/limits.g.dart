// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'limits.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Limits _$LimitsFromJson(Map<String, dynamic> json) => _Limits(
  maxPoints: (json['max_points'] as num?)?.toInt(),
  maxLengthM: (json['max_length_m'] as num?)?.toDouble(),
);

Map<String, dynamic> _$LimitsToJson(_Limits instance) => <String, dynamic>{
  'max_points': instance.maxPoints,
  'max_length_m': instance.maxLengthM,
};
