// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_generator_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteGeneratorRequest {

/// Wished distance in kilometres, 10 to 200
 double get distanceKm;/// Start. Absent: the team's location (400 VALIDATION if it has none)
 GeoPoint? get start;/// End. Absent: a loop, the route ends where it starts. Present: a one-way route from start to end
 GeoPoint? get end;/// Wished direction, only used when the end is closer than half the distance (a loop included)
 String? get bearing;/// From the team's roads (0, only the roads the team rides) to discovery (1, no preference for them); rounded to the hundredth by the engine. Absent: 0.25
 double? get discovery;/// What to ride. Absent: ROAD
 String? get type;/// Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0
 int? get seed;
/// Create a copy of RouteGeneratorRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteGeneratorRequestCopyWith<RouteGeneratorRequest> get copyWith => _$RouteGeneratorRequestCopyWithImpl<RouteGeneratorRequest>(this as RouteGeneratorRequest, _$identity);

  /// Serializes this RouteGeneratorRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteGeneratorRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteGeneratorRequest&&(identical(other.distanceKm, _this.distanceKm) || other.distanceKm == _this.distanceKm)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end)&&(identical(other.bearing, _this.bearing) || other.bearing == _this.bearing)&&(identical(other.discovery, _this.discovery) || other.discovery == _this.discovery)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.seed, _this.seed) || other.seed == _this.seed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteGeneratorRequest;
  return Object.hash(runtimeType,_this.distanceKm,_this.start,_this.end,_this.bearing,_this.discovery,_this.type,_this.seed);
}

@override
String toString() {
  final _this = this as RouteGeneratorRequest;
  return 'RouteGeneratorRequest(distanceKm: ${_this.distanceKm}, start: ${_this.start}, end: ${_this.end}, bearing: ${_this.bearing}, discovery: ${_this.discovery}, type: ${_this.type}, seed: ${_this.seed})';
}


}

/// @nodoc
abstract mixin class $RouteGeneratorRequestCopyWith<$Res>  {
  factory $RouteGeneratorRequestCopyWith(RouteGeneratorRequest value, $Res Function(RouteGeneratorRequest) _then) = _$RouteGeneratorRequestCopyWithImpl;
@useResult
$Res call({
 double distanceKm, GeoPoint? start, GeoPoint? end, String? bearing, double? discovery, String? type, int? seed
});


$GeoPointCopyWith<$Res>? get start;$GeoPointCopyWith<$Res>? get end;

}
/// @nodoc
class _$RouteGeneratorRequestCopyWithImpl<$Res>
    implements $RouteGeneratorRequestCopyWith<$Res> {
  _$RouteGeneratorRequestCopyWithImpl(this._self, this._then);

  final RouteGeneratorRequest _self;
  final $Res Function(RouteGeneratorRequest) _then;

/// Create a copy of RouteGeneratorRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? distanceKm = null,Object? start = freezed,Object? end = freezed,Object? bearing = freezed,Object? discovery = freezed,Object? type = freezed,Object? seed = freezed,}) {
  return _then(RouteGeneratorRequest(
distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as GeoPoint?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as GeoPoint?,bearing: freezed == bearing ? _self.bearing : bearing // ignore: cast_nullable_to_non_nullable
as String?,discovery: freezed == discovery ? _self.discovery : discovery // ignore: cast_nullable_to_non_nullable
as double?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of RouteGeneratorRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res>? get start {
    if (_self.start == null) {
    return null;
  }

  return $GeoPointCopyWith<$Res>(_self.start!, (value) {
    return _then(_self.copyWith(start: value));
  });
}/// Create a copy of RouteGeneratorRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res>? get end {
    if (_self.end == null) {
    return null;
  }

  return $GeoPointCopyWith<$Res>(_self.end!, (value) {
    return _then(_self.copyWith(end: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouteGeneratorRequest].
extension RouteGeneratorRequestPatterns on RouteGeneratorRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteGeneratorRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteGeneratorRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteGeneratorRequest value)  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteGeneratorRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RouteGeneratorRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double distanceKm,  GeoPoint? start,  GeoPoint? end,  String? bearing,  double? discovery,  String? type,  int? seed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteGeneratorRequest() when $default != null:
return $default(_that.distanceKm,_that.start,_that.end,_that.bearing,_that.discovery,_that.type,_that.seed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double distanceKm,  GeoPoint? start,  GeoPoint? end,  String? bearing,  double? discovery,  String? type,  int? seed)  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorRequest():
return $default(_that.distanceKm,_that.start,_that.end,_that.bearing,_that.discovery,_that.type,_that.seed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double distanceKm,  GeoPoint? start,  GeoPoint? end,  String? bearing,  double? discovery,  String? type,  int? seed)?  $default,) {final _that = this;
switch (_that) {
case _RouteGeneratorRequest() when $default != null:
return $default(_that.distanceKm,_that.start,_that.end,_that.bearing,_that.discovery,_that.type,_that.seed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteGeneratorRequest implements RouteGeneratorRequest {
  const _RouteGeneratorRequest({required this.distanceKm, this.start, this.end, this.bearing, this.discovery, this.type, this.seed});
  factory _RouteGeneratorRequest.fromJson(Map<String, dynamic> json) => _$RouteGeneratorRequestFromJson(json);

/// Wished distance in kilometres, 10 to 200
@override final  double distanceKm;
/// Start. Absent: the team's location (400 VALIDATION if it has none)
@override final  GeoPoint? start;
/// End. Absent: a loop, the route ends where it starts. Present: a one-way route from start to end
@override final  GeoPoint? end;
/// Wished direction, only used when the end is closer than half the distance (a loop included)
@override final  String? bearing;
/// From the team's roads (0, only the roads the team rides) to discovery (1, no preference for them); rounded to the hundredth by the engine. Absent: 0.25
@override final  double? discovery;
/// What to ride. Absent: ROAD
@override final  String? type;
/// Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0
@override final  int? seed;

/// Create a copy of RouteGeneratorRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteGeneratorRequestCopyWith<_RouteGeneratorRequest> get copyWith => __$RouteGeneratorRequestCopyWithImpl<_RouteGeneratorRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteGeneratorRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteGeneratorRequest&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.bearing, bearing) || other.bearing == bearing)&&(identical(other.discovery, discovery) || other.discovery == discovery)&&(identical(other.type, type) || other.type == type)&&(identical(other.seed, seed) || other.seed == seed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,distanceKm,start,end,bearing,discovery,type,seed);
}

@override
String toString() {
    return 'RouteGeneratorRequest(distanceKm: $distanceKm, start: $start, end: $end, bearing: $bearing, discovery: $discovery, type: $type, seed: $seed)';
}


}

/// @nodoc
abstract mixin class _$RouteGeneratorRequestCopyWith<$Res> implements $RouteGeneratorRequestCopyWith<$Res> {
  factory _$RouteGeneratorRequestCopyWith(_RouteGeneratorRequest value, $Res Function(_RouteGeneratorRequest) _then) = __$RouteGeneratorRequestCopyWithImpl;
@override @useResult
$Res call({
 double distanceKm, GeoPoint? start, GeoPoint? end, String? bearing, double? discovery, String? type, int? seed
});


@override $GeoPointCopyWith<$Res>? get start;@override $GeoPointCopyWith<$Res>? get end;

}
/// @nodoc
class __$RouteGeneratorRequestCopyWithImpl<$Res>
    implements _$RouteGeneratorRequestCopyWith<$Res> {
  __$RouteGeneratorRequestCopyWithImpl(this._self, this._then);

  final _RouteGeneratorRequest _self;
  final $Res Function(_RouteGeneratorRequest) _then;

/// Create a copy of RouteGeneratorRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? distanceKm = null,Object? start = freezed,Object? end = freezed,Object? bearing = freezed,Object? discovery = freezed,Object? type = freezed,Object? seed = freezed,}) {
  return _then(_RouteGeneratorRequest(
distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as GeoPoint?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as GeoPoint?,bearing: freezed == bearing ? _self.bearing : bearing // ignore: cast_nullable_to_non_nullable
as String?,discovery: freezed == discovery ? _self.discovery : discovery // ignore: cast_nullable_to_non_nullable
as double?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of RouteGeneratorRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res>? get start {
    if (_self.start == null) {
    return null;
  }

  return $GeoPointCopyWith<$Res>(_self.start!, (value) {
    return _then(_self.copyWith(start: value));
  });
}/// Create a copy of RouteGeneratorRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res>? get end {
    if (_self.end == null) {
    return null;
  }

  return $GeoPointCopyWith<$Res>(_self.end!, (value) {
    return _then(_self.copyWith(end: value));
  });
}
}

// dart format on
