// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather_leg_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WeatherLegDto _$WeatherLegDtoFromJson(
  Map<String, dynamic> json,
) => _WeatherLegDto(
  status: json['status'] as String,
  startTime: json['startTime'] as String,
  averageSpeed: (json['averageSpeed'] as num).toDouble(),
  speedIsDefault: json['speedIsDefault'] as bool,
  distance: (json['distance'] as num).toDouble(),
  arrivalTime: json['arrivalTime'] as String,
  checkpoints: (json['checkpoints'] as List<dynamic>)
      .map((e) => WeatherCheckpointDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  segments: (json['segments'] as List<dynamic>)
      .map((e) => WindSegmentDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  windExposure: WindExposureDto.fromJson(
    json['windExposure'] as Map<String, dynamic>,
  ),
  groupId: json['groupId'] as String?,
  availableFrom: json['availableFrom'] as String?,
  fetchedAt: json['fetchedAt'] as String?,
  prevailingWind: json['prevailingWind'] == null
      ? null
      : WindDto.fromJson(json['prevailingWind'] as Map<String, dynamic>),
  rainAlert: json['rainAlert'] == null
      ? null
      : WeatherRainAlertDto.fromJson(json['rainAlert'] as Map<String, dynamic>),
  summary: json['summary'] == null
      ? null
      : RideWeatherSummaryDto.fromJson(json['summary'] as Map<String, dynamic>),
  departure: json['departure'] == null
      ? null
      : DepartureWeatherDto.fromJson(json['departure'] as Map<String, dynamic>),
);

Map<String, dynamic> _$WeatherLegDtoToJson(_WeatherLegDto instance) =>
    <String, dynamic>{
      'status': instance.status,
      'startTime': instance.startTime,
      'averageSpeed': instance.averageSpeed,
      'speedIsDefault': instance.speedIsDefault,
      'distance': instance.distance,
      'arrivalTime': instance.arrivalTime,
      'checkpoints': instance.checkpoints.map((e) => e.toJson()).toList(),
      'segments': instance.segments.map((e) => e.toJson()).toList(),
      'windExposure': instance.windExposure.toJson(),
      'groupId': instance.groupId,
      'availableFrom': instance.availableFrom,
      'fetchedAt': instance.fetchedAt,
      'prevailingWind': instance.prevailingWind?.toJson(),
      'rainAlert': instance.rainAlert?.toJson(),
      'summary': instance.summary?.toJson(),
      'departure': instance.departure?.toJson(),
    };
