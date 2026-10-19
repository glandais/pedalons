// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'router_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouterResponse {

 GeoJsonLineString get route; double? get dist; double? get ascend;/// Runs of unpaved edges of route (compacted surface or worse, from the router's own maneuvers), half-open, ascending and disjoint; edge i joins route points i and i + 1. Absent when the router gave no surface; empty when all paved
 List<UnpavedSpan>? get unpaved;
/// Create a copy of RouterResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouterResponseCopyWith<RouterResponse> get copyWith => _$RouterResponseCopyWithImpl<RouterResponse>(this as RouterResponse, _$identity);

  /// Serializes this RouterResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouterResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouterResponse&&(identical(other.route, _this.route) || other.route == _this.route)&&(identical(other.dist, _this.dist) || other.dist == _this.dist)&&(identical(other.ascend, _this.ascend) || other.ascend == _this.ascend)&&const DeepCollectionEquality().equals(other.unpaved, _this.unpaved));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouterResponse;
  return Object.hash(runtimeType,_this.route,_this.dist,_this.ascend,const DeepCollectionEquality().hash(_this.unpaved));
}

@override
String toString() {
  final _this = this as RouterResponse;
  return 'RouterResponse(route: ${_this.route}, dist: ${_this.dist}, ascend: ${_this.ascend}, unpaved: ${_this.unpaved})';
}


}

/// @nodoc
abstract mixin class $RouterResponseCopyWith<$Res>  {
  factory $RouterResponseCopyWith(RouterResponse value, $Res Function(RouterResponse) _then) = _$RouterResponseCopyWithImpl;
@useResult
$Res call({
 GeoJsonLineString route, double? dist, double? ascend, List<UnpavedSpan>? unpaved
});


$GeoJsonLineStringCopyWith<$Res> get route;

}
/// @nodoc
class _$RouterResponseCopyWithImpl<$Res>
    implements $RouterResponseCopyWith<$Res> {
  _$RouterResponseCopyWithImpl(this._self, this._then);

  final RouterResponse _self;
  final $Res Function(RouterResponse) _then;

/// Create a copy of RouterResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? route = null,Object? dist = freezed,Object? ascend = freezed,Object? unpaved = freezed,}) {
  return _then(RouterResponse(
route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as GeoJsonLineString,dist: freezed == dist ? _self.dist : dist // ignore: cast_nullable_to_non_nullable
as double?,ascend: freezed == ascend ? _self.ascend : ascend // ignore: cast_nullable_to_non_nullable
as double?,unpaved: freezed == unpaved ? _self.unpaved : unpaved // ignore: cast_nullable_to_non_nullable
as List<UnpavedSpan>?,
  ));
}
/// Create a copy of RouterResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoJsonLineStringCopyWith<$Res> get route {
  
  return $GeoJsonLineStringCopyWith<$Res>(_self.route, (value) {
    return _then(_self.copyWith(route: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouterResponse].
extension RouterResponsePatterns on RouterResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouterResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouterResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouterResponse value)  $default,){
final _that = this;
switch (_that) {
case _RouterResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouterResponse value)?  $default,){
final _that = this;
switch (_that) {
case _RouterResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GeoJsonLineString route,  double? dist,  double? ascend,  List<UnpavedSpan>? unpaved)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouterResponse() when $default != null:
return $default(_that.route,_that.dist,_that.ascend,_that.unpaved);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GeoJsonLineString route,  double? dist,  double? ascend,  List<UnpavedSpan>? unpaved)  $default,) {final _that = this;
switch (_that) {
case _RouterResponse():
return $default(_that.route,_that.dist,_that.ascend,_that.unpaved);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GeoJsonLineString route,  double? dist,  double? ascend,  List<UnpavedSpan>? unpaved)?  $default,) {final _that = this;
switch (_that) {
case _RouterResponse() when $default != null:
return $default(_that.route,_that.dist,_that.ascend,_that.unpaved);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouterResponse implements RouterResponse {
  const _RouterResponse({required this.route, this.dist, this.ascend,  List<UnpavedSpan>? unpaved}): _unpaved = unpaved;
  factory _RouterResponse.fromJson(Map<String, dynamic> json) => _$RouterResponseFromJson(json);

@override final  GeoJsonLineString route;
@override final  double? dist;
@override final  double? ascend;
/// Runs of unpaved edges of route (compacted surface or worse, from the router's own maneuvers), half-open, ascending and disjoint; edge i joins route points i and i + 1. Absent when the router gave no surface; empty when all paved
 final  List<UnpavedSpan>? _unpaved;
/// Runs of unpaved edges of route (compacted surface or worse, from the router's own maneuvers), half-open, ascending and disjoint; edge i joins route points i and i + 1. Absent when the router gave no surface; empty when all paved
@override List<UnpavedSpan>? get unpaved {
  final value = _unpaved;
  if (value == null) return null;
  if (_unpaved is EqualUnmodifiableListView) return _unpaved;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of RouterResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouterResponseCopyWith<_RouterResponse> get copyWith => __$RouterResponseCopyWithImpl<_RouterResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouterResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouterResponse&&(identical(other.route, route) || other.route == route)&&(identical(other.dist, dist) || other.dist == dist)&&(identical(other.ascend, ascend) || other.ascend == ascend)&&const DeepCollectionEquality().equals(other.unpaved, _unpaved));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,route,dist,ascend,const DeepCollectionEquality().hash(_unpaved));
}

@override
String toString() {
    return 'RouterResponse(route: $route, dist: $dist, ascend: $ascend, unpaved: $unpaved)';
}


}

/// @nodoc
abstract mixin class _$RouterResponseCopyWith<$Res> implements $RouterResponseCopyWith<$Res> {
  factory _$RouterResponseCopyWith(_RouterResponse value, $Res Function(_RouterResponse) _then) = __$RouterResponseCopyWithImpl;
@override @useResult
$Res call({
 GeoJsonLineString route, double? dist, double? ascend, List<UnpavedSpan>? unpaved
});


@override $GeoJsonLineStringCopyWith<$Res> get route;

}
/// @nodoc
class __$RouterResponseCopyWithImpl<$Res>
    implements _$RouterResponseCopyWith<$Res> {
  __$RouterResponseCopyWithImpl(this._self, this._then);

  final _RouterResponse _self;
  final $Res Function(_RouterResponse) _then;

/// Create a copy of RouterResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? route = null,Object? dist = freezed,Object? ascend = freezed,Object? unpaved = freezed,}) {
  return _then(_RouterResponse(
route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as GeoJsonLineString,dist: freezed == dist ? _self.dist : dist // ignore: cast_nullable_to_non_nullable
as double?,ascend: freezed == ascend ? _self.ascend : ascend // ignore: cast_nullable_to_non_nullable
as double?,unpaved: freezed == unpaved ? _self._unpaved : unpaved // ignore: cast_nullable_to_non_nullable
as List<UnpavedSpan>?,
  ));
}

/// Create a copy of RouterResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoJsonLineStringCopyWith<$Res> get route {
  
  return $GeoJsonLineStringCopyWith<$Res>(_self.route, (value) {
    return _then(_self.copyWith(route: value));
  });
}
}

// dart format on
