// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteRequest {

/// Route name
 String get name;/// Media
 MediaDto get media;/// Surface type
 String get surfaceType;/// Whether the route is publicly visible
 String get visibility;/// Points from frontend routing
 List<GeoPoint>? get points;/// IDs (TSID) of the team's ROUTE tags the route carries, replacing the whole set — at most 10, each a tag of this team and of kind ROUTE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
 List<String>? get tagIds;/// Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it
 PlannerState? get plannerState;/// The complete list of the route's waypoints, replacing them. Omitted: they stay as they are (placed again on the new track when the track changes, and a new GPX file replaces the imported ones and keeps the author's). When present it wins over the waypoints of a GPX file sent with it
 List<WaypointRequest>? get waypoints;
/// Create a copy of RouteRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteRequestCopyWith<RouteRequest> get copyWith => _$RouteRequestCopyWithImpl<RouteRequest>(this as RouteRequest, _$identity);

  /// Serializes this RouteRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteRequest&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.surfaceType, _this.surfaceType) || other.surfaceType == _this.surfaceType)&&(identical(other.visibility, _this.visibility) || other.visibility == _this.visibility)&&const DeepCollectionEquality().equals(other.points, _this.points)&&const DeepCollectionEquality().equals(other.tagIds, _this.tagIds)&&(identical(other.plannerState, _this.plannerState) || other.plannerState == _this.plannerState)&&const DeepCollectionEquality().equals(other.waypoints, _this.waypoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteRequest;
  return Object.hash(runtimeType,_this.name,_this.media,_this.surfaceType,_this.visibility,const DeepCollectionEquality().hash(_this.points),const DeepCollectionEquality().hash(_this.tagIds),_this.plannerState,const DeepCollectionEquality().hash(_this.waypoints));
}

@override
String toString() {
  final _this = this as RouteRequest;
  return 'RouteRequest(name: ${_this.name}, media: ${_this.media}, surfaceType: ${_this.surfaceType}, visibility: ${_this.visibility}, points: ${_this.points}, tagIds: ${_this.tagIds}, plannerState: ${_this.plannerState}, waypoints: ${_this.waypoints})';
}


}

/// @nodoc
abstract mixin class $RouteRequestCopyWith<$Res>  {
  factory $RouteRequestCopyWith(RouteRequest value, $Res Function(RouteRequest) _then) = _$RouteRequestCopyWithImpl;
@useResult
$Res call({
 String name, MediaDto media, String surfaceType, String visibility, List<GeoPoint>? points, List<String>? tagIds, PlannerState? plannerState, List<WaypointRequest>? waypoints
});


$MediaDtoCopyWith<$Res> get media;$PlannerStateCopyWith<$Res>? get plannerState;

}
/// @nodoc
class _$RouteRequestCopyWithImpl<$Res>
    implements $RouteRequestCopyWith<$Res> {
  _$RouteRequestCopyWithImpl(this._self, this._then);

  final RouteRequest _self;
  final $Res Function(RouteRequest) _then;

/// Create a copy of RouteRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? media = null,Object? surfaceType = null,Object? visibility = null,Object? points = freezed,Object? tagIds = freezed,Object? plannerState = freezed,Object? waypoints = freezed,}) {
  return _then(RouteRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,surfaceType: null == surfaceType ? _self.surfaceType : surfaceType // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,points: freezed == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as List<GeoPoint>?,tagIds: freezed == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>?,plannerState: freezed == plannerState ? _self.plannerState : plannerState // ignore: cast_nullable_to_non_nullable
as PlannerState?,waypoints: freezed == waypoints ? _self.waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<WaypointRequest>?,
  ));
}
/// Create a copy of RouteRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of RouteRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlannerStateCopyWith<$Res>? get plannerState {
    if (_self.plannerState == null) {
    return null;
  }

  return $PlannerStateCopyWith<$Res>(_self.plannerState!, (value) {
    return _then(_self.copyWith(plannerState: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouteRequest].
extension RouteRequestPatterns on RouteRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteRequest value)  $default,){
final _that = this;
switch (_that) {
case _RouteRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RouteRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  MediaDto media,  String surfaceType,  String visibility,  List<GeoPoint>? points,  List<String>? tagIds,  PlannerState? plannerState,  List<WaypointRequest>? waypoints)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteRequest() when $default != null:
return $default(_that.name,_that.media,_that.surfaceType,_that.visibility,_that.points,_that.tagIds,_that.plannerState,_that.waypoints);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  MediaDto media,  String surfaceType,  String visibility,  List<GeoPoint>? points,  List<String>? tagIds,  PlannerState? plannerState,  List<WaypointRequest>? waypoints)  $default,) {final _that = this;
switch (_that) {
case _RouteRequest():
return $default(_that.name,_that.media,_that.surfaceType,_that.visibility,_that.points,_that.tagIds,_that.plannerState,_that.waypoints);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  MediaDto media,  String surfaceType,  String visibility,  List<GeoPoint>? points,  List<String>? tagIds,  PlannerState? plannerState,  List<WaypointRequest>? waypoints)?  $default,) {final _that = this;
switch (_that) {
case _RouteRequest() when $default != null:
return $default(_that.name,_that.media,_that.surfaceType,_that.visibility,_that.points,_that.tagIds,_that.plannerState,_that.waypoints);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteRequest implements RouteRequest {
  const _RouteRequest({required this.name, required this.media, required this.surfaceType, required this.visibility,  List<GeoPoint>? points,  List<String>? tagIds, this.plannerState,  List<WaypointRequest>? waypoints}): _points = points,_tagIds = tagIds,_waypoints = waypoints;
  factory _RouteRequest.fromJson(Map<String, dynamic> json) => _$RouteRequestFromJson(json);

/// Route name
@override final  String name;
/// Media
@override final  MediaDto media;
/// Surface type
@override final  String surfaceType;
/// Whether the route is publicly visible
@override final  String visibility;
/// Points from frontend routing
 final  List<GeoPoint>? _points;
/// Points from frontend routing
@override List<GeoPoint>? get points {
  final value = _points;
  if (value == null) return null;
  if (_points is EqualUnmodifiableListView) return _points;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// IDs (TSID) of the team's ROUTE tags the route carries, replacing the whole set — at most 10, each a tag of this team and of kind ROUTE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
 final  List<String>? _tagIds;
/// IDs (TSID) of the team's ROUTE tags the route carries, replacing the whole set — at most 10, each a tag of this team and of kind ROUTE, else 400 (TAG_INVALID, TOO_MANY_TAGS). An empty list removes them all. Omitted: none on a creation, left as they are on an update.
@override List<String>? get tagIds {
  final value = _tagIds;
  if (value == null) return null;
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it
@override final  PlannerState? plannerState;
/// The complete list of the route's waypoints, replacing them. Omitted: they stay as they are (placed again on the new track when the track changes, and a new GPX file replaces the imported ones and keeps the author's). When present it wins over the waypoints of a GPX file sent with it
 final  List<WaypointRequest>? _waypoints;
/// The complete list of the route's waypoints, replacing them. Omitted: they stay as they are (placed again on the new track when the track changes, and a new GPX file replaces the imported ones and keeps the author's). When present it wins over the waypoints of a GPX file sent with it
@override List<WaypointRequest>? get waypoints {
  final value = _waypoints;
  if (value == null) return null;
  if (_waypoints is EqualUnmodifiableListView) return _waypoints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of RouteRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteRequestCopyWith<_RouteRequest> get copyWith => __$RouteRequestCopyWithImpl<_RouteRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteRequest&&(identical(other.name, name) || other.name == name)&&(identical(other.media, media) || other.media == media)&&(identical(other.surfaceType, surfaceType) || other.surfaceType == surfaceType)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&const DeepCollectionEquality().equals(other.points, _points)&&const DeepCollectionEquality().equals(other.tagIds, _tagIds)&&(identical(other.plannerState, plannerState) || other.plannerState == plannerState)&&const DeepCollectionEquality().equals(other.waypoints, _waypoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,media,surfaceType,visibility,const DeepCollectionEquality().hash(_points),const DeepCollectionEquality().hash(_tagIds),plannerState,const DeepCollectionEquality().hash(_waypoints));
}

@override
String toString() {
    return 'RouteRequest(name: $name, media: $media, surfaceType: $surfaceType, visibility: $visibility, points: $points, tagIds: $tagIds, plannerState: $plannerState, waypoints: $waypoints)';
}


}

/// @nodoc
abstract mixin class _$RouteRequestCopyWith<$Res> implements $RouteRequestCopyWith<$Res> {
  factory _$RouteRequestCopyWith(_RouteRequest value, $Res Function(_RouteRequest) _then) = __$RouteRequestCopyWithImpl;
@override @useResult
$Res call({
 String name, MediaDto media, String surfaceType, String visibility, List<GeoPoint>? points, List<String>? tagIds, PlannerState? plannerState, List<WaypointRequest>? waypoints
});


@override $MediaDtoCopyWith<$Res> get media;@override $PlannerStateCopyWith<$Res>? get plannerState;

}
/// @nodoc
class __$RouteRequestCopyWithImpl<$Res>
    implements _$RouteRequestCopyWith<$Res> {
  __$RouteRequestCopyWithImpl(this._self, this._then);

  final _RouteRequest _self;
  final $Res Function(_RouteRequest) _then;

/// Create a copy of RouteRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? media = null,Object? surfaceType = null,Object? visibility = null,Object? points = freezed,Object? tagIds = freezed,Object? plannerState = freezed,Object? waypoints = freezed,}) {
  return _then(_RouteRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as MediaDto,surfaceType: null == surfaceType ? _self.surfaceType : surfaceType // ignore: cast_nullable_to_non_nullable
as String,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,points: freezed == points ? _self._points : points // ignore: cast_nullable_to_non_nullable
as List<GeoPoint>?,tagIds: freezed == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>?,plannerState: freezed == plannerState ? _self.plannerState : plannerState // ignore: cast_nullable_to_non_nullable
as PlannerState?,waypoints: freezed == waypoints ? _self._waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<WaypointRequest>?,
  ));
}

/// Create a copy of RouteRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaDtoCopyWith<$Res> get media {
  
  return $MediaDtoCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}/// Create a copy of RouteRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlannerStateCopyWith<$Res>? get plannerState {
    if (_self.plannerState == null) {
    return null;
  }

  return $PlannerStateCopyWith<$Res>(_self.plannerState!, (value) {
    return _then(_self.copyWith(plannerState: value));
  });
}
}

// dart format on
