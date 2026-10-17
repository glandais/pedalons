// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_detail_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteDetailDto {

/// Route ID (TSID)
 String get id;/// Route slug
 String get slug;/// Team
 TeamPublicationDto get team;/// Route name
 String get name;/// Media
 MediaDto get media;/// Distance in meters
 double get distance;/// Total elevation gain in meters
 double get elevationGain;/// Total elevation loss in meters
 double get elevationLoss;/// Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.
 String get elevationState;/// Surface type
 String get surfaceType;/// Whether the route is public
 String get visibility;/// Creator user
 PublicUserDto get createdBy;/// Creation timestamp
 String get createdAt;/// Last update timestamp
 String get updatedAt;/// Tracks, with the stored geometry untouched — every coordinate carries longitude, latitude, elevation and cumulative distance in meters. Empty when the bulk endpoint was called with 'geometry=false'.
 List<TrackDto> get tracks;/// Waypoints
 List<WaypointDto> get waypoints;/// Whether the route is soft-deleted
 bool get deleted;/// The team's ROUTE tags the route carries, sorted by label. Empty when it carries none.
 List<TagDto> get tags; GeoJsonPoint? get start; GeoJsonPoint? get end;/// Number of comments, replies included. Absent when the caller may not read the comments of this route — comments are members-only, so an outsider is told nothing, not even zero.
 int? get commentCount;
/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteDetailDtoCopyWith<RouteDetailDto> get copyWith => _$RouteDetailDtoCopyWithImpl<RouteDetailDto>(this as RouteDetailDto, _$identity);

  /// Serializes this RouteDetailDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteDetailDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteDetailDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.team, _this.team) || other.team == _this.team)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.elevationGain, _this.elevationGain) || other.elevationGain == _this.elevationGain)&&(identical(other.elevationLoss, _this.elevationLoss) || other.elevationLoss == _this.elevationLoss)&&(identical(other.elevationState, _this.elevationState) || other.elevationState == _this.elevationState)&&(identical(other.surfaceType, _this.surfaceType) || other.surfaceType == _this.surfaceType)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.createdBy, _this.createdBy) || other.createdBy == _this.createdBy)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&const DeepCollectionEquality().equals(other.tracks, _this.tracks)&&const DeepCollectionEquality().equals(other.waypoints, _this.waypoints)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end)&&(identical(other.commentCount, _this.commentCount) || other.commentCount == _this.commentCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteDetailDto;
  return Object.hashAll([runtimeType,_this.id,_this.slug,_this.team,_this.name,_this.media,_this.distance,_this.elevationGain,_this.elevationLoss,_this.elevationState,_this.surfaceType,_this.visibility,_this.createdBy,_this.createdAt,_this.updatedAt,const DeepCollectionEquality().hash(_this.tracks),const DeepCollectionEquality().hash(_this.waypoints),_this.deleted,const DeepCollectionEquality().hash(_this.tags),_this.start,_this.end,_this.commentCount]);
}

@override
String toString() {
  final _this = this as RouteDetailDto;
  return 'RouteDetailDto(id: ${_this.id}, slug: ${_this.slug}, team: ${_this.team}, name: ${_this.name}, media: ${_this.media}, distance: ${_this.distance}, elevationGain: ${_this.elevationGain}, elevationLoss: ${_this.elevationLoss}, elevationState: ${_this.elevationState}, surfaceType: ${_this.surfaceType}, visibility: ${_this.visibility}, createdBy: ${_this.createdBy}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, tracks: ${_this.tracks}, waypoints: ${_this.waypoints}, deleted: ${_this.deleted}, tags: ${_this.tags}, start: ${_this.start}, end: ${_this.end}, commentCount: ${_this.commentCount})';
}


}

/// @nodoc
abstract mixin class $RouteDetailDtoCopyWith<$Res>  {
  factory $RouteDetailDtoCopyWith(RouteDetailDto value, $Res Function(RouteDetailDto) _then) = _$RouteDetailDtoCopyWithImpl;
@useResult
$Res call({
 String id, String slug, TeamPublicationDto team, String name, MediaDto media, double distance, double elevationGain, double elevationLoss, String elevationState, String surfaceType, String visibility, PublicUserDto createdBy, String createdAt, String updatedAt, List<TrackDto> tracks, List<WaypointDto> waypoints, bool deleted, List<TagDto> tags, GeoJsonPoint? start, GeoJsonPoint? end, int? commentCount
});


$TeamPublicationDtoCopyWith<$Res> get team;$MediaDtoCopyWith<$Res> get media;$PublicUserDtoCopyWith<$Res> get createdBy;$GeoJsonPointCopyWith<$Res>? get start;$GeoJsonPointCopyWith<$Res>? get end;

}
/// @nodoc
class _$RouteDetailDtoCopyWithImpl<$Res>
    implements $RouteDetailDtoCopyWith<$Res> {
  _$RouteDetailDtoCopyWithImpl(this._self, this._then);

  final RouteDetailDto _self;
  final $Res Function(RouteDetailDto) _then;

/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? team = null,Object? name = null,Object? media = null,Object? distance = null,Object? elevationGain = null,Object? elevationLoss = null,Object? elevationState = null,Object? surfaceType = null,Object? visibility = null,Object? createdBy = null,Object? createdAt = null,Object? updatedAt = null,Object? tracks = null,Object? waypoints = null,Object? deleted = null,Object? tags = null,Object? start = freezed,Object? end = freezed,Object? commentCount = freezed,}) {
  return _then(RouteDetailDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,elevationGain: null == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double,elevationLoss: null == elevationLoss ? _self.elevationLoss : elevationLoss // ignore: cast_nullable_to_non_nullable
as double,elevationState: null == elevationState ? _self.elevationState : elevationState // ignore: cast_nullable_to_non_nullable
as String,surfaceType: null == surfaceType ? _self.surfaceType : surfaceType // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as PublicUserDto,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,tracks: null == tracks ? _self.tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<TrackDto>,waypoints: null == waypoints ? _self.waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<WaypointDto>,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as GeoJsonPoint?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as GeoJsonPoint?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicUserDtoCopyWith<$Res> get createdBy {
  
  return $PublicUserDtoCopyWith<$Res>(_self.createdBy, (value) {
    return _then(_self.copyWith(createdBy: value));
  });
}/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoJsonPointCopyWith<$Res>? get start {
    if (_self.start == null) {
    return null;
  }

  return $GeoJsonPointCopyWith<$Res>(_self.start!, (value) {
    return _then(_self.copyWith(start: value));
  });
}/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoJsonPointCopyWith<$Res>? get end {
    if (_self.end == null) {
    return null;
  }

  return $GeoJsonPointCopyWith<$Res>(_self.end!, (value) {
    return _then(_self.copyWith(end: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouteDetailDto].
extension RouteDetailDtoPatterns on RouteDetailDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteDetailDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteDetailDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteDetailDto value)  $default,){
final _that = this;
switch (_that) {
case _RouteDetailDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteDetailDto value)?  $default,){
final _that = this;
switch (_that) {
case _RouteDetailDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String slug,  TeamPublicationDto team,  String name,  MediaDto media,  double distance,  double elevationGain,  double elevationLoss,  String elevationState,  String surfaceType,  String visibility,  PublicUserDto createdBy,  String createdAt,  String updatedAt,  List<TrackDto> tracks,  List<WaypointDto> waypoints,  bool deleted,  List<TagDto> tags,  GeoJsonPoint? start,  GeoJsonPoint? end,  int? commentCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteDetailDto() when $default != null:
return $default(_that.id,_that.slug,_that.team,_that.name,_that.media,_that.distance,_that.elevationGain,_that.elevationLoss,_that.elevationState,_that.surfaceType,_that.visibility,_that.createdBy,_that.createdAt,_that.updatedAt,_that.tracks,_that.waypoints,_that.deleted,_that.tags,_that.start,_that.end,_that.commentCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String slug,  TeamPublicationDto team,  String name,  MediaDto media,  double distance,  double elevationGain,  double elevationLoss,  String elevationState,  String surfaceType,  String visibility,  PublicUserDto createdBy,  String createdAt,  String updatedAt,  List<TrackDto> tracks,  List<WaypointDto> waypoints,  bool deleted,  List<TagDto> tags,  GeoJsonPoint? start,  GeoJsonPoint? end,  int? commentCount)  $default,) {final _that = this;
switch (_that) {
case _RouteDetailDto():
return $default(_that.id,_that.slug,_that.team,_that.name,_that.media,_that.distance,_that.elevationGain,_that.elevationLoss,_that.elevationState,_that.surfaceType,_that.visibility,_that.createdBy,_that.createdAt,_that.updatedAt,_that.tracks,_that.waypoints,_that.deleted,_that.tags,_that.start,_that.end,_that.commentCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String slug,  TeamPublicationDto team,  String name,  MediaDto media,  double distance,  double elevationGain,  double elevationLoss,  String elevationState,  String surfaceType,  String visibility,  PublicUserDto createdBy,  String createdAt,  String updatedAt,  List<TrackDto> tracks,  List<WaypointDto> waypoints,  bool deleted,  List<TagDto> tags,  GeoJsonPoint? start,  GeoJsonPoint? end,  int? commentCount)?  $default,) {final _that = this;
switch (_that) {
case _RouteDetailDto() when $default != null:
return $default(_that.id,_that.slug,_that.team,_that.name,_that.media,_that.distance,_that.elevationGain,_that.elevationLoss,_that.elevationState,_that.surfaceType,_that.visibility,_that.createdBy,_that.createdAt,_that.updatedAt,_that.tracks,_that.waypoints,_that.deleted,_that.tags,_that.start,_that.end,_that.commentCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteDetailDto implements RouteDetailDto {
  const _RouteDetailDto({required this.id, required this.slug, required this.team, required this.name, required this.media, required this.distance, required this.elevationGain, required this.elevationLoss, required this.elevationState, required this.surfaceType, required this.visibility, required this.createdBy, required this.createdAt, required this.updatedAt, required  List<TrackDto> tracks, required  List<WaypointDto> waypoints, required this.deleted, required  List<TagDto> tags, this.start, this.end, this.commentCount}): _tracks = tracks,_waypoints = waypoints,_tags = tags;
  factory _RouteDetailDto.fromJson(Map<String, dynamic> json) => _$RouteDetailDtoFromJson(json);

/// Route ID (TSID)
@override final  String id;
/// Route slug
@override final  String slug;
/// Team
@override final  TeamPublicationDto team;
/// Route name
@override final  String name;
/// Media
@override final  MediaDto media;
/// Distance in meters
@override final  double distance;
/// Total elevation gain in meters
@override final  double elevationGain;
/// Total elevation loss in meters
@override final  double elevationLoss;
/// Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.
@override final  String elevationState;
/// Surface type
@override final  String surfaceType;
/// Whether the route is public
@override final  String visibility;
/// Creator user
@override final  PublicUserDto createdBy;
/// Creation timestamp
@override final  String createdAt;
/// Last update timestamp
@override final  String updatedAt;
/// Tracks, with the stored geometry untouched — every coordinate carries longitude, latitude, elevation and cumulative distance in meters. Empty when the bulk endpoint was called with 'geometry=false'.
 final  List<TrackDto> _tracks;
/// Tracks, with the stored geometry untouched — every coordinate carries longitude, latitude, elevation and cumulative distance in meters. Empty when the bulk endpoint was called with 'geometry=false'.
@override List<TrackDto> get tracks {
  if (_tracks is EqualUnmodifiableListView) return _tracks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tracks);
}

/// Waypoints
 final  List<WaypointDto> _waypoints;
/// Waypoints
@override List<WaypointDto> get waypoints {
  if (_waypoints is EqualUnmodifiableListView) return _waypoints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_waypoints);
}

/// Whether the route is soft-deleted
@override final  bool deleted;
/// The team's ROUTE tags the route carries, sorted by label. Empty when it carries none.
 final  List<TagDto> _tags;
/// The team's ROUTE tags the route carries, sorted by label. Empty when it carries none.
@override List<TagDto> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override final  GeoJsonPoint? start;
@override final  GeoJsonPoint? end;
/// Number of comments, replies included. Absent when the caller may not read the comments of this route — comments are members-only, so an outsider is told nothing, not even zero.
@override final  int? commentCount;

/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteDetailDtoCopyWith<_RouteDetailDto> get copyWith => __$RouteDetailDtoCopyWithImpl<_RouteDetailDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteDetailDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteDetailDto&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.team, team) || other.team == team)&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.elevationGain, elevationGain) || other.elevationGain == elevationGain)&&(identical(other.elevationLoss, elevationLoss) || other.elevationLoss == elevationLoss)&&(identical(other.elevationState, elevationState) || other.elevationState == elevationState)&&(identical(other.surfaceType, surfaceType) || other.surfaceType == surfaceType)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.tracks, _tracks)&&const DeepCollectionEquality().equals(other.waypoints, _waypoints)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,slug,team,name,media,distance,elevationGain,elevationLoss,elevationState,surfaceType,visibility,createdBy,createdAt,updatedAt,const DeepCollectionEquality().hash(_tracks),const DeepCollectionEquality().hash(_waypoints),deleted,const DeepCollectionEquality().hash(_tags),start,end,commentCount]);
}

@override
String toString() {
    return 'RouteDetailDto(id: $id, slug: $slug, team: $team, name: $name, media: $media, distance: $distance, elevationGain: $elevationGain, elevationLoss: $elevationLoss, elevationState: $elevationState, surfaceType: $surfaceType, visibility: $visibility, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, tracks: $tracks, waypoints: $waypoints, deleted: $deleted, tags: $tags, start: $start, end: $end, commentCount: $commentCount)';
}


}

/// @nodoc
abstract mixin class _$RouteDetailDtoCopyWith<$Res> implements $RouteDetailDtoCopyWith<$Res> {
  factory _$RouteDetailDtoCopyWith(_RouteDetailDto value, $Res Function(_RouteDetailDto) _then) = __$RouteDetailDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String slug, TeamPublicationDto team, String name, MediaDto media, double distance, double elevationGain, double elevationLoss, String elevationState, String surfaceType, String visibility, PublicUserDto createdBy, String createdAt, String updatedAt, List<TrackDto> tracks, List<WaypointDto> waypoints, bool deleted, List<TagDto> tags, GeoJsonPoint? start, GeoJsonPoint? end, int? commentCount
});


@override $TeamPublicationDtoCopyWith<$Res> get team;@override $MediaDtoCopyWith<$Res> get media;@override $PublicUserDtoCopyWith<$Res> get createdBy;@override $GeoJsonPointCopyWith<$Res>? get start;@override $GeoJsonPointCopyWith<$Res>? get end;

}
/// @nodoc
class __$RouteDetailDtoCopyWithImpl<$Res>
    implements _$RouteDetailDtoCopyWith<$Res> {
  __$RouteDetailDtoCopyWithImpl(this._self, this._then);

  final _RouteDetailDto _self;
  final $Res Function(_RouteDetailDto) _then;

/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? team = null,Object? name = null,Object? media = null,Object? distance = null,Object? elevationGain = null,Object? elevationLoss = null,Object? elevationState = null,Object? surfaceType = null,Object? visibility = null,Object? createdBy = null,Object? createdAt = null,Object? updatedAt = null,Object? tracks = null,Object? waypoints = null,Object? deleted = null,Object? tags = null,Object? start = freezed,Object? end = freezed,Object? commentCount = freezed,}) {
  return _then(_RouteDetailDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamPublicationDto,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,elevationGain: null == elevationGain ? _self.elevationGain : elevationGain // ignore: cast_nullable_to_non_nullable
as double,elevationLoss: null == elevationLoss ? _self.elevationLoss : elevationLoss // ignore: cast_nullable_to_non_nullable
as double,elevationState: null == elevationState ? _self.elevationState : elevationState // ignore: cast_nullable_to_non_nullable
as String,surfaceType: null == surfaceType ? _self.surfaceType : surfaceType // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as PublicUserDto,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as String,tracks: null == tracks ? _self._tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<TrackDto>,waypoints: null == waypoints ? _self._waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<WaypointDto>,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as GeoJsonPoint?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as GeoJsonPoint?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicUserDtoCopyWith<$Res> get createdBy {
  
  return $PublicUserDtoCopyWith<$Res>(_self.createdBy, (value) {
    return _then(_self.copyWith(createdBy: value));
  });
}/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoJsonPointCopyWith<$Res>? get start {
    if (_self.start == null) {
    return null;
  }

  return $GeoJsonPointCopyWith<$Res>(_self.start!, (value) {
    return _then(_self.copyWith(start: value));
  });
}/// Create a copy of RouteDetailDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoJsonPointCopyWith<$Res>? get end {
    if (_self.end == null) {
    return null;
  }

  return $GeoJsonPointCopyWith<$Res>(_self.end!, (value) {
    return _then(_self.copyWith(end: value));
  });
}
}

// dart format on
