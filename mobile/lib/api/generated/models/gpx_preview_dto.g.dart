// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gpx_preview_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GpxPreviewDto _$GpxPreviewDtoFromJson(Map<String, dynamic> json) =>
    _GpxPreviewDto(
      id: json['id'] as String,
      name: json['name'] as String,
      distance: (json['distance'] as num).toDouble(),
      elevationGain: (json['elevationGain'] as num).toDouble(),
      elevationLoss: (json['elevationLoss'] as num).toDouble(),
      hilliness: (json['hilliness'] as num).toDouble(),
      elevationState: json['elevationState'] as String,
      owned: json['owned'] as bool,
      createdAt: json['createdAt'] as String,
      gpxUrl: json['gpxUrl'] as String,
      fitUrl: json['fitUrl'] as String,
      drawn: json['drawn'] as bool,
      tracks: (json['tracks'] as List<dynamic>)
          .map((e) => TrackDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      waypoints: (json['waypoints'] as List<dynamic>)
          .map((e) => WaypointDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );

Map<String, dynamic> _$GpxPreviewDtoToJson(_GpxPreviewDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'distance': instance.distance,
      'elevationGain': instance.elevationGain,
      'elevationLoss': instance.elevationLoss,
      'hilliness': instance.hilliness,
      'elevationState': instance.elevationState,
      'owned': instance.owned,
      'createdAt': instance.createdAt,
      'gpxUrl': instance.gpxUrl,
      'fitUrl': instance.fitUrl,
      'drawn': instance.drawn,
      'tracks': instance.tracks.map((e) => e.toJson()).toList(),
      'waypoints': instance.waypoints.map((e) => e.toJson()).toList(),
      'thumbnailUrl': instance.thumbnailUrl,
    };
