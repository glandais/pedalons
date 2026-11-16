// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_generator_overlay_refresh_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteGeneratorOverlayRefreshItem _$RouteGeneratorOverlayRefreshItemFromJson(
  Map<String, dynamic> json,
) => _RouteGeneratorOverlayRefreshItem(
  teamId: json['teamId'] as String,
  teamSlug: json['teamSlug'] as String,
  action: json['action'] as String,
  reason: json['reason'] as String,
  state: json['state'] as String?,
  depositedAt: json['depositedAt'] as String?,
  expiresAt: json['expiresAt'] as String?,
);

Map<String, dynamic> _$RouteGeneratorOverlayRefreshItemToJson(
  _RouteGeneratorOverlayRefreshItem instance,
) => <String, dynamic>{
  'teamId': instance.teamId,
  'teamSlug': instance.teamSlug,
  'action': instance.action,
  'reason': instance.reason,
  'state': instance.state,
  'depositedAt': instance.depositedAt,
  'expiresAt': instance.expiresAt,
};
