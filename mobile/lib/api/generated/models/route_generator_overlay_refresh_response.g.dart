// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_generator_overlay_refresh_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteGeneratorOverlayRefreshResponse
_$RouteGeneratorOverlayRefreshResponseFromJson(Map<String, dynamic> json) =>
    _RouteGeneratorOverlayRefreshResponse(
      started: json['started'] as bool,
      items: (json['items'] as List<dynamic>)
          .map(
            (e) => RouteGeneratorOverlayRefreshItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      graphId: json['graphId'] as String?,
    );

Map<String, dynamic> _$RouteGeneratorOverlayRefreshResponseToJson(
  _RouteGeneratorOverlayRefreshResponse instance,
) => <String, dynamic>{
  'started': instance.started,
  'items': instance.items.map((e) => e.toJson()).toList(),
  'graphId': instance.graphId,
};
