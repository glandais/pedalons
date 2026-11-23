// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router_engine_offer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouterEngineOffer _$RouterEngineOfferFromJson(Map<String, dynamic> json) =>
    _RouterEngineOffer(
      engine: RouterEngine.fromJson(json['engine'] as String),
      profiles: (json['profiles'] as List<dynamic>)
          .map((e) => RouterProfile.fromJson(e as String))
          .toList(),
    );

Map<String, dynamic> _$RouterEngineOfferToJson(_RouterEngineOffer instance) =>
    <String, dynamic>{
      'engine': instance.engine.toJson(),
      'profiles': instance.profiles.map((e) => e.toJson()).toList(),
    };
