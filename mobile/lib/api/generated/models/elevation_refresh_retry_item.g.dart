// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'elevation_refresh_retry_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ElevationRefreshRetryItem _$ElevationRefreshRetryItemFromJson(
  Map<String, dynamic> json,
) => _ElevationRefreshRetryItem(
  kind: json['kind'] as String,
  targetId: json['targetId'] as String,
  attempts: (json['attempts'] as num).toInt(),
  firstRequestedAt: json['firstRequestedAt'] as String,
  teamSlug: json['teamSlug'] as String?,
  routeSlug: json['routeSlug'] as String?,
  previewPublicId: json['previewPublicId'] as String?,
  lastError: json['lastError'] as String?,
);

Map<String, dynamic> _$ElevationRefreshRetryItemToJson(
  _ElevationRefreshRetryItem instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'targetId': instance.targetId,
  'attempts': instance.attempts,
  'firstRequestedAt': instance.firstRequestedAt,
  'teamSlug': instance.teamSlug,
  'routeSlug': instance.routeSlug,
  'previewPublicId': instance.previewPublicId,
  'lastError': instance.lastError,
};
