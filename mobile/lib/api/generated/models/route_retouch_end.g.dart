// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_retouch_end.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteRetouchEnd _$RouteRetouchEndFromJson(Map<String, dynamic> json) =>
    _RouteRetouchEnd(
      point: json['point'] == null
          ? null
          : GeoPoint.fromJson(json['point'] as Map<String, dynamic>),
      placeId: json['placeId'] as String?,
    );

Map<String, dynamic> _$RouteRetouchEndToJson(_RouteRetouchEnd instance) =>
    <String, dynamic>{
      'point': instance.point?.toJson(),
      'placeId': instance.placeId,
    };
