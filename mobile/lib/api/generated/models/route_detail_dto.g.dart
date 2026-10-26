// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_detail_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RouteDetailDto _$RouteDetailDtoFromJson(Map<String, dynamic> json) =>
    _RouteDetailDto(
      id: json['id'] as String,
      slug: json['slug'] as String,
      team: TeamPublicationDto.fromJson(json['team'] as Map<String, dynamic>),
      name: json['name'] as String,
      media: MediaDto.fromJson(json['media'] as Map<String, dynamic>),
      distance: (json['distance'] as num).toDouble(),
      elevationGain: (json['elevationGain'] as num).toDouble(),
      elevationLoss: (json['elevationLoss'] as num).toDouble(),
      elevationState: json['elevationState'] as String,
      surfaceType: json['surfaceType'] as String,
      visibility: json['visibility'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      tracks: (json['tracks'] as List<dynamic>)
          .map((e) => TrackDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      waypoints: (json['waypoints'] as List<dynamic>)
          .map((e) => WaypointDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      deleted: json['deleted'] as bool,
      tags: (json['tags'] as List<dynamic>)
          .map((e) => TagDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      start: json['start'] == null
          ? null
          : GeoJsonPoint.fromJson(json['start'] as Map<String, dynamic>),
      end: json['end'] == null
          ? null
          : GeoJsonPoint.fromJson(json['end'] as Map<String, dynamic>),
      createdBy: json['createdBy'] == null
          ? null
          : PublicUserDto.fromJson(json['createdBy'] as Map<String, dynamic>),
      commentCount: (json['commentCount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RouteDetailDtoToJson(_RouteDetailDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'team': instance.team.toJson(),
      'name': instance.name,
      'media': instance.media.toJson(),
      'distance': instance.distance,
      'elevationGain': instance.elevationGain,
      'elevationLoss': instance.elevationLoss,
      'elevationState': instance.elevationState,
      'surfaceType': instance.surfaceType,
      'visibility': instance.visibility,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'tracks': instance.tracks.map((e) => e.toJson()).toList(),
      'waypoints': instance.waypoints.map((e) => e.toJson()).toList(),
      'deleted': instance.deleted,
      'tags': instance.tags.map((e) => e.toJson()).toList(),
      'start': instance.start?.toJson(),
      'end': instance.end?.toJson(),
      'createdBy': instance.createdBy?.toJson(),
      'commentCount': instance.commentCount,
    };
