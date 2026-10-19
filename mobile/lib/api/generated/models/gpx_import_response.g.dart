// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gpx_import_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GpxImportResponse _$GpxImportResponseFromJson(Map<String, dynamic> json) =>
    _GpxImportResponse(
      name: json['name'] as String,
      tracks: (json['tracks'] as List<dynamic>)
          .map((e) => GpxImportTrack.fromJson(e as Map<String, dynamic>))
          .toList(),
      waypointCount: (json['waypointCount'] as num).toInt(),
      elevationFallback: json['elevationFallback'] as bool,
    );

Map<String, dynamic> _$GpxImportResponseToJson(_GpxImportResponse instance) =>
    <String, dynamic>{
      'name': instance.name,
      'tracks': instance.tracks.map((e) => e.toJson()).toList(),
      'waypointCount': instance.waypointCount,
      'elevationFallback': instance.elevationFallback,
    };
