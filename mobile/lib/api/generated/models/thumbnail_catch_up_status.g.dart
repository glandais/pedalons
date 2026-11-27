// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thumbnail_catch_up_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ThumbnailCatchUpStatus _$ThumbnailCatchUpStatusFromJson(
  Map<String, dynamic> json,
) => _ThumbnailCatchUpStatus(
  version: (json['version'] as num).toInt(),
  enabled: json['enabled'] as bool,
  perHour: (json['perHour'] as num).toInt(),
  behind: (json['behind'] as num).toInt(),
  waiting: (json['waiting'] as num).toInt(),
  givenUp: (json['givenUp'] as num).toInt(),
);

Map<String, dynamic> _$ThumbnailCatchUpStatusToJson(
  _ThumbnailCatchUpStatus instance,
) => <String, dynamic>{
  'version': instance.version,
  'enabled': instance.enabled,
  'perHour': instance.perHour,
  'behind': instance.behind,
  'waiting': instance.waiting,
  'givenUp': instance.givenUp,
};
