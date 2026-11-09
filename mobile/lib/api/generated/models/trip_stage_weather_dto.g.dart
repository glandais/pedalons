// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_stage_weather_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TripStageWeatherDto _$TripStageWeatherDtoFromJson(Map<String, dynamic> json) =>
    _TripStageWeatherDto(
      leg: WeatherLegDto.fromJson(json['leg'] as Map<String, dynamic>),
      departure: DepartureWeatherDto.fromJson(
        json['departure'] as Map<String, dynamic>,
      ),
      stageId: json['stageId'] as String?,
      summary: json['summary'] == null
          ? null
          : RideWeatherSummaryDto.fromJson(
              json['summary'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$TripStageWeatherDtoToJson(
  _TripStageWeatherDto instance,
) => <String, dynamic>{
  'leg': instance.leg.toJson(),
  'departure': instance.departure.toJson(),
  'stageId': instance.stageId,
  'summary': instance.summary?.toJson(),
};
