// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line_elevation_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LineElevationRequest _$LineElevationRequestFromJson(
  Map<String, dynamic> json,
) => _LineElevationRequest(
  lines: (json['lines'] as List<dynamic>)
      .map((e) => StraightLine.fromJson(e as Map<String, dynamic>))
      .toList(),
  teamSlug: json['teamSlug'] as String?,
);

Map<String, dynamic> _$LineElevationRequestToJson(
  _LineElevationRequest instance,
) => <String, dynamic>{
  'lines': instance.lines.map((e) => e.toJson()).toList(),
  'teamSlug': instance.teamSlug,
};
