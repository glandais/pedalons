// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_activation_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminActivationResponse _$AdminActivationResponseFromJson(
  Map<String, dynamic> json,
) => _AdminActivationResponse(
  weeks: (json['weeks'] as List<dynamic>)
      .map((e) => AdminActivationWeekDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  weeksBack: (json['weeksBack'] as num).toInt(),
);

Map<String, dynamic> _$AdminActivationResponseToJson(
  _AdminActivationResponse instance,
) => <String, dynamic>{
  'weeks': instance.weeks.map((e) => e.toJson()).toList(),
  'weeksBack': instance.weeksBack,
};
