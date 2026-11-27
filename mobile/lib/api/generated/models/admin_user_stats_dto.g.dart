// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_user_stats_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminUserStatsDto _$AdminUserStatsDtoFromJson(Map<String, dynamic> json) =>
    _AdminUserStatsDto(
      total: (json['total'] as num).toInt(),
      deleted: (json['deleted'] as num).toInt(),
      emailVerified: (json['emailVerified'] as num).toInt(),
      termsAccepted: (json['termsAccepted'] as num).toInt(),
      platformAdmins: (json['platformAdmins'] as num).toInt(),
      withAvatar: (json['withAvatar'] as num).toInt(),
      neverLoggedIn: (json['neverLoggedIn'] as num).toInt(),
      activeLast7Days: (json['activeLast7Days'] as num).toInt(),
      activeLast30Days: (json['activeLast30Days'] as num).toInt(),
      activeLast90Days: (json['activeLast90Days'] as num).toInt(),
    );

Map<String, dynamic> _$AdminUserStatsDtoToJson(_AdminUserStatsDto instance) =>
    <String, dynamic>{
      'total': instance.total,
      'deleted': instance.deleted,
      'emailVerified': instance.emailVerified,
      'termsAccepted': instance.termsAccepted,
      'platformAdmins': instance.platformAdmins,
      'withAvatar': instance.withAvatar,
      'neverLoggedIn': instance.neverLoggedIn,
      'activeLast7Days': instance.activeLast7Days,
      'activeLast30Days': instance.activeLast30Days,
      'activeLast90Days': instance.activeLast90Days,
    };
