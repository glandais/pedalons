// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_team_attributes_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminTeamAttributesRequest _$AdminTeamAttributesRequestFromJson(
  Map<String, dynamic> json,
) => _AdminTeamAttributesRequest(
  visibilityEditable: json['visibilityEditable'] as bool,
  joinable: json['joinable'] as bool,
  addMemberAllowed: json['addMemberAllowed'] as bool,
  enableRoutePlanner: json['enableRoutePlanner'] as bool,
  publicContentAllowed: json['publicContentAllowed'] as bool?,
);

Map<String, dynamic> _$AdminTeamAttributesRequestToJson(
  _AdminTeamAttributesRequest instance,
) => <String, dynamic>{
  'visibilityEditable': instance.visibilityEditable,
  'joinable': instance.joinable,
  'addMemberAllowed': instance.addMemberAllowed,
  'enableRoutePlanner': instance.enableRoutePlanner,
  'publicContentAllowed': instance.publicContentAllowed,
};
