// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_visibilities_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ContentVisibilitiesDto _$ContentVisibilitiesDtoFromJson(
  Map<String, dynamic> json,
) => _ContentVisibilitiesDto(
  ride: (json['ride'] as List<dynamic>)
      .map((e) => Visibility.fromJson(e as String))
      .toList(),
  rideTemplate: (json['rideTemplate'] as List<dynamic>)
      .map((e) => Visibility.fromJson(e as String))
      .toList(),
  route: (json['route'] as List<dynamic>)
      .map((e) => Visibility.fromJson(e as String))
      .toList(),
  post: (json['post'] as List<dynamic>)
      .map((e) => Visibility.fromJson(e as String))
      .toList(),
  trip: (json['trip'] as List<dynamic>)
      .map((e) => Visibility.fromJson(e as String))
      .toList(),
  teamPage: (json['teamPage'] as List<dynamic>)
      .map((e) => Visibility.fromJson(e as String))
      .toList(),
  ad: (json['ad'] as List<dynamic>)
      .map((e) => Visibility.fromJson(e as String))
      .toList(),
);

Map<String, dynamic> _$ContentVisibilitiesDtoToJson(
  _ContentVisibilitiesDto instance,
) => <String, dynamic>{
  'ride': instance.ride.map((e) => e.toJson()).toList(),
  'rideTemplate': instance.rideTemplate.map((e) => e.toJson()).toList(),
  'route': instance.route.map((e) => e.toJson()).toList(),
  'post': instance.post.map((e) => e.toJson()).toList(),
  'trip': instance.trip.map((e) => e.toJson()).toList(),
  'teamPage': instance.teamPage.map((e) => e.toJson()).toList(),
  'ad': instance.ad.map((e) => e.toJson()).toList(),
};
