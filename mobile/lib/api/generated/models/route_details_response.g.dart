// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_details_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteDetailsResponse _$RouteDetailsResponseFromJson(
  Map<String, dynamic> json,
) => _RouteDetailsResponse(
  meta: json['meta'] == null
      ? null
      : Meta.fromJson(json['meta'] as Map<String, dynamic>),
  status: json['status'] as String?,
  points: (json['points'] as List<dynamic>?)
      ?.map((e) => OutputPoint.fromJson(e as Map<String, dynamic>))
      .toList(),
  segments: (json['segments'] as List<dynamic>?)
      ?.map((e) => Segment.fromJson(e as Map<String, dynamic>))
      .toList(),
  summary: json['summary'] == null
      ? null
      : Summary.fromJson(json['summary'] as Map<String, dynamic>),
  quality: json['quality'] == null
      ? null
      : Quality.fromJson(json['quality'] as Map<String, dynamic>),
  partial: json['partial'] as bool?,
);

Map<String, dynamic> _$RouteDetailsResponseToJson(
  _RouteDetailsResponse instance,
) => <String, dynamic>{
  'meta': instance.meta?.toJson(),
  'status': instance.status,
  'points': instance.points?.map((e) => e.toJson()).toList(),
  'segments': instance.segments?.map((e) => e.toJson()).toList(),
  'summary': instance.summary?.toJson(),
  'quality': instance.quality?.toJson(),
  'partial': instance.partial,
};
