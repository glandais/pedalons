// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'publication_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
PublicationDto _$PublicationDtoFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'RIDE':
          return PublicationDtoRide.fromJson(
            json
          );
                case 'POST':
          return PublicationDtoPost.fromJson(
            json
          );
                case 'TRIP':
          return PublicationDtoTrip.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'PublicationDto',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$PublicationDto {

/// Publication ID (TSID)
 String get id;/// Publication URL slug
 String get slug;/// Publication name
 String get name;/// Publication media
 MediaDto get media;/// Publication date/time
 String get dateTime;/// IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone.
 String get timezone;/// Publication status
 String get status;/// Visibility level
 String get visibility;/// Team
 TeamPublicationDto get team;/// The team's RIDE tags the ride carries, sorted by label. Empty when it carries none.
 List<TagDto> get tags;/// Whether the ride is soft-deleted
 bool get deleted;/// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailUrl;/// Creation timestamp
 String? get createdAt;/// Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.
 int? get commentCount;/// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
 String? get excerpt;/// Publication timestamp
 String? get publishAt;
/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicationDtoCopyWith<PublicationDto> get copyWith => _$PublicationDtoCopyWithImpl<PublicationDto>(this as PublicationDto, _$identity);

  /// Serializes this PublicationDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PublicationDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicationDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.dateTime, _this.dateTime) || other.dateTime == _this.dateTime)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.team, _this.team) || other.team == _this.team)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.commentCount, _this.commentCount) || other.commentCount == _this.commentCount)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt)&&(identical(other.publishAt, _this.publishAt) || other.publishAt == _this.publishAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PublicationDto;
  return Object.hash(runtimeType,_this.id,_this.slug,_this.name,_this.media,_this.dateTime,_this.timezone,_this.status,_this.visibility,_this.team,const DeepCollectionEquality().hash(_this.tags),_this.deleted,_this.thumbnailUrl,_this.createdAt,_this.commentCount,_this.excerpt,_this.publishAt);
}

@override
String toString() {
  final _this = this as PublicationDto;
  return 'PublicationDto(id: ${_this.id}, slug: ${_this.slug}, name: ${_this.name}, media: ${_this.media}, dateTime: ${_this.dateTime}, timezone: ${_this.timezone}, status: ${_this.status}, visibility: ${_this.visibility}, team: ${_this.team}, tags: ${_this.tags}, deleted: ${_this.deleted}, thumbnailUrl: ${_this.thumbnailUrl}, createdAt: ${_this.createdAt}, commentCount: ${_this.commentCount}, excerpt: ${_this.excerpt}, publishAt: ${_this.publishAt})';
}


}

/// @nodoc
abstract mixin class $PublicationDtoCopyWith<$Res>  {
  factory $PublicationDtoCopyWith(PublicationDto value, $Res Function(PublicationDto) _then) = _$PublicationDtoCopyWithImpl;
@useResult
$Res call({
 String id, String slug, String name, MediaDto media, String dateTime, String timezone, String status, String visibility, TeamPublicationDto team, List<TagDto> tags, bool deleted, String? thumbnailUrl, String? createdAt, int? commentCount, String? excerpt, String? publishAt
});


$MediaDtoCopyWith<$Res> get media;$TeamPublicationDtoCopyWith<$Res> get team;

}
/// @nodoc
class _$PublicationDtoCopyWithImpl<$Res>
    implements $PublicationDtoCopyWith<$Res> {
  _$PublicationDtoCopyWithImpl(this._self, this._then);

  final PublicationDto _self;
  final $Res Function(PublicationDto) _then;

/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? dateTime = null,Object? timezone = null,Object? status = null,Object? visibility = null,Object? team = null,Object? tags = null,Object? deleted = null,Object? thumbnailUrl = freezed,Object? createdAt = freezed,Object? commentCount = freezed,Object? excerpt = freezed,Object? publishAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}
}


/// Adds pattern-matching-related methods to [PublicationDto].
extension PublicationDtoPatterns on PublicationDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( PublicationDtoRide value)?  ride,TResult Function( PublicationDtoPost value)?  post,TResult Function( PublicationDtoTrip value)?  trip,required TResult orElse(),}){
final _that = this;
switch (_that) {
case PublicationDtoRide() when ride != null:
return ride(_that);case PublicationDtoPost() when post != null:
return post(_that);case PublicationDtoTrip() when trip != null:
return trip(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( PublicationDtoRide value)  ride,required TResult Function( PublicationDtoPost value)  post,required TResult Function( PublicationDtoTrip value)  trip,}){
final _that = this;
switch (_that) {
case PublicationDtoRide():
return ride(_that);case PublicationDtoPost():
return post(_that);case PublicationDtoTrip():
return trip(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( PublicationDtoRide value)?  ride,TResult? Function( PublicationDtoPost value)?  post,TResult? Function( PublicationDtoTrip value)?  trip,}){
final _that = this;
switch (_that) {
case PublicationDtoRide() when ride != null:
return ride(_that);case PublicationDtoPost() when post != null:
return post(_that);case PublicationDtoTrip() when trip != null:
return trip(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<RideGroupSummaryDto> groupSummaries,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  TeamPublicationDto team,  int participantCount,  int groupCount,  List<RideGroupDto> groups,  List<PublicUserDto> topParticipants,  bool full,  bool registered,  List<TagDto> tags,  bool deleted,  double? elevationGain,  String? surfaceType,  PlaceDetailDto? startPlace,  PlaceDetailDto? endPlace,  RideWeatherSummaryDto? weather,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  double? distance,  String? routeSlug,  String? registeredGroupId,  RideGroupDto? registeredGroup,  String? createdAt,  int? maxParticipants,  int? commentCount,  String? excerpt,  String? publishAt)?  ride,TResult Function( TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String status,  String visibility,  bool deleted,  bool signedAsTeam,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  String? publishAt,  String? createdAt,  int? commentCount,  PublicUserDto? createdBy)?  post,TResult Function( TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  int participantCount,  int stageCount,  List<TripStageDto> stages,  List<PublicUserDto> participants,  bool deleted,  bool registered,  List<TagDto> tags,  String? excerpt,  String? endDate,  String? publishAt,  String? createdAt,  String? routeSlug,  double? totalDistance,  double? totalElevationGain,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  int? commentCount,  RideWeatherSummaryDto? weather)?  trip,required TResult orElse(),}) {final _that = this;
switch (_that) {
case PublicationDtoRide() when ride != null:
return ride(_that.groupSummaries,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.team,_that.participantCount,_that.groupCount,_that.groups,_that.topParticipants,_that.full,_that.registered,_that.tags,_that.deleted,_that.elevationGain,_that.surfaceType,_that.startPlace,_that.endPlace,_that.weather,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.distance,_that.routeSlug,_that.registeredGroupId,_that.registeredGroup,_that.createdAt,_that.maxParticipants,_that.commentCount,_that.excerpt,_that.publishAt);case PublicationDtoPost() when post != null:
return post(_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.status,_that.visibility,_that.deleted,_that.signedAsTeam,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.publishAt,_that.createdAt,_that.commentCount,_that.createdBy);case PublicationDtoTrip() when trip != null:
return trip(_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.participantCount,_that.stageCount,_that.stages,_that.participants,_that.deleted,_that.registered,_that.tags,_that.excerpt,_that.endDate,_that.publishAt,_that.createdAt,_that.routeSlug,_that.totalDistance,_that.totalElevationGain,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.commentCount,_that.weather);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<RideGroupSummaryDto> groupSummaries,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  TeamPublicationDto team,  int participantCount,  int groupCount,  List<RideGroupDto> groups,  List<PublicUserDto> topParticipants,  bool full,  bool registered,  List<TagDto> tags,  bool deleted,  double? elevationGain,  String? surfaceType,  PlaceDetailDto? startPlace,  PlaceDetailDto? endPlace,  RideWeatherSummaryDto? weather,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  double? distance,  String? routeSlug,  String? registeredGroupId,  RideGroupDto? registeredGroup,  String? createdAt,  int? maxParticipants,  int? commentCount,  String? excerpt,  String? publishAt)  ride,required TResult Function( TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String status,  String visibility,  bool deleted,  bool signedAsTeam,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  String? publishAt,  String? createdAt,  int? commentCount,  PublicUserDto? createdBy)  post,required TResult Function( TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  int participantCount,  int stageCount,  List<TripStageDto> stages,  List<PublicUserDto> participants,  bool deleted,  bool registered,  List<TagDto> tags,  String? excerpt,  String? endDate,  String? publishAt,  String? createdAt,  String? routeSlug,  double? totalDistance,  double? totalElevationGain,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  int? commentCount,  RideWeatherSummaryDto? weather)  trip,}) {final _that = this;
switch (_that) {
case PublicationDtoRide():
return ride(_that.groupSummaries,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.team,_that.participantCount,_that.groupCount,_that.groups,_that.topParticipants,_that.full,_that.registered,_that.tags,_that.deleted,_that.elevationGain,_that.surfaceType,_that.startPlace,_that.endPlace,_that.weather,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.distance,_that.routeSlug,_that.registeredGroupId,_that.registeredGroup,_that.createdAt,_that.maxParticipants,_that.commentCount,_that.excerpt,_that.publishAt);case PublicationDtoPost():
return post(_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.status,_that.visibility,_that.deleted,_that.signedAsTeam,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.publishAt,_that.createdAt,_that.commentCount,_that.createdBy);case PublicationDtoTrip():
return trip(_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.participantCount,_that.stageCount,_that.stages,_that.participants,_that.deleted,_that.registered,_that.tags,_that.excerpt,_that.endDate,_that.publishAt,_that.createdAt,_that.routeSlug,_that.totalDistance,_that.totalElevationGain,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.commentCount,_that.weather);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<RideGroupSummaryDto> groupSummaries,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  TeamPublicationDto team,  int participantCount,  int groupCount,  List<RideGroupDto> groups,  List<PublicUserDto> topParticipants,  bool full,  bool registered,  List<TagDto> tags,  bool deleted,  double? elevationGain,  String? surfaceType,  PlaceDetailDto? startPlace,  PlaceDetailDto? endPlace,  RideWeatherSummaryDto? weather,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  double? distance,  String? routeSlug,  String? registeredGroupId,  RideGroupDto? registeredGroup,  String? createdAt,  int? maxParticipants,  int? commentCount,  String? excerpt,  String? publishAt)?  ride,TResult? Function( TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String status,  String visibility,  bool deleted,  bool signedAsTeam,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  String? publishAt,  String? createdAt,  int? commentCount,  PublicUserDto? createdBy)?  post,TResult? Function( TeamPublicationDto team,  String id,  String slug,  String name,  MediaDto media,  String dateTime,  String timezone,  String endDateTime,  String status,  bool finished,  String visibility,  int participantCount,  int stageCount,  List<TripStageDto> stages,  List<PublicUserDto> participants,  bool deleted,  bool registered,  List<TagDto> tags,  String? excerpt,  String? endDate,  String? publishAt,  String? createdAt,  String? routeSlug,  double? totalDistance,  double? totalElevationGain,  String? thumbnailLightUrl,  String? thumbnailDarkUrl,  String? thumbnailUrl,  int? commentCount,  RideWeatherSummaryDto? weather)?  trip,}) {final _that = this;
switch (_that) {
case PublicationDtoRide() when ride != null:
return ride(_that.groupSummaries,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.team,_that.participantCount,_that.groupCount,_that.groups,_that.topParticipants,_that.full,_that.registered,_that.tags,_that.deleted,_that.elevationGain,_that.surfaceType,_that.startPlace,_that.endPlace,_that.weather,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.distance,_that.routeSlug,_that.registeredGroupId,_that.registeredGroup,_that.createdAt,_that.maxParticipants,_that.commentCount,_that.excerpt,_that.publishAt);case PublicationDtoPost() when post != null:
return post(_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.status,_that.visibility,_that.deleted,_that.signedAsTeam,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.publishAt,_that.createdAt,_that.commentCount,_that.createdBy);case PublicationDtoTrip() when trip != null:
return trip(_that.team,_that.id,_that.slug,_that.name,_that.media,_that.dateTime,_that.timezone,_that.endDateTime,_that.status,_that.finished,_that.visibility,_that.participantCount,_that.stageCount,_that.stages,_that.participants,_that.deleted,_that.registered,_that.tags,_that.excerpt,_that.endDate,_that.publishAt,_that.createdAt,_that.routeSlug,_that.totalDistance,_that.totalElevationGain,_that.thumbnailLightUrl,_that.thumbnailDarkUrl,_that.thumbnailUrl,_that.commentCount,_that.weather);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class PublicationDtoRide implements PublicationDto {
  const PublicationDtoRide({required  List<RideGroupSummaryDto> groupSummaries, required this.id, required this.slug, required this.name, required this.media, required this.dateTime, required this.timezone, required this.endDateTime, required this.status, required this.finished, required this.visibility, required this.team, required this.participantCount, required this.groupCount, required  List<RideGroupDto> groups, required  List<PublicUserDto> topParticipants, required this.full, required this.registered, required  List<TagDto> tags, required this.deleted, this.elevationGain, this.surfaceType, this.startPlace, this.endPlace, this.weather, this.thumbnailLightUrl, this.thumbnailDarkUrl, this.thumbnailUrl, this.distance, this.routeSlug, this.registeredGroupId, this.registeredGroup, this.createdAt, this.maxParticipants, this.commentCount, this.excerpt, this.publishAt,  String? $type}): _groupSummaries = groupSummaries,_groups = groups,_topParticipants = topParticipants,_tags = tags,$type = $type ?? 'RIDE';
  factory PublicationDtoRide.fromJson(Map<String, dynamic> json) => _$PublicationDtoRideFromJson(json);

/// Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.
 final  List<RideGroupSummaryDto> _groupSummaries;
/// Every group of the ride in sort order, as a card shows it: name, pace, start time and fill (countParticipants against maxParticipants). Filled on list rows too, where groups is empty — a card draws its per-group fill bars without opening the ride. Carries no leader nor participants: those are on groups, in the detail.
 List<RideGroupSummaryDto> get groupSummaries {
  if (_groupSummaries is EqualUnmodifiableListView) return _groupSummaries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groupSummaries);
}

/// Publication ID (TSID)
@override final  String id;
/// Publication URL slug
@override final  String slug;
/// Publication name
@override final  String name;
/// Publication media
@override final  MediaDto media;
/// Publication date/time
@override final  String dateTime;
/// IANA zone the ride's times were entered in and read in: its start place's, else its route's, else the team's. dateTime, publishAt, endDateTime and the groups' startAt are rendezvous in this zone.
@override final  String timezone;
/// When the ride is over, computed by the server: the latest of its groups, each one its departure plus its route's length at its average speed — or plus 3 hours when the group has no speed or no route, and for a ride with no group. What the upcoming and past lists (when=UPCOMING|PAST) and the calendar read.
 final  String endDateTime;
/// Publication status
@override final  String status;
/// Whether the ride is over, computed by the server when the response is built: its start time has passed. Independent of status — a past cancelled ride is both CANCELLED and finished.
 final  bool finished;
/// Visibility level
@override final  String visibility;
/// Team
@override final  TeamPublicationDto team;
/// Number of participants
 final  int participantCount;
/// Number of groups
 final  int groupCount;
/// Ride groups
 final  List<RideGroupDto> _groups;
/// Ride groups
 List<RideGroupDto> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

/// Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.
 final  List<PublicUserDto> _topParticipants;
/// Preview of first participants (max 5). Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.
 List<PublicUserDto> get topParticipants {
  if (_topParticipants is EqualUnmodifiableListView) return _topParticipants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topParticipants);
}

/// Whether every group of the ride has reached its capacity. False when the ride has no group, or when at least one group has no maxParticipants.
 final  bool full;
/// Whether the current user is registered in one of this ride's groups. False if anonymous.
 final  bool registered;
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
/// Total elevation gain in meters, from the same route as distance. Null when no route is set anywhere.
 final  double? elevationGain;
/// Surface type, from the same route as distance. Null when no route is set anywhere.
 final  String? surfaceType;
/// Start place
 final  PlaceDetailDto? startPlace;
/// End place
 final  PlaceDetailDto? endPlace;
/// The weather line of a card: the meeting point, over the window from the departure to the estimated arrival of the last group. Absent when there is nothing to show — finished or cancelled ride, no place, forecast not in cache yet; present only with status OK, STALE or NOT_YET_AVAILABLE. The full forecast is getRideWeather.
 final  RideWeatherSummaryDto? weather;
/// Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.
 final  String? thumbnailLightUrl;
/// Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.
 final  String? thumbnailDarkUrl;
/// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;
/// Distance in meters of the ride's route — or, when the ride itself has none, of the route of its first group (in sort order) that has one. Null when no route is set anywhere.
 final  double? distance;
/// Route slug
 final  String? routeSlug;
/// ID (TSID) of the group the current user joined, null if not registered
 final  String? registeredGroupId;
/// The group the current user joined, in full — the same object as the matching entry of groups. Null if not registered or anonymous. Set on list rows too, where groups is empty: a client rendering "my next ride" needs no second request for its group. Its leader is the group's own, null when none was designated.
 final  RideGroupDto? registeredGroup;
/// Creation timestamp
@override final  String? createdAt;
/// Capacity of the whole ride: the sum of its groups' maxParticipants, to render participantCount against it ("12/40"). Null when the ride has no group, or when at least one group has no maxParticipants — the ride then has no overall limit, and is never full. Set on list rows too, where groups is empty.
 final  int? maxParticipants;
/// Number of comments, replies included. Absent when the caller may not read the comments of this ride — comments are members-only, so an outsider is told nothing, not even zero.
@override final  int? commentCount;
/// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
@override final  String? excerpt;
/// Publication timestamp
@override final  String? publishAt;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicationDtoRideCopyWith<PublicationDtoRide> get copyWith => _$PublicationDtoRideCopyWithImpl<PublicationDtoRide>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicationDtoRideToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicationDtoRide&&const DeepCollectionEquality().equals(other.groupSummaries, _groupSummaries)&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.dateTime, dateTime) || other.dateTime == dateTime)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.endDateTime, endDateTime) || other.endDateTime == endDateTime)&&(identical(other.status, status) || other.status == status)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.team, team) || other.team == team)&&(identical(other.participantCount, participantCount) || other.participantCount == participantCount)&&(identical(other.groupCount, groupCount) || other.groupCount == groupCount)&&const DeepCollectionEquality().equals(other.groups, _groups)&&const DeepCollectionEquality().equals(other.topParticipants, _topParticipants)&&(identical(other.full, full) || other.full == full)&&(identical(other.registered, registered) || other.registered == registered)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.elevationGain, elevationGain) || other.elevationGain == elevationGain)&&(identical(other.surfaceType, surfaceType) || other.surfaceType == surfaceType)&&(identical(other.startPlace, startPlace) || other.startPlace == startPlace)&&(identical(other.endPlace, endPlace) || other.endPlace == endPlace)&&(identical(other.weather, weather) || other.weather == weather)&&(identical(other.thumbnailLightUrl, thumbnailLightUrl) || other.thumbnailLightUrl == thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, thumbnailDarkUrl) || other.thumbnailDarkUrl == thumbnailDarkUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.routeSlug, routeSlug) || other.routeSlug == routeSlug)&&(identical(other.registeredGroupId, registeredGroupId) || other.registeredGroupId == registeredGroupId)&&(identical(other.registeredGroup, registeredGroup) || other.registeredGroup == registeredGroup)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.maxParticipants, maxParticipants) || other.maxParticipants == maxParticipants)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.publishAt, publishAt) || other.publishAt == publishAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,const DeepCollectionEquality().hash(_groupSummaries),id,slug,name,media,dateTime,timezone,endDateTime,status,finished,visibility,team,participantCount,groupCount,const DeepCollectionEquality().hash(_groups),const DeepCollectionEquality().hash(_topParticipants),full,registered,const DeepCollectionEquality().hash(_tags),deleted,elevationGain,surfaceType,startPlace,endPlace,weather,thumbnailLightUrl,thumbnailDarkUrl,thumbnailUrl,distance,routeSlug,registeredGroupId,registeredGroup,createdAt,maxParticipants,commentCount,excerpt,publishAt]);
}

@override
String toString() {
    return 'PublicationDto.ride(groupSummaries: $groupSummaries, id: $id, slug: $slug, name: $name, media: $media, dateTime: $dateTime, timezone: $timezone, endDateTime: $endDateTime, status: $status, finished: $finished, visibility: $visibility, team: $team, participantCount: $participantCount, groupCount: $groupCount, groups: $groups, topParticipants: $topParticipants, full: $full, registered: $registered, tags: $tags, deleted: $deleted, elevationGain: $elevationGain, surfaceType: $surfaceType, startPlace: $startPlace, endPlace: $endPlace, weather: $weather, thumbnailLightUrl: $thumbnailLightUrl, thumbnailDarkUrl: $thumbnailDarkUrl, thumbnailUrl: $thumbnailUrl, distance: $distance, routeSlug: $routeSlug, registeredGroupId: $registeredGroupId, registeredGroup: $registeredGroup, createdAt: $createdAt, maxParticipants: $maxParticipants, commentCount: $commentCount, excerpt: $excerpt, publishAt: $publishAt)';
}


}

/// @nodoc
abstract mixin class $PublicationDtoRideCopyWith<$Res> implements $PublicationDtoCopyWith<$Res> {
  factory $PublicationDtoRideCopyWith(PublicationDtoRide value, $Res Function(PublicationDtoRide) _then) = _$PublicationDtoRideCopyWithImpl;
@override @useResult
$Res call({
 List<RideGroupSummaryDto> groupSummaries, String id, String slug, String name, MediaDto media, String dateTime, String timezone, String endDateTime, String status, bool finished, String visibility, TeamPublicationDto team, int participantCount, int groupCount, List<RideGroupDto> groups, List<PublicUserDto> topParticipants, bool full, bool registered, List<TagDto> tags, bool deleted, double? elevationGain, String? surfaceType, PlaceDetailDto? startPlace, PlaceDetailDto? endPlace, RideWeatherSummaryDto? weather, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? thumbnailUrl, double? distance, String? routeSlug, String? registeredGroupId, RideGroupDto? registeredGroup, String? createdAt, int? maxParticipants, int? commentCount, String? excerpt, String? publishAt
});


@override $MediaDtoCopyWith<$Res> get media;@override $TeamPublicationDtoCopyWith<$Res> get team;$PlaceDetailDtoCopyWith<$Res>? get startPlace;$PlaceDetailDtoCopyWith<$Res>? get endPlace;$RideWeatherSummaryDtoCopyWith<$Res>? get weather;$RideGroupDtoCopyWith<$Res>? get registeredGroup;

}
/// @nodoc
class _$PublicationDtoRideCopyWithImpl<$Res>
    implements $PublicationDtoRideCopyWith<$Res> {
  _$PublicationDtoRideCopyWithImpl(this._self, this._then);

  final PublicationDtoRide _self;
  final $Res Function(PublicationDtoRide) _then;

/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? groupSummaries = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? dateTime = null,Object? timezone = null,Object? endDateTime = null,Object? status = null,Object? finished = null,Object? visibility = null,Object? team = null,Object? participantCount = null,Object? groupCount = null,Object? groups = null,Object? topParticipants = null,Object? full = null,Object? registered = null,Object? tags = null,Object? deleted = null,Object? elevationGain = freezed,Object? surfaceType = freezed,Object? startPlace = freezed,Object? endPlace = freezed,Object? weather = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? thumbnailUrl = freezed,Object? distance = freezed,Object? routeSlug = freezed,Object? registeredGroupId = freezed,Object? registeredGroup = freezed,Object? createdAt = freezed,Object? maxParticipants = freezed,Object? commentCount = freezed,Object? excerpt = freezed,Object? publishAt = freezed,}) {
  return _then(PublicationDtoRide(
groupSummaries: null == groupSummaries ? _self._groupSummaries : groupSummaries // ignore: cast_nullable_to_non_nullable
as List<RideGroupSummaryDto>,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,endDateTime: null == endDateTime ? _self.endDateTime : endDateTime // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,finished: null == finished ? _self.finished : finished // ignore: cast_nullable_to_non_nullable
as bool,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,participantCount: null == participantCount ? _self.participantCount : participantCount // ignore: cast_nullable_to_non_nullable
as int,groupCount: null == groupCount ? _self.groupCount : groupCount // ignore: cast_nullable_to_non_nullable
as int,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<RideGroupDto>,topParticipants: null == topParticipants ? _self._topParticipants : topParticipants // ignore: cast_nullable_to_non_nullable
as List<PublicUserDto>,full: null == full ? _self.full : full // ignore: cast_nullable_to_non_nullable
as bool,registered: null == registered ? _self.registered : registered // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,elevationGain: freezed == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double?,surfaceType: freezed == surfaceType ? _self.surfaceType : surfaceType // ignore: cast_nullable_to_non_nullable
as String?,startPlace: freezed == startPlace ? _self.startPlace : startPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,endPlace: freezed == endPlace ? _self.endPlace : endPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,weather: freezed == weather ? _self.weather : weather // ignore: cast_nullable_to_non_nullable
as RideWeatherSummaryDto?,thumbnailLightUrl: freezed == thumbnailLightUrl ? _self.thumbnailLightUrl : thumbnailLightUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailDarkUrl: freezed == thumbnailDarkUrl ? _self.thumbnailDarkUrl : thumbnailDarkUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,routeSlug: freezed == routeSlug ? _self.routeSlug : routeSlug // ignore: cast_nullable_to_non_nullable
as String?,registeredGroupId: freezed == registeredGroupId ? _self.registeredGroupId : registeredGroupId // ignore: cast_nullable_to_non_nullable
as String?,registeredGroup: freezed == registeredGroup ? _self.registeredGroup : registeredGroup // ignore: cast_nullable_to_non_nullable
as RideGroupDto?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,maxParticipants: freezed == maxParticipants ? _self.maxParticipants : maxParticipants // ignore: cast_nullable_to_non_nullable
as int?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of PublicationDto
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
}/// Create a copy of PublicationDto
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
}/// Create a copy of PublicationDto
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
}/// Create a copy of PublicationDto
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
}
}

/// @nodoc
@JsonSerializable()

class PublicationDtoPost implements PublicationDto {
  const PublicationDtoPost({required this.team, required this.id, required this.slug, required this.name, required this.media, required this.dateTime, required this.timezone, required this.status, required this.visibility, required this.deleted, required this.signedAsTeam, required  List<TagDto> tags, this.excerpt, this.thumbnailUrl, this.publishAt, this.createdAt, this.commentCount, this.createdBy,  String? $type}): _tags = tags,$type = $type ?? 'POST';
  factory PublicationDtoPost.fromJson(Map<String, dynamic> json) => _$PublicationDtoPostFromJson(json);

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
/// Publication date/time
@override final  String dateTime;
/// IANA zone the post's times were entered in and read in: the team's at its last save. dateTime, publishAt are rendezvous in this zone.
@override final  String timezone;
/// Publication status
@override final  String status;
/// Visibility level
@override final  String visibility;
/// Whether the post is soft-deleted
@override final  bool deleted;
/// Whether the post is signed by the team rather than by its author. Readers are then not told who wrote it: createdBy is absent unless the caller administers the team or wrote the post.
 final  bool signedAsTeam;
/// The team's POST tags the post carries, sorted by label. Empty when it carries none.
 final  List<TagDto> _tags;
/// The team's POST tags the post carries, sorted by label. Empty when it carries none.
@override List<TagDto> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

/// Plain-text opening of the markdown body, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the body holds no text. Lets a list row render its two lines without the body being sent at all — see the 'view' parameter.
@override final  String? excerpt;
/// URL template of the post's first image, the one a card shows. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;
/// Publication timestamp
@override final  String? publishAt;
/// Creation timestamp
@override final  String? createdAt;
/// Number of comments, replies included. Absent when the caller may not read the comments of this post — comments are members-only, so an outsider is told nothing, not even zero.
@override final  int? commentCount;
/// Who wrote the post. Absent when the caller is not a member of the team — member names are never sent to anyone else — and when the post is signed by the team (signedAsTeam) and the caller neither administers the team nor wrote it: render the team instead.
 final  PublicUserDto? createdBy;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicationDtoPostCopyWith<PublicationDtoPost> get copyWith => _$PublicationDtoPostCopyWithImpl<PublicationDtoPost>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicationDtoPostToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicationDtoPost&&(identical(other.team, team) || other.team == team)&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.dateTime, dateTime) || other.dateTime == dateTime)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.status, status) || other.status == status)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.signedAsTeam, signedAsTeam) || other.signedAsTeam == signedAsTeam)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.publishAt, publishAt) || other.publishAt == publishAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,team,id,slug,name,media,dateTime,timezone,status,visibility,deleted,signedAsTeam,const DeepCollectionEquality().hash(_tags),excerpt,thumbnailUrl,publishAt,createdAt,commentCount,createdBy);
}

@override
String toString() {
    return 'PublicationDto.post(team: $team, id: $id, slug: $slug, name: $name, media: $media, dateTime: $dateTime, timezone: $timezone, status: $status, visibility: $visibility, deleted: $deleted, signedAsTeam: $signedAsTeam, tags: $tags, excerpt: $excerpt, thumbnailUrl: $thumbnailUrl, publishAt: $publishAt, createdAt: $createdAt, commentCount: $commentCount, createdBy: $createdBy)';
}


}

/// @nodoc
abstract mixin class $PublicationDtoPostCopyWith<$Res> implements $PublicationDtoCopyWith<$Res> {
  factory $PublicationDtoPostCopyWith(PublicationDtoPost value, $Res Function(PublicationDtoPost) _then) = _$PublicationDtoPostCopyWithImpl;
@override @useResult
$Res call({
 TeamPublicationDto team, String id, String slug, String name, MediaDto media, String dateTime, String timezone, String status, String visibility, bool deleted, bool signedAsTeam, List<TagDto> tags, String? excerpt, String? thumbnailUrl, String? publishAt, String? createdAt, int? commentCount, PublicUserDto? createdBy
});


@override $TeamPublicationDtoCopyWith<$Res> get team;@override $MediaDtoCopyWith<$Res> get media;$PublicUserDtoCopyWith<$Res>? get createdBy;

}
/// @nodoc
class _$PublicationDtoPostCopyWithImpl<$Res>
    implements $PublicationDtoPostCopyWith<$Res> {
  _$PublicationDtoPostCopyWithImpl(this._self, this._then);

  final PublicationDtoPost _self;
  final $Res Function(PublicationDtoPost) _then;

/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? dateTime = null,Object? timezone = null,Object? status = null,Object? visibility = null,Object? deleted = null,Object? signedAsTeam = null,Object? tags = null,Object? excerpt = freezed,Object? thumbnailUrl = freezed,Object? publishAt = freezed,Object? createdAt = freezed,Object? commentCount = freezed,Object? createdBy = freezed,}) {
  return _then(PublicationDtoPost(
team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,signedAsTeam: null == signedAsTeam ? _self.signedAsTeam : signedAsTeam // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,publishAt: freezed == publishAt ? _self.publishAt : publishAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as PublicUserDto?,
  ));
}

/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicUserDtoCopyWith<$Res>? get createdBy {
    if (_self.createdBy == null) {
    return null;
  }

  return $PublicUserDtoCopyWith<$Res>(_self.createdBy!, (value) {
    return _then(_self.copyWith(createdBy: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class PublicationDtoTrip implements PublicationDto {
  const PublicationDtoTrip({required this.team, required this.id, required this.slug, required this.name, required this.media, required this.dateTime, required this.timezone, required this.endDateTime, required this.status, required this.finished, required this.visibility, required this.participantCount, required this.stageCount, required  List<TripStageDto> stages, required  List<PublicUserDto> participants, required this.deleted, required this.registered, required  List<TagDto> tags, this.excerpt, this.endDate, this.publishAt, this.createdAt, this.routeSlug, this.totalDistance, this.totalElevationGain, this.thumbnailLightUrl, this.thumbnailDarkUrl, this.thumbnailUrl, this.commentCount, this.weather,  String? $type}): _stages = stages,_participants = participants,_tags = tags,$type = $type ?? 'TRIP';
  factory PublicationDtoTrip.fromJson(Map<String, dynamic> json) => _$PublicationDtoTripFromJson(json);

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
 final  String endDateTime;
/// Publication status
@override final  String status;
/// Whether the trip is over, computed by the server when the response is built: its last stage (endDate, or dateTime when there is none) has started. Independent of status — a past cancelled trip is both CANCELLED and finished.
 final  bool finished;
/// Visibility level
@override final  String visibility;
/// Number of participants
 final  int participantCount;
/// Number of stages
 final  int stageCount;
/// Trip stages
 final  List<TripStageDto> _stages;
/// Trip stages
 List<TripStageDto> get stages {
  if (_stages is EqualUnmodifiableListView) return _stages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stages);
}

/// The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.
 final  List<PublicUserDto> _participants;
/// The first participants of the trip (at most 8), earliest registrations first — enough to draw avatars; empty on a list row. participantCount is the total; the whole list is paginated and searched by GET …/trips/{tripSlug}/participants. Always empty for a caller who is not a member of the team (member names are never sent to anyone else): the count stays.
 List<PublicUserDto> get participants {
  if (_participants is EqualUnmodifiableListView) return _participants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_participants);
}

/// Whether the trip is soft-deleted
@override final  bool deleted;
/// Whether the current user is registered for this trip. False if anonymous.
 final  bool registered;
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
 final  String? endDate;
/// Publication timestamp
@override final  String? publishAt;
/// Creation timestamp
@override final  String? createdAt;
/// Route slug
 final  String? routeSlug;
/// Distance in metres over every stage that has a route. Null when no stage has one — an unrouted trip has no distance, which is not the same as a distance of zero.
 final  double? totalDistance;
/// Elevation gain in metres over every stage that has a route. Null when no stage has one.
 final  double? totalElevationGain;
/// Thumbnail URL (light). Opaque URL: may carry a query string; substitute {size} only.
 final  String? thumbnailLightUrl;
/// Thumbnail URL (dark). Opaque URL: may carry a query string; substitute {size} only.
 final  String? thumbnailDarkUrl;
/// The one thumbnail to show when the client does not theme its cards: the light variant if there is one, else the dark one. Saves a compact row from carrying media.assets just to find a picture. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;
/// Number of comments, replies included. Absent when the caller may not read the comments of this trip — comments are members-only, so an outsider is told nothing, not even zero.
@override final  int? commentCount;
/// The weather line of a list card: that of the trip's next leg — its first stage still to leave, else the trip itself when it has no stage — at the start of its route, over the window from its departure to its estimated arrival. Absent when there is nothing to show — trip finished, draft or cancelled, next stage without a route, forecast not in cache yet — and on the trip's own detail, which reads getTripWeather; present only with status OK, STALE or NOT_YET_AVAILABLE.
 final  RideWeatherSummaryDto? weather;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicationDtoTripCopyWith<PublicationDtoTrip> get copyWith => _$PublicationDtoTripCopyWithImpl<PublicationDtoTrip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicationDtoTripToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicationDtoTrip&&(identical(other.team, team) || other.team == team)&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.dateTime, dateTime) || other.dateTime == dateTime)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.endDateTime, endDateTime) || other.endDateTime == endDateTime)&&(identical(other.status, status) || other.status == status)&&(identical(other.finished, finished) || other.finished == finished)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.participantCount, participantCount) || other.participantCount == participantCount)&&(identical(other.stageCount, stageCount) || other.stageCount == stageCount)&&const DeepCollectionEquality().equals(other.stages, _stages)&&const DeepCollectionEquality().equals(other.participants, _participants)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.registered, registered) || other.registered == registered)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.publishAt, publishAt) || other.publishAt == publishAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.routeSlug, routeSlug) || other.routeSlug == routeSlug)&&(identical(other.totalDistance, totalDistance) || other.totalDistance == totalDistance)&&(identical(other.totalElevationGain, totalElevationGain) || other.totalElevationGain == totalElevationGain)&&(identical(other.thumbnailLightUrl, thumbnailLightUrl) || other.thumbnailLightUrl == thumbnailLightUrl)&&(identical(other.thumbnailDarkUrl, thumbnailDarkUrl) || other.thumbnailDarkUrl == thumbnailDarkUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.weather, weather) || other.weather == weather));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,team,id,slug,name,media,dateTime,timezone,endDateTime,status,finished,visibility,participantCount,stageCount,const DeepCollectionEquality().hash(_stages),const DeepCollectionEquality().hash(_participants),deleted,registered,const DeepCollectionEquality().hash(_tags),excerpt,endDate,publishAt,createdAt,routeSlug,totalDistance,totalElevationGain,thumbnailLightUrl,thumbnailDarkUrl,thumbnailUrl,commentCount,weather]);
}

@override
String toString() {
    return 'PublicationDto.trip(team: $team, id: $id, slug: $slug, name: $name, media: $media, dateTime: $dateTime, timezone: $timezone, endDateTime: $endDateTime, status: $status, finished: $finished, visibility: $visibility, participantCount: $participantCount, stageCount: $stageCount, stages: $stages, participants: $participants, deleted: $deleted, registered: $registered, tags: $tags, excerpt: $excerpt, endDate: $endDate, publishAt: $publishAt, createdAt: $createdAt, routeSlug: $routeSlug, totalDistance: $totalDistance, totalElevationGain: $totalElevationGain, thumbnailLightUrl: $thumbnailLightUrl, thumbnailDarkUrl: $thumbnailDarkUrl, thumbnailUrl: $thumbnailUrl, commentCount: $commentCount, weather: $weather)';
}


}

/// @nodoc
abstract mixin class $PublicationDtoTripCopyWith<$Res> implements $PublicationDtoCopyWith<$Res> {
  factory $PublicationDtoTripCopyWith(PublicationDtoTrip value, $Res Function(PublicationDtoTrip) _then) = _$PublicationDtoTripCopyWithImpl;
@override @useResult
$Res call({
 TeamPublicationDto team, String id, String slug, String name, MediaDto media, String dateTime, String timezone, String endDateTime, String status, bool finished, String visibility, int participantCount, int stageCount, List<TripStageDto> stages, List<PublicUserDto> participants, bool deleted, bool registered, List<TagDto> tags, String? excerpt, String? endDate, String? publishAt, String? createdAt, String? routeSlug, double? totalDistance, double? totalElevationGain, String? thumbnailLightUrl, String? thumbnailDarkUrl, String? thumbnailUrl, int? commentCount, RideWeatherSummaryDto? weather
});


@override $TeamPublicationDtoCopyWith<$Res> get team;@override $MediaDtoCopyWith<$Res> get media;$RideWeatherSummaryDtoCopyWith<$Res>? get weather;

}
/// @nodoc
class _$PublicationDtoTripCopyWithImpl<$Res>
    implements $PublicationDtoTripCopyWith<$Res> {
  _$PublicationDtoTripCopyWithImpl(this._self, this._then);

  final PublicationDtoTrip _self;
  final $Res Function(PublicationDtoTrip) _then;

/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? team = null,Object? id = null,Object? slug = null,Object? name = null,Object? media = null,Object? dateTime = null,Object? timezone = null,Object? endDateTime = null,Object? status = null,Object? finished = null,Object? visibility = null,Object? participantCount = null,Object? stageCount = null,Object? stages = null,Object? participants = null,Object? deleted = null,Object? registered = null,Object? tags = null,Object? excerpt = freezed,Object? endDate = freezed,Object? publishAt = freezed,Object? createdAt = freezed,Object? routeSlug = freezed,Object? totalDistance = freezed,Object? totalElevationGain = freezed,Object? thumbnailLightUrl = freezed,Object? thumbnailDarkUrl = freezed,Object? thumbnailUrl = freezed,Object? commentCount = freezed,Object? weather = freezed,}) {
  return _then(PublicationDtoTrip(
team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
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

/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of PublicationDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of PublicationDto
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
