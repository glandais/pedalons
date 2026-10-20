// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gpx_preview_update_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GpxPreviewUpdateRequest {

/// Preview name
 String get name;/// Points from frontend routing
 List<GeoPoint>? get points;/// Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it
 PlannerState? get plannerState;/// The complete list of the waypoints, replacing them. Omitted: they stay as they are (placed again when the track changes)
 List<WaypointRequest>? get waypoints;
/// Create a copy of GpxPreviewUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GpxPreviewUpdateRequestCopyWith<GpxPreviewUpdateRequest> get copyWith => _$GpxPreviewUpdateRequestCopyWithImpl<GpxPreviewUpdateRequest>(this as GpxPreviewUpdateRequest, _$identity);

  /// Serializes this GpxPreviewUpdateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GpxPreviewUpdateRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GpxPreviewUpdateRequest&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.points, _this.points)&&(identical(other.plannerState, _this.plannerState) || other.plannerState == _this.plannerState)&&const DeepCollectionEquality().equals(other.waypoints, _this.waypoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GpxPreviewUpdateRequest;
  return Object.hash(runtimeType,_this.name,const DeepCollectionEquality().hash(_this.points),_this.plannerState,const DeepCollectionEquality().hash(_this.waypoints));
}

@override
String toString() {
  final _this = this as GpxPreviewUpdateRequest;
  return 'GpxPreviewUpdateRequest(name: ${_this.name}, points: ${_this.points}, plannerState: ${_this.plannerState}, waypoints: ${_this.waypoints})';
}


}

/// @nodoc
abstract mixin class $GpxPreviewUpdateRequestCopyWith<$Res>  {
  factory $GpxPreviewUpdateRequestCopyWith(GpxPreviewUpdateRequest value, $Res Function(GpxPreviewUpdateRequest) _then) = _$GpxPreviewUpdateRequestCopyWithImpl;
@useResult
$Res call({
 String name, List<GeoPoint>? points, PlannerState? plannerState, List<WaypointRequest>? waypoints
});


$PlannerStateCopyWith<$Res>? get plannerState;

}
/// @nodoc
class _$GpxPreviewUpdateRequestCopyWithImpl<$Res>
    implements $GpxPreviewUpdateRequestCopyWith<$Res> {
  _$GpxPreviewUpdateRequestCopyWithImpl(this._self, this._then);

  final GpxPreviewUpdateRequest _self;
  final $Res Function(GpxPreviewUpdateRequest) _then;

/// Create a copy of GpxPreviewUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? points = freezed,Object? plannerState = freezed,Object? waypoints = freezed,}) {
  return _then(GpxPreviewUpdateRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,points: freezed == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as List<GeoPoint>?,plannerState: freezed == plannerState ? _self.plannerState : plannerState // ignore: cast_nullable_to_non_nullable
as PlannerState?,waypoints: freezed == waypoints ? _self.waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<WaypointRequest>?,
  ));
}
/// Create a copy of GpxPreviewUpdateRequest
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


/// Adds pattern-matching-related methods to [GpxPreviewUpdateRequest].
extension GpxPreviewUpdateRequestPatterns on GpxPreviewUpdateRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GpxPreviewUpdateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GpxPreviewUpdateRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GpxPreviewUpdateRequest value)  $default,){
final _that = this;
switch (_that) {
case _GpxPreviewUpdateRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GpxPreviewUpdateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _GpxPreviewUpdateRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  List<GeoPoint>? points,  PlannerState? plannerState,  List<WaypointRequest>? waypoints)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GpxPreviewUpdateRequest() when $default != null:
return $default(_that.name,_that.points,_that.plannerState,_that.waypoints);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  List<GeoPoint>? points,  PlannerState? plannerState,  List<WaypointRequest>? waypoints)  $default,) {final _that = this;
switch (_that) {
case _GpxPreviewUpdateRequest():
return $default(_that.name,_that.points,_that.plannerState,_that.waypoints);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  List<GeoPoint>? points,  PlannerState? plannerState,  List<WaypointRequest>? waypoints)?  $default,) {final _that = this;
switch (_that) {
case _GpxPreviewUpdateRequest() when $default != null:
return $default(_that.name,_that.points,_that.plannerState,_that.waypoints);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GpxPreviewUpdateRequest implements GpxPreviewUpdateRequest {
  const _GpxPreviewUpdateRequest({required this.name,  List<GeoPoint>? points, this.plannerState,  List<WaypointRequest>? waypoints}): _points = points,_waypoints = waypoints;
  factory _GpxPreviewUpdateRequest.fromJson(Map<String, dynamic> json) => _$GpxPreviewUpdateRequestFromJson(json);

/// Preview name
@override final  String name;
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

/// Editing state of the planner; the server derives the track from it. Not with points (400 PLANNER_STATE_INVALID); a gpxFile wins over it
@override final  PlannerState? plannerState;
/// The complete list of the waypoints, replacing them. Omitted: they stay as they are (placed again when the track changes)
 final  List<WaypointRequest>? _waypoints;
/// The complete list of the waypoints, replacing them. Omitted: they stay as they are (placed again when the track changes)
@override List<WaypointRequest>? get waypoints {
  final value = _waypoints;
  if (value == null) return null;
  if (_waypoints is EqualUnmodifiableListView) return _waypoints;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of GpxPreviewUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GpxPreviewUpdateRequestCopyWith<_GpxPreviewUpdateRequest> get copyWith => __$GpxPreviewUpdateRequestCopyWithImpl<_GpxPreviewUpdateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GpxPreviewUpdateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GpxPreviewUpdateRequest&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.points, _points)&&(identical(other.plannerState, plannerState) || other.plannerState == plannerState)&&const DeepCollectionEquality().equals(other.waypoints, _waypoints));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,const DeepCollectionEquality().hash(_points),plannerState,const DeepCollectionEquality().hash(_waypoints));
}

@override
String toString() {
    return 'GpxPreviewUpdateRequest(name: $name, points: $points, plannerState: $plannerState, waypoints: $waypoints)';
}


}

/// @nodoc
abstract mixin class _$GpxPreviewUpdateRequestCopyWith<$Res> implements $GpxPreviewUpdateRequestCopyWith<$Res> {
  factory _$GpxPreviewUpdateRequestCopyWith(_GpxPreviewUpdateRequest value, $Res Function(_GpxPreviewUpdateRequest) _then) = __$GpxPreviewUpdateRequestCopyWithImpl;
@override @useResult
$Res call({
 String name, List<GeoPoint>? points, PlannerState? plannerState, List<WaypointRequest>? waypoints
});


@override $PlannerStateCopyWith<$Res>? get plannerState;

}
/// @nodoc
class __$GpxPreviewUpdateRequestCopyWithImpl<$Res>
    implements _$GpxPreviewUpdateRequestCopyWith<$Res> {
  __$GpxPreviewUpdateRequestCopyWithImpl(this._self, this._then);

  final _GpxPreviewUpdateRequest _self;
  final $Res Function(_GpxPreviewUpdateRequest) _then;

/// Create a copy of GpxPreviewUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? points = freezed,Object? plannerState = freezed,Object? waypoints = freezed,}) {
  return _then(_GpxPreviewUpdateRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,points: freezed == points ? _self._points : points // ignore: cast_nullable_to_non_nullable
as List<GeoPoint>?,plannerState: freezed == plannerState ? _self.plannerState : plannerState // ignore: cast_nullable_to_non_nullable
as PlannerState?,waypoints: freezed == waypoints ? _self._waypoints : waypoints // ignore: cast_nullable_to_non_nullable
as List<WaypointRequest>?,
  ));
}

/// Create a copy of GpxPreviewUpdateRequest
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
