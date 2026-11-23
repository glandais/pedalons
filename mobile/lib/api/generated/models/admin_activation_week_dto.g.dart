// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_activation_week_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminActivationWeekDto _$AdminActivationWeekDtoFromJson(
  Map<String, dynamic> json,
) => _AdminActivationWeekDto(
  domainId: json['domainId'] as String,
  domainName: json['domainName'] as String,
  weekStart: json['weekStart'] as String,
  complete: json['complete'] as bool,
  signedUp: (json['signedUp'] as num).toInt(),
  verified: (json['verified'] as num).toInt(),
  joinedTeam: (json['joinedTeam'] as num).toInt(),
  joinedRide: (json['joinedRide'] as num).toInt(),
);

Map<String, dynamic> _$AdminActivationWeekDtoToJson(
  _AdminActivationWeekDto instance,
) => <String, dynamic>{
  'domainId': instance.domainId,
  'domainName': instance.domainName,
  'weekStart': instance.weekStart,
  'complete': instance.complete,
  'signedUp': instance.signedUp,
  'verified': instance.verified,
  'joinedTeam': instance.joinedTeam,
  'joinedRide': instance.joinedRide,
};
