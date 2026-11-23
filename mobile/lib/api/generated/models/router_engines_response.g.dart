// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router_engines_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouterEnginesResponse _$RouterEnginesResponseFromJson(
  Map<String, dynamic> json,
) => _RouterEnginesResponse(
  engines: (json['engines'] as List<dynamic>)
      .map((e) => RouterEngineOffer.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$RouterEnginesResponseToJson(
  _RouterEnginesResponse instance,
) => <String, dynamic>{
  'engines': instance.engines.map((e) => e.toJson()).toList(),
};
