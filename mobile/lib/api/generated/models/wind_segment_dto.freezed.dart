// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wind_segment_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WindSegmentDto {

/// Start of the stretch, equal to its checkpoint's distance: metres from the start of the route, its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next (unlike the 4th coordinate of a track geometry, which restarts at 0 on each track).
 double get fromDistance;/// End of the stretch, equal to the next checkpoint's distance: metres from the start of the route, its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next (unlike the 4th coordinate of a track geometry, which restarts at 0 on each track).
 double get toDistance;/// HEAD when the head component exceeds half the wind speed, TAIL below minus half, CROSS otherwise. Always shown with its label and an arrow, not by colour alone.
 String get relativeWind;/// Mean head component, km/h, signed: positive against the rider
 double get headwind;
/// Create a copy of WindSegmentDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WindSegmentDtoCopyWith<WindSegmentDto> get copyWith => _$WindSegmentDtoCopyWithImpl<WindSegmentDto>(this as WindSegmentDto, _$identity);

  /// Serializes this WindSegmentDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WindSegmentDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WindSegmentDto&&(identical(other.fromDistance, _this.fromDistance) || other.fromDistance == _this.fromDistance)&&(identical(other.toDistance, _this.toDistance) || other.toDistance == _this.toDistance)&&(identical(other.relativeWind, _this.relativeWind) || other.relativeWind == _this.relativeWind)&&(identical(other.headwind, _this.headwind) || other.headwind == _this.headwind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WindSegmentDto;
  return Object.hash(runtimeType,_this.fromDistance,_this.toDistance,_this.relativeWind,_this.headwind);
}

@override
String toString() {
  final _this = this as WindSegmentDto;
  return 'WindSegmentDto(fromDistance: ${_this.fromDistance}, toDistance: ${_this.toDistance}, relativeWind: ${_this.relativeWind}, headwind: ${_this.headwind})';
}


}

/// @nodoc
abstract mixin class $WindSegmentDtoCopyWith<$Res>  {
  factory $WindSegmentDtoCopyWith(WindSegmentDto value, $Res Function(WindSegmentDto) _then) = _$WindSegmentDtoCopyWithImpl;
@useResult
$Res call({
 double fromDistance, double toDistance, String relativeWind, double headwind
});




}
/// @nodoc
class _$WindSegmentDtoCopyWithImpl<$Res>
    implements $WindSegmentDtoCopyWith<$Res> {
  _$WindSegmentDtoCopyWithImpl(this._self, this._then);

  final WindSegmentDto _self;
  final $Res Function(WindSegmentDto) _then;

/// Create a copy of WindSegmentDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fromDistance = null,Object? toDistance = null,Object? relativeWind = null,Object? headwind = null,}) {
  return _then(WindSegmentDto(
fromDistance: null == fromDistance ? _self.fromDistance : fromDistance // ignore: cast_nullable_to_non_nullable
as double,toDistance: null == toDistance ? _self.toDistance : toDistance // ignore: cast_nullable_to_non_nullable
as double,relativeWind: null == relativeWind ? _self.relativeWind : relativeWind // ignore: cast_nullable_to_non_nullable
as String,headwind: null == headwind ? _self.headwind : headwind // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [WindSegmentDto].
extension WindSegmentDtoPatterns on WindSegmentDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WindSegmentDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WindSegmentDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WindSegmentDto value)  $default,){
final _that = this;
switch (_that) {
case _WindSegmentDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WindSegmentDto value)?  $default,){
final _that = this;
switch (_that) {
case _WindSegmentDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double fromDistance,  double toDistance,  String relativeWind,  double headwind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WindSegmentDto() when $default != null:
return $default(_that.fromDistance,_that.toDistance,_that.relativeWind,_that.headwind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double fromDistance,  double toDistance,  String relativeWind,  double headwind)  $default,) {final _that = this;
switch (_that) {
case _WindSegmentDto():
return $default(_that.fromDistance,_that.toDistance,_that.relativeWind,_that.headwind);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double fromDistance,  double toDistance,  String relativeWind,  double headwind)?  $default,) {final _that = this;
switch (_that) {
case _WindSegmentDto() when $default != null:
return $default(_that.fromDistance,_that.toDistance,_that.relativeWind,_that.headwind);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WindSegmentDto implements WindSegmentDto {
  const _WindSegmentDto({required this.fromDistance, required this.toDistance, required this.relativeWind, required this.headwind});
  factory _WindSegmentDto.fromJson(Map<String, dynamic> json) => _$WindSegmentDtoFromJson(json);

/// Start of the stretch, equal to its checkpoint's distance: metres from the start of the route, its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next (unlike the 4th coordinate of a track geometry, which restarts at 0 on each track).
@override final  double fromDistance;
/// End of the stretch, equal to the next checkpoint's distance: metres from the start of the route, its tracks laid end to end in the order of their ids, without counting the gap between the end of one track and the start of the next (unlike the 4th coordinate of a track geometry, which restarts at 0 on each track).
@override final  double toDistance;
/// HEAD when the head component exceeds half the wind speed, TAIL below minus half, CROSS otherwise. Always shown with its label and an arrow, not by colour alone.
@override final  String relativeWind;
/// Mean head component, km/h, signed: positive against the rider
@override final  double headwind;

/// Create a copy of WindSegmentDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WindSegmentDtoCopyWith<_WindSegmentDto> get copyWith => __$WindSegmentDtoCopyWithImpl<_WindSegmentDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WindSegmentDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WindSegmentDto&&(identical(other.fromDistance, fromDistance) || other.fromDistance == fromDistance)&&(identical(other.toDistance, toDistance) || other.toDistance == toDistance)&&(identical(other.relativeWind, relativeWind) || other.relativeWind == relativeWind)&&(identical(other.headwind, headwind) || other.headwind == headwind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,fromDistance,toDistance,relativeWind,headwind);
}

@override
String toString() {
    return 'WindSegmentDto(fromDistance: $fromDistance, toDistance: $toDistance, relativeWind: $relativeWind, headwind: $headwind)';
}


}

/// @nodoc
abstract mixin class _$WindSegmentDtoCopyWith<$Res> implements $WindSegmentDtoCopyWith<$Res> {
  factory _$WindSegmentDtoCopyWith(_WindSegmentDto value, $Res Function(_WindSegmentDto) _then) = __$WindSegmentDtoCopyWithImpl;
@override @useResult
$Res call({
 double fromDistance, double toDistance, String relativeWind, double headwind
});




}
/// @nodoc
class __$WindSegmentDtoCopyWithImpl<$Res>
    implements _$WindSegmentDtoCopyWith<$Res> {
  __$WindSegmentDtoCopyWithImpl(this._self, this._then);

  final _WindSegmentDto _self;
  final $Res Function(_WindSegmentDto) _then;

/// Create a copy of WindSegmentDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fromDistance = null,Object? toDistance = null,Object? relativeWind = null,Object? headwind = null,}) {
  return _then(_WindSegmentDto(
fromDistance: null == fromDistance ? _self.fromDistance : fromDistance // ignore: cast_nullable_to_non_nullable
as double,toDistance: null == toDistance ? _self.toDistance : toDistance // ignore: cast_nullable_to_non_nullable
as double,relativeWind: null == relativeWind ? _self.relativeWind : relativeWind // ignore: cast_nullable_to_non_nullable
as String,headwind: null == headwind ? _self.headwind : headwind // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
