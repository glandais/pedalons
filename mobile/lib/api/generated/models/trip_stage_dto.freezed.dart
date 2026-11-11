// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trip_stage_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TripStageDto {

/// Stage ID (TSID)
 String get id;/// Stage slug
 String get slug;/// Stage name
 String get name;/// Stage date/time
 String get dateTime;/// IANA zone the stage's time was entered in and is read in: its start place's, else its route's, else the previous stage's, else the trip route's, else the team's. A stage may differ from its trip.
 String get timezone;/// Stage media
 MediaDto get media;/// Sort order
 int get sortOrder;/// Position of this stage among the trip's live stages, 1-based — the 'Day 2' of a stage header. Unlike sortOrder, which is a persisted rank that may have gaps, this is a rank a client can print.
 int get stageIndex;/// How many live stages the trip has — the '/ 5' of 'Day 2 / 5'.
 int get stageCount;/// What the caller may do with the stage: comment on it, and edit or delete it — through its trip, which a stage is written with. No allowedVisibilities: a stage has its trip's visibility.
 ContentPermissionsDto get permissions;/// Average speed in km/h
 double? get averageSpeed;/// Route
 RouteDto? get route;/// Start place
 PlaceDetailDto? get startPlace;/// End place
 PlaceDetailDto? get endPlace;/// Number of comments on the stage's own thread. Absent when the caller cannot read comments (not a member of the team), like TripDto.commentCount.
 int? get commentCount;/// When the stage is expected to end: dateTime plus its route's length at its averageSpeed. Absent when it has no route or no averageSpeed — no default speed here. Known whatever the forecast window, unlike WeatherLegDto.arrivalTime.
 String? get estimatedArrival;/// Minutes from dateTime to estimatedArrival, rounded. Absent when estimatedArrival is.
 int? get estimatedDurationMinutes;
/// Create a copy of TripStageDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TripStageDtoCopyWith<TripStageDto> get copyWith => _$TripStageDtoCopyWithImpl<TripStageDto>(this as TripStageDto, _$identity);

  /// Serializes this TripStageDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TripStageDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TripStageDto&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.dateTime, _this.dateTime) || other.dateTime == _this.dateTime)&&(identical(other.timezone, _this.timezone) || other.timezone == _this.timezone)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.stageIndex, _this.stageIndex) || other.stageIndex == _this.stageIndex)&&(identical(other.stageCount, _this.stageCount) || other.stageCount == _this.stageCount)&&(identical(other.permissions, _this.permissions) || other.permissions == _this.permissions)&&(identical(other.averageSpeed, _this.averageSpeed) || other.averageSpeed == _this.averageSpeed)&&(identical(other.route, _this.route) || other.route == _this.route)&&(identical(other.startPlace, _this.startPlace) || other.startPlace == _this.startPlace)&&(identical(other.endPlace, _this.endPlace) || other.endPlace == _this.endPlace)&&(identical(other.commentCount, _this.commentCount) || other.commentCount == _this.commentCount)&&(identical(other.estimatedArrival, _this.estimatedArrival) || other.estimatedArrival == _this.estimatedArrival)&&(identical(other.estimatedDurationMinutes, _this.estimatedDurationMinutes) || other.estimatedDurationMinutes == _this.estimatedDurationMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TripStageDto;
  return Object.hash(runtimeType,_this.id,_this.slug,_this.name,_this.dateTime,_this.timezone,_this.media,_this.sortOrder,_this.stageIndex,_this.stageCount,_this.permissions,_this.averageSpeed,_this.route,_this.startPlace,_this.endPlace,_this.commentCount,_this.estimatedArrival,_this.estimatedDurationMinutes);
}

@override
String toString() {
  final _this = this as TripStageDto;
  return 'TripStageDto(id: ${_this.id}, slug: ${_this.slug}, name: ${_this.name}, dateTime: ${_this.dateTime}, timezone: ${_this.timezone}, media: ${_this.media}, sortOrder: ${_this.sortOrder}, stageIndex: ${_this.stageIndex}, stageCount: ${_this.stageCount}, permissions: ${_this.permissions}, averageSpeed: ${_this.averageSpeed}, route: ${_this.route}, startPlace: ${_this.startPlace}, endPlace: ${_this.endPlace}, commentCount: ${_this.commentCount}, estimatedArrival: ${_this.estimatedArrival}, estimatedDurationMinutes: ${_this.estimatedDurationMinutes})';
}


}

/// @nodoc
abstract mixin class $TripStageDtoCopyWith<$Res>  {
  factory $TripStageDtoCopyWith(TripStageDto value, $Res Function(TripStageDto) _then) = _$TripStageDtoCopyWithImpl;
@useResult
$Res call({
 String id, String slug, String name, String dateTime, String timezone, MediaDto media, int sortOrder, int stageIndex, int stageCount, ContentPermissionsDto permissions, double? averageSpeed, RouteDto? route, PlaceDetailDto? startPlace, PlaceDetailDto? endPlace, int? commentCount, String? estimatedArrival, int? estimatedDurationMinutes
});


$MediaDtoCopyWith<$Res> get media;$ContentPermissionsDtoCopyWith<$Res> get permissions;$RouteDtoCopyWith<$Res>? get route;$PlaceDetailDtoCopyWith<$Res>? get startPlace;$PlaceDetailDtoCopyWith<$Res>? get endPlace;

}
/// @nodoc
class _$TripStageDtoCopyWithImpl<$Res>
    implements $TripStageDtoCopyWith<$Res> {
  _$TripStageDtoCopyWithImpl(this._self, this._then);

  final TripStageDto _self;
  final $Res Function(TripStageDto) _then;

/// Create a copy of TripStageDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? dateTime = null,Object? timezone = null,Object? media = null,Object? sortOrder = null,Object? stageIndex = null,Object? stageCount = null,Object? permissions = null,Object? averageSpeed = freezed,Object? route = freezed,Object? startPlace = freezed,Object? endPlace = freezed,Object? commentCount = freezed,Object? estimatedArrival = freezed,Object? estimatedDurationMinutes = freezed,}) {
  return _then(TripStageDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,stageIndex: null == stageIndex ? _self.stageIndex : stageIndex // ignore: cast_nullable_to_non_nullable
as int,stageCount: null == stageCount ? _self.stageCount : stageCount // ignore: cast_nullable_to_non_nullable
as int,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as ContentPermissionsDto,averageSpeed: freezed == averageSpeed ? _self.averageSpeed : averageSpeed // ignore: cast_nullable_to_non_nullable
as double?,route: freezed == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as RouteDto?,startPlace: freezed == startPlace ? _self.startPlace : startPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,endPlace: freezed == endPlace ? _self.endPlace : endPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,estimatedArrival: freezed == estimatedArrival ? _self.estimatedArrival : estimatedArrival // ignore: cast_nullable_to_non_nullable
as String?,estimatedDurationMinutes: freezed == estimatedDurationMinutes ? _self.estimatedDurationMinutes : estimatedDurationMinutes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of TripStageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of TripStageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentPermissionsDtoCopyWith<$Res> get permissions {
  
  return $ContentPermissionsDtoCopyWith<$Res>(_self.permissions, (value) {
    return _then(_self.copyWith(permissions: value));
  });
}/// Create a copy of TripStageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RouteDtoCopyWith<$Res>? get route {
    if (_self.route == null) {
    return null;
  }

  return $RouteDtoCopyWith<$Res>(_self.route!, (value) {
    return _then(_self.copyWith(route: value));
  });
}/// Create a copy of TripStageDto
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
}/// Create a copy of TripStageDto
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


/// Adds pattern-matching-related methods to [TripStageDto].
extension TripStageDtoPatterns on TripStageDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TripStageDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TripStageDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TripStageDto value)  $default,){
final _that = this;
switch (_that) {
case _TripStageDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TripStageDto value)?  $default,){
final _that = this;
switch (_that) {
case _TripStageDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String slug,  String name,  String dateTime,  String timezone,  MediaDto media,  int sortOrder,  int stageIndex,  int stageCount,  ContentPermissionsDto permissions,  double? averageSpeed,  RouteDto? route,  PlaceDetailDto? startPlace,  PlaceDetailDto? endPlace,  int? commentCount,  String? estimatedArrival,  int? estimatedDurationMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TripStageDto() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.dateTime,_that.timezone,_that.media,_that.sortOrder,_that.stageIndex,_that.stageCount,_that.permissions,_that.averageSpeed,_that.route,_that.startPlace,_that.endPlace,_that.commentCount,_that.estimatedArrival,_that.estimatedDurationMinutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String slug,  String name,  String dateTime,  String timezone,  MediaDto media,  int sortOrder,  int stageIndex,  int stageCount,  ContentPermissionsDto permissions,  double? averageSpeed,  RouteDto? route,  PlaceDetailDto? startPlace,  PlaceDetailDto? endPlace,  int? commentCount,  String? estimatedArrival,  int? estimatedDurationMinutes)  $default,) {final _that = this;
switch (_that) {
case _TripStageDto():
return $default(_that.id,_that.slug,_that.name,_that.dateTime,_that.timezone,_that.media,_that.sortOrder,_that.stageIndex,_that.stageCount,_that.permissions,_that.averageSpeed,_that.route,_that.startPlace,_that.endPlace,_that.commentCount,_that.estimatedArrival,_that.estimatedDurationMinutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String slug,  String name,  String dateTime,  String timezone,  MediaDto media,  int sortOrder,  int stageIndex,  int stageCount,  ContentPermissionsDto permissions,  double? averageSpeed,  RouteDto? route,  PlaceDetailDto? startPlace,  PlaceDetailDto? endPlace,  int? commentCount,  String? estimatedArrival,  int? estimatedDurationMinutes)?  $default,) {final _that = this;
switch (_that) {
case _TripStageDto() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.dateTime,_that.timezone,_that.media,_that.sortOrder,_that.stageIndex,_that.stageCount,_that.permissions,_that.averageSpeed,_that.route,_that.startPlace,_that.endPlace,_that.commentCount,_that.estimatedArrival,_that.estimatedDurationMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TripStageDto implements TripStageDto {
  const _TripStageDto({required this.id, required this.slug, required this.name, required this.dateTime, required this.timezone, required this.media, required this.sortOrder, required this.stageIndex, required this.stageCount, required this.permissions, this.averageSpeed, this.route, this.startPlace, this.endPlace, this.commentCount, this.estimatedArrival, this.estimatedDurationMinutes});
  factory _TripStageDto.fromJson(Map<String, dynamic> json) => _$TripStageDtoFromJson(json);

/// Stage ID (TSID)
@override final  String id;
/// Stage slug
@override final  String slug;
/// Stage name
@override final  String name;
/// Stage date/time
@override final  String dateTime;
/// IANA zone the stage's time was entered in and is read in: its start place's, else its route's, else the previous stage's, else the trip route's, else the team's. A stage may differ from its trip.
@override final  String timezone;
/// Stage media
@override final  MediaDto media;
/// Sort order
@override final  int sortOrder;
/// Position of this stage among the trip's live stages, 1-based — the 'Day 2' of a stage header. Unlike sortOrder, which is a persisted rank that may have gaps, this is a rank a client can print.
@override final  int stageIndex;
/// How many live stages the trip has — the '/ 5' of 'Day 2 / 5'.
@override final  int stageCount;
/// What the caller may do with the stage: comment on it, and edit or delete it — through its trip, which a stage is written with. No allowedVisibilities: a stage has its trip's visibility.
@override final  ContentPermissionsDto permissions;
/// Average speed in km/h
@override final  double? averageSpeed;
/// Route
@override final  RouteDto? route;
/// Start place
@override final  PlaceDetailDto? startPlace;
/// End place
@override final  PlaceDetailDto? endPlace;
/// Number of comments on the stage's own thread. Absent when the caller cannot read comments (not a member of the team), like TripDto.commentCount.
@override final  int? commentCount;
/// When the stage is expected to end: dateTime plus its route's length at its averageSpeed. Absent when it has no route or no averageSpeed — no default speed here. Known whatever the forecast window, unlike WeatherLegDto.arrivalTime.
@override final  String? estimatedArrival;
/// Minutes from dateTime to estimatedArrival, rounded. Absent when estimatedArrival is.
@override final  int? estimatedDurationMinutes;

/// Create a copy of TripStageDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TripStageDtoCopyWith<_TripStageDto> get copyWith => __$TripStageDtoCopyWithImpl<_TripStageDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TripStageDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TripStageDto&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.dateTime, dateTime) || other.dateTime == dateTime)&&(identical(other.timezone, timezone) || other.timezone == timezone)&&(identical(other.media, media) || other.media == media)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.stageIndex, stageIndex) || other.stageIndex == stageIndex)&&(identical(other.stageCount, stageCount) || other.stageCount == stageCount)&&(identical(other.permissions, permissions) || other.permissions == permissions)&&(identical(other.averageSpeed, averageSpeed) || other.averageSpeed == averageSpeed)&&(identical(other.route, route) || other.route == route)&&(identical(other.startPlace, startPlace) || other.startPlace == startPlace)&&(identical(other.endPlace, endPlace) || other.endPlace == endPlace)&&(identical(other.commentCount, commentCount) || other.commentCount == commentCount)&&(identical(other.estimatedArrival, estimatedArrival) || other.estimatedArrival == estimatedArrival)&&(identical(other.estimatedDurationMinutes, estimatedDurationMinutes) || other.estimatedDurationMinutes == estimatedDurationMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,slug,name,dateTime,timezone,media,sortOrder,stageIndex,stageCount,permissions,averageSpeed,route,startPlace,endPlace,commentCount,estimatedArrival,estimatedDurationMinutes);
}

@override
String toString() {
    return 'TripStageDto(id: $id, slug: $slug, name: $name, dateTime: $dateTime, timezone: $timezone, media: $media, sortOrder: $sortOrder, stageIndex: $stageIndex, stageCount: $stageCount, permissions: $permissions, averageSpeed: $averageSpeed, route: $route, startPlace: $startPlace, endPlace: $endPlace, commentCount: $commentCount, estimatedArrival: $estimatedArrival, estimatedDurationMinutes: $estimatedDurationMinutes)';
}


}

/// @nodoc
abstract mixin class _$TripStageDtoCopyWith<$Res> implements $TripStageDtoCopyWith<$Res> {
  factory _$TripStageDtoCopyWith(_TripStageDto value, $Res Function(_TripStageDto) _then) = __$TripStageDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String slug, String name, String dateTime, String timezone, MediaDto media, int sortOrder, int stageIndex, int stageCount, ContentPermissionsDto permissions, double? averageSpeed, RouteDto? route, PlaceDetailDto? startPlace, PlaceDetailDto? endPlace, int? commentCount, String? estimatedArrival, int? estimatedDurationMinutes
});


@override $MediaDtoCopyWith<$Res> get media;@override $ContentPermissionsDtoCopyWith<$Res> get permissions;@override $RouteDtoCopyWith<$Res>? get route;@override $PlaceDetailDtoCopyWith<$Res>? get startPlace;@override $PlaceDetailDtoCopyWith<$Res>? get endPlace;

}
/// @nodoc
class __$TripStageDtoCopyWithImpl<$Res>
    implements _$TripStageDtoCopyWith<$Res> {
  __$TripStageDtoCopyWithImpl(this._self, this._then);

  final _TripStageDto _self;
  final $Res Function(_TripStageDto) _then;

/// Create a copy of TripStageDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? dateTime = null,Object? timezone = null,Object? media = null,Object? sortOrder = null,Object? stageIndex = null,Object? stageCount = null,Object? permissions = null,Object? averageSpeed = freezed,Object? route = freezed,Object? startPlace = freezed,Object? endPlace = freezed,Object? commentCount = freezed,Object? estimatedArrival = freezed,Object? estimatedDurationMinutes = freezed,}) {
  return _then(_TripStageDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,dateTime: null == dateTime ? _self.dateTime : dateTime // ignore: cast_nullable_to_non_nullable
as String,timezone: null == timezone ? _self.timezone : timezone // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,stageIndex: null == stageIndex ? _self.stageIndex : stageIndex // ignore: cast_nullable_to_non_nullable
as int,stageCount: null == stageCount ? _self.stageCount : stageCount // ignore: cast_nullable_to_non_nullable
as int,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as ContentPermissionsDto,averageSpeed: freezed == averageSpeed ? _self.averageSpeed : averageSpeed // ignore: cast_nullable_to_non_nullable
as double?,route: freezed == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as RouteDto?,startPlace: freezed == startPlace ? _self.startPlace : startPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,endPlace: freezed == endPlace ? _self.endPlace : endPlace // ignore: cast_nullable_to_non_nullable
as PlaceDetailDto?,commentCount: freezed == commentCount ? _self.commentCount : commentCount // ignore: cast_nullable_to_non_nullable
as int?,estimatedArrival: freezed == estimatedArrival ? _self.estimatedArrival : estimatedArrival // ignore: cast_nullable_to_non_nullable
as String?,estimatedDurationMinutes: freezed == estimatedDurationMinutes ? _self.estimatedDurationMinutes : estimatedDurationMinutes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of TripStageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of TripStageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContentPermissionsDtoCopyWith<$Res> get permissions {
  
  return $ContentPermissionsDtoCopyWith<$Res>(_self.permissions, (value) {
    return _then(_self.copyWith(permissions: value));
  });
}/// Create a copy of TripStageDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RouteDtoCopyWith<$Res>? get route {
    if (_self.route == null) {
    return null;
  }

  return $RouteDtoCopyWith<$Res>(_self.route!, (value) {
    return _then(_self.copyWith(route: value));
  });
}/// Create a copy of TripStageDto
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
}/// Create a copy of TripStageDto
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
