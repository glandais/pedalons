// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_details_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteDetailsRequest _$RouteDetailsRequestFromJson(Map<String, dynamic> json) =>
    _RouteDetailsRequest(
      polyline: json['polyline'] as String?,
      polylinePrecision: (json['polyline_precision'] as num?)?.toInt(),
      points: (json['points'] as List<dynamic>?)
          ?.map((e) => Point.fromJson(e as Map<String, dynamic>))
          .toList(),
      options: json['options'] == null
          ? null
          : RouteDetailsOptions.fromJson(
              json['options'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$RouteDetailsRequestToJson(
  _RouteDetailsRequest instance,
) => <String, dynamic>{
  'polyline': instance.polyline,
  'polyline_precision': instance.polylinePrecision,
  'points': instance.points?.map((e) => e.toJson()).toList(),
  'options': instance.options?.toJson(),
};
