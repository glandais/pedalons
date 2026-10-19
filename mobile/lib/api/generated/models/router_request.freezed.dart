// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'router_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouterRequest {

 GeoPoint get from; GeoPoint get to; RouterProfile get profile;/// Slug of the team the route is being drawn for. When present, the team must have the route planner enabled and the caller must be allowed to create routes in it. When absent, the domain's GPX planner must be enabled.
 String? get teamSlug;/// Propensity to climb, 0 (avoid hills) to 1 (no fear). Absent: the profile's value. Bicycle profiles only; ignored otherwise.
 double? get useHills;/// Propensity to ride with traffic, 0 (cycleways and paths) to 1 (roads). Absent: the profile's value (1 for FASTBIKE). Bicycle profiles only; ignored otherwise.
 double? get useRoads;
/// Create a copy of RouterRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouterRequestCopyWith<RouterRequest> get copyWith => _$RouterRequestCopyWithImpl<RouterRequest>(this as RouterRequest, _$identity);

  /// Serializes this RouterRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouterRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouterRequest&&(identical(other.from, _this.from) || other.from == _this.from)&&(identical(other.to, _this.to) || other.to == _this.to)&&(identical(other.profile, _this.profile) || other.profile == _this.profile)&&(identical(other.teamSlug, _this.teamSlug) || other.teamSlug == _this.teamSlug)&&(identical(other.useHills, _this.useHills) || other.useHills == _this.useHills)&&(identical(other.useRoads, _this.useRoads) || other.useRoads == _this.useRoads));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouterRequest;
  return Object.hash(runtimeType,_this.from,_this.to,_this.profile,_this.teamSlug,_this.useHills,_this.useRoads);
}

@override
String toString() {
  final _this = this as RouterRequest;
  return 'RouterRequest(from: ${_this.from}, to: ${_this.to}, profile: ${_this.profile}, teamSlug: ${_this.teamSlug}, useHills: ${_this.useHills}, useRoads: ${_this.useRoads})';
}


}

/// @nodoc
abstract mixin class $RouterRequestCopyWith<$Res>  {
  factory $RouterRequestCopyWith(RouterRequest value, $Res Function(RouterRequest) _then) = _$RouterRequestCopyWithImpl;
@useResult
$Res call({
 GeoPoint from, GeoPoint to, RouterProfile profile, String? teamSlug, double? useHills, double? useRoads
});


$GeoPointCopyWith<$Res> get from;$GeoPointCopyWith<$Res> get to;

}
/// @nodoc
class _$RouterRequestCopyWithImpl<$Res>
    implements $RouterRequestCopyWith<$Res> {
  _$RouterRequestCopyWithImpl(this._self, this._then);

  final RouterRequest _self;
  final $Res Function(RouterRequest) _then;

/// Create a copy of RouterRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? from = null,Object? to = null,Object? profile = null,Object? teamSlug = freezed,Object? useHills = freezed,Object? useRoads = freezed,}) {
  return _then(RouterRequest(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as GeoPoint,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as GeoPoint,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as RouterProfile,teamSlug: freezed == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String?,useHills: freezed == useHills ? _self.useHills : useHills // ignore: cast_nullable_to_non_nullable
as double?,useRoads: freezed == useRoads ? _self.useRoads : useRoads // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}
/// Create a copy of RouterRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get from {
  
  return $GeoPointCopyWith<$Res>(_self.from, (value) {
    return _then(_self.copyWith(from: value));
  });
}/// Create a copy of RouterRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get to {
  
  return $GeoPointCopyWith<$Res>(_self.to, (value) {
    return _then(_self.copyWith(to: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouterRequest].
extension RouterRequestPatterns on RouterRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouterRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouterRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouterRequest value)  $default,){
final _that = this;
switch (_that) {
case _RouterRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouterRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RouterRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GeoPoint from,  GeoPoint to,  RouterProfile profile,  String? teamSlug,  double? useHills,  double? useRoads)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouterRequest() when $default != null:
return $default(_that.from,_that.to,_that.profile,_that.teamSlug,_that.useHills,_that.useRoads);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GeoPoint from,  GeoPoint to,  RouterProfile profile,  String? teamSlug,  double? useHills,  double? useRoads)  $default,) {final _that = this;
switch (_that) {
case _RouterRequest():
return $default(_that.from,_that.to,_that.profile,_that.teamSlug,_that.useHills,_that.useRoads);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GeoPoint from,  GeoPoint to,  RouterProfile profile,  String? teamSlug,  double? useHills,  double? useRoads)?  $default,) {final _that = this;
switch (_that) {
case _RouterRequest() when $default != null:
return $default(_that.from,_that.to,_that.profile,_that.teamSlug,_that.useHills,_that.useRoads);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouterRequest implements RouterRequest {
  const _RouterRequest({required this.from, required this.to, required this.profile, this.teamSlug, this.useHills, this.useRoads});
  factory _RouterRequest.fromJson(Map<String, dynamic> json) => _$RouterRequestFromJson(json);

@override final  GeoPoint from;
@override final  GeoPoint to;
@override final  RouterProfile profile;
/// Slug of the team the route is being drawn for. When present, the team must have the route planner enabled and the caller must be allowed to create routes in it. When absent, the domain's GPX planner must be enabled.
@override final  String? teamSlug;
/// Propensity to climb, 0 (avoid hills) to 1 (no fear). Absent: the profile's value. Bicycle profiles only; ignored otherwise.
@override final  double? useHills;
/// Propensity to ride with traffic, 0 (cycleways and paths) to 1 (roads). Absent: the profile's value (1 for FASTBIKE). Bicycle profiles only; ignored otherwise.
@override final  double? useRoads;

/// Create a copy of RouterRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouterRequestCopyWith<_RouterRequest> get copyWith => __$RouterRequestCopyWithImpl<_RouterRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouterRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouterRequest&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.teamSlug, teamSlug) || other.teamSlug == teamSlug)&&(identical(other.useHills, useHills) || other.useHills == useHills)&&(identical(other.useRoads, useRoads) || other.useRoads == useRoads));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,from,to,profile,teamSlug,useHills,useRoads);
}

@override
String toString() {
    return 'RouterRequest(from: $from, to: $to, profile: $profile, teamSlug: $teamSlug, useHills: $useHills, useRoads: $useRoads)';
}


}

/// @nodoc
abstract mixin class _$RouterRequestCopyWith<$Res> implements $RouterRequestCopyWith<$Res> {
  factory _$RouterRequestCopyWith(_RouterRequest value, $Res Function(_RouterRequest) _then) = __$RouterRequestCopyWithImpl;
@override @useResult
$Res call({
 GeoPoint from, GeoPoint to, RouterProfile profile, String? teamSlug, double? useHills, double? useRoads
});


@override $GeoPointCopyWith<$Res> get from;@override $GeoPointCopyWith<$Res> get to;

}
/// @nodoc
class __$RouterRequestCopyWithImpl<$Res>
    implements _$RouterRequestCopyWith<$Res> {
  __$RouterRequestCopyWithImpl(this._self, this._then);

  final _RouterRequest _self;
  final $Res Function(_RouterRequest) _then;

/// Create a copy of RouterRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? from = null,Object? to = null,Object? profile = null,Object? teamSlug = freezed,Object? useHills = freezed,Object? useRoads = freezed,}) {
  return _then(_RouterRequest(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as GeoPoint,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as GeoPoint,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as RouterProfile,teamSlug: freezed == teamSlug ? _self.teamSlug : teamSlug // ignore: cast_nullable_to_non_nullable
as String?,useHills: freezed == useHills ? _self.useHills : useHills // ignore: cast_nullable_to_non_nullable
as double?,useRoads: freezed == useRoads ? _self.useRoads : useRoads // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of RouterRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get from {
  
  return $GeoPointCopyWith<$Res>(_self.from, (value) {
    return _then(_self.copyWith(from: value));
  });
}/// Create a copy of RouterRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get to {
  
  return $GeoPointCopyWith<$Res>(_self.to, (value) {
    return _then(_self.copyWith(to: value));
  });
}
}

// dart format on
