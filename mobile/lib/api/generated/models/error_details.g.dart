// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorDetailsValidation _$ErrorDetailsValidationFromJson(
  Map<String, dynamic> json,
) => ErrorDetailsValidation(
  fieldErrors: (json['fieldErrors'] as List<dynamic>)
      .map((e) => FieldError.fromJson(e as Map<String, dynamic>))
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ErrorDetailsValidationToJson(
  ErrorDetailsValidation instance,
) => <String, dynamic>{
  'fieldErrors': instance.fieldErrors.map((e) => e.toJson()).toList(),
  'type': instance.$type,
};

ErrorDetailsNotFound _$ErrorDetailsNotFoundFromJson(
  Map<String, dynamic> json,
) => ErrorDetailsNotFound(
  entityType: json['entityType'] as String,
  searchedBy: json['searchedBy'] as String,
  id: json['id'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ErrorDetailsNotFoundToJson(
  ErrorDetailsNotFound instance,
) => <String, dynamic>{
  'entityType': instance.entityType,
  'searchedBy': instance.searchedBy,
  'id': instance.id,
  'type': instance.$type,
};

ErrorDetailsAssetNotAvailable _$ErrorDetailsAssetNotAvailableFromJson(
  Map<String, dynamic> json,
) => ErrorDetailsAssetNotAvailable(
  assetId: json['assetId'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ErrorDetailsAssetNotAvailableToJson(
  ErrorDetailsAssetNotAvailable instance,
) => <String, dynamic>{'assetId': instance.assetId, 'type': instance.$type};

ErrorDetailsIncompatibleVisibility _$ErrorDetailsIncompatibleVisibilityFromJson(
  Map<String, dynamic> json,
) => ErrorDetailsIncompatibleVisibility(
  routes: (json['routes'] as List<dynamic>)
      .map((e) => IncompatibleRouteDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  usages: (json['usages'] as List<dynamic>)
      .map((e) => IncompatibleRouteUsageDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ErrorDetailsIncompatibleVisibilityToJson(
  ErrorDetailsIncompatibleVisibility instance,
) => <String, dynamic>{
  'routes': instance.routes.map((e) => e.toJson()).toList(),
  'usages': instance.usages.map((e) => e.toJson()).toList(),
  'type': instance.$type,
};

ErrorDetailsTeamMemberLimitReached _$ErrorDetailsTeamMemberLimitReachedFromJson(
  Map<String, dynamic> json,
) => ErrorDetailsTeamMemberLimitReached(
  limit: (json['limit'] as num).toInt(),
  current: (json['current'] as num).toInt(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ErrorDetailsTeamMemberLimitReachedToJson(
  ErrorDetailsTeamMemberLimitReached instance,
) => <String, dynamic>{
  'limit': instance.limit,
  'current': instance.current,
  'type': instance.$type,
};

ErrorDetailsPlannerQuotaReached _$ErrorDetailsPlannerQuotaReachedFromJson(
  Map<String, dynamic> json,
) => ErrorDetailsPlannerQuotaReached(
  scope: json['scope'] as String,
  limit: (json['limit'] as num).toInt(),
  current: (json['current'] as num).toInt(),
  resetsOn: json['resetsOn'] as String,
  teamName: json['teamName'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ErrorDetailsPlannerQuotaReachedToJson(
  ErrorDetailsPlannerQuotaReached instance,
) => <String, dynamic>{
  'scope': instance.scope,
  'limit': instance.limit,
  'current': instance.current,
  'resetsOn': instance.resetsOn,
  'teamName': instance.teamName,
  'type': instance.$type,
};
