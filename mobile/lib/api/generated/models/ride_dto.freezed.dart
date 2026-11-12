// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RideDto {

/// Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.
 List<PublicUserDto> get topParticipants;/// Team
 TeamPublicationDto get team;/// Publication ID (TSID)
 String get id;/// Publication URL slug
 String get slug;/// Publication name
 String get name;/// Publication media
 MediaDto get media;/// When the ride starts: its own departure, which a group without a time of its own leaves at (RideGroupDto.startAt holds each group's). Not the publication date — that is publishAt for a scheduled one.
 String get dateTime;/// IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone.
 String get timezone;/// When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read.
 String get endDateTime;/// Publication status
 String get status;/// Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.
 bool get finished;/// Visibility level
 String get visibility;/// Type
 String get type;/// Number of participants
 int get participantCount;/// Number of groups
 int get groupCount;/// Ride groups
 List<RideGroupDto> get groups;/// Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.
 List<RideGroupSummaryDto> get groupSummaries;/// Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.
 bool get full;/// Whether the current user is registered in one of this ride's groups. False if anonymous.
 bool get registered;/// The team's RIDE tags the ride carries, sorted by label. Empty when it carries none.
 List<TagDto> get tags;/// Whether the ride is soft-deleted
 bool get deleted;/// What the caller may do with the ride: edit, delete, register, comment, see who rides. allowedVisibilities is only on the detail.
 ContentPermissionsDto get permissions;/// Surface type, from the same route as distance. Null when no route is set anywhere.
 String? get surfaceType;/// The distance in meters a card shows to the caller, computed by the server: the route of the group they joined when they are registered (its own, else the ride's); otherwise the route every group of the ride rides (the ride's own when it has no group); otherwise null — groups on different routes and caller not registered, or no route at all. Anonymous and non-member callers get the not-registered answer. Same value on list rows and on the detail; clients show it as is instead of choosing between distance, registeredGroup.distance and the groups'.
 double? get displayDistance;/// The elevation gain in meters a card shows to the caller, from the same route as displayDistance. Null whenever displayDistance is.
 double? get displayElevationGain;/// Start place
 PlaceDetailDto? get startPlace;/// End place
 PlaceDetailDto? get endPlace;/// Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.
 double? get elevationGain;/// Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailLightUrl;/// Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailDarkUrl;/// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailUrl;/// Publication timestamp
 String? get publishAt;/// Route slug
 String? get routeSlug;/// ID (TSID) of the group the current user joined, null if not registered
 String? get registeredGroupId;/// The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group's own, null when none was designated.
 RideGroupDto? get registeredGroup;/// Creation timestamp
 String? get createdAt;/// Capacity of the whole ride: the sum of its groups' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty.
 int? get maxParticipants;/// Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.
 int? get commentCount;/// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
 String? get excerpt;/// The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.
 RideWeatherSummaryDto? get weather;/// Where the ride's own route (the one of routeSlug) stands at each of the caller's GPS services whose automatic sync is on and which hold it, sorted by service — each group's route is on the group. Only ever about the caller's own connections. Absent when there is none: anonymous caller, no such service, no route.
 List<RouteGpsSyncStatusDto>? get gpsSyncStatuses;/// Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere.
 double? get distance;
/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RideDtoCopyWith<RideDto> get copyWith => _$RideDtoCopyWithImpl<RideDto>(this as RideDto, _$identity);

  /// Serializes this RideDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RideDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RideDto&&const DeepCollectionEquality().equals(other.topParticipants, _this.topParticipants)&&(identical(other.team, _this.team) || other.team == _this.team)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.dateTime, _this.dateTime) || other.dateTime == _this.dateTime)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.endDateTime, _this.endDateTime) || other.endDateTime == _this.endDateTime)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.finished, _this.finished) || other.finished == _this.finished)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.participantCount, _this.participantCount) || other.participantCount == _this.participantCount)&&(identical(other.groupCount, _this.groupCount) || other.groupCount == _this.groupCount)&&const DeepCollectionEquality().equals(other.groups, _this.groups)&&const DeepCollectionEquality().equals(other.groupSummaries, _this.groupSummaries)&&(identical(other.full, _this.full) || other.full == _this.full)&&(identical(other.registered, _this.registered) || other.registered == _this.registered)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&(identical(other.permissions, _this.permissions) || other.permissions == _this.permissions)&&(identical(other.surfaceType, _this.surfaceType) || other.surfaceType == _this.surfaceType)&&(identical(other.displayDistance, _this.displayDistance) || other.displayDistance == _this.displayDistance)&&(identical(other.displayElevationGain, _this.displayElevationGain) || other.displayElevationGain == _this.displayElevationGain)&&(identical(other.startPlace, _this.startPlace) || other.startPlace == _this.startPlace)&&(identical(other.endPlace, _this.endPlace) || other.endPlace == _this.endPlace)&&(identical(other.elevationGain, _this.elevationGain) || other.elevationGain == _this.elevationGain)&&(identical(other.thumbnailLightUrl, _this.thumbnailLightUrl) || other.thumbnailLightUrl == _this.thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, _this.thumbnailDarkUrl) || other.thumbnailDarkUrl == _this.thumbnailDarkUrl)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.publishAt, _this.publishAt) || other.publishAt == _this.publishAt)&&(identical(other.routeSlug, _this.routeSlug) || other.routeSlug == _this.routeSlug)&&(identical(other.registeredGroupId, _this.registeredGroupId) || other.registeredGroupId == _this.registeredGroupId)&&(identical(other.registeredGroup, _this.registeredGroup) || other.registeredGroup == _this.registeredGroup)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.maxParticipants, _this.maxParticipants) || other.maxParticipants == _this.maxParticipants)&&(identical(other.commentCount, _this.commentCount) || other.commentCount == _this.commentCount)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt)&&(identical(other.weather, _this.weather) || other.weather == _this.weather)&&const DeepCollectionEquality().equals(other.gpsSyncStatuses, _this.gpsSyncStatuses)&&(identical(other.distance, _this.distance) || other.distance == _this.distance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RideDto;
  return Object.hashAll([runtimeType,const DeepCollectionEquality().hash(_this.topParticipants),_this.team,_this.id,_this.slug,_this.name,_this.media,_this.dateTime,_this.timezone,_this.endDateTime,_this.status,_this.finished,_this.visibility,_this.type,_this.participantCount,_this.groupCount,const DeepCollectionEquality().hash(_this.groups),const DeepCollectionEquality().hash(_this.groupSummaries),_this.full,_this.registered,const DeepCollectionEquality().hash(_this.tags),_this.deleted,_this.permissions,_this.surfaceType,_this.displayDistance,_this.displayElevationGain,_this.startPlace,_this.endPlace,_this.elevationGain,_this.thumbnailLightUrl,_this.thumbnailDarkUrl,_this.thumbnailUrl,_this.publishAt,_this.routeSlug,_this.registeredGroupId,_this.registeredGroup,_this.createdAt,_this.maxParticipants,_this.commentCount,_this.excerpt,_this.weather,const DeepCollectionEquality().hash(_this.gpsSyncStatuses),_this.distance]);
}

@override
String toString() {
  final _this = this as RideDto;
  return 'RideDto(topParticipants: ${_this.topParticipants}, team: ${_this.team}, id: ${_this.id}, slug: ${_this.slug}, name: ${_this.name}, media: ${_this.media}, dateTime: ${_this.dateTime}, timezone: ${_this.timezone}, endDateTime: ${_this.endDateTime}, status: ${_this.status}, finished: ${_this.finished}, visibility: ${_this.visibility}, type: ${_this.type}, participantCount: ${_this.participantCount}, groupCount: ${_this.groupCount}, groups: ${_this.groups}, groupSummaries: ${_this.groupSummaries}, full: ${_this.full}, registered: ${_this.registered}, tags: ${_this.tags}, deleted: ${_this.deleted}, permissions: ${_this.permissions}, surfaceType: ${_this.surfaceType}, displayDistance: ${_this.displayDistance}, displayElevationGain: ${_this.displayElevationGain}, startPlace: ${_this.startPlace}, endPlace: ${_this.endPlace}, elevationGain: ${_this.elevationGain}, thumbnailLightUrl: ${_this.thumbnailLightUrl}, thumbnailDarkUrl: ${_this.thumbnailDarkUrl}, thumbnailUrl: ${_this.thumbnailUrl}, publishAt: ${_this.publishAt}, routeSlug: ${_this.routeSlug}, registeredGroupId: ${_this.registeredGroupId}, registeredGroup: ${_this.registeredGroup}, createdAt: ${_this.createdAt}, maxParticipants: ${_this.maxParticipants}, commentCount: ${_this.commentCount}, excerpt: ${_this.excerpt}, weather: ${_this.weather}, gpsSyncStatuses: ${_this.gpsSyncStatuses}, distance: ${_this.distance})';
}


}

/// @nodoc
abstract mixin class $RideDtoCopyWith<$Res>  {
  factory $RideDtoCopyWith(RideDto value, $Res Function(RideDto) _then) = _$RideDtoCopyWithImpl;
@useResult
$Res call({
 List<PublicUserDto> topParticipants, TeamPublicationDto team, String id, String slug, String name, MediaDto media, String dateTime, String timezone, String endDateTime, String status, bool finished, String visibility, String type, int participantCount, int groupCount, List<RideGroupDto> groups, List<RideGroupSummaryDto> groupSummaries, bool full, bool registered, List<TagDto> tags, bool deleted, ContentPermissionsDto permissions, String? surfaceType, double? displayDistance, double? displayElevationGain, PlaceDetailDto? startPlace, PlaceDetailDto? endPlace, double? elevationGain, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? thumbnailUrl, String? publishAt, String? routeSlug, String? registeredGroupId, RideGroupDto? registeredGroup, String? createdAt, int? maxParticipants, int? commentCount, String? excerpt, RideWeatherSummaryDto? weather, List<RouteGpsSyncStatusDto>? gpsSyncStatuses, double? distance
});


$TeamPublicationDtoCopyWith<$Res> get team;$MediaDtoCopyWith<$Res> get media;$ContentPermissionsDtoCopyWith<$Res> get permissions;$PlaceDetailDtoCopyWith<$Res>? get startPlace;$PlaceDetailDtoCopyWith<$Res>? get endPlace;$RideGroupDtoCopyWith<$Res>? get registeredGroup;$RideWeatherSummaryDtoCopyWith<$Res>? get weather;

}
/// @nodoc
class _$RideDtoCopyWithImpl<$Res>
    implements $RideDtoCopyWith<$Res> {
  _$RideDtoCopyWithImpl(this._self, this._then);

  final RideDto _self;
  final $Res Function(RideDto) _then;

/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? topParticipants = null,Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? dateTime = null,Object? timezone = null,Object? endDateTime = null,Object? status = null,Object? finished = null,Object? visibility = null,Object? type = null,Object? participantCount = null,Object? groupCount = null,Object? groups = null,Object? groupSummaries = null,Object? full = null,Object? registered = null,Object? tags = null,Object? deleted = null,Object? permissions = null,Object? surfaceType = freezed,Object? displayDistance = freezed,Object? displayElevationGain = freezed,Object? startPlace = freezed,Object? endPlace = freezed,Object? elevationGain = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? thumbnailUrl = freezed,Object? publishAt = freezed,Object? routeSlug = freezed,Object? registeredGroupId = freezed,Object? registeredGroup = freezed,Object? createdAt = freezed,Object? maxParticipants = freezed,Object? commentCount = freezed,Object? excerpt = freezed,Object? weather = freezed,Object? gpsSyncStatuses = freezed,Object? distance = freezed,}) {
  return _then(RideDto(
topParticipants: null == topParticipants ? _self.topParticipants : topParticipants // ignore: cast_nullable_to_non_nullable
as List<PublicUserDto>,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,endDateTime: null == endDateTime ? _self.endDateTime : endDateTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,groupCount: null == groupCount ? _self.groupCount : groupCount // ignore: cast_nullable_to_non_nullable
as int,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<RideGroupDto>,groupSummaries: null == groupSummaries ? _self.groupSummaries : groupSummaries // ignore: cast_nullable_to_non_nullable
as List<RideGroupSummaryDto>,full: null == full ? _self.full : full // ignore: cast_nullable_to_non_nullable
as bool,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as ContentPermissionsDto,surfaceType: freezed == surfaceType ? _self.surfaceType : surfaceType // ignore: cast_nullable_to_non_nullable
as String?,displayDistance: freezed == displayDistance ? _self.displayDistance : displayDistance // ignore: cast_nullable_to_non_nullable
as double?,displayElevationGain: freezed == displayElevationGain ? _self.displayElevationGain : displayElevationGain // ignore: cast_nullable_to_non_nullable
as double?,startPlace: freezed == startPlace ? _self.startPlace : startPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,endPlace: freezed == endPlace ? _self.endPlace : endPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,elevationGain: freezed == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double?,thumbnailLightUrl: freezed == thumbnailLightUrl ? _self.thumbnailLightUrl : thumbnailLightUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailDarkUrl: freezed == thumbnailDarkUrl ? _self.thumbnailDarkUrl : thumbnailDarkUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,registeredGroupId: freezed == registeredGroupId ? _self.registeredGroupId : registeredGroupId // ignore: cast_nullable_to_non_nullable
as String?,registeredGroup: freezed == registeredGroup ? _self.registeredGroup : registeredGroup // ignore: cast_nullable_to_non_nullable
as RideGroupDto?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,maxParticipants: freezed == maxParticipants ? _self.maxParticipants : maxParticipants // ignore: cast_nullable_to_non_nullable
as int?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as RideWeatherSummaryDto?,gpsSyncStatuses: freezed == gpsSyncStatuses ? _self.gpsSyncStatuses : gpsSyncStatuses // ignore: cast_nullable_to_non_nullable
as List<RouteGpsSyncStatusDto>?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}
/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentPermissionsDtoCopyWith<$Res> get permissions {
  
  return $ContentPermissionsDtoCopyWith<$Res>(_self.permissions, (value) {
    return _then(_self.copyWith(permissions: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceDetailDtoCopyWith<$Res>? get startPlace {
    if (_self.startPlace == null) {
    return null;
  }

  return $PlaceDetailDtoCopyWith<$Res>(_self.startPlace!, (value) {
    return _then(_self.copyWith(startPlace: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceDetailDtoCopyWith<$Res>? get endPlace {
    if (_self.endPlace == null) {
    return null;
  }

  return $PlaceDetailDtoCopyWith<$Res>(_self.endPlace!, (value) {
    return _then(_self.copyWith(endPlace: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RideGroupDtoCopyWith<$Res>? get registeredGroup {
    if (_self.registeredGroup == null) {
    return null;
  }

  return $RideGroupDtoCopyWith<$Res>(_self.registeredGroup!, (value) {
    return _then(_self.copyWith(registeredGroup: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RideWeatherSummaryDtoCopyWith<$Res>? get weather {
    if (_self.weather == null) {
    return null;
  }

  return $RideWeatherSummaryDtoCopyWith<$Res>(_self.weather!, (value) {
    return _then(_self.copyWith(weather: value));
  });
}
}


/// Adds pattern-matching-related methods to [RideDto].
extension RideDtoPatterns on RideDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RideDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RideDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RideDto value)  $default,){
final _that = this;
switch (_that) {
case _RideDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RideDto value)?  $default,){
final _that = this;
switch (_that) {
case _RideDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PublicUserDto> topParticipants,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  String type,  int participantCount,  int groupCount,  List<RideGroupDto> groups,  List<RideGroupSummaryDto> groupSummaries,  bool full,  bool registered,  List<TagDto> tags,  bool deleted,  ContentPermissionsDto permissions,  String? surfaceType,  double? displayDistance,  double? displayElevationGain,  PlaceDetailDto? startPlace,  PlaceDetailDto? endPlace,  double? elevationGain,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  String? publishAt,  String? routeSlug,  String? registeredGroupId,  RideGroupDto? registeredGroup,  String? createdAt,  int? maxParticipants,  int? commentCount,  String? excerpt,  RideWeatherSummaryDto? weather,  List<RouteGpsSyncStatusDto>? gpsSyncStatuses,  double? distance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RideDto() when $default != null:
return $default(_that.topParticipants,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.type,_that.participantCount,_that.groupCount,_that.groups,_that.groupSummaries,_that.full,_that.registered,_that.tags,_that.deleted,_that.permissions,_that.surfaceType,_that.displayDistance,_that.displayElevationGain,_that.startPlace,_that.endPlace,_that.elevationGain,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.publishAt,_that.routeSlug,_that.registeredGroupId,_that.registeredGroup,_that.createdAt,_that.maxParticipants,_that.commentCount,_that.excerpt,_that.weather,_that.gpsSyncStatuses,_that.distance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PublicUserDto> topParticipants,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  String type,  int participantCount,  int groupCount,  List<RideGroupDto> groups,  List<RideGroupSummaryDto> groupSummaries,  bool full,  bool registered,  List<TagDto> tags,  bool deleted,  ContentPermissionsDto permissions,  String? surfaceType,  double? displayDistance,  double? displayElevationGain,  PlaceDetailDto? startPlace,  PlaceDetailDto? endPlace,  double? elevationGain,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  String? publishAt,  String? routeSlug,  String? registeredGroupId,  RideGroupDto? registeredGroup,  String? createdAt,  int? maxParticipants,  int? commentCount,  String? excerpt,  RideWeatherSummaryDto? weather,  List<RouteGpsSyncStatusDto>? gpsSyncStatuses,  double? distance)  $default,) {final _that = this;
switch (_that) {
case _RideDto():
return $default(_that.topParticipants,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.type,_that.participantCount,_that.groupCount,_that.groups,_that.groupSummaries,_that.full,_that.registered,_that.tags,_that.deleted,_that.permissions,_that.surfaceType,_that.displayDistance,_that.displayElevationGain,_that.startPlace,_that.endPlace,_that.elevationGain,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.publishAt,_that.routeSlug,_that.registeredGroupId,_that.registeredGroup,_that.createdAt,_that.maxParticipants,_that.commentCount,_that.excerpt,_that.weather,_that.gpsSyncStatuses,_that.distance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PublicUserDto> topParticipants,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  String type,  int participantCount,  int groupCount,  List<RideGroupDto> groups,  List<RideGroupSummaryDto> groupSummaries,  bool full,  bool registered,  List<TagDto> tags,  bool deleted,  ContentPermissionsDto permissions,  String? surfaceType,  double? displayDistance,  double? displayElevationGain,  PlaceDetailDto? startPlace,  PlaceDetailDto? endPlace,  double? elevationGain,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  String? publishAt,  String? routeSlug,  String? registeredGroupId,  RideGroupDto? registeredGroup,  String? createdAt,  int? maxParticipants,  int? commentCount,  String? excerpt,  RideWeatherSummaryDto? weather,  List<RouteGpsSyncStatusDto>? gpsSyncStatuses,  double? distance)?  $default,) {final _that = this;
switch (_that) {
case _RideDto() when $default != null:
return $default(_that.topParticipants,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.type,_that.participantCount,_that.groupCount,_that.groups,_that.groupSummaries,_that.full,_that.registered,_that.tags,_that.deleted,_that.permissions,_that.surfaceType,_that.displayDistance,_that.displayElevationGain,_that.startPlace,_that.endPlace,_that.elevationGain,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.publishAt,_that.routeSlug,_that.registeredGroupId,_that.registeredGroup,_that.createdAt,_that.maxParticipants,_that.commentCount,_that.excerpt,_that.weather,_that.gpsSyncStatuses,_that.distance);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RideDto implements RideDto {
  const _RideDto({required  List<PublicUserDto> topParticipants, required this.team, required this.id, required this.slug, required this.name, required this.media, required this.dateTime, required this.timezone, required this.endDateTime, required this.status, required this.finished, required this.visibility, required this.type, required this.participantCount, required this.groupCount, required  List<RideGroupDto> groups, required  List<RideGroupSummaryDto> groupSummaries, required this.full, required this.registered, required  List<TagDto> tags, required this.deleted, required this.permissions, this.surfaceType, this.displayDistance, this.displayElevationGain, this.startPlace, this.endPlace, this.elevationGain, this.thumbnailLightUrl, this.thumbnailDarkUrl, this.thumbnailUrl, this.publishAt, this.routeSlug, this.registeredGroupId, this.registeredGroup, this.createdAt, this.maxParticipants, this.commentCount, this.excerpt, this.weather,  List<RouteGpsSyncStatusDto>? gpsSyncStatuses, this.distance}): _topParticipants = topParticipants,_groups = groups,_groupSummaries = groupSummaries,_tags = tags,_gpsSyncStatuses = gpsSyncStatuses;
  factory _RideDto.fromJson(Map<String, dynamic> json) => _$RideDtoFromJson(json);

/// Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.
 final  List<PublicUserDto> _topParticipants;
/// Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.
@override List<PublicUserDto> get topParticipants {
  if (_topParticipants is EqualUnmodifiableListView) return _topParticipants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topParticipants);
}

/// Team
@override final  TeamPublicationDto team;
/// Publication ID (TSID)
@override final  String id;
/// Publication URL slug
@override final  String slug;
/// Publication name
@override final  String name;
/// Publication media
@override final  MediaDto media;
/// When the ride starts: its own departure, which a group without a time of its own leaves at (RideGroupDto.startAt holds each group's). Not the publication date — that is publishAt for a scheduled one.
@override final  String dateTime;
/// IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone.
@override final  String timezone;
/// When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read.
@override final  String endDateTime;
/// Publication status
@override final  String status;
/// Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.
@override final  bool finished;
/// Visibility level
@override final  String visibility;
/// Type
@override final  String type;
/// Number of participants
@override final  int participantCount;
/// Number of groups
@override final  int groupCount;
/// Ride groups
 final  List<RideGroupDto> _groups;
/// Ride groups
@override List<RideGroupDto> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

/// Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.
 final  List<RideGroupSummaryDto> _groupSummaries;
/// Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.
@override List<RideGroupSummaryDto> get groupSummaries {
  if (_groupSummaries is EqualUnmodifiableListView) return _groupSummaries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groupSummaries);
}

/// Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.
@override final  bool full;
/// Whether the current user is registered in one of this ride's groups. False if anonymous.
@override final  bool registered;
/// The team's RIDE tags the ride carries, sorted by label. Empty when it carries none.
 final  List<TagDto> _tags;
/// The team's RIDE tags the ride carries, sorted by label. Empty when it carries none.
@override List<TagDto> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// Whether the ride is soft-deleted
@override final  bool deleted;
/// What the caller may do with the ride: edit, delete, register, comment, see who rides. allowedVisibilities is only on the detail.
@override final  ContentPermissionsDto permissions;
/// Surface type, from the same route as distance. Null when no route is set anywhere.
@override final  String? surfaceType;
/// The distance in meters a card shows to the caller, computed by the server: the route of the group they joined when they are registered (its own, else the ride's); otherwise the route every group of the ride rides (the ride's own when it has no group); otherwise null — groups on different routes and caller not registered, or no route at all. Anonymous and non-member callers get the not-registered answer. Same value on list rows and on the detail; clients show it as is instead of choosing between distance, registeredGroup.distance and the groups'.
@override final  double? displayDistance;
/// The elevation gain in meters a card shows to the caller, from the same route as displayDistance. Null whenever displayDistance is.
@override final  double? displayElevationGain;
/// Start place
@override final  PlaceDetailDto? startPlace;
/// End place
@override final  PlaceDetailDto? endPlace;
/// Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.
@override final  double? elevationGain;
/// Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailLightUrl;
/// Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailDarkUrl;
/// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;
/// Publication timestamp
@override final  String? publishAt;
/// Route slug
@override final  String? routeSlug;
/// ID (TSID) of the group the current user joined, null if not registered
@override final  String? registeredGroupId;
/// The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group's own, null when none was designated.
@override final  RideGroupDto? registeredGroup;
/// Creation timestamp
@override final  String? createdAt;
/// Capacity of the whole ride: the sum of its groups' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty.
@override final  int? maxParticipants;
/// Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.
@override final  int? commentCount;
/// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
@override final  String? excerpt;
/// The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.
@override final  RideWeatherSummaryDto? weather;
/// Where the ride's own route (the one of routeSlug) stands at each of the caller's GPS services whose automatic sync is on and which hold it, sorted by service — each group's route is on the group. Only ever about the caller's own connections. Absent when there is none: anonymous caller, no such service, no route.
 final  List<RouteGpsSyncStatusDto>? _gpsSyncStatuses;
/// Where the ride's own route (the one of routeSlug) stands at each of the caller's GPS services whose automatic sync is on and which hold it, sorted by service — each group's route is on the group. Only ever about the caller's own connections. Absent when there is none: anonymous caller, no such service, no route.
@override List<RouteGpsSyncStatusDto>? get gpsSyncStatuses {
  final value = _gpsSyncStatuses;
  if (value == null) return null;
  if (_gpsSyncStatuses is EqualUnmodifiableListView) return _gpsSyncStatuses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere.
@override final  double? distance;

/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RideDtoCopyWith<_RideDto> get copyWith => __$RideDtoCopyWithImpl<_RideDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RideDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RideDto&&const DeepCollectionEquality().equals(other.topParticipants, _topParticipants)&&(identical(other.team, team) || other.team == team)&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.dateTime, dateTime) || other.dateTime == dateTime)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.endDateTime, endDateTime) || other.endDateTime == endDateTime)&&(identical(other.status, status) || other.status == status)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.type, type) || other.type == type)&&(identical(other.participantCount, participantCount) || other.participantCount == participantCount)&&(identical(other.groupCount, groupCount) || other.groupCount == groupCount)&&const DeepCollectionEquality().equals(other.groups, _groups)&&const DeepCollectionEquality().equals(other.groupSummaries, _groupSummaries)&&(identical(other.full, full) || other.full == full)&&(identical(other.registered, registered) || other.registered == registered)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.permissions, permissions) || other.permissions == permissions)&&(identical(other.surfaceType, surfaceType) || other.surfaceType == surfaceType)&&(identical(other.displayDistance, displayDistance) || other.displayDistance == displayDistance)&&(identical(other.displayElevationGain, displayElevationGain) || other.displayElevationGain == displayElevationGain)&&(identical(other.startPlace, startPlace) || other.startPlace == startPlace)&&(identical(other.endPlace, endPlace) || other.endPlace == endPlace)&&(identical(other.elevationGain, elevationGain) || other.elevationGain == elevationGain)&&(identical(other.thumbnailLightUrl, thumbnailLightUrl) || other.thumbnailLightUrl == thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, thumbnailDarkUrl) || other.thumbnailDarkUrl == thumbnailDarkUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.publishAt, publishAt) || other.publishAt == publishAt)&&(identical(other.routeSlug, routeSlug) || other.routeSlug == routeSlug)&&(identical(other.registeredGroupId, registeredGroupId) || other.registeredGroupId == registeredGroupId)&&(identical(other.registeredGroup, registeredGroup) || other.registeredGroup == registeredGroup)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.maxParticipants, maxParticipants) || other.maxParticipants == maxParticipants)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.weather, weather) || other.weather == weather)&&const DeepCollectionEquality().equals(other.gpsSyncStatuses, _gpsSyncStatuses)&&(identical(other.distance, distance) || other.distance == distance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,const DeepCollectionEquality().hash(_topParticipants),team,id,slug,name,media,dateTime,timezone,endDateTime,status,finished,visibility,type,participantCount,groupCount,const DeepCollectionEquality().hash(_groups),const DeepCollectionEquality().hash(_groupSummaries),full,registered,const DeepCollectionEquality().hash(_tags),deleted,permissions,surfaceType,displayDistance,displayElevationGain,startPlace,endPlace,elevationGain,thumbnailLightUrl,thumbnailDarkUrl,thumbnailUrl,publishAt,routeSlug,registeredGroupId,registeredGroup,createdAt,maxParticipants,commentCount,excerpt,weather,const DeepCollectionEquality().hash(_gpsSyncStatuses),distance]);
}

@override
String toString() {
    return 'RideDto(topParticipants: $topParticipants, team: $team, id: $id, slug: $slug, name: $name, media: $media, dateTime: $dateTime, timezone: $timezone, endDateTime: $endDateTime, status: $status, finished: $finished, visibility: $visibility, type: $type, participantCount: $participantCount, groupCount: $groupCount, groups: $groups, groupSummaries: $groupSummaries, full: $full, registered: $registered, tags: $tags, deleted: $deleted, permissions: $permissions, surfaceType: $surfaceType, displayDistance: $displayDistance, displayElevationGain: $displayElevationGain, startPlace: $startPlace, endPlace: $endPlace, elevationGain: $elevationGain, thumbnailLightUrl: $thumbnailLightUrl, thumbnailDarkUrl: $thumbnailDarkUrl, thumbnailUrl: $thumbnailUrl, publishAt: $publishAt, routeSlug: $routeSlug, registeredGroupId: $registeredGroupId, registeredGroup: $registeredGroup, createdAt: $createdAt, maxParticipants: $maxParticipants, commentCount: $commentCount, excerpt: $excerpt, weather: $weather, gpsSyncStatuses: $gpsSyncStatuses, distance: $distance)';
}


}

/// @nodoc
abstract mixin class _$RideDtoCopyWith<$Res> implements $RideDtoCopyWith<$Res> {
  factory _$RideDtoCopyWith(_RideDto value, $Res Function(_RideDto) _then) = __$RideDtoCopyWithImpl;
@override @useResult
$Res call({
 List<PublicUserDto> topParticipants, TeamPublicationDto team, String id, String slug, String name, MediaDto media, String dateTime, String timezone, String endDateTime, String status, bool finished, String visibility, String type, int participantCount, int groupCount, List<RideGroupDto> groups, List<RideGroupSummaryDto> groupSummaries, bool full, bool registered, List<TagDto> tags, bool deleted, ContentPermissionsDto permissions, String? surfaceType, double? displayDistance, double? displayElevationGain, PlaceDetailDto? startPlace, PlaceDetailDto? endPlace, double? elevationGain, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? thumbnailUrl, String? publishAt, String? routeSlug, String? registeredGroupId, RideGroupDto? registeredGroup, String? createdAt, int? maxParticipants, int? commentCount, String? excerpt, RideWeatherSummaryDto? weather, List<RouteGpsSyncStatusDto>? gpsSyncStatuses, double? distance
});


@override $TeamPublicationDtoCopyWith<$Res> get team;@override $MediaDtoCopyWith<$Res> get media;@override $ContentPermissionsDtoCopyWith<$Res> get permissions;@override $PlaceDetailDtoCopyWith<$Res>? get startPlace;@override $PlaceDetailDtoCopyWith<$Res>? get endPlace;@override $RideGroupDtoCopyWith<$Res>? get registeredGroup;@override $RideWeatherSummaryDtoCopyWith<$Res>? get weather;

}
/// @nodoc
class __$RideDtoCopyWithImpl<$Res>
    implements _$RideDtoCopyWith<$Res> {
  __$RideDtoCopyWithImpl(this._self, this._then);

  final _RideDto _self;
  final $Res Function(_RideDto) _then;

/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? topParticipants = null,Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? dateTime = null,Object? timezone = null,Object? endDateTime = null,Object? status = null,Object? finished = null,Object? visibility = null,Object? type = null,Object? participantCount = null,Object? groupCount = null,Object? groups = null,Object? groupSummaries = null,Object? full = null,Object? registered = null,Object? tags = null,Object? deleted = null,Object? permissions = null,Object? surfaceType = freezed,Object? displayDistance = freezed,Object? displayElevationGain = freezed,Object? startPlace = freezed,Object? endPlace = freezed,Object? elevationGain = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? thumbnailUrl = freezed,Object? publishAt = freezed,Object? routeSlug = freezed,Object? registeredGroupId = freezed,Object? registeredGroup = freezed,Object? createdAt = freezed,Object? maxParticipants = freezed,Object? commentCount = freezed,Object? excerpt = freezed,Object? weather = freezed,Object? gpsSyncStatuses = freezed,Object? distance = freezed,}) {
  return _then(_RideDto(
topParticipants: null == topParticipants ? _self._topParticipants : topParticipants // ignore: cast_nullable_to_non_nullable
as List<PublicUserDto>,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,endDateTime: null == endDateTime ? _self.endDateTime : endDateTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,groupCount: null == groupCount ? _self.groupCount : groupCount // ignore: cast_nullable_to_non_nullable
as int,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<RideGroupDto>,groupSummaries: null == groupSummaries ? _self._groupSummaries : groupSummaries // ignore: cast_nullable_to_non_nullable
as List<RideGroupSummaryDto>,full: null == full ? _self.full : full // ignore: cast_nullable_to_non_nullable
as bool,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as ContentPermissionsDto,surfaceType: freezed == surfaceType ? _self.surfaceType : surfaceType // ignore: cast_nullable_to_non_nullable
as String?,displayDistance: freezed == displayDistance ? _self.displayDistance : displayDistance // ignore: cast_nullable_to_non_nullable
as double?,displayElevationGain: freezed == displayElevationGain ? _self.displayElevationGain : displayElevationGain // ignore: cast_nullable_to_non_nullable
as double?,startPlace: freezed == startPlace ? _self.startPlace : startPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,endPlace: freezed == endPlace ? _self.endPlace : endPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,elevationGain: freezed == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double?,thumbnailLightUrl: freezed == thumbnailLightUrl ? _self.thumbnailLightUrl : thumbnailLightUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailDarkUrl: freezed == thumbnailDarkUrl ? _self.thumbnailDarkUrl : thumbnailDarkUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,registeredGroupId: freezed == registeredGroupId ? _self.registeredGroupId : registeredGroupId // ignore: cast_nullable_to_non_nullable
as String?,registeredGroup: freezed == registeredGroup ? _self.registeredGroup : registeredGroup // ignore: cast_nullable_to_non_nullable
as RideGroupDto?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,maxParticipants: freezed == maxParticipants ? _self.maxParticipants : maxParticipants // ignore: cast_nullable_to_non_nullable
as int?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as RideWeatherSummaryDto?,gpsSyncStatuses: freezed == gpsSyncStatuses ? _self._gpsSyncStatuses : gpsSyncStatuses // ignore: cast_nullable_to_non_nullable
as List<RouteGpsSyncStatusDto>?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentPermissionsDtoCopyWith<$Res> get permissions {
  
  return $ContentPermissionsDtoCopyWith<$Res>(_self.permissions, (value) {
    return _then(_self.copyWith(permissions: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceDetailDtoCopyWith<$Res>? get startPlace {
    if (_self.startPlace == null) {
    return null;
  }

  return $PlaceDetailDtoCopyWith<$Res>(_self.startPlace!, (value) {
    return _then(_self.copyWith(startPlace: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceDetailDtoCopyWith<$Res>? get endPlace {
    if (_self.endPlace == null) {
    return null;
  }

  return $PlaceDetailDtoCopyWith<$Res>(_self.endPlace!, (value) {
    return _then(_self.copyWith(endPlace: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RideGroupDtoCopyWith<$Res>? get registeredGroup {
    if (_self.registeredGroup == null) {
    return null;
  }

  return $RideGroupDtoCopyWith<$Res>(_self.registeredGroup!, (value) {
    return _then(_self.copyWith(registeredGroup: value));
  });
}/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RideWeatherSummaryDtoCopyWith<$Res>? get weather {
    if (_self.weather == null) {
    return null;
  }

  return $RideWeatherSummaryDtoCopyWith<$Res>(_self.weather!, (value) {
    return _then(_self.copyWith(weather: value));
  });
}
}

// dart format on
