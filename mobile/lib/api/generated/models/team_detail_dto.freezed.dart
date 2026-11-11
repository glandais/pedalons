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

/// Whether any domain user can join this team
 bool get joinable;/// Team name
 String get name;/// Team URL slug
 String get slug;/// About page content
 MediaDto get about;/// The team's plan, set by a platform admin only. FREE caps the members and the route planner saves, UNLOCKED lifts both caps.
 String get tier;/// Rides enabled
 bool get enableRides;/// Whether a platform admin allowed this private team to publish content as public or unlisted, readable by link only and kept out of every listing and of the sitemap. Meaningless for a team that is not private. For the platform administration screen: editors read allowedContentVisibilities.
 bool get publicContentAllowed;/// Whether the team is public
 String get visibility;/// Trips enabled
 bool get enableTrips;/// Ads enabled
 bool get enableAds;/// Posts enabled
 bool get enablePosts;/// Team ID (TSID)
 String get id;/// Routes enabled
 bool get enableRoutes;/// Whether the member directory is readable by every member and not just by administrators. Clients use it to decide whether to offer the directory at all: an entry that always leads to a 403 is worse than no entry. Organisers see the directory whatever its value, but only get each member's role and join date when it is true.
 bool get enableMemberDirectory;/// Whether a new post starts signed by the team rather than by its author — the initial value of the editor's « on behalf of the team » box.
 bool get postsAsTeamByDefault;/// Whether visibility is editable by team admins
 bool get visibilityEditable;/// Routes of this team the caller may open, under the same visibility rules as the route listing.
 int get routeCount;/// Whether team admins can add members
 bool get addMemberAllowed;/// Whether the interactive route planner is open to this team. Unlike enableRoutes it never hides the routes section: when false the track can still be imported or replaced from a GPX file, only drawing is closed. Platform-admin only.
 bool get enableRoutePlanner;/// Number of team members
 int get memberCount;/// Rides of this team dated in the future that the caller may open. Follows the same visibility rules as the ride listing, so it never announces more than the caller can actually see.
 int get upcomingRideCount;/// The visibility a creation form starts from: the team's own, so TEAM for a private team, publicContentAllowed or not. Not for ads, which are always TEAM.
 String get defaultContentVisibility;/// Trips of this team starting in the future that the caller may open, under the same visibility rules as the trip listing. 0 when trips are disabled.
 int get upcomingTripCount;/// Published posts of this team dated within the last 7 days (and not in the future) that the caller may open, under the same visibility rules as the post listing. Feeds the activity line of a member's team card. 0 when posts are disabled.
 int get recentPostCount;/// The visibilities the team accepts for each type of content: what a creation form offers. The same for every caller who may read the team — the server still decides who may write. A private team holds TEAM only, unless a platform admin set publicContentAllowed.
 ContentVisibilitiesDto get allowedContentVisibilities;/// Team creation timestamp
 String get createdAt;/// The team's IANA zone: the one its rides, trips and posts fall back on when no place locates them. Administrators change it through TeamRequest.timezone.
 String get timezone;/// Team location coordinates [longitude, latitude]
 TeamDetailDtoGeometry? get geometry;/// URL template of the team's logo, when it has one. Same picture as about.assets.logo, hoisted so a card does not have to walk the asset inventory to find it. Opaque URL: may carry a query string; substitute {size} only.
 String? get logoUrl;/// Members per role. Only for the team's administrators (platform admins included): null for everyone else, and in the team listings.
 MemberCountByRoleDto? get memberCountByRole;/// The most members the team may hold, pending invitations included; null when unlimited. Compare with memberCount.
 int? get memberLimit;/// Additional team pages
 List<TeamPageSummaryDto>? get pages;/// Plain-text opening of the about page, flattened and cut on a word boundary at about 200 characters. Null when the about page holds no text. Lets a team card render its two lines without parsing the markdown client-side.
 String? get excerpt;/// Current user's role (null if not a member). The real membership, platform admins included: their extra rights come from the platform role of /api/me, not from this field.
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamDetailDto&&(identical(other.joinable, _this.joinable) || other.joinable == _this.joinable)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.about, _this.about) || other.about == _this.about)&&(identical(other.tier, _this.tier) || other.tier == _this.tier)&&(identical(other.enableRides, _this.enableRides) || other.enableRides == _this.enableRides)&&(identical(other.publicContentAllowed, _this.publicContentAllowed) || other.publicContentAllowed == _this.publicContentAllowed)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.enableTrips, _this.enableTrips) || other.enableTrips == _this.enableTrips)&&(identical(other.enableAds, _this.enableAds) || other.enableAds == _this.enableAds)&&(identical(other.enablePosts, _this.enablePosts) || other.enablePosts == _this.enablePosts)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.enableRoutes, _this.enableRoutes) || other.enableRoutes == _this.enableRoutes)&&(identical(other.enableMemberDirectory, _this.enableMemberDirectory) || other.enableMemberDirectory == _this.enableMemberDirectory)&&(identical(other.postsAsTeamByDefault, _this.postsAsTeamByDefault) || other.postsAsTeamByDefault == _this.postsAsTeamByDefault)&&(identical(other.visibilityEditable, _this.visibilityEditable) || other.visibilityEditable == _this.visibilityEditable)&&(identical(other.routeCount, _this.routeCount) || other.routeCount == _this.routeCount)&&(identical(other.addMemberAllowed, _this.addMemberAllowed) || other.addMemberAllowed == _this.addMemberAllowed)&&(identical(other.enableRoutePlanner, _this.enableRoutePlanner) || other.enableRoutePlanner == _this.enableRoutePlanner)&&(identical(other.memberCount, _this.memberCount) || other.memberCount == _this.memberCount)&&(identical(other.upcomingRideCount, _this.upcomingRideCount) || other.upcomingRideCount == _this.upcomingRideCount)&&(identical(other.defaultContentVisibility, _this.defaultContentVisibility) || other.defaultContentVisibility == _this.defaultContentVisibility)&&(identical(other.upcomingTripCount, _this.upcomingTripCount) || other.upcomingTripCount == _this.upcomingTripCount)&&(identical(other.recentPostCount, _this.recentPostCount) || other.recentPostCount == _this.recentPostCount)&&(identical(other.allowedContentVisibilities, _this.allowedContentVisibilities) || other.allowedContentVisibilities == _this.allowedContentVisibilities)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.geometry, _this.geometry) || other.geometry == _this.geometry)&&(identical(other.logoUrl, _this.logoUrl) || other.logoUrl == _this.logoUrl)&&(identical(other.memberCountByRole, _this.memberCountByRole) || other.memberCountByRole == _this.memberCountByRole)&&(identical(other.memberLimit, _this.memberLimit) || other.memberLimit == _this.memberLimit)&&const DeepCollectionEquality().equals(other.pages, _this.pages)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt)&&(identical(other.role, _this.role) || other.role == _this.role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TeamDetailDto;
  return Object.hashAll([runtimeType,_this.joinable,_this.name,_this.slug,_this.about,_this.tier,_this.enableRides,_this.publicContentAllowed,_this.visibility,_this.enableTrips,_this.enableAds,_this.enablePosts,_this.id,_this.enableRoutes,_this.enableMemberDirectory,_this.postsAsTeamByDefault,_this.visibilityEditable,_this.routeCount,_this.addMemberAllowed,_this.enableRoutePlanner,_this.memberCount,_this.upcomingRideCount,_this.defaultContentVisibility,_this.upcomingTripCount,_this.recentPostCount,_this.allowedContentVisibilities,_this.createdAt,_this.timezone,_this.geometry,_this.logoUrl,_this.memberCountByRole,_this.memberLimit,const DeepCollectionEquality().hash(_this.pages),_this.excerpt,_this.role]);
}

@override
String toString() {
  final _this = this as TeamDetailDto;
  return 'TeamDetailDto(joinable: ${_this.joinable}, name: ${_this.name}, slug: ${_this.slug}, about: ${_this.about}, tier: ${_this.tier}, enableRides: ${_this.enableRides}, publicContentAllowed: ${_this.publicContentAllowed}, visibility: ${_this.visibility}, enableTrips: ${_this.enableTrips}, enableAds: ${_this.enableAds}, enablePosts: ${_this.enablePosts}, id: ${_this.id}, enableRoutes: ${_this.enableRoutes}, enableMemberDirectory: ${_this.enableMemberDirectory}, postsAsTeamByDefault: ${_this.postsAsTeamByDefault}, visibilityEditable: ${_this.visibilityEditable}, routeCount: ${_this.routeCount}, addMemberAllowed: ${_this.addMemberAllowed}, enableRoutePlanner: ${_this.enableRoutePlanner}, memberCount: ${_this.memberCount}, upcomingRideCount: ${_this.upcomingRideCount}, defaultContentVisibility: ${_this.defaultContentVisibility}, upcomingTripCount: ${_this.upcomingTripCount}, recentPostCount: ${_this.recentPostCount}, allowedContentVisibilities: ${_this.allowedContentVisibilities}, createdAt: ${_this.createdAt}, timezone: ${_this.timezone}, geometry: ${_this.geometry}, logoUrl: ${_this.logoUrl}, memberCountByRole: ${_this.memberCountByRole}, memberLimit: ${_this.memberLimit}, pages: ${_this.pages}, excerpt: ${_this.excerpt}, role: ${_this.role})';
}


}

/// @nodoc
abstract mixin class $TeamDetailDtoCopyWith<$Res>  {
  factory $TeamDetailDtoCopyWith(TeamDetailDto value, $Res Function(TeamDetailDto) _then) = _$TeamDetailDtoCopyWithImpl;
@useResult
$Res call({
 bool joinable, String name, String slug, MediaDto about, String tier, bool enableRides, bool publicContentAllowed, String visibility, bool enableTrips, bool enableAds, bool enablePosts, String id, bool enableRoutes, bool enableMemberDirectory, bool postsAsTeamByDefault, bool visibilityEditable, int routeCount, bool addMemberAllowed, bool enableRoutePlanner, int memberCount, int upcomingRideCount, String defaultContentVisibility, int upcomingTripCount, int recentPostCount, ContentVisibilitiesDto allowedContentVisibilities, String createdAt, String timezone, TeamDetailDtoGeometry? geometry, String? logoUrl, MemberCountByRoleDto? memberCountByRole, int? memberLimit, List<TeamPageSummaryDto>? pages, String? excerpt, String? role
});


$MediaDtoCopyWith<$Res> get about;$ContentVisibilitiesDtoCopyWith<$Res> get allowedContentVisibilities;$TeamDetailDtoGeometryCopyWith<$Res>? get geometry;$MemberCountByRoleDtoCopyWith<$Res>? get memberCountByRole;

}
/// @nodoc
class _$TeamDetailDtoCopyWithImpl<$Res>
    implements $TeamDetailDtoCopyWith<$Res> {
  _$TeamDetailDtoCopyWithImpl(this._self, this._then);

  final TeamDetailDto _self;
  final $Res Function(TeamDetailDto) _then;

/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? joinable = null,Object? name = null,Object? slug = null,Object? about = null,Object? tier = null,Object? enableRides = null,Object? publicContentAllowed = null,Object? visibility = null,Object? enableTrips = null,Object? enableAds = null,Object? enablePosts = null,Object? id = null,Object? enableRoutes = null,Object? enableMemberDirectory = null,Object? postsAsTeamByDefault = null,Object? visibilityEditable = null,Object? routeCount = null,Object? addMemberAllowed = null,Object? enableRoutePlanner = null,Object? memberCount = null,Object? upcomingRideCount = null,Object? defaultContentVisibility = null,Object? upcomingTripCount = null,Object? recentPostCount = null,Object? allowedContentVisibilities = null,Object? createdAt = null,Object? timezone = null,Object? geometry = freezed,Object? logoUrl = freezed,Object? memberCountByRole = freezed,Object? memberLimit = freezed,Object? pages = freezed,Object? excerpt = freezed,Object? role = freezed,}) {
  return _then(TeamDetailDto(
joinable: null == joinable ? _self.joinable : joinable // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,about: null == about ? _self.about : about // ignore: cast_nullable_to_non_nullable
as MediaDto,tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as String,enableRides: null == enableRides ? _self.enableRides : enableRides // ignore: cast_nullable_to_non_nullable
as bool,publicContentAllowed: null == publicContentAllowed ? _self.publicContentAllowed : publicContentAllowed // ignore: cast_nullable_to_non_nullable
as bool,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,enableTrips: null == enableTrips ? _self.enableTrips : enableTrips // ignore: cast_nullable_to_non_nullable
as bool,enableAds: null == enableAds ? _self.enableAds : enableAds // ignore: cast_nullable_to_non_nullable
as bool,enablePosts: null == enablePosts ? _self.enablePosts : enablePosts // ignore: cast_nullable_to_non_nullable
as bool,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,enableRoutes: null == enableRoutes ? _self.enableRoutes : enableRoutes // ignore: cast_nullable_to_non_nullable
as bool,enableMemberDirectory: null == enableMemberDirectory ? _self.enableMemberDirectory : enableMemberDirectory // ignore: cast_nullable_to_non_nullable
as bool,postsAsTeamByDefault: null == postsAsTeamByDefault ? _self.postsAsTeamByDefault : postsAsTeamByDefault // ignore: cast_nullable_to_non_nullable
as bool,visibilityEditable: null == visibilityEditable ? _self.visibilityEditable : visibilityEditable // ignore: cast_nullable_to_non_nullable
as bool,routeCount: null == routeCount ? _self.routeCount : routeCount // ignore: cast_nullable_to_non_nullable
as int,addMemberAllowed: null == addMemberAllowed ? _self.addMemberAllowed : addMemberAllowed // ignore: cast_nullable_to_non_nullable
as bool,enableRoutePlanner: null == enableRoutePlanner ? _self.enableRoutePlanner : enableRoutePlanner // ignore: cast_nullable_to_non_nullable
as bool,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,upcomingRideCount: null == upcomingRideCount ? _self.upcomingRideCount : upcomingRideCount // ignore: cast_nullable_to_non_nullable
as int,defaultContentVisibility: null == defaultContentVisibility ? _self.defaultContentVisibility : defaultContentVisibility // ignore: cast_nullable_to_non_nullable
as String,upcomingTripCount: null == upcomingTripCount ? _self.upcomingTripCount : upcomingTripCount // ignore: cast_nullable_to_non_nullable
as int,recentPostCount: null == recentPostCount ? _self.recentPostCount : recentPostCount // ignore: cast_nullable_to_non_nullable
as int,allowedContentVisibilities: null == allowedContentVisibilities ? _self.allowedContentVisibilities : allowedContentVisibilities // ignore: cast_nullable_to_non_nullable
as ContentVisibilitiesDto,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,geometry: freezed == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as TeamDetailDtoGeometry?,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,memberCountByRole: freezed == memberCountByRole ? _self.memberCountByRole : memberCountByRole // ignore: cast_nullable_to_non_nullable
as MemberCountByRoleDto?,memberLimit: freezed == memberLimit ? _self.memberLimit : memberLimit // ignore: cast_nullable_to_non_nullable
as int?,pages: freezed == pages ? _self.pages : pages // ignore: cast_nullable_to_non_nullable
as List<TeamPageSummaryDto>?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool joinable,  String name,  String slug,  MediaDto about,  String tier,  bool enableRides,  bool publicContentAllowed,  String visibility,  bool enableTrips,  bool enableAds,  bool enablePosts,  String id,  bool enableRoutes,  bool enableMemberDirectory,  bool postsAsTeamByDefault,  bool visibilityEditable,  int routeCount,  bool addMemberAllowed,  bool enableRoutePlanner,  int memberCount,  int upcomingRideCount,  String defaultContentVisibility,  int upcomingTripCount,  int recentPostCount,  ContentVisibilitiesDto allowedContentVisibilities,  String createdAt,  String timezone,  TeamDetailDtoGeometry? geometry,  String? logoUrl,  MemberCountByRoleDto? memberCountByRole,  int? memberLimit,  List<TeamPageSummaryDto>? pages,  String? excerpt,  String? role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamDetailDto() when $default != null:
return $default(_that.joinable,_that.name,_that.slug,_that.about,_that.tier,_that.enableRides,_that.publicContentAllowed,_that.visibility,_that.enableTrips,_that.enableAds,_that.enablePosts,_that.id,_that.enableRoutes,_that.enableMemberDirectory,_that.postsAsTeamByDefault,_that.visibilityEditable,_that.routeCount,_that.addMemberAllowed,_that.enableRoutePlanner,_that.memberCount,_that.upcomingRideCount,_that.defaultContentVisibility,_that.upcomingTripCount,_that.recentPostCount,_that.allowedContentVisibilities,_that.createdAt,_that.timezone,_that.geometry,_that.logoUrl,_that.memberCountByRole,_that.memberLimit,_that.pages,_that.excerpt,_that.role);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool joinable,  String name,  String slug,  MediaDto about,  String tier,  bool enableRides,  bool publicContentAllowed,  String visibility,  bool enableTrips,  bool enableAds,  bool enablePosts,  String id,  bool enableRoutes,  bool enableMemberDirectory,  bool postsAsTeamByDefault,  bool visibilityEditable,  int routeCount,  bool addMemberAllowed,  bool enableRoutePlanner,  int memberCount,  int upcomingRideCount,  String defaultContentVisibility,  int upcomingTripCount,  int recentPostCount,  ContentVisibilitiesDto allowedContentVisibilities,  String createdAt,  String timezone,  TeamDetailDtoGeometry? geometry,  String? logoUrl,  MemberCountByRoleDto? memberCountByRole,  int? memberLimit,  List<TeamPageSummaryDto>? pages,  String? excerpt,  String? role)  $default,) {final _that = this;
switch (_that) {
case _TeamDetailDto():
return $default(_that.joinable,_that.name,_that.slug,_that.about,_that.tier,_that.enableRides,_that.publicContentAllowed,_that.visibility,_that.enableTrips,_that.enableAds,_that.enablePosts,_that.id,_that.enableRoutes,_that.enableMemberDirectory,_that.postsAsTeamByDefault,_that.visibilityEditable,_that.routeCount,_that.addMemberAllowed,_that.enableRoutePlanner,_that.memberCount,_that.upcomingRideCount,_that.defaultContentVisibility,_that.upcomingTripCount,_that.recentPostCount,_that.allowedContentVisibilities,_that.createdAt,_that.timezone,_that.geometry,_that.logoUrl,_that.memberCountByRole,_that.memberLimit,_that.pages,_that.excerpt,_that.role);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool joinable,  String name,  String slug,  MediaDto about,  String tier,  bool enableRides,  bool publicContentAllowed,  String visibility,  bool enableTrips,  bool enableAds,  bool enablePosts,  String id,  bool enableRoutes,  bool enableMemberDirectory,  bool postsAsTeamByDefault,  bool visibilityEditable,  int routeCount,  bool addMemberAllowed,  bool enableRoutePlanner,  int memberCount,  int upcomingRideCount,  String defaultContentVisibility,  int upcomingTripCount,  int recentPostCount,  ContentVisibilitiesDto allowedContentVisibilities,  String createdAt,  String timezone,  TeamDetailDtoGeometry? geometry,  String? logoUrl,  MemberCountByRoleDto? memberCountByRole,  int? memberLimit,  List<TeamPageSummaryDto>? pages,  String? excerpt,  String? role)?  $default,) {final _that = this;
switch (_that) {
case _TeamDetailDto() when $default != null:
return $default(_that.joinable,_that.name,_that.slug,_that.about,_that.tier,_that.enableRides,_that.publicContentAllowed,_that.visibility,_that.enableTrips,_that.enableAds,_that.enablePosts,_that.id,_that.enableRoutes,_that.enableMemberDirectory,_that.postsAsTeamByDefault,_that.visibilityEditable,_that.routeCount,_that.addMemberAllowed,_that.enableRoutePlanner,_that.memberCount,_that.upcomingRideCount,_that.defaultContentVisibility,_that.upcomingTripCount,_that.recentPostCount,_that.allowedContentVisibilities,_that.createdAt,_that.timezone,_that.geometry,_that.logoUrl,_that.memberCountByRole,_that.memberLimit,_that.pages,_that.excerpt,_that.role);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamDetailDto implements TeamDetailDto {
  const _TeamDetailDto({required this.joinable, required this.name, required this.slug, required this.about, required this.tier, required this.enableRides, required this.publicContentAllowed, required this.visibility, required this.enableTrips, required this.enableAds, required this.enablePosts, required this.id, required this.enableRoutes, required this.enableMemberDirectory, required this.postsAsTeamByDefault, required this.visibilityEditable, required this.routeCount, required this.addMemberAllowed, required this.enableRoutePlanner, required this.memberCount, required this.upcomingRideCount, required this.defaultContentVisibility, required this.upcomingTripCount, required this.recentPostCount, required this.allowedContentVisibilities, required this.createdAt, required this.timezone, this.geometry, this.logoUrl, this.memberCountByRole, this.memberLimit,  List<TeamPageSummaryDto>? pages, this.excerpt, this.role}): _pages = pages;
  factory _TeamDetailDto.fromJson(Map<String, dynamic> json) => _$TeamDetailDtoFromJson(json);

/// Whether any domain user can join this team
@override final  bool joinable;
/// Team name
@override final  String name;
/// Team URL slug
@override final  String slug;
/// About page content
@override final  MediaDto about;
/// The team's plan, set by a platform admin only. FREE caps the members and the route planner saves, UNLOCKED lifts both caps.
@override final  String tier;
/// Rides enabled
@override final  bool enableRides;
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
/// Team ID (TSID)
@override final  String id;
/// Routes enabled
@override final  bool enableRoutes;
/// Whether the member directory is readable by every member and not just by administrators. Clients use it to decide whether to offer the directory at all: an entry that always leads to a 403 is worse than no entry. Organisers see the directory whatever its value, but only get each member's role and join date when it is true.
@override final  bool enableMemberDirectory;
/// Whether a new post starts signed by the team rather than by its author — the initial value of the editor's « on behalf of the team » box.
@override final  bool postsAsTeamByDefault;
/// Whether visibility is editable by team admins
@override final  bool visibilityEditable;
/// Routes of this team the caller may open, under the same visibility rules as the route listing.
@override final  int routeCount;
/// Whether team admins can add members
@override final  bool addMemberAllowed;
/// Whether the interactive route planner is open to this team. Unlike enableRoutes it never hides the routes section: when false the track can still be imported or replaced from a GPX file, only drawing is closed. Platform-admin only.
@override final  bool enableRoutePlanner;
/// Number of team members
@override final  int memberCount;
/// Rides of this team dated in the future that the caller may open. Follows the same visibility rules as the ride listing, so it never announces more than the caller can actually see.
@override final  int upcomingRideCount;
/// The visibility a creation form starts from: the team's own, so TEAM for a private team, publicContentAllowed or not. Not for ads, which are always TEAM.
@override final  String defaultContentVisibility;
/// Trips of this team starting in the future that the caller may open, under the same visibility rules as the trip listing. 0 when trips are disabled.
@override final  int upcomingTripCount;
/// Published posts of this team dated within the last 7 days (and not in the future) that the caller may open, under the same visibility rules as the post listing. Feeds the activity line of a member's team card. 0 when posts are disabled.
@override final  int recentPostCount;
/// The visibilities the team accepts for each type of content: what a creation form offers. The same for every caller who may read the team — the server still decides who may write. A private team holds TEAM only, unless a platform admin set publicContentAllowed.
@override final  ContentVisibilitiesDto allowedContentVisibilities;
/// Team creation timestamp
@override final  String createdAt;
/// The team's IANA zone: the one its rides, trips and posts fall back on when no place locates them. Administrators change it through TeamRequest.timezone.
@override final  String timezone;
/// Team location coordinates [longitude, latitude]
@override final  TeamDetailDtoGeometry? geometry;
/// URL template of the team's logo, when it has one. Same picture as about.assets.logo, hoisted so a card does not have to walk the asset inventory to find it. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? logoUrl;
/// Members per role. Only for the team's administrators (platform admins included): null for everyone else, and in the team listings.
@override final  MemberCountByRoleDto? memberCountByRole;
/// The most members the team may hold, pending invitations included; null when unlimited. Compare with memberCount.
@override final  int? memberLimit;
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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamDetailDto&&(identical(other.joinable, joinable) || other.joinable == joinable)&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.about, about) || other.about == about)&&(identical(other.tier, tier) || other.tier == tier)&&(identical(other.enableRides, enableRides) || other.enableRides == enableRides)&&(identical(other.publicContentAllowed, publicContentAllowed) || other.publicContentAllowed == publicContentAllowed)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.enableTrips, enableTrips) || other.enableTrips == enableTrips)&&(identical(other.enableAds, enableAds) || other.enableAds == enableAds)&&(identical(other.enablePosts, enablePosts) || other.enablePosts == enablePosts)&&(identical(other.id, id) || other.id == id)&&(identical(other.enableRoutes, enableRoutes) || other.enableRoutes == enableRoutes)&&(identical(other.enableMemberDirectory, enableMemberDirectory) || other.enableMemberDirectory == enableMemberDirectory)&&(identical(other.postsAsTeamByDefault, postsAsTeamByDefault) || other.postsAsTeamByDefault == postsAsTeamByDefault)&&(identical(other.visibilityEditable, visibilityEditable) || other.visibilityEditable == visibilityEditable)&&(identical(other.routeCount, routeCount) || other.routeCount == routeCount)&&(identical(other.addMemberAllowed, addMemberAllowed) || other.addMemberAllowed == addMemberAllowed)&&(identical(other.enableRoutePlanner, enableRoutePlanner) || other.enableRoutePlanner == enableRoutePlanner)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.upcomingRideCount, upcomingRideCount) || other.upcomingRideCount == upcomingRideCount)&&(identical(other.defaultContentVisibility, defaultContentVisibility) || other.defaultContentVisibility == defaultContentVisibility)&&(identical(other.upcomingTripCount, upcomingTripCount) || other.upcomingTripCount == upcomingTripCount)&&(identical(other.recentPostCount, recentPostCount) || other.recentPostCount == recentPostCount)&&(identical(other.allowedContentVisibilities, allowedContentVisibilities) || other.allowedContentVisibilities == allowedContentVisibilities)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.geometry, geometry) || other.geometry == geometry)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.memberCountByRole, memberCountByRole) || other.memberCountByRole == memberCountByRole)&&(identical(other.memberLimit, memberLimit) || other.memberLimit == memberLimit)&&const DeepCollectionEquality().equals(other.pages, _pages)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,joinable,name,slug,about,tier,enableRides,publicContentAllowed,visibility,enableTrips,enableAds,enablePosts,id,enableRoutes,enableMemberDirectory,postsAsTeamByDefault,visibilityEditable,routeCount,addMemberAllowed,enableRoutePlanner,memberCount,upcomingRideCount,defaultContentVisibility,upcomingTripCount,recentPostCount,allowedContentVisibilities,createdAt,timezone,geometry,logoUrl,memberCountByRole,memberLimit,const DeepCollectionEquality().hash(_pages),excerpt,role]);
}

@override
String toString() {
    return 'TeamDetailDto(joinable: $joinable, name: $name, slug: $slug, about: $about, tier: $tier, enableRides: $enableRides, publicContentAllowed: $publicContentAllowed, visibility: $visibility, enableTrips: $enableTrips, enableAds: $enableAds, enablePosts: $enablePosts, id: $id, enableRoutes: $enableRoutes, enableMemberDirectory: $enableMemberDirectory, postsAsTeamByDefault: $postsAsTeamByDefault, visibilityEditable: $visibilityEditable, routeCount: $routeCount, addMemberAllowed: $addMemberAllowed, enableRoutePlanner: $enableRoutePlanner, memberCount: $memberCount, upcomingRideCount: $upcomingRideCount, defaultContentVisibility: $defaultContentVisibility, upcomingTripCount: $upcomingTripCount, recentPostCount: $recentPostCount, allowedContentVisibilities: $allowedContentVisibilities, createdAt: $createdAt, timezone: $timezone, geometry: $geometry, logoUrl: $logoUrl, memberCountByRole: $memberCountByRole, memberLimit: $memberLimit, pages: $pages, excerpt: $excerpt, role: $role)';
}


}

/// @nodoc
abstract mixin class _$TeamDetailDtoCopyWith<$Res> implements $TeamDetailDtoCopyWith<$Res> {
  factory _$TeamDetailDtoCopyWith(_TeamDetailDto value, $Res Function(_TeamDetailDto) _then) = __$TeamDetailDtoCopyWithImpl;
@override @useResult
$Res call({
 bool joinable, String name, String slug, MediaDto about, String tier, bool enableRides, bool publicContentAllowed, String visibility, bool enableTrips, bool enableAds, bool enablePosts, String id, bool enableRoutes, bool enableMemberDirectory, bool postsAsTeamByDefault, bool visibilityEditable, int routeCount, bool addMemberAllowed, bool enableRoutePlanner, int memberCount, int upcomingRideCount, String defaultContentVisibility, int upcomingTripCount, int recentPostCount, ContentVisibilitiesDto allowedContentVisibilities, String createdAt, String timezone, TeamDetailDtoGeometry? geometry, String? logoUrl, MemberCountByRoleDto? memberCountByRole, int? memberLimit, List<TeamPageSummaryDto>? pages, String? excerpt, String? role
});


@override $MediaDtoCopyWith<$Res> get about;@override $ContentVisibilitiesDtoCopyWith<$Res> get allowedContentVisibilities;@override $TeamDetailDtoGeometryCopyWith<$Res>? get geometry;@override $MemberCountByRoleDtoCopyWith<$Res>? get memberCountByRole;

}
/// @nodoc
class __$TeamDetailDtoCopyWithImpl<$Res>
    implements _$TeamDetailDtoCopyWith<$Res> {
  __$TeamDetailDtoCopyWithImpl(this._self, this._then);

  final _TeamDetailDto _self;
  final $Res Function(_TeamDetailDto) _then;

/// Create a copy of TeamDetailDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? joinable = null,Object? name = null,Object? slug = null,Object? about = null,Object? tier = null,Object? enableRides = null,Object? publicContentAllowed = null,Object? visibility = null,Object? enableTrips = null,Object? enableAds = null,Object? enablePosts = null,Object? id = null,Object? enableRoutes = null,Object? enableMemberDirectory = null,Object? postsAsTeamByDefault = null,Object? visibilityEditable = null,Object? routeCount = null,Object? addMemberAllowed = null,Object? enableRoutePlanner = null,Object? memberCount = null,Object? upcomingRideCount = null,Object? defaultContentVisibility = null,Object? upcomingTripCount = null,Object? recentPostCount = null,Object? allowedContentVisibilities = null,Object? createdAt = null,Object? timezone = null,Object? geometry = freezed,Object? logoUrl = freezed,Object? memberCountByRole = freezed,Object? memberLimit = freezed,Object? pages = freezed,Object? excerpt = freezed,Object? role = freezed,}) {
  return _then(_TeamDetailDto(
joinable: null == joinable ? _self.joinable : joinable // ignore: cast_nullable_to_non_nullable
as bool,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,about: null == about ? _self.about : about // ignore: cast_nullable_to_non_nullable
as MediaDto,tier: null == tier ? _self.tier : tier // ignore: cast_nullable_to_non_nullable
as String,enableRides: null == enableRides ? _self.enableRides : enableRides // ignore: cast_nullable_to_non_nullable
as bool,publicContentAllowed: null == publicContentAllowed ? _self.publicContentAllowed : publicContentAllowed // ignore: cast_nullable_to_non_nullable
as bool,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,enableTrips: null == enableTrips ? _self.enableTrips : enableTrips // ignore: cast_nullable_to_non_nullable
as bool,enableAds: null == enableAds ? _self.enableAds : enableAds // ignore: cast_nullable_to_non_nullable
as bool,enablePosts: null == enablePosts ? _self.enablePosts : enablePosts // ignore: cast_nullable_to_non_nullable
as bool,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,enableRoutes: null == enableRoutes ? _self.enableRoutes : enableRoutes // ignore: cast_nullable_to_non_nullable
as bool,enableMemberDirectory: null == enableMemberDirectory ? _self.enableMemberDirectory : enableMemberDirectory // ignore: cast_nullable_to_non_nullable
as bool,postsAsTeamByDefault: null == postsAsTeamByDefault ? _self.postsAsTeamByDefault : postsAsTeamByDefault // ignore: cast_nullable_to_non_nullable
as bool,visibilityEditable: null == visibilityEditable ? _self.visibilityEditable : visibilityEditable // ignore: cast_nullable_to_non_nullable
as bool,routeCount: null == routeCount ? _self.routeCount : routeCount // ignore: cast_nullable_to_non_nullable
as int,addMemberAllowed: null == addMemberAllowed ? _self.addMemberAllowed : addMemberAllowed // ignore: cast_nullable_to_non_nullable
as bool,enableRoutePlanner: null == enableRoutePlanner ? _self.enableRoutePlanner : enableRoutePlanner // ignore: cast_nullable_to_non_nullable
as bool,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,upcomingRideCount: null == upcomingRideCount ? _self.upcomingRideCount : upcomingRideCount // ignore: cast_nullable_to_non_nullable
as int,defaultContentVisibility: null == defaultContentVisibility ? _self.defaultContentVisibility : defaultContentVisibility // ignore: cast_nullable_to_non_nullable
as String,upcomingTripCount: null == upcomingTripCount ? _self.upcomingTripCount : upcomingTripCount // ignore: cast_nullable_to_non_nullable
as int,recentPostCount: null == recentPostCount ? _self.recentPostCount : recentPostCount // ignore: cast_nullable_to_non_nullable
as int,allowedContentVisibilities: null == allowedContentVisibilities ? _self.allowedContentVisibilities : allowedContentVisibilities // ignore: cast_nullable_to_non_nullable
as ContentVisibilitiesDto,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,geometry: freezed == geometry ? _self.geometry : geometry // ignore: cast_nullable_to_non_nullable
as TeamDetailDtoGeometry?,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,memberCountByRole: freezed == memberCountByRole ? _self.memberCountByRole : memberCountByRole // ignore: cast_nullable_to_non_nullable
as MemberCountByRoleDto?,memberLimit: freezed == memberLimit ? _self.memberLimit : memberLimit // ignore: cast_nullable_to_non_nullable
as int?,pages: freezed == pages ? _self._pages : pages // ignore: cast_nullable_to_non_nullable
as List<TeamPageSummaryDto>?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
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
}
}

// dart format on
