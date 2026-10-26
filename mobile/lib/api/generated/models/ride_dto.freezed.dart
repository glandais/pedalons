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

/// Ride groups
 List<RideGroupDto> get groups;/// Team
 TeamPublicationDto get team;/// Publication ID (TSID)
 String get id;/// Publication URL slug
 String get slug;/// Publication name
 String get name;/// Publication media
 MediaDto get media;/// Visibility level
 String get visibility;/// Publication date/time
 String get dateTime;/// IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone.
 String get timezone;/// When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read.
 String get endDateTime;/// Publication status
 String get status;/// Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.
 bool get finished;/// Type
 String get type;/// Number of participants
 int get participantCount;/// Number of groups
 int get groupCount;/// Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.
 List<RideGroupSummaryDto> get groupSummaries;/// The team's RIDE tags the ride carries, sorted by label. Empty when it carries none.
 List<TagDto> get tags;/// Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.
 bool get full;/// Whether the ride is soft-deleted
 bool get deleted;/// Whether the current user is registered in one of this ride's groups. False if anonymous.
 bool get registered;/// Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.
 List<PublicUserDto> get topParticipants;/// Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.
 double? get elevationGain;/// Surface type, from the same route as distance. Null when no route is set anywhere.
 String? get surfaceType;/// Start place
 PlaceDetailDto? get startPlace;/// The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.
 RideWeatherSummaryDto? get weather;/// Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere.
 double? get distance;/// Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailLightUrl;/// Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailDarkUrl;/// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailUrl;/// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
 String? get excerpt;/// Route slug
 String? get routeSlug;/// ID (TSID) of the group the current user joined, null if not registered
 String? get registeredGroupId;/// The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group's own, null when none was designated.
 RideGroupDto? get registeredGroup;/// Creation timestamp
 String? get createdAt;/// Capacity of the whole ride: the sum of its groups' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty.
 int? get maxParticipants;/// Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.
 int? get commentCount;/// Publication timestamp
 String? get publishAt;/// End place
 PlaceDetailDto? get endPlace;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RideDto&&const DeepCollectionEquality().equals(other.groups, _this.groups)&&(identical(other.team, _this.team) || other.team == _this.team)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.dateTime, _this.dateTime) || other.dateTime == _this.dateTime)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.endDateTime, _this.endDateTime) || other.endDateTime == _this.endDateTime)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.finished, _this.finished) || other.finished == _this.finished)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.participantCount, _this.participantCount) || other.participantCount == _this.participantCount)&&(identical(other.groupCount, _this.groupCount) || other.groupCount == _this.groupCount)&&const DeepCollectionEquality().equals(other.groupSummaries, _this.groupSummaries)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.full, _this.full) || other.full == _this.full)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&(identical(other.registered, _this.registered) || other.registered == _this.registered)&&const DeepCollectionEquality().equals(other.topParticipants, _this.topParticipants)&&(identical(other.elevationGain, _this.elevationGain) || other.elevationGain == _this.elevationGain)&&(identical(other.surfaceType, _this.surfaceType) || other.surfaceType == _this.surfaceType)&&(identical(other.startPlace, _this.startPlace) || other.startPlace == _this.startPlace)&&(identical(other.weather, _this.weather) || other.weather == _this.weather)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.thumbnailLightUrl, _this.thumbnailLightUrl) || other.thumbnailLightUrl == _this.thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, _this.thumbnailDarkUrl) || other.thumbnailDarkUrl == _this.thumbnailDarkUrl)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt)&&(identical(other.routeSlug, _this.routeSlug) || other.routeSlug == _this.routeSlug)&&(identical(other.registeredGroupId, _this.registeredGroupId) || other.registeredGroupId == _this.registeredGroupId)&&(identical(other.registeredGroup, _this.registeredGroup) || other.registeredGroup == _this.registeredGroup)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.maxParticipants, _this.maxParticipants) || other.maxParticipants == _this.maxParticipants)&&(identical(other.commentCount, _this.commentCount) || other.commentCount == _this.commentCount)&&(identical(other.publishAt, _this.publishAt) || other.publishAt == _this.publishAt)&&(identical(other.endPlace, _this.endPlace) || other.endPlace == _this.endPlace));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RideDto;
  return Object.hashAll([runtimeType,const DeepCollectionEquality().hash(_this.groups),_this.team,_this.id,_this.slug,_this.name,_this.media,_this.visibility,_this.dateTime,_this.timezone,_this.endDateTime,_this.status,_this.finished,_this.type,_this.participantCount,_this.groupCount,const DeepCollectionEquality().hash(_this.groupSummaries),const DeepCollectionEquality().hash(_this.tags),_this.full,_this.deleted,_this.registered,const DeepCollectionEquality().hash(_this.topParticipants),_this.elevationGain,_this.surfaceType,_this.startPlace,_this.weather,_this.distance,_this.thumbnailLightUrl,_this.thumbnailDarkUrl,_this.thumbnailUrl,_this.excerpt,_this.routeSlug,_this.registeredGroupId,_this.registeredGroup,_this.createdAt,_this.maxParticipants,_this.commentCount,_this.publishAt,_this.endPlace]);
}

@override
String toString() {
  final _this = this as RideDto;
  return 'RideDto(groups: ${_this.groups}, team: ${_this.team}, id: ${_this.id}, slug: ${_this.slug}, name: ${_this.name}, media: ${_this.media}, visibility: ${_this.visibility}, dateTime: ${_this.dateTime}, timezone: ${_this.timezone}, endDateTime: ${_this.endDateTime}, status: ${_this.status}, finished: ${_this.finished}, type: ${_this.type}, participantCount: ${_this.participantCount}, groupCount: ${_this.groupCount}, groupSummaries: ${_this.groupSummaries}, tags: ${_this.tags}, full: ${_this.full}, deleted: ${_this.deleted}, registered: ${_this.registered}, topParticipants: ${_this.topParticipants}, elevationGain: ${_this.elevationGain}, surfaceType: ${_this.surfaceType}, startPlace: ${_this.startPlace}, weather: ${_this.weather}, distance: ${_this.distance}, thumbnailLightUrl: ${_this.thumbnailLightUrl}, thumbnailDarkUrl: ${_this.thumbnailDarkUrl}, thumbnailUrl: ${_this.thumbnailUrl}, excerpt: ${_this.excerpt}, routeSlug: ${_this.routeSlug}, registeredGroupId: ${_this.registeredGroupId}, registeredGroup: ${_this.registeredGroup}, createdAt: ${_this.createdAt}, maxParticipants: ${_this.maxParticipants}, commentCount: ${_this.commentCount}, publishAt: ${_this.publishAt}, endPlace: ${_this.endPlace})';
}


}

/// @nodoc
abstract mixin class $RideDtoCopyWith<$Res>  {
  factory $RideDtoCopyWith(RideDto value, $Res Function(RideDto) _then) = _$RideDtoCopyWithImpl;
@useResult
$Res call({
 List<RideGroupDto> groups, TeamPublicationDto team, String id, String slug, String name, MediaDto media, String visibility, String dateTime, String timezone, String endDateTime, String status, bool finished, String type, int participantCount, int groupCount, List<RideGroupSummaryDto> groupSummaries, List<TagDto> tags, bool full, bool deleted, bool registered, List<PublicUserDto> topParticipants, double? elevationGain, String? surfaceType, PlaceDetailDto? startPlace, RideWeatherSummaryDto? weather, double? distance, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? thumbnailUrl, String? excerpt, String? routeSlug, String? registeredGroupId, RideGroupDto? registeredGroup, String? createdAt, int? maxParticipants, int? commentCount, String? publishAt, PlaceDetailDto? endPlace
});


$TeamPublicationDtoCopyWith<$Res> get team;$MediaDtoCopyWith<$Res> get media;$PlaceDetailDtoCopyWith<$Res>? get startPlace;$RideWeatherSummaryDtoCopyWith<$Res>? get weather;$RideGroupDtoCopyWith<$Res>? get registeredGroup;$PlaceDetailDtoCopyWith<$Res>? get endPlace;

}
/// @nodoc
class _$RideDtoCopyWithImpl<$Res>
    implements $RideDtoCopyWith<$Res> {
  _$RideDtoCopyWithImpl(this._self, this._then);

  final RideDto _self;
  final $Res Function(RideDto) _then;

/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groups = null,Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? visibility = null,Object? dateTime = null,Object? timezone = null,Object? endDateTime = null,Object? status = null,Object? finished = null,Object? type = null,Object? participantCount = null,Object? groupCount = null,Object? groupSummaries = null,Object? tags = null,Object? full = null,Object? deleted = null,Object? registered = null,Object? topParticipants = null,Object? elevationGain = freezed,Object? surfaceType = freezed,Object? startPlace = freezed,Object? weather = freezed,Object? distance = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? thumbnailUrl = freezed,Object? excerpt = freezed,Object? routeSlug = freezed,Object? registeredGroupId = freezed,Object? registeredGroup = freezed,Object? createdAt = freezed,Object? maxParticipants = freezed,Object? commentCount = freezed,Object? publishAt = freezed,Object? endPlace = freezed,}) {
  return _then(RideDto(
groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<RideGroupDto>,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,endDateTime: null == endDateTime ? _self.endDateTime : endDateTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,groupCount: null == groupCount ? _self.groupCount : groupCount // ignore: cast_nullable_to_non_nullable
as int,groupSummaries: null == groupSummaries ? _self.groupSummaries : groupSummaries // ignore: cast_nullable_to_non_nullable
as List<RideGroupSummaryDto>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,full: null == full ? _self.full : full // ignore: cast_nullable_to_non_nullable
as bool,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,topParticipants: null == topParticipants ? _self.topParticipants : topParticipants // ignore: cast_nullable_to_non_nullable
as List<PublicUserDto>,elevationGain: freezed == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double?,surfaceType: freezed == surfaceType ? _self.surfaceType : surfaceType // ignore: cast_nullable_to_non_nullable
as String?,startPlace: freezed == startPlace ? _self.startPlace : startPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as RideWeatherSummaryDto?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,thumbnailLightUrl: freezed == thumbnailLightUrl ? _self.thumbnailLightUrl : thumbnailLightUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailDarkUrl: freezed == thumbnailDarkUrl ? _self.thumbnailDarkUrl : thumbnailDarkUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,registeredGroupId: freezed == registeredGroupId ? _self.registeredGroupId : registeredGroupId // ignore: cast_nullable_to_non_nullable
as String?,registeredGroup: freezed == registeredGroup ? _self.registeredGroup : registeredGroup // ignore: cast_nullable_to_non_nullable
as RideGroupDto?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,maxParticipants: freezed == maxParticipants ? _self.maxParticipants : maxParticipants // ignore: cast_nullable_to_non_nullable
as int?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,endPlace: freezed == endPlace ? _self.endPlace : endPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,
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
$RideWeatherSummaryDtoCopyWith<$Res>? get weather {
    if (_self.weather == null) {
    return null;
  }

  return $RideWeatherSummaryDtoCopyWith<$Res>(_self.weather!, (value) {
    return _then(_self.copyWith(weather: value));
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
$PlaceDetailDtoCopyWith<$Res>? get endPlace {
    if (_self.endPlace == null) {
    return null;
  }

  return $PlaceDetailDtoCopyWith<$Res>(_self.endPlace!, (value) {
    return _then(_self.copyWith(endPlace: value));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<RideGroupDto> groups,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String visibility,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String type,  int participantCount,  int groupCount,  List<RideGroupSummaryDto> groupSummaries,  List<TagDto> tags,  bool full,  bool deleted,  bool registered,  List<PublicUserDto> topParticipants,  double? elevationGain,  String? surfaceType,  PlaceDetailDto? startPlace,  RideWeatherSummaryDto? weather,  double? distance,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  String? excerpt,  String? routeSlug,  String? registeredGroupId,  RideGroupDto? registeredGroup,  String? createdAt,  int? maxParticipants,  int? commentCount,  String? publishAt,  PlaceDetailDto? endPlace)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RideDto() when $default != null:
return $default(_that.groups,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.visibility,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.type,_that.participantCount,_that.groupCount,_that.groupSummaries,_that.tags,_that.full,_that.deleted,_that.registered,_that.topParticipants,_that.elevationGain,_that.surfaceType,_that.startPlace,_that.weather,_that.distance,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.excerpt,_that.routeSlug,_that.registeredGroupId,_that.registeredGroup,_that.createdAt,_that.maxParticipants,_that.commentCount,_that.publishAt,_that.endPlace);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<RideGroupDto> groups,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String visibility,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String type,  int participantCount,  int groupCount,  List<RideGroupSummaryDto> groupSummaries,  List<TagDto> tags,  bool full,  bool deleted,  bool registered,  List<PublicUserDto> topParticipants,  double? elevationGain,  String? surfaceType,  PlaceDetailDto? startPlace,  RideWeatherSummaryDto? weather,  double? distance,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  String? excerpt,  String? routeSlug,  String? registeredGroupId,  RideGroupDto? registeredGroup,  String? createdAt,  int? maxParticipants,  int? commentCount,  String? publishAt,  PlaceDetailDto? endPlace)  $default,) {final _that = this;
switch (_that) {
case _RideDto():
return $default(_that.groups,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.visibility,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.type,_that.participantCount,_that.groupCount,_that.groupSummaries,_that.tags,_that.full,_that.deleted,_that.registered,_that.topParticipants,_that.elevationGain,_that.surfaceType,_that.startPlace,_that.weather,_that.distance,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.excerpt,_that.routeSlug,_that.registeredGroupId,_that.registeredGroup,_that.createdAt,_that.maxParticipants,_that.commentCount,_that.publishAt,_that.endPlace);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<RideGroupDto> groups,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String visibility,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String type,  int participantCount,  int groupCount,  List<RideGroupSummaryDto> groupSummaries,  List<TagDto> tags,  bool full,  bool deleted,  bool registered,  List<PublicUserDto> topParticipants,  double? elevationGain,  String? surfaceType,  PlaceDetailDto? startPlace,  RideWeatherSummaryDto? weather,  double? distance,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  String? excerpt,  String? routeSlug,  String? registeredGroupId,  RideGroupDto? registeredGroup,  String? createdAt,  int? maxParticipants,  int? commentCount,  String? publishAt,  PlaceDetailDto? endPlace)?  $default,) {final _that = this;
switch (_that) {
case _RideDto() when $default != null:
return $default(_that.groups,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.visibility,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.type,_that.participantCount,_that.groupCount,_that.groupSummaries,_that.tags,_that.full,_that.deleted,_that.registered,_that.topParticipants,_that.elevationGain,_that.surfaceType,_that.startPlace,_that.weather,_that.distance,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.excerpt,_that.routeSlug,_that.registeredGroupId,_that.registeredGroup,_that.createdAt,_that.maxParticipants,_that.commentCount,_that.publishAt,_that.endPlace);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RideDto implements RideDto {
  const _RideDto({required  List<RideGroupDto> groups, required this.team, required this.id, required this.slug, required this.name, required this.media, required this.visibility, required this.dateTime, required this.timezone, required this.endDateTime, required this.status, required this.finished, required this.type, required this.participantCount, required this.groupCount, required  List<RideGroupSummaryDto> groupSummaries, required  List<TagDto> tags, required this.full, required this.deleted, required this.registered, required  List<PublicUserDto> topParticipants, this.elevationGain, this.surfaceType, this.startPlace, this.weather, this.distance, this.thumbnailLightUrl, this.thumbnailDarkUrl, this.thumbnailUrl, this.excerpt, this.routeSlug, this.registeredGroupId, this.registeredGroup, this.createdAt, this.maxParticipants, this.commentCount, this.publishAt, this.endPlace}): _groups = groups,_groupSummaries = groupSummaries,_tags = tags,_topParticipants = topParticipants;
  factory _RideDto.fromJson(Map<String, dynamic> json) => _$RideDtoFromJson(json);

/// Ride groups
 final  List<RideGroupDto> _groups;
/// Ride groups
@override List<RideGroupDto> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
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
/// Visibility level
@override final  String visibility;
/// Publication date/time
@override final  String dateTime;
/// IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone.
@override final  String timezone;
/// When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read.
@override final  String endDateTime;
/// Publication status
@override final  String status;
/// Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.
@override final  bool finished;
/// Type
@override final  String type;
/// Number of participants
@override final  int participantCount;
/// Number of groups
@override final  int groupCount;
/// Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.
 final  List<RideGroupSummaryDto> _groupSummaries;
/// Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.
@override List<RideGroupSummaryDto> get groupSummaries {
  if (_groupSummaries is EqualUnmodifiableListView) return _groupSummaries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groupSummaries);
}

/// The team's RIDE tags the ride carries, sorted by label. Empty when it carries none.
 final  List<TagDto> _tags;
/// The team's RIDE tags the ride carries, sorted by label. Empty when it carries none.
@override List<TagDto> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.
@override final  bool full;
/// Whether the ride is soft-deleted
@override final  bool deleted;
/// Whether the current user is registered in one of this ride's groups. False if anonymous.
@override final  bool registered;
/// Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.
 final  List<PublicUserDto> _topParticipants;
/// Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.
@override List<PublicUserDto> get topParticipants {
  if (_topParticipants is EqualUnmodifiableListView) return _topParticipants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topParticipants);
}

/// Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.
@override final  double? elevationGain;
/// Surface type, from the same route as distance. Null when no route is set anywhere.
@override final  String? surfaceType;
/// Start place
@override final  PlaceDetailDto? startPlace;
/// The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.
@override final  RideWeatherSummaryDto? weather;
/// Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere.
@override final  double? distance;
/// Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailLightUrl;
/// Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailDarkUrl;
/// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;
/// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
@override final  String? excerpt;
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
/// Publication timestamp
@override final  String? publishAt;
/// End place
@override final  PlaceDetailDto? endPlace;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RideDto&&const DeepCollectionEquality().equals(other.groups, _groups)&&(identical(other.team, team) || other.team == team)&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.dateTime, dateTime) || other.dateTime == dateTime)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.endDateTime, endDateTime) || other.endDateTime == endDateTime)&&(identical(other.status, status) || other.status == status)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.type, type) || other.type == type)&&(identical(other.participantCount, participantCount) || other.participantCount == participantCount)&&(identical(other.groupCount, groupCount) || other.groupCount == groupCount)&&const DeepCollectionEquality().equals(other.groupSummaries, _groupSummaries)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.full, full) || other.full == full)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.registered, registered) || other.registered == registered)&&const DeepCollectionEquality().equals(other.topParticipants, _topParticipants)&&(identical(other.elevationGain, elevationGain) || other.elevationGain == elevationGain)&&(identical(other.surfaceType, surfaceType) || other.surfaceType == surfaceType)&&(identical(other.startPlace, startPlace) || other.startPlace == startPlace)&&(identical(other.weather, weather) || other.weather == weather)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.thumbnailLightUrl, thumbnailLightUrl) || other.thumbnailLightUrl == thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, thumbnailDarkUrl) || other.thumbnailDarkUrl == thumbnailDarkUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.routeSlug, routeSlug) || other.routeSlug == routeSlug)&&(identical(other.registeredGroupId, registeredGroupId) || other.registeredGroupId == registeredGroupId)&&(identical(other.registeredGroup, registeredGroup) || other.registeredGroup == registeredGroup)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.maxParticipants, maxParticipants) || other.maxParticipants == maxParticipants)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.publishAt, publishAt) || other.publishAt == publishAt)&&(identical(other.endPlace, endPlace) || other.endPlace == endPlace));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,const DeepCollectionEquality().hash(_groups),team,id,slug,name,media,visibility,dateTime,timezone,endDateTime,status,finished,type,participantCount,groupCount,const DeepCollectionEquality().hash(_groupSummaries),const DeepCollectionEquality().hash(_tags),full,deleted,registered,const DeepCollectionEquality().hash(_topParticipants),elevationGain,surfaceType,startPlace,weather,distance,thumbnailLightUrl,thumbnailDarkUrl,thumbnailUrl,excerpt,routeSlug,registeredGroupId,registeredGroup,createdAt,maxParticipants,commentCount,publishAt,endPlace]);
}

@override
String toString() {
    return 'RideDto(groups: $groups, team: $team, id: $id, slug: $slug, name: $name, media: $media, visibility: $visibility, dateTime: $dateTime, timezone: $timezone, endDateTime: $endDateTime, status: $status, finished: $finished, type: $type, participantCount: $participantCount, groupCount: $groupCount, groupSummaries: $groupSummaries, tags: $tags, full: $full, deleted: $deleted, registered: $registered, topParticipants: $topParticipants, elevationGain: $elevationGain, surfaceType: $surfaceType, startPlace: $startPlace, weather: $weather, distance: $distance, thumbnailLightUrl: $thumbnailLightUrl, thumbnailDarkUrl: $thumbnailDarkUrl, thumbnailUrl: $thumbnailUrl, excerpt: $excerpt, routeSlug: $routeSlug, registeredGroupId: $registeredGroupId, registeredGroup: $registeredGroup, createdAt: $createdAt, maxParticipants: $maxParticipants, commentCount: $commentCount, publishAt: $publishAt, endPlace: $endPlace)';
}


}

/// @nodoc
abstract mixin class _$RideDtoCopyWith<$Res> implements $RideDtoCopyWith<$Res> {
  factory _$RideDtoCopyWith(_RideDto value, $Res Function(_RideDto) _then) = __$RideDtoCopyWithImpl;
@override @useResult
$Res call({
 List<RideGroupDto> groups, TeamPublicationDto team, String id, String slug, String name, MediaDto media, String visibility, String dateTime, String timezone, String endDateTime, String status, bool finished, String type, int participantCount, int groupCount, List<RideGroupSummaryDto> groupSummaries, List<TagDto> tags, bool full, bool deleted, bool registered, List<PublicUserDto> topParticipants, double? elevationGain, String? surfaceType, PlaceDetailDto? startPlace, RideWeatherSummaryDto? weather, double? distance, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? thumbnailUrl, String? excerpt, String? routeSlug, String? registeredGroupId, RideGroupDto? registeredGroup, String? createdAt, int? maxParticipants, int? commentCount, String? publishAt, PlaceDetailDto? endPlace
});


@override $TeamPublicationDtoCopyWith<$Res> get team;@override $MediaDtoCopyWith<$Res> get media;@override $PlaceDetailDtoCopyWith<$Res>? get startPlace;@override $RideWeatherSummaryDtoCopyWith<$Res>? get weather;@override $RideGroupDtoCopyWith<$Res>? get registeredGroup;@override $PlaceDetailDtoCopyWith<$Res>? get endPlace;

}
/// @nodoc
class __$RideDtoCopyWithImpl<$Res>
    implements _$RideDtoCopyWith<$Res> {
  __$RideDtoCopyWithImpl(this._self, this._then);

  final _RideDto _self;
  final $Res Function(_RideDto) _then;

/// Create a copy of RideDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? groups = null,Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? visibility = null,Object? dateTime = null,Object? timezone = null,Object? endDateTime = null,Object? status = null,Object? finished = null,Object? type = null,Object? participantCount = null,Object? groupCount = null,Object? groupSummaries = null,Object? tags = null,Object? full = null,Object? deleted = null,Object? registered = null,Object? topParticipants = null,Object? elevationGain = freezed,Object? surfaceType = freezed,Object? startPlace = freezed,Object? weather = freezed,Object? distance = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? thumbnailUrl = freezed,Object? excerpt = freezed,Object? routeSlug = freezed,Object? registeredGroupId = freezed,Object? registeredGroup = freezed,Object? createdAt = freezed,Object? maxParticipants = freezed,Object? commentCount = freezed,Object? publishAt = freezed,Object? endPlace = freezed,}) {
  return _then(_RideDto(
groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<RideGroupDto>,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,endDateTime: null == endDateTime ? _self.endDateTime : endDateTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,groupCount: null == groupCount ? _self.groupCount : groupCount // ignore: cast_nullable_to_non_nullable
as int,groupSummaries: null == groupSummaries ? _self._groupSummaries : groupSummaries // ignore: cast_nullable_to_non_nullable
as List<RideGroupSummaryDto>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,full: null == full ? _self.full : full // ignore: cast_nullable_to_non_nullable
as bool,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,topParticipants: null == topParticipants ? _self._topParticipants : topParticipants // ignore: cast_nullable_to_non_nullable
as List<PublicUserDto>,elevationGain: freezed == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double?,surfaceType: freezed == surfaceType ? _self.surfaceType : surfaceType // ignore: cast_nullable_to_non_nullable
as String?,startPlace: freezed == startPlace ? _self.startPlace : startPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as RideWeatherSummaryDto?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,thumbnailLightUrl: freezed == thumbnailLightUrl ? _self.thumbnailLightUrl : thumbnailLightUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailDarkUrl: freezed == thumbnailDarkUrl ? _self.thumbnailDarkUrl : thumbnailDarkUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,registeredGroupId: freezed == registeredGroupId ? _self.registeredGroupId : registeredGroupId // ignore: cast_nullable_to_non_nullable
as String?,registeredGroup: freezed == registeredGroup ? _self.registeredGroup : registeredGroup // ignore: cast_nullable_to_non_nullable
as RideGroupDto?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,maxParticipants: freezed == maxParticipants ? _self.maxParticipants : maxParticipants // ignore: cast_nullable_to_non_nullable
as int?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,endPlace: freezed == endPlace ? _self.endPlace : endPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,
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
$RideWeatherSummaryDtoCopyWith<$Res>? get weather {
    if (_self.weather == null) {
    return null;
  }

  return $RideWeatherSummaryDtoCopyWith<$Res>(_self.weather!, (value) {
    return _then(_self.copyWith(weather: value));
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
$PlaceDetailDtoCopyWith<$Res>? get endPlace {
    if (_self.endPlace == null) {
    return null;
  }

  return $PlaceDetailDtoCopyWith<$Res>(_self.endPlace!, (value) {
    return _then(_self.copyWith(endPlace: value));
  });
}
}

// dart format on
