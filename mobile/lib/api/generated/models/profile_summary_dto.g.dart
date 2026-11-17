// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_summary_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProfileSummaryDto _$ProfileSummaryDtoFromJson(Map<String, dynamic> json) =>
    _ProfileSummaryDto(
      teams: (json['teams'] as List<dynamic>)
          .map((e) => ProfileTeamDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      passkeyCount: (json['passkeyCount'] as num).toInt(),
      pairedDevices: (json['pairedDevices'] as List<dynamic>)
          .map((e) => PairedDeviceDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      blockedUserCount: (json['blockedUserCount'] as num).toInt(),
      notifications: ProfileNotificationSummaryDto.fromJson(
        json['notifications'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$ProfileSummaryDtoToJson(_ProfileSummaryDto instance) =>
    <String, dynamic>{
      'teams': instance.teams.map((e) => e.toJson()).toList(),
      'passkeyCount': instance.passkeyCount,
      'pairedDevices': instance.pairedDevices.map((e) => e.toJson()).toList(),
      'blockedUserCount': instance.blockedUserCount,
      'notifications': instance.notifications.toJson(),
    };
