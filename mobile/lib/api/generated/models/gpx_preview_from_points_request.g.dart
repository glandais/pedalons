// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gpx_preview_from_points_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GpxPreviewFromPointsRequest _$GpxPreviewFromPointsRequestFromJson(
  Map<String, dynamic> json,
) => _GpxPreviewFromPointsRequest(
  name: json['name'] as String,
  points: (json['points'] as List<dynamic>?)
      ?.map((e) => GeoPoint.fromJson(e as Map<String, dynamic>))
      .toList(),
  plannerState: json['plannerState'] == null
      ? null
      : PlannerState.fromJson(json['plannerState'] as Map<String, dynamic>),
);

Map<String, dynamic> _$GpxPreviewFromPointsRequestToJson(
  _GpxPreviewFromPointsRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'points': instance.points?.map((e) => e.toJson()).toList(),
  'plannerState': instance.plannerState?.toJson(),
};
