// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line_elevation_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LineElevationResponse _$LineElevationResponseFromJson(
  Map<String, dynamic> json,
) => _LineElevationResponse(
  lines: (json['lines'] as List<dynamic>)
      .map((e) => GpxImportTrack.fromJson(e as Map<String, dynamic>))
      .toList(),
  elevationFallback: json['elevationFallback'] as bool,
);

Map<String, dynamic> _$LineElevationResponseToJson(
  _LineElevationResponse instance,
) => <String, dynamic>{
  'lines': instance.lines.map((e) => e.toJson()).toList(),
  'elevationFallback': instance.elevationFallback,
};
