// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gpx_preview_summary_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GpxPreviewSummaryDto _$GpxPreviewSummaryDtoFromJson(
  Map<String, dynamic> json,
) => _GpxPreviewSummaryDto(
  id: json['id'] as String,
  name: json['name'] as String,
  distance: (json['distance'] as num).toDouble(),
  elevationGain: (json['elevationGain'] as num).toDouble(),
  elevationLoss: (json['elevationLoss'] as num).toDouble(),
  hilliness: (json['hilliness'] as num).toDouble(),
  createdAt: json['createdAt'] as String,
  departureTime: json['departureTime'] as String?,
  departureTimezone: json['departureTimezone'] as String?,
);

Map<String, dynamic> _$GpxPreviewSummaryDtoToJson(
  _GpxPreviewSummaryDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'distance': instance.distance,
  'elevationGain': instance.elevationGain,
  'elevationLoss': instance.elevationLoss,
  'hilliness': instance.hilliness,
  'createdAt': instance.createdAt,
  'departureTime': instance.departureTime,
  'departureTimezone': instance.departureTimezone,
};
