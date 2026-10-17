// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteDto {

/// Route ID (TSID)
 String get id;/// Route slug
 String get slug;/// Team
 TeamPublicationDto get team;/// Route name
 String get name;/// Route description
 MediaDto get media;/// Distance in meters
 double get distance;/// Total elevation gain in meters
 double get elevationGain;/// Total elevation loss in meters
 double get elevationLoss;/// Where the elevation profile stands. PENDING: the fast profile (Mapterhorn) is stored and the precise IGN LiDAR HD recomputation is scheduled. HD: the precise profile. FAST: the fast profile is kept, the HD recomputation failed.
 String get elevationState;/// Surface type
 String get surfaceType;/// Whether the route is public
 String get visibility;/// Creation timestamp
 String get createdAt;/// Whether the route is soft-deleted
 bool get deleted;/// The team's ROUTE tags the route carries, sorted by label. Empty when it carries none.
 List<TagDto> get tags;/// Plain-text opening of the description, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the description holds no text. Lets a list row render its two lines without the description being sent at all — see the 'view' parameter.
 String? get excerpt;/// URL template of the route's thumbnail, light variant if there is one, else dark. Saves a compact row from carrying media.assets just to find the map preview. Opaque URL: may carry a query string; substitute {size} only.
 String? get thumbnailUrl;/// Number of comments, replies included. Absent when the caller may not read the comments of this route — comments are members-only, so an outsider is told nothing, not even zero.
 int? get commentCount;
/// Create a copy of RouteDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteDtoCopyWith<RouteDto> get copyWith => _$RouteDtoCopyWithImpl<RouteDto>(this as RouteDto, _$identity);

  /// Serializes this RouteDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.team, _this.team) || other.team == _this.team)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.distance, _this.distance) || other.distance == _this.distance)&&(identical(other.elevationGain, _this.elevationGain) || other.elevationGain == _this.elevationGain)&&(identical(other.elevationLoss, _this.elevationLoss) || other.elevationLoss == _this.elevationLoss)&&(identical(other.elevationState, _this.elevationState) || other.elevationState == _this.elevationState)&&(identical(other.surfaceType, _this.surfaceType) || other.surfaceType == _this.surfaceType)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.deleted, _this.deleted) || other.deleted == _this.deleted)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt)&&(identical(other.thumbnailUrl, _this.thumbnailUrl) || other.thumbnailUrl == _this.thumbnailUrl)&&(identical(other.commentCount, _this.commentCount) || other.commentCount == _this.commentCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteDto;
  return Object.hash(runtimeType,_this.id,_this.slug,_this.team,_this.name,_this.media,_this.distance,_this.elevationGain,_this.elevationLoss,_this.elevationState,_this.surfaceType,_this.visibility,_this.createdAt,_this.deleted,const DeepCollectionEquality().hash(_this.tags),_this.excerpt,_this.thumbnailUrl,_this.commentCount);
}

@override
String toString() {
  final _this = this as RouteDto;
  return 'RouteDto(id: ${_this.id}, slug: ${_this.slug}, team: ${_this.team}, name: ${_this.name}, media: ${_this.media}, distance: ${_this.distance}, elevationGain: ${_this.elevationGain}, elevationLoss: ${_this.elevationLoss}, elevationState: ${_this.elevationState}, surfaceType: ${_this.surfaceType}, visibility: ${_this.visibility}, createdAt: ${_this.createdAt}, deleted: ${_this.deleted}, tags: ${_this.tags}, excerpt: ${_this.excerpt}, thumbnailUrl: ${_this.thumbnailUrl}, commentCount: ${_this.commentCount})';
}


}

/// @nodoc
abstract mixin class $RouteDtoCopyWith<$Res>  {
  factory $RouteDtoCopyWith(RouteDto value, $Res Function(RouteDto) _then) = _$RouteDtoCopyWithImpl;
@useResult
$Res call({
 String id, String slug, TeamPublicationDto team, String name, MediaDto media, double distance, double elevationGain, double elevationLoss, String elevationState, String surfaceType, String visibility, String createdAt, bool deleted, List<TagDto> tags, String? excerpt, String? thumbnailUrl, int? commentCount
});


$TeamPublicationDtoCopyWith<$Res> get team;$MediaDtoCopyWith<$Res> get media;

}
/// @nodoc
class _$RouteDtoCopyWithImpl<$Res>
    implements $RouteDtoCopyWith<$Res> {
  _$RouteDtoCopyWithImpl(this._self, this._then);

  final RouteDto _self;
  final $Res Function(RouteDto) _then;

/// Create a copy of RouteDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? team = null,Object? name = null,Object? media = null,Object? distance = null,Object? elevationGain = null,Object? elevationLoss = null,Object? elevationState = null,Object? surfaceType = null,Object? visibility = null,Object? createdAt = null,Object? deleted = null,Object? tags = null,Object? excerpt = freezed,Object? thumbnailUrl = freezed,Object? commentCount = freezed,}) {
  return _then(RouteDto(
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
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of RouteDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of RouteDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouteDto].
extension RouteDtoPatterns on RouteDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteDto value)  $default,){
final _that = this;
switch (_that) {
case _RouteDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteDto value)?  $default,){
final _that = this;
switch (_that) {
case _RouteDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String slug,  TeamPublicationDto team,  String name,  MediaDto media,  double distance,  double elevationGain,  double elevationLoss,  String elevationState,  String surfaceType,  String visibility,  String createdAt,  bool deleted,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  int? commentCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteDto() when $default != null:
return $default(_that.id,_that.slug,_that.team,_that.name,_that.media,_that.distance,_that.elevationGain,_that.elevationLoss,_that.elevationState,_that.surfaceType,_that.visibility,_that.createdAt,_that.deleted,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.commentCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String slug,  TeamPublicationDto team,  String name,  MediaDto media,  double distance,  double elevationGain,  double elevationLoss,  String elevationState,  String surfaceType,  String visibility,  String createdAt,  bool deleted,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  int? commentCount)  $default,) {final _that = this;
switch (_that) {
case _RouteDto():
return $default(_that.id,_that.slug,_that.team,_that.name,_that.media,_that.distance,_that.elevationGain,_that.elevationLoss,_that.elevationState,_that.surfaceType,_that.visibility,_that.createdAt,_that.deleted,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.commentCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String slug,  TeamPublicationDto team,  String name,  MediaDto media,  double distance,  double elevationGain,  double elevationLoss,  String elevationState,  String surfaceType,  String visibility,  String createdAt,  bool deleted,  List<TagDto> tags,  String? excerpt,  String? thumbnailUrl,  int? commentCount)?  $default,) {final _that = this;
switch (_that) {
case _RouteDto() when $default != null:
return $default(_that.id,_that.slug,_that.team,_that.name,_that.media,_that.distance,_that.elevationGain,_that.elevationLoss,_that.elevationState,_that.surfaceType,_that.visibility,_that.createdAt,_that.deleted,_that.tags,_that.excerpt,_that.thumbnailUrl,_that.commentCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteDto implements RouteDto {
  const _RouteDto({required this.id, required this.slug, required this.team, required this.name, required this.media, required this.distance, required this.elevationGain, required this.elevationLoss, required this.elevationState, required this.surfaceType, required this.visibility, required this.createdAt, required this.deleted, required  List<TagDto> tags, this.excerpt, this.thumbnailUrl, this.commentCount}): _tags = tags;
  factory _RouteDto.fromJson(Map<String, dynamic> json) => _$RouteDtoFromJson(json);

/// Route ID (TSID)
@override final  String id;
/// Route slug
@override final  String slug;
/// Team
@override final  TeamPublicationDto team;
/// Route name
@override final  String name;
/// Route description
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
/// Creation timestamp
@override final  String createdAt;
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

/// Plain-text opening of the description, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the description holds no text. Lets a list row render its two lines without the description being sent at all — see the 'view' parameter.
@override final  String? excerpt;
/// URL template of the route's thumbnail, light variant if there is one, else dark. Saves a compact row from carrying media.assets just to find the map preview. Opaque URL: may carry a query string; substitute {size} only.
@override final  String? thumbnailUrl;
/// Number of comments, replies included. Absent when the caller may not read the comments of this route — comments are members-only, so an outsider is told nothing, not even zero.
@override final  int? commentCount;

/// Create a copy of RouteDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteDtoCopyWith<_RouteDto> get copyWith => __$RouteDtoCopyWithImpl<_RouteDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteDto&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.team, team) || other.team == team)&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.elevationGain, elevationGain) || other.elevationGain == elevationGain)&&(identical(other.elevationLoss, elevationLoss) || other.elevationLoss == elevationLoss)&&(identical(other.elevationState, elevationState) || other.elevationState == elevationState)&&(identical(other.surfaceType, surfaceType) || other.surfaceType == surfaceType)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,slug,team,name,media,distance,elevationGain,elevationLoss,elevationState,surfaceType,visibility,createdAt,deleted,const DeepCollectionEquality().hash(_tags),excerpt,thumbnailUrl,commentCount);
}

@override
String toString() {
    return 'RouteDto(id: $id, slug: $slug, team: $team, name: $name, media: $media, distance: $distance, elevationGain: $elevationGain, elevationLoss: $elevationLoss, elevationState: $elevationState, surfaceType: $surfaceType, visibility: $visibility, createdAt: $createdAt, deleted: $deleted, tags: $tags, excerpt: $excerpt, thumbnailUrl: $thumbnailUrl, commentCount: $commentCount)';
}


}

/// @nodoc
abstract mixin class _$RouteDtoCopyWith<$Res> implements $RouteDtoCopyWith<$Res> {
  factory _$RouteDtoCopyWith(_RouteDto value, $Res Function(_RouteDto) _then) = __$RouteDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String slug, TeamPublicationDto team, String name, MediaDto media, double distance, double elevationGain, double elevationLoss, String elevationState, String surfaceType, String visibility, String createdAt, bool deleted, List<TagDto> tags, String? excerpt, String? thumbnailUrl, int? commentCount
});


@override $TeamPublicationDtoCopyWith<$Res> get team;@override $MediaDtoCopyWith<$Res> get media;

}
/// @nodoc
class __$RouteDtoCopyWithImpl<$Res>
    implements _$RouteDtoCopyWith<$Res> {
  __$RouteDtoCopyWithImpl(this._self, this._then);

  final _RouteDto _self;
  final $Res Function(_RouteDto) _then;

/// Create a copy of RouteDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? team = null,Object? name = null,Object? media = null,Object? distance = null,Object? elevationGain = null,Object? elevationLoss = null,Object? elevationState = null,Object? surfaceType = null,Object? visibility = null,Object? createdAt = null,Object? deleted = null,Object? tags = null,Object? excerpt = freezed,Object? thumbnailUrl = freezed,Object? commentCount = freezed,}) {
  return _then(_RouteDto(
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
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagDto>,excerpt: freezed == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of RouteDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamPublicationDtoCopyWith<$Res> get team {
  
  return $TeamPublicationDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of RouteDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}

// dart format on
