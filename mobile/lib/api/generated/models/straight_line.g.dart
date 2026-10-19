// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'straight_line.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StraightLine _$StraightLineFromJson(Map<String, dynamic> json) =>
    _StraightLine(
      from: GeoPoint.fromJson(json['from'] as Map<String, dynamic>),
      to: GeoPoint.fromJson(json['to'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$StraightLineToJson(_StraightLine instance) =>
    <String, dynamic>{
      'from': instance.from.toJson(),
      'to': instance.to.toJson(),
    };
