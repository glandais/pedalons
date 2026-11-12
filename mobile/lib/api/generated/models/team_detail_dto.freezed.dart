// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_detail_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TeamDetailDto {

/// Whether team admins can add members
 bool get addMemberAllowed;/// Team name
 String get name;/// Team URL slug
 String get slug;/// About page content
 MediaDto get about;/// The team's plan, set by a platform admin only. FREE caps the members and the route planner saves, UNLOCKED lifts both caps.
 String get tier;/// Routes enabled
 bool get enableRoutes;/// Whether a platform admin allowed this private team to publish content as public or unlisted, readable by link only and kept out of every listing and of the sitemap. Meaningless for a team that is not private. For the platform administration screen: editors read allowedContentVisibilities.
 bool get publicContentAllowed;/// Whether the team is public
 String get visibility;/// Trips enabled
 bool get enableTrips;/// Ads enabled
 bool get enableAds;/// Posts enabled
 bool get enablePosts;/// Rides enabled
 bool get enableRides;/// Team ID (TSID)
 String get id;/// Whether the member directory is readable by every member and not just by administrators. Clients use it to decide whether to offer the directory at all: an entry that always leads to a 403 is worse than no entry. Organisers see the directory whatever its value, but only get each member's role and join date when it is true.
 bool get enableMemberDirectory;/// Whether a new post starts signed by the team rather than by its author — the initial value of the editor's « on behalf of the team » box.
 bool get postsAsTeamByDefault;/// Whether visibility is editable by team admins
 bool get visibilityEditable;/// Whether any domain user can join this team
 bool get joinable;/// Trips of this team starting in the future that the caller may open, under the same visibility rules as the trip listing. 0 when trips are disabled.
 int get upcomingTripCount;/// Whether the interactive route planner is open to this team. Unlike enableRoutes it never hides the routes section: when false the track can still be imported or replaced from a GPX file, only drawing is closed. Platform-admin only.
 bool get enableRoutePlanner;/// Number of team members
 int get memberCount;/// Rides of this team dated in the future that the caller may open. Follows the same visibility rules as the ride listing, so it never announces more than the caller can actually see.
 int get upcomingRideCount;/// Routes of this team the caller may open, under the same visibility rules as the route listing.
 int get routeCount;/// The visibility a creation form starts from: the team's own, so TEAM for a private team, publicContentAllowed or not. Not for ads, which are always TEAM.
 String get defaultContentVisibility;/// Published posts of this team dated within the last 7 days (and not in the future) that the caller may open, under the same visibility rules as the post listing. Feeds the activity line of a member's team card. 0 when posts are disabled.
 int get recentPostCount;/// The team's IANA zone: the one its rides, trips and posts fall back on when no place locates them. Administrators change it through TeamRequest.timezone.
 String get timezone;/// Team creation timestamp
 String get createdAt;/// The visibilities the team accepts for each type of content: what a creation form offers. The same for every caller who may read the team — the server still decides who may write. A private team holds TEAM only, unless a platform admin set publicContentAllowed.
 ContentVisibilitiesDto get allowedContentVisibilities;/// Team location coordinates [longitude, latitude]
 TeamDetailDtoGeometry? get geometry;/// Members per role. Only for the team's administrators (platform admins included): null for everyone else, and in the team listings.
 MemberCountByRoleDto? get memberCountByRole;/// URL template of the team's logo, when it has one. Same picture as about.assets.logo, hoisted so a card does not have to walk the asset inventory to find it. Opaque URL: may carry a query string; substitute {size} only.
 String? get logoUrl;/// Where the team's route planner quota stands this month: the saves of a track drawn on the map, against the plan's limit (null when unlimited). Only for a caller who may create routes in the team, and only when one team is read: null for everyone else and in the team listings. Clients show no counter; they close « draw on the map » when used >= limit already.
 PlannerQuotaDto? get plannerQuota;/// Additional team pages
 List<TeamPageSummaryDto>? get pages;/// Plain-text opening of the about page, flattened and cut on a word boundary at about 200 characters. Null when the about page holds no text. Lets a team card render its two lines without parsing the markdown client-side.
 String? get excerpt;/// The most members the team may hold, pending invitations included; null when unlimited. Compare with memberCount.
 int? get memberLimit;/// Current user's role (null if not a member). The real membership, platform admins included: their extra rights come from the platform role of /api/me, not from this field.
 String? get role;
/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamDetailDtoCopyWith<TeamDetailDto> get copyWith => _$TeamDetailDtoCopyWithImpl<TeamDetailDto>(this as TeamDetailDto, _$identity);

  /// Serializes this TeamDetailDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TeamDetailDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamDetailDto&&(identical(other.addMemberAllowed, _this.addMemberAllowed) || other.addMemberAllowed == _this.addMemberAllowed)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.about, _this.about) || other.about == _this.about)&&(identical(other.tier, _this.tier) || other.tier == _this.tier)&&(identical(other.enableRoutes, _this.enableRoutes) || other.enableRoutes == _this.enableRoutes)&&(identical(other.publicContentAllowed, _this.publicContentAllowed) || other.publicContentAllowed == _this.publicContentAllowed)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.enableTrips, _this.enableTrips) || other.enableTrips == _this.enableTrips)&&(identical(other.enableAds, _this.enableAds) || other.enableAds == _this.enableAds)&&(identical(other.enablePosts, _this.enablePosts) || other.enablePosts == _this.enablePosts)&&(identical(other.enableRides, _this.enableRides) || other.enableRides == _this.enableRides)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.enableMemberDirectory, _this.enableMemberDirectory) || other.enableMemberDirectory == _this.enableMemberDirectory)&&(identical(other.postsAsTeamByDefault, _this.postsAsTeamByDefault) || other.postsAsTeamByDefault == _this.postsAsTeamByDefault)&&(identical(other.visibilityEditable, _this.visibilityEditable) || other.visibilityEditable == _this.visibilityEditable)&&(identical(other.joinable, _this.joinable) || other.joinable == _this.joinable)&&(identical(other.upcomingTripCount, _this.upcomingTripCount) || other.upcomingTripCount == _this.upcomingTripCount)&&(identical(other.enableRoutePlanner, _this.enableRoutePlanner) || other.enableRoutePlanner == _this.enableRoutePlanner)&&(identical(other.memberCount, _this.memberCount) || other.memberCount == _this.memberCount)&&(identical(other.upcomingRideCount, _this.upcomingRideCount) || other.upcomingRideCount == _this.upcomingRideCount)&&(identical(other.routeCount, _this.routeCount) || other.routeCount == _this.routeCount)&&(identical(other.defaultContentVisibility, _this.defaultContentVisibility) || other.defaultContentVisibility == _this.defaultContentVisibility)&&(identical(other.recentPostCount, _this.recentPostCount) || other.recentPostCount == _this.recentPostCount)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.allowedContentVisibilities, _this.allowedContentVisibilities) || other.allowedContentVisibilities == _this.allowedContentVisibilities)&&(identical(other.geometry, _this.geometry) || other.geometry == _this.geometry)&&(identical(other.memberCountByRole, _this.memberCountByRole) || other.memberCountByRole == _this.memberCountByRole)&&(identical(other.logoUrl, _this.logoUrl) || other.logoUrl == _this.logoUrl)&&(identical(other.plannerQuota, _this.plannerQuota) || other.plannerQuota == _this.plannerQuota)&&const DeepCollectionEquality().equals(other.pages, _this.pages)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt)&&(identical(other.memberLimit, _this.memberLimit) || other.memberLimit == _this.memberLimit)&&(identical(other.role, _this.role) || other.role == _this.role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TeamDetailDto;
  return Object.hashAll([runtimeType,_this.addMemberAllowed,_this.name,_this.slug,_this.about,_this.tier,_this.enableRoutes,_this.publicContentAllowed,_this.visibility,_this.enableTrips,_this.enableAds,_this.enablePosts,_this.enableRides,_this.id,_this.enableMemberDirectory,_this.postsAsTeamByDefault,_this.visibilityEditable,_this.joinable,_this.upcomingTripCount,_this.enableRoutePlanner,_this.memberCount,_this.upcomingRideCount,_this.routeCount,_this.defaultContentVisibility,_this.recentPostCount,_this.timezone,_this.createdAt,_this.allowedContentVisibilities,_this.geometry,_this.memberCountByRole,_this.logoUrl,_this.plannerQuota,const DeepCollectionEquality().hash(_this.pages),_this.excerpt,_this.memberLimit,_this.role]);
}

@override
String toString() {
  final _this = this as TeamDetailDto;
  return 'TeamDetailDto(addMemberAllowed: ${_this.addMemberAllowed}, name: ${_this.name}, slug: ${_this.slug}, about: ${_this.about}, tier: ${_this.tier}, enableRoutes: ${_this.enableRoutes}, publicContentAllowed: ${_this.publicContentAllowed}, visibility: ${_this.visibility}, enableTrips: ${_this.enableTrips}, enableAds: ${_this.enableAds}, enablePosts: ${_this.enablePosts}, enableRides: ${_this.enableRides}, id: ${_this.id}, enableMemberDirectory: ${_this.enableMemberDirectory}, postsAsTeamByDefault: ${_this.postsAsTeamByDefault}, visibilityEditable: ${_this.visibilityEditable}, joinable: ${_this.joinable}, upcomingTripCount: ${_this.upcomingTripCount}, enableRoutePlanner: ${_this.enableRoutePlanner}, memberCount: ${_this.memberCount}, upcomingRideCount: ${_this.upcomingRideCount}, routeCount: ${_this.routeCount}, defaultContentVisibility: ${_this.defaultContentVisibility}, recentPostCount: ${_this.recentPostCount}, timezone: ${_this.timezone}, createdAt: ${_this.createdAt}, allowedContentVisibilities: ${_this.allowedContentVisibilities}, geometry: ${_this.geometry}, memberCountByRole: ${_this.memberCountByRole}, logoUrl: ${_this.logoUrl}, plannerQuota: ${_this.plannerQuota}, pages: ${_this.pages}, excerpt: ${_this.excerpt}, memberLimit: ${_this.memberLimit}, role: ${_this.role})';
}


}

/// @nodoc
abstract mixin class $TeamDetailDtoCopyWith<$Res>  {
  factory $TeamDetailDtoCopyWith(TeamDetailDto value, $Res Function(TeamDetailDto) _then) = _$TeamDetailDtoCopyWithImpl;
@useResult
$Res call({
 bool addMemberAllowed, String name, String slug, MediaDto about, String tier, bool enableRoutes, bool publicContentAllowed, String visibility, bool enableTrips, bool enableAds, bool enablePosts, bool enableRides, String id, bool enableMemberDirectory, bool postsAsTeamByDefault, bool visibilityEditable, bool joinable, int upcomingTripCount, bool enableRoutePlanner, int memberCount, int upcomingRideCount, int routeCount, String defaultContentVisibility, int recentPostCount, String timezone, String createdAt, ContentVisibilitiesDto allowedContentVisibilities, TeamDetailDtoGeometry? geometry, MemberCountByRoleDto? memberCountByRole, String? logoUrl, PlannerQuotaDto? plannerQuota, List<TeamPageSummaryDto>? pages, String? excerpt, int? memberLimit, String? role
});


$MediaDtoCopyWith<$Res> get about;$ContentVisibilitiesDtoCopyWith<$Res> get allowedContentVisibilities;$TeamDetailDtoGeometryCopyWith<$Res>? get geometry;$MemberCountByRoleDtoCopyWith<$Res>? get memberCountByRole;$PlannerQuotaDtoCopyWith<$Res>? get plannerQuota;

}
/// @nodoc
class _$TeamDetailDtoCopyWithImpl<$Res>
    implements $TeamDetailDtoCopyWith<$Res> {
  _$TeamDetailDtoCopyWithImpl(this._self, this._then);

  final TeamDetailDto _self;
  final $Res Function(TeamDetailDto) _then;

/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? addMemberAllowed = null,Object? name = null,Object? slug = null,Object? about = null,Object? tier = null,Object? enableRoutes = null,Object? publicContentAllowed = null,Object? visibility = null,Object? enableTrips = null,Object? enableAds = null,Object? enablePosts = null,Object? enableRides = null,Object? id = null,Object? enableMemberDirectory = null,Object? postsAsTeamByDefault = null,Object? visibilityEditable = null,Object? joinable = null,Object? upcomingTripCount = null,Object? enableRoutePlanner = null,Object? memberCount = null,Object? upcomingRideCount = null,Object? routeCount = null,Object? defaultContentVisibility = null,Object? recentPostCount = null,Object? timezone = null,Object? createdAt = null,Object? allowedContentVisibilities = null,Object? geometry = freezed,Object? memberCountByRole = freezed,Object? logoUrl = freezed,Object? plannerQuota = freezed,Object? pages = freezed,Object? excerpt = freezed,Object? memberLimit = freezed,Object? role = freezed,}) {
  return _then(TeamDetailDto(
addMemberAllowed: null == addMemberAllowed ? _self.addMemberAllowed : addMemberAllowed // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,about: null == about ? _self.about : about // ignore: cast_nullable_to_non_nullable
as MediaDto,tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as String,enableRoutes: null == enableRoutes ? _self.enableRoutes : enableRoutes // ignore: cast_nullable_to_non_nullable
as bool,publicContentAllowed: null == publicContentAllowed ? _self.publicContentAllowed : publicContentAllowed // ignore: cast_nullable_to_non_nullable
as bool,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,enableTrips: null == enableTrips ? _self.enableTrips : enableTrips // ignore: cast_nullable_to_non_nullable
as bool,enableAds: null == enableAds ? _self.enableAds : enableAds // ignore: cast_nullable_to_non_nullable
as bool,enablePosts: null == enablePosts ? _self.enablePosts : enablePosts // ignore: cast_nullable_to_non_nullable
as bool,enableRides: null == enableRides ? _self.enableRides : enableRides // ignore: cast_nullable_to_non_nullable
as bool,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,enableMemberDirectory: null == enableMemberDirectory ? _self.enableMemberDirectory : enableMemberDirectory // ignore: cast_nullable_to_non_nullable
as bool,postsAsTeamByDefault: null == postsAsTeamByDefault ? _self.postsAsTeamByDefault : postsAsTeamByDefault // ignore: cast_nullable_to_non_nullable
as bool,visibilityEditable: null == visibilityEditable ? _self.visibilityEditable : visibilityEditable // ignore: cast_nullable_to_non_nullable
as bool,joinable: null == joinable ? _self.joinable : joinable // ignore: cast_nullable_to_non_nullable
as bool,upcomingTripCount: null == upcomingTripCount ? _self.upcomingTripCount : upcomingTripCount // ignore: cast_nullable_to_non_nullable
as int,enableRoutePlanner: null == enableRoutePlanner ? _self.enableRoutePlanner : enableRoutePlanner // ignore: cast_nullable_to_non_nullable
as bool,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,upcomingRideCount: null == upcomingRideCount ? _self.upcomingRideCount : upcomingRideCount // ignore: cast_nullable_to_non_nullable
as int,routeCount: null == routeCount ? _self.routeCount : routeCount // ignore: cast_nullable_to_non_nullable
as int,defaultContentVisibility: null == defaultContentVisibility ? _self.defaultContentVisibility : defaultContentVisibility // ignore: cast_nullable_to_non_nullable
as String,recentPostCount: null == recentPostCount ? _self.recentPostCount : recentPostCount // ignore: cast_nullable_to_non_nullable
as int,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,allowedContentVisibilities: null == allowedContentVisibilities ? _self.allowedContentVisibilities : allowedContentVisibilities // ignore: cast_nullable_to_non_nullable
as ContentVisibilitiesDto,geometry: freezed == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as TeamDetailDtoGeometry?,memberCountByRole: freezed == memberCountByRole ? _self.memberCountByRole : memberCountByRole // ignore: cast_nullable_to_non_nullable
as MemberCountByRoleDto?,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,plannerQuota: freezed == plannerQuota ? _self.plannerQuota : plannerQuota // ignore: cast_nullable_to_non_nullable
as PlannerQuotaDto?,pages: freezed == pages ? _self.pages : pages // ignore: cast_nullable_to_non_nullable
as List<TeamPageSummaryDto>?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,memberLimit: freezed == memberLimit ? _self.memberLimit : memberLimit // ignore: cast_nullable_to_non_nullable
as int?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get about {
  
  return $MediaDtoCopyWith<$Res>(_self.about, (value) {
    return _then(_self.copyWith(about: value));
  });
}/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentVisibilitiesDtoCopyWith<$Res> get allowedContentVisibilities {
  
  return $ContentVisibilitiesDtoCopyWith<$Res>(_self.allowedContentVisibilities, (value) {
    return _then(_self.copyWith(allowedContentVisibilities: value));
  });
}/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDetailDtoGeometryCopyWith<$Res>? get geometry {
    if (_self.geometry == null) {
    return null;
  }

  return $TeamDetailDtoGeometryCopyWith<$Res>(_self.geometry!, (value) {
    return _then(_self.copyWith(geometry: value));
  });
}/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MemberCountByRoleDtoCopyWith<$Res>? get memberCountByRole {
    if (_self.memberCountByRole == null) {
    return null;
  }

  return $MemberCountByRoleDtoCopyWith<$Res>(_self.memberCountByRole!, (value) {
    return _then(_self.copyWith(memberCountByRole: value));
  });
}/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlannerQuotaDtoCopyWith<$Res>? get plannerQuota {
    if (_self.plannerQuota == null) {
    return null;
  }

  return $PlannerQuotaDtoCopyWith<$Res>(_self.plannerQuota!, (value) {
    return _then(_self.copyWith(plannerQuota: value));
  });
}
}


/// Adds pattern-matching-related methods to [TeamDetailDto].
extension TeamDetailDtoPatterns on TeamDetailDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamDetailDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamDetailDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamDetailDto value)  $default,){
final _that = this;
switch (_that) {
case _TeamDetailDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamDetailDto value)?  $default,){
final _that = this;
switch (_that) {
case _TeamDetailDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool addMemberAllowed,  String name,  String slug,  MediaDto about,  String tier,  bool enableRoutes,  bool publicContentAllowed,  String visibility,  bool enableTrips,  bool enableAds,  bool enablePosts,  bool enableRides,  String id,  bool enableMemberDirectory,  bool postsAsTeamByDefault,  bool visibilityEditable,  bool joinable,  int upcomingTripCount,  bool enableRoutePlanner,  int memberCount,  int upcomingRideCount,  int routeCount,  String defaultContentVisibility,  int recentPostCount,  String timezone,  String createdAt,  ContentVisibilitiesDto allowedContentVisibilities,  TeamDetailDtoGeometry? geometry,  MemberCountByRoleDto? memberCountByRole,  String? logoUrl,  PlannerQuotaDto? plannerQuota,  List<TeamPageSummaryDto>? pages,  String? excerpt,  int? memberLimit,  String? role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamDetailDto() when $default != null:
return $default(_that.addMemberAllowed,_that.name,_that.slug,_that.about,_that.tier,_that.enableRoutes,_that.publicContentAllowed,_that.visibility,_that.enableTrips,_that.enableAds,_that.enablePosts,_that.enableRides,_that.id,_that.enableMemberDirectory,_that.postsAsTeamByDefault,_that.visibilityEditable,_that.joinable,_that.upcomingTripCount,_that.enableRoutePlanner,_that.memberCount,_that.upcomingRideCount,_that.routeCount,_that.defaultContentVisibility,_that.recentPostCount,_that.timezone,_that.createdAt,_that.allowedContentVisibilities,_that.geometry,_that.memberCountByRole,_that.logoUrl,_that.plannerQuota,_that.pages,_that.excerpt,_that.memberLimit,_that.role);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool addMemberAllowed,  String name,  String slug,  MediaDto about,  String tier,  bool enableRoutes,  bool publicContentAllowed,  String visibility,  bool enableTrips,  bool enableAds,  bool enablePosts,  bool enableRides,  String id,  bool enableMemberDirectory,  bool postsAsTeamByDefault,  bool visibilityEditable,  bool joinable,  int upcomingTripCount,  bool enableRoutePlanner,  int memberCount,  int upcomingRideCount,  int routeCount,  String defaultContentVisibility,  int recentPostCount,  String timezone,  String createdAt,  ContentVisibilitiesDto allowedContentVisibilities,  TeamDetailDtoGeometry? geometry,  MemberCountByRoleDto? memberCountByRole,  String? logoUrl,  PlannerQuotaDto? plannerQuota,  List<TeamPageSummaryDto>? pages,  String? excerpt,  int? memberLimit,  String? role)  $default,) {final _that = this;
switch (_that) {
case _TeamDetailDto():
return $default(_that.addMemberAllowed,_that.name,_that.slug,_that.about,_that.tier,_that.enableRoutes,_that.publicContentAllowed,_that.visibility,_that.enableTrips,_that.enableAds,_that.enablePosts,_that.enableRides,_that.id,_that.enableMemberDirectory,_that.postsAsTeamByDefault,_that.visibilityEditable,_that.joinable,_that.upcomingTripCount,_that.enableRoutePlanner,_that.memberCount,_that.upcomingRideCount,_that.routeCount,_that.defaultContentVisibility,_that.recentPostCount,_that.timezone,_that.createdAt,_that.allowedContentVisibilities,_that.geometry,_that.memberCountByRole,_that.logoUrl,_that.plannerQuota,_that.pages,_that.excerpt,_that.memberLimit,_that.role);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool addMemberAllowed,  String name,  String slug,  MediaDto about,  String tier,  bool enableRoutes,  bool publicContentAllowed,  String visibility,  bool enableTrips,  bool enableAds,  bool enablePosts,  bool enableRides,  String id,  bool enableMemberDirectory,  bool postsAsTeamByDefault,  bool visibilityEditable,  bool joinable,  int upcomingTripCount,  bool enableRoutePlanner,  int memberCount,  int upcomingRideCount,  int routeCount,  String defaultContentVisibility,  int recentPostCount,  String timezone,  String createdAt,  ContentVisibilitiesDto allowedContentVisibilities,  TeamDetailDtoGeometry? geometry,  MemberCountByRoleDto? memberCountByRole,  String? logoUrl,  PlannerQuotaDto? plannerQuota,  List<TeamPageSummaryDto>? pages,  String? excerpt,  int? memberLimit,  String? role)?  $default,) {final _that = this;
switch (_that) {
case _TeamDetailDto() when $default != null:
return $default(_that.addMemberAllowed,_that.name,_that.slug,_that.about,_that.tier,_that.enableRoutes,_that.publicContentAllowed,_that.visibility,_that.enableTrips,_that.enableAds,_that.enablePosts,_that.enableRides,_that.id,_that.enableMemberDirectory,_that.postsAsTeamByDefault,_that.visibilityEditable,_that.joinable,_that.upcomingTripCount,_that.enableRoutePlanner,_that.memberCount,_that.upcomingRideCount,_that.routeCount,_that.defaultContentVisibility,_that.recentPostCount,_that.timezone,_that.createdAt,_that.allowedContentVisibilities,_that.geometry,_that.memberCountByRole,_that.logoUrl,_that.plannerQuota,_that.pages,_that.excerpt,_that.memberLimit,_that.role);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamDetailDto implements TeamDetailDto {
  const _TeamDetailDto({required this.addMemberAllowed, required this.name, required this.slug, required this.about, required this.tier, required this.enableRoutes, required this.publicContentAllowed, required this.visibility, required this.enableTrips, required this.enableAds, required this.enablePosts, required this.enableRides, required this.id, required this.enableMemberDirectory, required this.postsAsTeamByDefault, required this.visibilityEditable, required this.joinable, required this.upcomingTripCount, required this.enableRoutePlanner, required this.memberCount, required this.upcomingRideCount, required this.routeCount, required this.defaultContentVisibility, required this.recentPostCount, required this.timezone, required this.createdAt, required this.allowedContentVisibilities, this.geometry, this.memberCountByRole, this.logoUrl, this.plannerQuota,  List<TeamPageSummaryDto>? pages, this.excerpt, this.memberLimit, this.role}): _pages = pages;
  factory _TeamDetailDto.fromJson(Map<String, dynamic> json) => _$TeamDetailDtoFromJson(json);

/// Whether team admins can add members
@override final  bool addMemberAllowed;
/// Team name
@override final  String name;
/// Team URL slug
@override final  String slug;
/// About page content
@override final  MediaDto about;
/// The team's plan, set by a platform admin only. FREE caps the members and the route planner saves, UNLOCKED lifts both caps.
@override final  String tier;
/// Routes enabled
@override final  bool enableRoutes;
/// Whether a platform admin allowed this private team to publish content as public or unlisted, readable by link only and kept out of every listing and of the sitemap. Meaningless for a team that is not private. For the platform administration screen: editors read allowedContentVisibilities.
@override final  bool publicContentAllowed;
/// Whether the team is public
@override final  String visibility;
/// Trips enabled
@override final  bool enableTrips;
/// Ads enabled
@override final  bool enableAds;
/// Posts enabled
@override final  bool enablePosts;
/// Rides enabled
@override final  bool enableRides;
/// Team ID (TSID)
@override final  String id;
/// Whether the member directory is readable by every member and not just by administrators. Clients use it to decide whether to offer the directory at all: an entry that always leads to a 403 is worse than no entry. Organisers see the directory whatever its value, but only get each member's role and join date when it is true.
@override final  bool enableMemberDirectory;
/// Whether a new post starts signed by the team rather than by its author — the initial value of the editor's « on behalf of the team » box.
@override final  bool postsAsTeamByDefault;
/// Whether visibility is editable by team admins
@override final  bool visibilityEditable;
/// Whether any domain user can join this team
@override final  bool joinable;
/// Trips of this team starting in the future that the caller may open, under the same visibility rules as the trip listing. 0 when trips are disabled.
@override final  int upcomingTripCount;
/// Whether the interactive route planner is open to this team. Unlike enableRoutes it never hides the routes section: when false the track can still be imported or replaced from a GPX file, only drawing is closed. Platform-admin only.
@override final  bool enableRoutePlanner;
/// Number of team members
@override final  int memberCount;
/// Rides of this team dated in the future that the caller may open. Follows the same visibility rules as the ride listing, so it never announces more than the caller can actually see.
@override final  int upcomingRideCount;
/// Routes of this team the caller may open, under the same visibility rules as the route listing.
@override final  int routeCount;
/// The visibility a creation form starts from: the team's own, so TEAM for a private team, publicContentAllowed or not. Not for ads, which are always TEAM.
@override final  String defaultContentVisibility;
/// Published posts of this team dated within the last 7 days (and not in the future) that the caller may open, under the same visibility rules as the post listing. Feeds the activity line of a member's team card. 0 when posts are disabled.
@override final  int recentPostCount;
/// The team's IANA zone: the one its rides, trips and posts fall back on when no place locates them. Administrators change it through TeamRequest.timezone.
@override final  String timezone;
/// Team creation timestamp
@override final  String createdAt;
/// The visibilities the team accepts for each type of content: what a creation form offers. The same for every caller who may read the team — the server still decides who may write. A private team holds TEAM only, unless a platform admin set publicContentAllowed.
@override final  ContentVisibilitiesDto allowedContentVisibilities;
/// Team location coordinates [longitude, latitude]
@override final  TeamDetailDtoGeometry? geometry;
/// Members per role. Only for the team's administrators (platform admins included): null for everyone else, and in the team listings.
@override final  MemberCountByRoleDto? memberCountByRole;
/// URL template of the team's logo, when it has one. Same picture as about.assets.logo, hoisted so a card does not have to walk the asset inventory to find it. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? logoUrl;
/// Where the team's route planner quota stands this month: the saves of a track drawn on the map, against the plan's limit (null when unlimited). Only for a caller who may create routes in the team, and only when one team is read: null for everyone else and in the team listings. Clients show no counter; they close « draw on the map » when used >= limit already.
@override final  PlannerQuotaDto? plannerQuota;
/// Additional team pages
 final  List<TeamPageSummaryDto>? _pages;
/// Additional team pages
@override List<TeamPageSummaryDto>? get pages {
  final value = _pages;
  if (value == null) return null;
  if (_pages is EqualUnmodifiableListView) return _pages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Plain-text opening of the about page, flattened and cut on a word boundary at about 200 characters. Null when the about page holds no text. Lets a team card render its two lines without parsing the markdown client-side.
@override final  String? excerpt;
/// The most members the team may hold, pending invitations included; null when unlimited. Compare with memberCount.
@override final  int? memberLimit;
/// Current user's role (null if not a member). The real membership, platform admins included: their extra rights come from the platform role of /api/me, not from this field.
@override final  String? role;

/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamDetailDtoCopyWith<_TeamDetailDto> get copyWith => __$TeamDetailDtoCopyWithImpl<_TeamDetailDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamDetailDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamDetailDto&&(identical(other.addMemberAllowed, addMemberAllowed) || other.addMemberAllowed == addMemberAllowed)&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.about, about) || other.about == about)&&(identical(other.tier, tier) || other.tier == tier)&&(identical(other.enableRoutes, enableRoutes) || other.enableRoutes == enableRoutes)&&(identical(other.publicContentAllowed, publicContentAllowed) || other.publicContentAllowed == publicContentAllowed)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.enableTrips, enableTrips) || other.enableTrips == enableTrips)&&(identical(other.enableAds, enableAds) || other.enableAds == enableAds)&&(identical(other.enablePosts, enablePosts) || other.enablePosts == enablePosts)&&(identical(other.enableRides, enableRides) || other.enableRides == enableRides)&&(identical(other.id, id) || other.id == id)&&(identical(other.enableMemberDirectory, enableMemberDirectory) || other.enableMemberDirectory == enableMemberDirectory)&&(identical(other.postsAsTeamByDefault, postsAsTeamByDefault) || other.postsAsTeamByDefault == postsAsTeamByDefault)&&(identical(other.visibilityEditable, visibilityEditable) || other.visibilityEditable == visibilityEditable)&&(identical(other.joinable, joinable) || other.joinable == joinable)&&(identical(other.upcomingTripCount, upcomingTripCount) || other.upcomingTripCount == upcomingTripCount)&&(identical(other.enableRoutePlanner, enableRoutePlanner) || other.enableRoutePlanner == enableRoutePlanner)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.upcomingRideCount, upcomingRideCount) || other.upcomingRideCount == upcomingRideCount)&&(identical(other.routeCount, routeCount) || other.routeCount == routeCount)&&(identical(other.defaultContentVisibility, defaultContentVisibility) || other.defaultContentVisibility == defaultContentVisibility)&&(identical(other.recentPostCount, recentPostCount) || other.recentPostCount == recentPostCount)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.allowedContentVisibilities, allowedContentVisibilities) || other.allowedContentVisibilities == allowedContentVisibilities)&&(identical(other.geometry, geometry) || other.geometry == geometry)&&(identical(other.memberCountByRole, memberCountByRole) || other.memberCountByRole == memberCountByRole)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.plannerQuota, plannerQuota) || other.plannerQuota == plannerQuota)&&const DeepCollectionEquality().equals(other.pages, _pages)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.memberLimit, memberLimit) || other.memberLimit == memberLimit)&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,addMemberAllowed,name,slug,about,tier,enableRoutes,publicContentAllowed,visibility,enableTrips,enableAds,enablePosts,enableRides,id,enableMemberDirectory,postsAsTeamByDefault,visibilityEditable,joinable,upcomingTripCount,enableRoutePlanner,memberCount,upcomingRideCount,routeCount,defaultContentVisibility,recentPostCount,timezone,createdAt,allowedContentVisibilities,geometry,memberCountByRole,logoUrl,plannerQuota,const DeepCollectionEquality().hash(_pages),excerpt,memberLimit,role]);
}

@override
String toString() {
    return 'TeamDetailDto(addMemberAllowed: $addMemberAllowed, name: $name, slug: $slug, about: $about, tier: $tier, enableRoutes: $enableRoutes, publicContentAllowed: $publicContentAllowed, visibility: $visibility, enableTrips: $enableTrips, enableAds: $enableAds, enablePosts: $enablePosts, enableRides: $enableRides, id: $id, enableMemberDirectory: $enableMemberDirectory, postsAsTeamByDefault: $postsAsTeamByDefault, visibilityEditable: $visibilityEditable, joinable: $joinable, upcomingTripCount: $upcomingTripCount, enableRoutePlanner: $enableRoutePlanner, memberCount: $memberCount, upcomingRideCount: $upcomingRideCount, routeCount: $routeCount, defaultContentVisibility: $defaultContentVisibility, recentPostCount: $recentPostCount, timezone: $timezone, createdAt: $createdAt, allowedContentVisibilities: $allowedContentVisibilities, geometry: $geometry, memberCountByRole: $memberCountByRole, logoUrl: $logoUrl, plannerQuota: $plannerQuota, pages: $pages, excerpt: $excerpt, memberLimit: $memberLimit, role: $role)';
}


}

/// @nodoc
abstract mixin class _$TeamDetailDtoCopyWith<$Res> implements $TeamDetailDtoCopyWith<$Res> {
  factory _$TeamDetailDtoCopyWith(_TeamDetailDto value, $Res Function(_TeamDetailDto) _then) = __$TeamDetailDtoCopyWithImpl;
@override @useResult
$Res call({
 bool addMemberAllowed, String name, String slug, MediaDto about, String tier, bool enableRoutes, bool publicContentAllowed, String visibility, bool enableTrips, bool enableAds, bool enablePosts, bool enableRides, String id, bool enableMemberDirectory, bool postsAsTeamByDefault, bool visibilityEditable, bool joinable, int upcomingTripCount, bool enableRoutePlanner, int memberCount, int upcomingRideCount, int routeCount, String defaultContentVisibility, int recentPostCount, String timezone, String createdAt, ContentVisibilitiesDto allowedContentVisibilities, TeamDetailDtoGeometry? geometry, MemberCountByRoleDto? memberCountByRole, String? logoUrl, PlannerQuotaDto? plannerQuota, List<TeamPageSummaryDto>? pages, String? excerpt, int? memberLimit, String? role
});


@override $MediaDtoCopyWith<$Res> get about;@override $ContentVisibilitiesDtoCopyWith<$Res> get allowedContentVisibilities;@override $TeamDetailDtoGeometryCopyWith<$Res>? get geometry;@override $MemberCountByRoleDtoCopyWith<$Res>? get memberCountByRole;@override $PlannerQuotaDtoCopyWith<$Res>? get plannerQuota;

}
/// @nodoc
class __$TeamDetailDtoCopyWithImpl<$Res>
    implements _$TeamDetailDtoCopyWith<$Res> {
  __$TeamDetailDtoCopyWithImpl(this._self, this._then);

  final _TeamDetailDto _self;
  final $Res Function(_TeamDetailDto) _then;

/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? addMemberAllowed = null,Object? name = null,Object? slug = null,Object? about = null,Object? tier = null,Object? enableRoutes = null,Object? publicContentAllowed = null,Object? visibility = null,Object? enableTrips = null,Object? enableAds = null,Object? enablePosts = null,Object? enableRides = null,Object? id = null,Object? enableMemberDirectory = null,Object? postsAsTeamByDefault = null,Object? visibilityEditable = null,Object? joinable = null,Object? upcomingTripCount = null,Object? enableRoutePlanner = null,Object? memberCount = null,Object? upcomingRideCount = null,Object? routeCount = null,Object? defaultContentVisibility = null,Object? recentPostCount = null,Object? timezone = null,Object? createdAt = null,Object? allowedContentVisibilities = null,Object? geometry = freezed,Object? memberCountByRole = freezed,Object? logoUrl = freezed,Object? plannerQuota = freezed,Object? pages = freezed,Object? excerpt = freezed,Object? memberLimit = freezed,Object? role = freezed,}) {
  return _then(_TeamDetailDto(
addMemberAllowed: null == addMemberAllowed ? _self.addMemberAllowed : addMemberAllowed // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,about: null == about ? _self.about : about // ignore: cast_nullable_to_non_nullable
as MediaDto,tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as String,enableRoutes: null == enableRoutes ? _self.enableRoutes : enableRoutes // ignore: cast_nullable_to_non_nullable
as bool,publicContentAllowed: null == publicContentAllowed ? _self.publicContentAllowed : publicContentAllowed // ignore: cast_nullable_to_non_nullable
as bool,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,enableTrips: null == enableTrips ? _self.enableTrips : enableTrips // ignore: cast_nullable_to_non_nullable
as bool,enableAds: null == enableAds ? _self.enableAds : enableAds // ignore: cast_nullable_to_non_nullable
as bool,enablePosts: null == enablePosts ? _self.enablePosts : enablePosts // ignore: cast_nullable_to_non_nullable
as bool,enableRides: null == enableRides ? _self.enableRides : enableRides // ignore: cast_nullable_to_non_nullable
as bool,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,enableMemberDirectory: null == enableMemberDirectory ? _self.enableMemberDirectory : enableMemberDirectory // ignore: cast_nullable_to_non_nullable
as bool,postsAsTeamByDefault: null == postsAsTeamByDefault ? _self.postsAsTeamByDefault : postsAsTeamByDefault // ignore: cast_nullable_to_non_nullable
as bool,visibilityEditable: null == visibilityEditable ? _self.visibilityEditable : visibilityEditable // ignore: cast_nullable_to_non_nullable
as bool,joinable: null == joinable ? _self.joinable : joinable // ignore: cast_nullable_to_non_nullable
as bool,upcomingTripCount: null == upcomingTripCount ? _self.upcomingTripCount : upcomingTripCount // ignore: cast_nullable_to_non_nullable
as int,enableRoutePlanner: null == enableRoutePlanner ? _self.enableRoutePlanner : enableRoutePlanner // ignore: cast_nullable_to_non_nullable
as bool,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,upcomingRideCount: null == upcomingRideCount ? _self.upcomingRideCount : upcomingRideCount // ignore: cast_nullable_to_non_nullable
as int,routeCount: null == routeCount ? _self.routeCount : routeCount // ignore: cast_nullable_to_non_nullable
as int,defaultContentVisibility: null == defaultContentVisibility ? _self.defaultContentVisibility : defaultContentVisibility // ignore: cast_nullable_to_non_nullable
as String,recentPostCount: null == recentPostCount ? _self.recentPostCount : recentPostCount // ignore: cast_nullable_to_non_nullable
as int,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,allowedContentVisibilities: null == allowedContentVisibilities ? _self.allowedContentVisibilities : allowedContentVisibilities // ignore: cast_nullable_to_non_nullable
as ContentVisibilitiesDto,geometry: freezed == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as TeamDetailDtoGeometry?,memberCountByRole: freezed == memberCountByRole ? _self.memberCountByRole : memberCountByRole // ignore: cast_nullable_to_non_nullable
as MemberCountByRoleDto?,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,plannerQuota: freezed == plannerQuota ? _self.plannerQuota : plannerQuota // ignore: cast_nullable_to_non_nullable
as PlannerQuotaDto?,pages: freezed == pages ? _self._pages : pages // ignore: cast_nullable_to_non_nullable
as List<TeamPageSummaryDto>?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,memberLimit: freezed == memberLimit ? _self.memberLimit : memberLimit // ignore: cast_nullable_to_non_nullable
as int?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get about {
  
  return $MediaDtoCopyWith<$Res>(_self.about, (value) {
    return _then(_self.copyWith(about: value));
  });
}/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentVisibilitiesDtoCopyWith<$Res> get allowedContentVisibilities {
  
  return $ContentVisibilitiesDtoCopyWith<$Res>(_self.allowedContentVisibilities, (value) {
    return _then(_self.copyWith(allowedContentVisibilities: value));
  });
}/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDetailDtoGeometryCopyWith<$Res>? get geometry {
    if (_self.geometry == null) {
    return null;
  }

  return $TeamDetailDtoGeometryCopyWith<$Res>(_self.geometry!, (value) {
    return _then(_self.copyWith(geometry: value));
  });
}/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MemberCountByRoleDtoCopyWith<$Res>? get memberCountByRole {
    if (_self.memberCountByRole == null) {
    return null;
  }

  return $MemberCountByRoleDtoCopyWith<$Res>(_self.memberCountByRole!, (value) {
    return _then(_self.copyWith(memberCountByRole: value));
  });
}/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlannerQuotaDtoCopyWith<$Res>? get plannerQuota {
    if (_self.plannerQuota == null) {
    return null;
  }

  return $PlannerQuotaDtoCopyWith<$Res>(_self.plannerQuota!, (value) {
    return _then(_self.copyWith(plannerQuota: value));
  });
}
}

// dart format on
