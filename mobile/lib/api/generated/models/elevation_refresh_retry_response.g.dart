// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'elevation_refresh_retry_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ElevationRefreshRetryResponse _$ElevationRefreshRetryResponseFromJson(
  Map<String, dynamic> json,
) => _ElevationRefreshRetryResponse(
  dryRun: json['dryRun'] as bool,
  matched: (json['matched'] as num).toInt(),
  items: (json['items'] as List<dynamic>)
      .map((e) => ElevationRefreshRetryItem.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ElevationRefreshRetryResponseToJson(
  _ElevationRefreshRetryResponse instance,
) => <String, dynamic>{
  'dryRun': instance.dryRun,
  'matched': instance.matched,
  'items': instance.items.map((e) => e.toJson()).toList(),
};
