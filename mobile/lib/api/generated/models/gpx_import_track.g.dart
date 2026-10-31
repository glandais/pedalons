// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gpx_import_track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GpxImportTrack _$GpxImportTrackFromJson(Map<String, dynamic> json) =>
    _GpxImportTrack(
      line: json['line'] as String,
      dist: (json['dist'] as num).toDouble(),
      ascend: (json['ascend'] as num).toDouble(),
      ele: json['ele'] as String?,
      climb: json['climb'] as String?,
      shape: json['shape'] as String?,
    );

Map<String, dynamic> _$GpxImportTrackToJson(_GpxImportTrack instance) =>
    <String, dynamic>{
      'line': instance.line,
      'dist': instance.dist,
      'ascend': instance.ascend,
      'ele': instance.ele,
      'climb': instance.climb,
      'shape': instance.shape,
    };
