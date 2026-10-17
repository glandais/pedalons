// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geocode_result_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GeocodeResultDto _$GeocodeResultDtoFromJson(Map<String, dynamic> json) =>
    _GeocodeResultDto(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$GeocodeResultDtoToJson(_GeocodeResultDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'lat': instance.lat,
      'lon': instance.lon,
    };
