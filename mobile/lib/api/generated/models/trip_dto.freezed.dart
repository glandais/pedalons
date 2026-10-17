// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trip_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TripDto {

/// Type
 String get type;/// Team
 TeamPublicationDto get team;/// Publication ID (TSID)
 String get id;/// Publication URL slug
 String get slug;/// Publication name
 String get name;/// Publication media
 MediaDto get media;/// Trip start date/time
 String get dateTime;/// IANA zone the trip's times were entered in and read in: its first stage's, else its route's, else the team's. dateTime, endDate, endDateTime and publishAt are rendezvous in this zone.
 String get timezone;/// When the trip is over, computed by the server: the end of its latest stage — its departure plus its route's length at its average speed, or plus 3 hours when the stage has no speed or no route — or dateTime plus 3 hours for a trip with no stage. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read.
 String get endDateTime;/// Publication status
 String get status;/// Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.
 bool get finished;/// Visibility level
 String get visibility;/// Number of participants
 int get participantCount;/// Number of stages
 int get stageCount;/// Trip stages
 List<TripStageDto> get stages;/// The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants.
 List<PublicUserDto> get participants;/// Whether the trip is soft-deleted
 bool get deleted;/// Whether the current user is registered for this trip. False if anonymous.
 bool get registered;/// The team's TRIP tags the trip carries, sorted by label. Empty when it carries none.
 List<TagDto> get tags;/// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
 String? get excerpt;/// Date of the last stage — the day the trip ends. Null when the trip has no stage, in which case it lasts a day and dateTime is both ends.
 String? get endDate;/// Publication timestamp
 String? get publishAt;/// Creation timestamp
 String? get createdAt;/// Route slug
 String? get routeSlug;/// Distance in metres over every stage that has a route. Null when no stage has one — an unrouted trip has no distance, which is not the same as a distance of zero.
 double? get totalDistance;/// Elevation gain in metres over every stage that has a route. Null when no stage has one.
 double? get totalElevationGain;/// Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailLightUrl;/// Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailDarkUrl;/// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailUrl;/// Number of comments, replies included. Absent when the caller may not read the comments of this trip — comments are members-only, so an outsider is told nothing, not even zero.
 int? get commentCount;/// The weather line of a list card: that of the trip's next leg — its first stage still to leave, else the trip itself when it has no stage — at the start of its route, over the window from its departure to its estimated arrival. Absent when there is nothing to show — trip finished, draft or cancelled, next stage without a route, forecast not in cache yet — and on the trip's own detail, which reads getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE.
 RideWeatherSummaryDto? get weather;
/// Create a copy of TripDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripDtoCopyWith<TripDto> get copyWith => _$TripDtoCopyWithImpl<TripDto>(this as TripDto, _$identity);

  /// Serializes this TripDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TripDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripDto&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.team, _this.team) || other.team == _this.team)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.dateTime, _this.dateTime) || other.dateTime == _this.dateTime)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.endDateTime, _this.endDateTime) || other.endDateTime == _this.endDateTime)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.finished, _this.finished) || other.finished == _this.finished)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.participantCount, _this.participantCount) || other.participantCount == _this.participantCount)&&(identical(other.stageCount, _this.stageCount) || other.stageCount == _this.stageCount)&&const DeepCollectionEquality().equals(other.stages, _this.stages)&&const DeepCollectionEquality().equals(other.participants, _this.participants)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&(identical(other.registered, _this.registered) || other.registered == _this.registered)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt)&&(identical(other.endDate, _this.endDate) || other.endDate == _this.endDate)&&(identical(other.publishAt, _this.publishAt) || other.publishAt == _this.publishAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.routeSlug, _this.routeSlug) || other.routeSlug == _this.routeSlug)&&(identical(other.totalDistance, _this.totalDistance) || other.totalDistance == _this.totalDistance)&&(identical(other.totalElevationGain, _this.totalElevationGain) || other.totalElevationGain == _this.totalElevationGain)&&(identical(other.thumbnailLightUrl, _this.thumbnailLightUrl) || other.thumbnailLightUrl == _this.thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, _this.thumbnailDarkUrl) || other.thumbnailDarkUrl == _this.thumbnailDarkUrl)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.commentCount, _this.commentCount) || other.commentCount == _this.commentCount)&&(identical(other.weather, _this.weather) || other.weather == _this.weather));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TripDto;
  return Object.hashAll([runtimeType,_this.type,_this.team,_this.id,_this.slug,_this.name,_this.media,_this.dateTime,_this.timezone,_this.endDateTime,_this.status,_this.finished,_this.visibility,_this.participantCount,_this.stageCount,const DeepCollectionEquality().hash(_this.stages),const DeepCollectionEquality().hash(_this.participants),_this.deleted,_this.registered,const DeepCollectionEquality().hash(_this.tags),_this.excerpt,_this.endDate,_this.publishAt,_this.createdAt,_this.routeSlug,_this.totalDistance,_this.totalElevationGain,_this.thumbnailLightUrl,_this.thumbnailDarkUrl,_this.thumbnailUrl,_this.commentCount,_this.weather]);
}

@override
String toString() {
  final _this = this as TripDto;
  return 'TripDto(type: ${_this.type}, team: ${_this.team}, id: ${_this.id}, slug: ${_this.slug}, name: ${_this.name}, media: ${_this.media}, dateTime: ${_this.dateTime}, timezone: ${_this.timezone}, endDateTime: ${_this.endDateTime}, status: ${_this.status}, finished: ${_this.finished}, visibility: ${_this.visibility}, participantCount: ${_this.participantCount}, stageCount: ${_this.stageCount}, stages: ${_this.stages}, participants: ${_this.participants}, deleted: ${_this.deleted}, registered: ${_this.registered}, tags: ${_this.tags}, excerpt: ${_this.excerpt}, endDate: ${_this.endDate}, publishAt: ${_this.publishAt}, createdAt: ${_this.createdAt}, routeSlug: ${_this.routeSlug}, totalDistance: ${_this.totalDistance}, totalElevationGain: ${_this.totalElevationGain}, thumbnailLightUrl: ${_this.thumbnailLightUrl}, thumbnailDarkUrl: ${_this.thumbnailDarkUrl}, thumbnailUrl: ${_this.thumbnailUrl}, commentCount: ${_this.commentCount}, weather: ${_this.weather})';
}


}

/// @nodoc
abstract mixin class $TripDtoCopyWith<$Res>  {
  factory $TripDtoCopyWith(TripDto value, $Res Function(TripDto) _then) = _$TripDtoCopyWithImpl;
@useResult
$Res call({
 String type, TeamPublicationDto team, String id, String slug, String name, MediaDto media, String dateTime, String timezone, String endDateTime, String status, bool finished, String visibility, int participantCount, int stageCount, List<TripStageDto> stages, List<PublicUserDto> participants, bool deleted, bool registered, List<TagDto> tags, String? excerpt, String? endDate, String? publishAt, String? createdAt, String? routeSlug, double? totalDistance, double? totalElevationGain, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? thumbnailUrl, int? commentCount, RideWeatherSummaryDto? weather
});


$TeamPublicationDtoCopyWith<$Res> get team;$MediaDtoCopyWith<$Res> get media;$RideWeatherSummaryDtoCopyWith<$Res>? get weather;

}
/// @nodoc
class _$TripDtoCopyWithImpl<$Res>
    implements $TripDtoCopyWith<$Res> {
  _$TripDtoCopyWithImpl(this._self, this._then);

  final TripDto _self;
  final $Res Function(TripDto) _then;

/// Create a copy of TripDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? dateTime = null,Object? timezone = null,Object? endDateTime = null,Object? status = null,Object? finished = null,Object? visibility = null,Object? participantCount = null,Object? stageCount = null,Object? stages = null,Object? participants = null,Object? deleted = null,Object? registered = null,Object? tags = null,Object? excerpt = freezed,Object? endDate = freezed,Object? publishAt = freezed,Object? createdAt = freezed,Object? routeSlug = freezed,Object? totalDistance = freezed,Object? totalElevationGain = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? thumbnailUrl = freezed,Object? commentCount = freezed,Object? weather = freezed,}) {
  return _then(TripDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
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
as String,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,stageCount: null == stageCount ? _self.stageCount : stageCount // ignore: cast_nullable_to_non_nullable
as int,stages: null == stages ? _self.stages : stages // ignore: cast_nullable_to_non_nullable
as List<TripStageDto>,participants: null == participants ? _self.participants : participants // ignore: cast_nullable_to_non_nullable
as List<PublicUserDto>,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,totalDistance: freezed == totalDistance ? _self.totalDistance : totalDistance // ignore: cast_nullable_to_non_nullable
as double?,totalElevationGain: freezed == totalElevationGain ? _self.totalElevationGain : totalElevationGain // ignore: cast_nullable_to_non_nullable
as double?,thumbnailLightUrl: freezed == thumbnailLightUrl ? _self.thumbnailLightUrl : thumbnailLightUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailDarkUrl: freezed == thumbnailDarkUrl ? _self.thumbnailDarkUrl : thumbnailDarkUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as RideWeatherSummaryDto?,
  ));
}
/// Create a copy of TripDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of TripDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of TripDto
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


/// Adds pattern-matching-related methods to [TripDto].
extension TripDtoPatterns on TripDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripDto value)  $default,){
final _that = this;
switch (_that) {
case _TripDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripDto value)?  $default,){
final _that = this;
switch (_that) {
case _TripDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  int participantCount,  int stageCount,  List<TripStageDto> stages,  List<PublicUserDto> participants,  bool deleted,  bool registered,  List<TagDto> tags,  String? excerpt,  String? endDate,  String? publishAt,  String? createdAt,  String? routeSlug,  double? totalDistance,  double? totalElevationGain,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  int? commentCount,  RideWeatherSummaryDto? weather)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripDto() when $default != null:
return $default(_that.type,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.participantCount,_that.stageCount,_that.stages,_that.participants,_that.deleted,_that.registered,_that.tags,_that.excerpt,_that.endDate,_that.publishAt,_that.createdAt,_that.routeSlug,_that.totalDistance,_that.totalElevationGain,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.commentCount,_that.weather);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  int participantCount,  int stageCount,  List<TripStageDto> stages,  List<PublicUserDto> participants,  bool deleted,  bool registered,  List<TagDto> tags,  String? excerpt,  String? endDate,  String? publishAt,  String? createdAt,  String? routeSlug,  double? totalDistance,  double? totalElevationGain,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  int? commentCount,  RideWeatherSummaryDto? weather)  $default,) {final _that = this;
switch (_that) {
case _TripDto():
return $default(_that.type,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.participantCount,_that.stageCount,_that.stages,_that.participants,_that.deleted,_that.registered,_that.tags,_that.excerpt,_that.endDate,_that.publishAt,_that.createdAt,_that.routeSlug,_that.totalDistance,_that.totalElevationGain,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.commentCount,_that.weather);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  int participantCount,  int stageCount,  List<TripStageDto> stages,  List<PublicUserDto> participants,  bool deleted,  bool registered,  List<TagDto> tags,  String? excerpt,  String? endDate,  String? publishAt,  String? createdAt,  String? routeSlug,  double? totalDistance,  double? totalElevationGain,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  int? commentCount,  RideWeatherSummaryDto? weather)?  $default,) {final _that = this;
switch (_that) {
case _TripDto() when $default != null:
return $default(_that.type,_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.participantCount,_that.stageCount,_that.stages,_that.participants,_that.deleted,_that.registered,_that.tags,_that.excerpt,_that.endDate,_that.publishAt,_that.createdAt,_that.routeSlug,_that.totalDistance,_that.totalElevationGain,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.commentCount,_that.weather);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripDto implements TripDto {
  const _TripDto({required this.type, required this.team, required this.id, required this.slug, required this.name, required this.media, required this.dateTime, required this.timezone, required this.endDateTime, required this.status, required this.finished, required this.visibility, required this.participantCount, required this.stageCount, required  List<TripStageDto> stages, required  List<PublicUserDto> participants, required this.deleted, required this.registered, required  List<TagDto> tags, this.excerpt, this.endDate, this.publishAt, this.createdAt, this.routeSlug, this.totalDistance, this.totalElevationGain, this.thumbnailLightUrl, this.thumbnailDarkUrl, this.thumbnailUrl, this.commentCount, this.weather}): _stages = stages,_participants = participants,_tags = tags;
  factory _TripDto.fromJson(Map<String, dynamic> json) => _$TripDtoFromJson(json);

/// Type
@override final  String type;
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
/// Trip start date/time
@override final  String dateTime;
/// IANA zone the trip's times were entered in and read in: its first stage's, else its route's, else the team's. dateTime, endDate, endDateTime and publishAt are rendezvous in this zone.
@override final  String timezone;
/// When the trip is over, computed by the server: the end of its latest stage — its departure plus its route's length at its average speed, or plus 3 hours when the stage has no speed or no route — or dateTime plus 3 hours for a trip with no stage. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read.
@override final  String endDateTime;
/// Publication status
@override final  String status;
/// Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.
@override final  bool finished;
/// Visibility level
@override final  String visibility;
/// Number of participants
@override final  int participantCount;
/// Number of stages
@override final  int stageCount;
/// Trip stages
 final  List<TripStageDto> _stages;
/// Trip stages
@override List<TripStageDto> get stages {
  if (_stages is EqualUnmodifiableListView) return _stages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stages);
}

/// The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants.
 final  List<PublicUserDto> _participants;
/// The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants.
@override List<PublicUserDto> get participants {
  if (_participants is EqualUnmodifiableListView) return _participants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_participants);
}

/// Whether the trip is soft-deleted
@override final  bool deleted;
/// Whether the current user is registered for this trip. False if anonymous.
@override final  bool registered;
/// The team's TRIP tags the trip carries, sorted by label. Empty when it carries none.
 final  List<TagDto> _tags;
/// The team's TRIP tags the trip carries, sorted by label. Empty when it carries none.
@override List<TagDto> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
@override final  String? excerpt;
/// Date of the last stage — the day the trip ends. Null when the trip has no stage, in which case it lasts a day and dateTime is both ends.
@override final  String? endDate;
/// Publication timestamp
@override final  String? publishAt;
/// Creation timestamp
@override final  String? createdAt;
/// Route slug
@override final  String? routeSlug;
/// Distance in metres over every stage that has a route. Null when no stage has one — an unrouted trip has no distance, which is not the same as a distance of zero.
@override final  double? totalDistance;
/// Elevation gain in metres over every stage that has a route. Null when no stage has one.
@override final  double? totalElevationGain;
/// Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailLightUrl;
/// Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailDarkUrl;
/// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;
/// Number of comments, replies included. Absent when the caller may not read the comments of this trip — comments are members-only, so an outsider is told nothing, not even zero.
@override final  int? commentCount;
/// The weather line of a list card: that of the trip's next leg — its first stage still to leave, else the trip itself when it has no stage — at the start of its route, over the window from its departure to its estimated arrival. Absent when there is nothing to show — trip finished, draft or cancelled, next stage without a route, forecast not in cache yet — and on the trip's own detail, which reads getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE.
@override final  RideWeatherSummaryDto? weather;

/// Create a copy of TripDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripDtoCopyWith<_TripDto> get copyWith => __$TripDtoCopyWithImpl<_TripDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripDto&&(identical(other.type, type) || other.type == type)&&(identical(other.team, team) || other.team == team)&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.dateTime, dateTime) || other.dateTime == dateTime)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.endDateTime, endDateTime) || other.endDateTime == endDateTime)&&(identical(other.status, status) || other.status == status)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.participantCount, participantCount) || other.participantCount == participantCount)&&(identical(other.stageCount, stageCount) || other.stageCount == stageCount)&&const DeepCollectionEquality().equals(other.stages, _stages)&&const DeepCollectionEquality().equals(other.participants, _participants)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.registered, registered) || other.registered == registered)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.publishAt, publishAt) || other.publishAt == publishAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.routeSlug, routeSlug) || other.routeSlug == routeSlug)&&(identical(other.totalDistance, totalDistance) || other.totalDistance == totalDistance)&&(identical(other.totalElevationGain, totalElevationGain) || other.totalElevationGain == totalElevationGain)&&(identical(other.thumbnailLightUrl, thumbnailLightUrl) || other.thumbnailLightUrl == thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, thumbnailDarkUrl) || other.thumbnailDarkUrl == thumbnailDarkUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.weather, weather) || other.weather == weather));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,type,team,id,slug,name,media,dateTime,timezone,endDateTime,status,finished,visibility,participantCount,stageCount,const DeepCollectionEquality().hash(_stages),const DeepCollectionEquality().hash(_participants),deleted,registered,const DeepCollectionEquality().hash(_tags),excerpt,endDate,publishAt,createdAt,routeSlug,totalDistance,totalElevationGain,thumbnailLightUrl,thumbnailDarkUrl,thumbnailUrl,commentCount,weather]);
}

@override
String toString() {
    return 'TripDto(type: $type, team: $team, id: $id, slug: $slug, name: $name, media: $media, dateTime: $dateTime, timezone: $timezone, endDateTime: $endDateTime, status: $status, finished: $finished, visibility: $visibility, participantCount: $participantCount, stageCount: $stageCount, stages: $stages, participants: $participants, deleted: $deleted, registered: $registered, tags: $tags, excerpt: $excerpt, endDate: $endDate, publishAt: $publishAt, createdAt: $createdAt, routeSlug: $routeSlug, totalDistance: $totalDistance, totalElevationGain: $totalElevationGain, thumbnailLightUrl: $thumbnailLightUrl, thumbnailDarkUrl: $thumbnailDarkUrl, thumbnailUrl: $thumbnailUrl, commentCount: $commentCount, weather: $weather)';
}


}

/// @nodoc
abstract mixin class _$TripDtoCopyWith<$Res> implements $TripDtoCopyWith<$Res> {
  factory _$TripDtoCopyWith(_TripDto value, $Res Function(_TripDto) _then) = __$TripDtoCopyWithImpl;
@override @useResult
$Res call({
 String type, TeamPublicationDto team, String id, String slug, String name, MediaDto media, String dateTime, String timezone, String endDateTime, String status, bool finished, String visibility, int participantCount, int stageCount, List<TripStageDto> stages, List<PublicUserDto> participants, bool deleted, bool registered, List<TagDto> tags, String? excerpt, String? endDate, String? publishAt, String? createdAt, String? routeSlug, double? totalDistance, double? totalElevationGain, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? thumbnailUrl, int? commentCount, RideWeatherSummaryDto? weather
});


@override $TeamPublicationDtoCopyWith<$Res> get team;@override $MediaDtoCopyWith<$Res> get media;@override $RideWeatherSummaryDtoCopyWith<$Res>? get weather;

}
/// @nodoc
class __$TripDtoCopyWithImpl<$Res>
    implements _$TripDtoCopyWith<$Res> {
  __$TripDtoCopyWithImpl(this._self, this._then);

  final _TripDto _self;
  final $Res Function(_TripDto) _then;

/// Create a copy of TripDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? dateTime = null,Object? timezone = null,Object? endDateTime = null,Object? status = null,Object? finished = null,Object? visibility = null,Object? participantCount = null,Object? stageCount = null,Object? stages = null,Object? participants = null,Object? deleted = null,Object? registered = null,Object? tags = null,Object? excerpt = freezed,Object? endDate = freezed,Object? publishAt = freezed,Object? createdAt = freezed,Object? routeSlug = freezed,Object? totalDistance = freezed,Object? totalElevationGain = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? thumbnailUrl = freezed,Object? commentCount = freezed,Object? weather = freezed,}) {
  return _then(_TripDto(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
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
as String,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,stageCount: null == stageCount ? _self.stageCount : stageCount // ignore: cast_nullable_to_non_nullable
as int,stages: null == stages ? _self._stages : stages // ignore: cast_nullable_to_non_nullable
as List<TripStageDto>,participants: null == participants ? _self._participants : participants // ignore: cast_nullable_to_non_nullable
as List<PublicUserDto>,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,totalDistance: freezed == totalDistance ? _self.totalDistance : totalDistance // ignore: cast_nullable_to_non_nullable
as double?,totalElevationGain: freezed == totalElevationGain ? _self.totalElevationGain : totalElevationGain // ignore: cast_nullable_to_non_nullable
as double?,thumbnailLightUrl: freezed == thumbnailLightUrl ? _self.thumbnailLightUrl : thumbnailLightUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailDarkUrl: freezed == thumbnailDarkUrl ? _self.thumbnailDarkUrl : thumbnailDarkUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as RideWeatherSummaryDto?,
  ));
}

/// Create a copy of TripDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of TripDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of TripDto
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
