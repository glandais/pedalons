// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_retouch_offer_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteRetouchOfferDto _$RouteRetouchOfferDtoFromJson(
  Map<String, dynamic> json,
) => _RouteRetouchOfferDto(
  available: json['available'] as bool,
  operations: (json['operations'] as List<dynamic>)
      .map((e) => RouteRetouchOperation.fromJson(e as String))
      .toList(),
  unavailableReason: json['unavailableReason'] as String?,
  originalDistanceM: (json['originalDistanceM'] as num?)?.toDouble(),
  minDistanceKm: (json['minDistanceKm'] as num?)?.toDouble(),
  maxDistanceKm: (json['maxDistanceKm'] as num?)?.toDouble(),
  minChangeKm: (json['minChangeKm'] as num?)?.toDouble(),
  maxChangeShare: (json['maxChangeShare'] as num?)?.toDouble(),
  endSnapM: (json['endSnapM'] as num?)?.toDouble(),
  proposalsMax: (json['proposalsMax'] as num?)?.toInt(),
  rideType: json['rideType'] as String?,
);

Map<String, dynamic> _$RouteRetouchOfferDtoToJson(
  _RouteRetouchOfferDto instance,
) => <String, dynamic>{
  'available': instance.available,
  'operations': instance.operations.map((e) => e.toJson()).toList(),
  'unavailableReason': instance.unavailableReason,
  'originalDistanceM': instance.originalDistanceM,
  'minDistanceKm': instance.minDistanceKm,
  'maxDistanceKm': instance.maxDistanceKm,
  'minChangeKm': instance.minChangeKm,
  'maxChangeShare': instance.maxChangeShare,
  'endSnapM': instance.endSnapM,
  'proposalsMax': instance.proposalsMax,
  'rideType': instance.rideType,
};
