// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retouched_route_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RetouchedRouteDto _$RetouchedRouteDtoFromJson(Map<String, dynamic> json) =>
    _RetouchedRouteDto(
      polyline: json['polyline'] as String,
      distanceM: (json['distanceM'] as num).toDouble(),
      kind: json['kind'] as String,
      keptShare: (json['keptShare'] as num).toDouble(),
      unmatchedM: (json['unmatchedM'] as num).toDouble(),
      changed: RetouchedSpanDto.fromJson(
        json['changed'] as Map<String, dynamic>,
      ),
      bounds: BoundsDto.fromJson(json['bounds'] as Map<String, dynamic>),
      ascentM: (json['ascentM'] as num?)?.toDouble(),
      descentM: (json['descentM'] as num?)?.toDouble(),
      variant: json['variant'] as String?,
      endSnapM: (json['endSnapM'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$RetouchedRouteDtoToJson(_RetouchedRouteDto instance) =>
    <String, dynamic>{
      'polyline': instance.polyline,
      'distanceM': instance.distanceM,
      'kind': instance.kind,
      'keptShare': instance.keptShare,
      'unmatchedM': instance.unmatchedM,
      'changed': instance.changed.toJson(),
      'bounds': instance.bounds.toJson(),
      'ascentM': instance.ascentM,
      'descentM': instance.descentM,
      'variant': instance.variant,
      'endSnapM': instance.endSnapM,
    };
