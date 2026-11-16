// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_generator_overlay_refresh_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteGeneratorOverlayRefreshRequest
_$RouteGeneratorOverlayRefreshRequestFromJson(Map<String, dynamic> json) =>
    _RouteGeneratorOverlayRefreshRequest(
      force: json['force'] as bool,
      dryRun: json['dryRun'] as bool,
      teamId: json['teamId'] as String?,
    );

Map<String, dynamic> _$RouteGeneratorOverlayRefreshRequestToJson(
  _RouteGeneratorOverlayRefreshRequest instance,
) => <String, dynamic>{
  'force': instance.force,
  'dryRun': instance.dryRun,
  'teamId': instance.teamId,
};
