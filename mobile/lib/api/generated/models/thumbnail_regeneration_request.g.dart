// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thumbnail_regeneration_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ThumbnailRegenerationRequest _$ThumbnailRegenerationRequestFromJson(
  Map<String, dynamic> json,
) => _ThumbnailRegenerationRequest(
  dryRun: json['dryRun'] as bool,
  renderedFrom: json['renderedFrom'] as String?,
  renderedTo: json['renderedTo'] as String?,
  suspectBelowBytes: (json['suspectBelowBytes'] as num?)?.toInt(),
  includeMissing: json['includeMissing'] as bool?,
  outdated: json['outdated'] as bool?,
  givenUp: json['givenUp'] as bool?,
  limit: (json['limit'] as num?)?.toInt(),
);

Map<String, dynamic> _$ThumbnailRegenerationRequestToJson(
  _ThumbnailRegenerationRequest instance,
) => <String, dynamic>{
  'dryRun': instance.dryRun,
  'renderedFrom': instance.renderedFrom,
  'renderedTo': instance.renderedTo,
  'suspectBelowBytes': instance.suspectBelowBytes,
  'includeMissing': instance.includeMissing,
  'outdated': instance.outdated,
  'givenUp': instance.givenUp,
  'limit': instance.limit,
};
