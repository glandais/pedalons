// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'elevation_refresh_retry_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ElevationRefreshRetryRequest _$ElevationRefreshRetryRequestFromJson(
  Map<String, dynamic> json,
) => _ElevationRefreshRetryRequest(
  dryRun: json['dryRun'] as bool,
  limit: (json['limit'] as num?)?.toInt(),
  kind: json['kind'] as String?,
);

Map<String, dynamic> _$ElevationRefreshRetryRequestToJson(
  _ElevationRefreshRetryRequest instance,
) => <String, dynamic>{
  'dryRun': instance.dryRun,
  'limit': instance.limit,
  'kind': instance.kind,
};
