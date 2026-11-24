// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_retouch_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteRetouchRequest {

/// The total distance aimed at, in kilometres (not the change). The bounds of the field are the offer's (GET .../retouch): minDistanceKm to maxDistanceKm
 double? get targetDistanceKm;/// The new finish
 RouteRetouchEnd? get end;/// From the team's roads (0) to discovery (1); rounded to the hundredth by the engine. Absent: 0.25
 double? get discovery;/// Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0
 int? get seed;
/// Create a copy of RouteRetouchRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteRetouchRequestCopyWith<RouteRetouchRequest> get copyWith => _$RouteRetouchRequestCopyWithImpl<RouteRetouchRequest>(this as RouteRetouchRequest, _$identity);

  /// Serializes this RouteRetouchRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteRetouchRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteRetouchRequest&&(identical(other.targetDistanceKm, _this.targetDistanceKm) || other.targetDistanceKm == _this.targetDistanceKm)&&(identical(other.end, _this.end) || other.end == _this.end)&&(identical(other.discovery, _this.discovery) || other.discovery == _this.discovery)&&(identical(other.seed, _this.seed) || other.seed == _this.seed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteRetouchRequest;
  return Object.hash(runtimeType,_this.targetDistanceKm,_this.end,_this.discovery,_this.seed);
}

@override
String toString() {
  final _this = this as RouteRetouchRequest;
  return 'RouteRetouchRequest(targetDistanceKm: ${_this.targetDistanceKm}, end: ${_this.end}, discovery: ${_this.discovery}, seed: ${_this.seed})';
}


}

/// @nodoc
abstract mixin class $RouteRetouchRequestCopyWith<$Res>  {
  factory $RouteRetouchRequestCopyWith(RouteRetouchRequest value, $Res Function(RouteRetouchRequest) _then) = _$RouteRetouchRequestCopyWithImpl;
@useResult
$Res call({
 double? targetDistanceKm, RouteRetouchEnd? end, double? discovery, int? seed
});


$RouteRetouchEndCopyWith<$Res>? get end;

}
/// @nodoc
class _$RouteRetouchRequestCopyWithImpl<$Res>
    implements $RouteRetouchRequestCopyWith<$Res> {
  _$RouteRetouchRequestCopyWithImpl(this._self, this._then);

  final RouteRetouchRequest _self;
  final $Res Function(RouteRetouchRequest) _then;

/// Create a copy of RouteRetouchRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? targetDistanceKm = freezed,Object? end = freezed,Object? discovery = freezed,Object? seed = freezed,}) {
  return _then(RouteRetouchRequest(
targetDistanceKm: freezed == targetDistanceKm ? _self.targetDistanceKm : targetDistanceKm // ignore: cast_nullable_to_non_nullable
as double?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as RouteRetouchEnd?,discovery: freezed == discovery ? _self.discovery : discovery // ignore: cast_nullable_to_non_nullable
as double?,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of RouteRetouchRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RouteRetouchEndCopyWith<$Res>? get end {
    if (_self.end == null) {
    return null;
  }

  return $RouteRetouchEndCopyWith<$Res>(_self.end!, (value) {
    return _then(_self.copyWith(end: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouteRetouchRequest].
extension RouteRetouchRequestPatterns on RouteRetouchRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteRetouchRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteRetouchRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteRetouchRequest value)  $default,){
final _that = this;
switch (_that) {
case _RouteRetouchRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteRetouchRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RouteRetouchRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double? targetDistanceKm,  RouteRetouchEnd? end,  double? discovery,  int? seed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteRetouchRequest() when $default != null:
return $default(_that.targetDistanceKm,_that.end,_that.discovery,_that.seed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double? targetDistanceKm,  RouteRetouchEnd? end,  double? discovery,  int? seed)  $default,) {final _that = this;
switch (_that) {
case _RouteRetouchRequest():
return $default(_that.targetDistanceKm,_that.end,_that.discovery,_that.seed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double? targetDistanceKm,  RouteRetouchEnd? end,  double? discovery,  int? seed)?  $default,) {final _that = this;
switch (_that) {
case _RouteRetouchRequest() when $default != null:
return $default(_that.targetDistanceKm,_that.end,_that.discovery,_that.seed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteRetouchRequest implements RouteRetouchRequest {
  const _RouteRetouchRequest({this.targetDistanceKm, this.end, this.discovery, this.seed});
  factory _RouteRetouchRequest.fromJson(Map<String, dynamic> json) => _$RouteRetouchRequestFromJson(json);

/// The total distance aimed at, in kilometres (not the change). The bounds of the field are the offer's (GET .../retouch): minDistanceKm to maxDistanceKm
@override final  double? targetDistanceKm;
/// The new finish
@override final  RouteRetouchEnd? end;
/// From the team's roads (0) to discovery (1); rounded to the hundredth by the engine. Absent: 0.25
@override final  double? discovery;
/// Makes "other proposals" reproducible: the same seed gives the same routes. Absent: 0
@override final  int? seed;

/// Create a copy of RouteRetouchRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteRetouchRequestCopyWith<_RouteRetouchRequest> get copyWith => __$RouteRetouchRequestCopyWithImpl<_RouteRetouchRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteRetouchRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteRetouchRequest&&(identical(other.targetDistanceKm, targetDistanceKm) || other.targetDistanceKm == targetDistanceKm)&&(identical(other.end, end) || other.end == end)&&(identical(other.discovery, discovery) || other.discovery == discovery)&&(identical(other.seed, seed) || other.seed == seed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,targetDistanceKm,end,discovery,seed);
}

@override
String toString() {
    return 'RouteRetouchRequest(targetDistanceKm: $targetDistanceKm, end: $end, discovery: $discovery, seed: $seed)';
}


}

/// @nodoc
abstract mixin class _$RouteRetouchRequestCopyWith<$Res> implements $RouteRetouchRequestCopyWith<$Res> {
  factory _$RouteRetouchRequestCopyWith(_RouteRetouchRequest value, $Res Function(_RouteRetouchRequest) _then) = __$RouteRetouchRequestCopyWithImpl;
@override @useResult
$Res call({
 double? targetDistanceKm, RouteRetouchEnd? end, double? discovery, int? seed
});


@override $RouteRetouchEndCopyWith<$Res>? get end;

}
/// @nodoc
class __$RouteRetouchRequestCopyWithImpl<$Res>
    implements _$RouteRetouchRequestCopyWith<$Res> {
  __$RouteRetouchRequestCopyWithImpl(this._self, this._then);

  final _RouteRetouchRequest _self;
  final $Res Function(_RouteRetouchRequest) _then;

/// Create a copy of RouteRetouchRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? targetDistanceKm = freezed,Object? end = freezed,Object? discovery = freezed,Object? seed = freezed,}) {
  return _then(_RouteRetouchRequest(
targetDistanceKm: freezed == targetDistanceKm ? _self.targetDistanceKm : targetDistanceKm // ignore: cast_nullable_to_non_nullable
as double?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as RouteRetouchEnd?,discovery: freezed == discovery ? _self.discovery : discovery // ignore: cast_nullable_to_non_nullable
as double?,seed: freezed == seed ? _self.seed : seed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of RouteRetouchRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RouteRetouchEndCopyWith<$Res>? get end {
    if (_self.end == null) {
    return null;
  }

  return $RouteRetouchEndCopyWith<$Res>(_self.end!, (value) {
    return _then(_self.copyWith(end: value));
  });
}
}

// dart format on
