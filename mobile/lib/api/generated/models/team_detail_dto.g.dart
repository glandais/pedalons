// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_detail_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TeamDetailDto _$TeamDetailDtoFromJson(Map<String, dynamic> json) =>
    _TeamDetailDto(
      joinable: json['joinable'] as bool,
      name: json['name'] as String,
      slug: json['slug'] as String,
      about: MediaDto.fromJson(json['about'] as Map<String, dynamic>),
      tier: json['tier'] as String,
      enableRides: json['enableRides'] as bool,
      publicContentAllowed: json['publicContentAllowed'] as bool,
      visibility: json['visibility'] as String,
      enableTrips: json['enableTrips'] as bool,
      enableAds: json['enableAds'] as bool,
      enablePosts: json['enablePosts'] as bool,
      id: json['id'] as String,
      enableRoutes: json['enableRoutes'] as bool,
      enableMemberDirectory: json['enableMemberDirectory'] as bool,
      postsAsTeamByDefault: json['postsAsTeamByDefault'] as bool,
      visibilityEditable: json['visibilityEditable'] as bool,
      routeCount: (json['routeCount'] as num).toInt(),
      addMemberAllowed: json['addMemberAllowed'] as bool,
      enableRoutePlanner: json['enableRoutePlanner'] as bool,
      memberCount: (json['memberCount'] as num).toInt(),
      upcomingRideCount: (json['upcomingRideCount'] as num).toInt(),
      defaultContentVisibility: json['defaultContentVisibility'] as String,
      upcomingTripCount: (json['upcomingTripCount'] as num).toInt(),
      recentPostCount: (json['recentPostCount'] as num).toInt(),
      allowedContentVisibilities: ContentVisibilitiesDto.fromJson(
        json['allowedContentVisibilities'] as Map<String, dynamic>,
      ),
      createdAt: json['createdAt'] as String,
      timezone: json['timezone'] as String,
      geometry: json['geometry'] == null
          ? null
          : TeamDetailDtoGeometry.fromJson(
              json['geometry'] as Map<String, dynamic>,
            ),
      logoUrl: json['logoUrl'] as String?,
      memberCountByRole: json['memberCountByRole'] == null
          ? null
          : MemberCountByRoleDto.fromJson(
              json['memberCountByRole'] as Map<String, dynamic>,
            ),
      memberLimit: (json['memberLimit'] as num?)?.toInt(),
      pages: (json['pages'] as List<dynamic>?)
          ?.map((e) => TeamPageSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      excerpt: json['excerpt'] as String?,
      role: json['role'] as String?,
    );

Map<String, dynamic> _$TeamDetailDtoToJson(
  _TeamDetailDto instance,
) => <String, dynamic>{
  'joinable': instance.joinable,
  'name': instance.name,
  'slug': instance.slug,
  'about': instance.about.toJson(),
  'tier': instance.tier,
  'enableRides': instance.enableRides,
  'publicContentAllowed': instance.publicContentAllowed,
  'visibility': instance.visibility,
  'enableTrips': instance.enableTrips,
  'enableAds': instance.enableAds,
  'enablePosts': instance.enablePosts,
  'id': instance.id,
  'enableRoutes': instance.enableRoutes,
  'enableMemberDirectory': instance.enableMemberDirectory,
  'postsAsTeamByDefault': instance.postsAsTeamByDefault,
  'visibilityEditable': instance.visibilityEditable,
  'routeCount': instance.routeCount,
  'addMemberAllowed': instance.addMemberAllowed,
  'enableRoutePlanner': instance.enableRoutePlanner,
  'memberCount': instance.memberCount,
  'upcomingRideCount': instance.upcomingRideCount,
  'defaultContentVisibility': instance.defaultContentVisibility,
  'upcomingTripCount': instance.upcomingTripCount,
  'recentPostCount': instance.recentPostCount,
  'allowedContentVisibilities': instance.allowedContentVisibilities.toJson(),
  'createdAt': instance.createdAt,
  'timezone': instance.timezone,
  'geometry': instance.geometry?.toJson(),
  'logoUrl': instance.logoUrl,
  'memberCountByRole': instance.memberCountByRole?.toJson(),
  'memberLimit': instance.memberLimit,
  'pages': instance.pages?.map((e) => e.toJson()).toList(),
  'excerpt': instance.excerpt,
  'role': instance.role,
};
