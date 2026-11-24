// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retouched_span_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RetouchedSpanDto _$RetouchedSpanDtoFromJson(Map<String, dynamic> json) =>
    _RetouchedSpanDto(
      fromM: (json['fromM'] as num).toDouble(),
      toM: (json['toM'] as num).toDouble(),
      newM: (json['newM'] as num).toDouble(),
      startIndex: (json['startIndex'] as num).toInt(),
      endIndex: (json['endIndex'] as num).toInt(),
      teamShare: (json['teamShare'] as num).toDouble(),
      unpavedShare: (json['unpavedShare'] as num).toDouble(),
      crossings: (json['crossings'] as num).toInt(),
    );

Map<String, dynamic> _$RetouchedSpanDtoToJson(_RetouchedSpanDto instance) =>
    <String, dynamic>{
      'fromM': instance.fromM,
      'toM': instance.toM,
      'newM': instance.newM,
      'startIndex': instance.startIndex,
      'endIndex': instance.endIndex,
      'teamShare': instance.teamShare,
      'unpavedShare': instance.unpavedShare,
      'crossings': instance.crossings,
    };
