// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_retouch_end.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteRetouchEnd {

/// A position, e.g. a tap on the map
 GeoPoint? get point;/// A place of the route's team, by id: its position is the finish (400 VALIDATION on end.placeId when it is not one of the team's)
 String? get placeId;
/// Create a copy of RouteRetouchEnd
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteRetouchEndCopyWith<RouteRetouchEnd> get copyWith => _$RouteRetouchEndCopyWithImpl<RouteRetouchEnd>(this as RouteRetouchEnd, _$identity);

  /// Serializes this RouteRetouchEnd to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteRetouchEnd;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteRetouchEnd&&(identical(other.point, _this.point) || other.point == _this.point)&&(identical(other.placeId, _this.placeId) || other.placeId == _this.placeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteRetouchEnd;
  return Object.hash(runtimeType,_this.point,_this.placeId);
}

@override
String toString() {
  final _this = this as RouteRetouchEnd;
  return 'RouteRetouchEnd(point: ${_this.point}, placeId: ${_this.placeId})';
}


}

/// @nodoc
abstract mixin class $RouteRetouchEndCopyWith<$Res>  {
  factory $RouteRetouchEndCopyWith(RouteRetouchEnd value, $Res Function(RouteRetouchEnd) _then) = _$RouteRetouchEndCopyWithImpl;
@useResult
$Res call({
 GeoPoint? point, String? placeId
});


$GeoPointCopyWith<$Res>? get point;

}
/// @nodoc
class _$RouteRetouchEndCopyWithImpl<$Res>
    implements $RouteRetouchEndCopyWith<$Res> {
  _$RouteRetouchEndCopyWithImpl(this._self, this._then);

  final RouteRetouchEnd _self;
  final $Res Function(RouteRetouchEnd) _then;

/// Create a copy of RouteRetouchEnd
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? point = freezed,Object? placeId = freezed,}) {
  return _then(RouteRetouchEnd(
point: freezed == point ? _self.point : point // ignore: cast_nullable_to_non_nullable
as GeoPoint?,placeId: freezed == placeId ? _self.placeId : placeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of RouteRetouchEnd
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res>? get point {
    if (_self.point == null) {
    return null;
  }

  return $GeoPointCopyWith<$Res>(_self.point!, (value) {
    return _then(_self.copyWith(point: value));
  });
}
}


/// Adds pattern-matching-related methods to [RouteRetouchEnd].
extension RouteRetouchEndPatterns on RouteRetouchEnd {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteRetouchEnd value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteRetouchEnd() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteRetouchEnd value)  $default,){
final _that = this;
switch (_that) {
case _RouteRetouchEnd():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteRetouchEnd value)?  $default,){
final _that = this;
switch (_that) {
case _RouteRetouchEnd() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GeoPoint? point,  String? placeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteRetouchEnd() when $default != null:
return $default(_that.point,_that.placeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GeoPoint? point,  String? placeId)  $default,) {final _that = this;
switch (_that) {
case _RouteRetouchEnd():
return $default(_that.point,_that.placeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GeoPoint? point,  String? placeId)?  $default,) {final _that = this;
switch (_that) {
case _RouteRetouchEnd() when $default != null:
return $default(_that.point,_that.placeId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteRetouchEnd implements RouteRetouchEnd {
  const _RouteRetouchEnd({this.point, this.placeId});
  factory _RouteRetouchEnd.fromJson(Map<String, dynamic> json) => _$RouteRetouchEndFromJson(json);

/// A position, e.g. a tap on the map
@override final  GeoPoint? point;
/// A place of the route's team, by id: its position is the finish (400 VALIDATION on end.placeId when it is not one of the team's)
@override final  String? placeId;

/// Create a copy of RouteRetouchEnd
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteRetouchEndCopyWith<_RouteRetouchEnd> get copyWith => __$RouteRetouchEndCopyWithImpl<_RouteRetouchEnd>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteRetouchEndToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteRetouchEnd&&(identical(other.point, point) || other.point == point)&&(identical(other.placeId, placeId) || other.placeId == placeId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,point,placeId);
}

@override
String toString() {
    return 'RouteRetouchEnd(point: $point, placeId: $placeId)';
}


}

/// @nodoc
abstract mixin class _$RouteRetouchEndCopyWith<$Res> implements $RouteRetouchEndCopyWith<$Res> {
  factory _$RouteRetouchEndCopyWith(_RouteRetouchEnd value, $Res Function(_RouteRetouchEnd) _then) = __$RouteRetouchEndCopyWithImpl;
@override @useResult
$Res call({
 GeoPoint? point, String? placeId
});


@override $GeoPointCopyWith<$Res>? get point;

}
/// @nodoc
class __$RouteRetouchEndCopyWithImpl<$Res>
    implements _$RouteRetouchEndCopyWith<$Res> {
  __$RouteRetouchEndCopyWithImpl(this._self, this._then);

  final _RouteRetouchEnd _self;
  final $Res Function(_RouteRetouchEnd) _then;

/// Create a copy of RouteRetouchEnd
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? point = freezed,Object? placeId = freezed,}) {
  return _then(_RouteRetouchEnd(
point: freezed == point ? _self.point : point // ignore: cast_nullable_to_non_nullable
as GeoPoint?,placeId: freezed == placeId ? _self.placeId : placeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of RouteRetouchEnd
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res>? get point {
    if (_self.point == null) {
    return null;
  }

  return $GeoPointCopyWith<$Res>(_self.point!, (value) {
    return _then(_self.copyWith(point: value));
  });
}
}

// dart format on
