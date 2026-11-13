// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enums.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Enums _$EnumsFromJson(Map<String, dynamic> json) => _Enums(
  profiles: (json['profiles'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  surfaceDetail: (json['surface_detail'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$EnumsToJson(_Enums instance) => <String, dynamic>{
  'profiles': instance.profiles,
  'surface_detail': instance.surfaceDetail,
};
