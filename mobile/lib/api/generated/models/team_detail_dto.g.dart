// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_detail_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TeamDetailDto _$TeamDetailDtoFromJson(Map<String, dynamic> json) =>
    _TeamDetailDto(
      addMemberAllowed: json['addMemberAllowed'] as bool,
      name: json['name'] as String,
      slug: json['slug'] as String,
      about: MediaDto.fromJson(json['about'] as Map<String, dynamic>),
      tier: json['tier'] as String,
      enableRoutes: json['enableRoutes'] as bool,
      publicContentAllowed: json['publicContentAllowed'] as bool,
      visibility: json['visibility'] as String,
      enableTrips: json['enableTrips'] as bool,
      enableAds: json['enableAds'] as bool,
      enablePosts: json['enablePosts'] as bool,
      enableRides: json['enableRides'] as bool,
      id: json['id'] as String,
      enableMemberDirectory: json['enableMemberDirectory'] as bool,
      postsAsTeamByDefault: json['postsAsTeamByDefault'] as bool,
      visibilityEditable: json['visibilityEditable'] as bool,
      joinable: json['joinable'] as bool,
      upcomingTripCount: (json['upcomingTripCount'] as num).toInt(),
      enableRoutePlanner: json['enableRoutePlanner'] as bool,
      memberCount: (json['memberCount'] as num).toInt(),
      upcomingRideCount: (json['upcomingRideCount'] as num).toInt(),
      routeCount: (json['routeCount'] as num).toInt(),
      defaultContentVisibility: json['defaultContentVisibility'] as String,
      recentPostCount: (json['recentPostCount'] as num).toInt(),
      timezone: json['timezone'] as String,
      createdAt: json['createdAt'] as String,
      allowedContentVisibilities: ContentVisibilitiesDto.fromJson(
        json['allowedContentVisibilities'] as Map<String, dynamic>,
      ),
      geometry: json['geometry'] == null
          ? null
          : TeamDetailDtoGeometry.fromJson(
              json['geometry'] as Map<String, dynamic>,
            ),
      memberCountByRole: json['memberCountByRole'] == null
          ? null
          : MemberCountByRoleDto.fromJson(
              json['memberCountByRole'] as Map<String, dynamic>,
            ),
      logoUrl: json['logoUrl'] as String?,
      plannerQuota: json['plannerQuota'] == null
          ? null
          : PlannerQuotaDto.fromJson(
              json['plannerQuota'] as Map<String, dynamic>,
            ),
      pages: (json['pages'] as List<dynamic>?)
          ?.map((e) => TeamPageSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      excerpt: json['excerpt'] as String?,
      memberLimit: (json['memberLimit'] as num?)?.toInt(),
      role: json['role'] as String?,
    );

Map<String, dynamic> _$TeamDetailDtoToJson(
  _TeamDetailDto instance,
) => <String, dynamic>{
  'addMemberAllowed': instance.addMemberAllowed,
  'name': instance.name,
  'slug': instance.slug,
  'about': instance.about.toJson(),
  'tier': instance.tier,
  'enableRoutes': instance.enableRoutes,
  'publicContentAllowed': instance.publicContentAllowed,
  'visibility': instance.visibility,
  'enableTrips': instance.enableTrips,
  'enableAds': instance.enableAds,
  'enablePosts': instance.enablePosts,
  'enableRides': instance.enableRides,
  'id': instance.id,
  'enableMemberDirectory': instance.enableMemberDirectory,
  'postsAsTeamByDefault': instance.postsAsTeamByDefault,
  'visibilityEditable': instance.visibilityEditable,
  'joinable': instance.joinable,
  'upcomingTripCount': instance.upcomingTripCount,
  'enableRoutePlanner': instance.enableRoutePlanner,
  'memberCount': instance.memberCount,
  'upcomingRideCount': instance.upcomingRideCount,
  'routeCount': instance.routeCount,
  'defaultContentVisibility': instance.defaultContentVisibility,
  'recentPostCount': instance.recentPostCount,
  'timezone': instance.timezone,
  'createdAt': instance.createdAt,
  'allowedContentVisibilities': instance.allowedContentVisibilities.toJson(),
  'geometry': instance.geometry?.toJson(),
  'memberCountByRole': instance.memberCountByRole?.toJson(),
  'logoUrl': instance.logoUrl,
  'plannerQuota': instance.plannerQuota?.toJson(),
  'pages': instance.pages?.map((e) => e.toJson()).toList(),
  'excerpt': instance.excerpt,
  'memberLimit': instance.memberLimit,
  'role': instance.role,
};
