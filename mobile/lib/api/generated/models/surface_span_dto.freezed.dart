// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'surface_span_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SurfaceSpanDto {

/// Start, metres along the track
 double get from;/// End, metres along the track
 double get to; TrackSurface get surface;
/// Create a copy of SurfaceSpanDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SurfaceSpanDtoCopyWith<SurfaceSpanDto> get copyWith => _$SurfaceSpanDtoCopyWithImpl<SurfaceSpanDto>(this as SurfaceSpanDto, _$identity);

  /// Serializes this SurfaceSpanDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SurfaceSpanDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SurfaceSpanDto&&(identical(other.from, _this.from) || other.from == _this.from)&&(identical(other.to, _this.to) || other.to == _this.to)&&(identical(other.surface, _this.surface) || other.surface == _this.surface));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SurfaceSpanDto;
  return Object.hash(runtimeType,_this.from,_this.to,_this.surface);
}

@override
String toString() {
  final _this = this as SurfaceSpanDto;
  return 'SurfaceSpanDto(from: ${_this.from}, to: ${_this.to}, surface: ${_this.surface})';
}


}

/// @nodoc
abstract mixin class $SurfaceSpanDtoCopyWith<$Res>  {
  factory $SurfaceSpanDtoCopyWith(SurfaceSpanDto value, $Res Function(SurfaceSpanDto) _then) = _$SurfaceSpanDtoCopyWithImpl;
@useResult
$Res call({
 double from, double to, TrackSurface surface
});




}
/// @nodoc
class _$SurfaceSpanDtoCopyWithImpl<$Res>
    implements $SurfaceSpanDtoCopyWith<$Res> {
  _$SurfaceSpanDtoCopyWithImpl(this._self, this._then);

  final SurfaceSpanDto _self;
  final $Res Function(SurfaceSpanDto) _then;

/// Create a copy of SurfaceSpanDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? from = null,Object? to = null,Object? surface = null,}) {
  return _then(SurfaceSpanDto(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as double,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as double,surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as TrackSurface,
  ));
}

}


/// Adds pattern-matching-related methods to [SurfaceSpanDto].
extension SurfaceSpanDtoPatterns on SurfaceSpanDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SurfaceSpanDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SurfaceSpanDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SurfaceSpanDto value)  $default,){
final _that = this;
switch (_that) {
case _SurfaceSpanDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SurfaceSpanDto value)?  $default,){
final _that = this;
switch (_that) {
case _SurfaceSpanDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double from,  double to,  TrackSurface surface)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SurfaceSpanDto() when $default != null:
return $default(_that.from,_that.to,_that.surface);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double from,  double to,  TrackSurface surface)  $default,) {final _that = this;
switch (_that) {
case _SurfaceSpanDto():
return $default(_that.from,_that.to,_that.surface);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double from,  double to,  TrackSurface surface)?  $default,) {final _that = this;
switch (_that) {
case _SurfaceSpanDto() when $default != null:
return $default(_that.from,_that.to,_that.surface);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SurfaceSpanDto implements SurfaceSpanDto {
  const _SurfaceSpanDto({required this.from, required this.to, required this.surface});
  factory _SurfaceSpanDto.fromJson(Map<String, dynamic> json) => _$SurfaceSpanDtoFromJson(json);

/// Start, metres along the track
@override final  double from;
/// End, metres along the track
@override final  double to;
@override final  TrackSurface surface;

/// Create a copy of SurfaceSpanDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SurfaceSpanDtoCopyWith<_SurfaceSpanDto> get copyWith => __$SurfaceSpanDtoCopyWithImpl<_SurfaceSpanDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SurfaceSpanDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SurfaceSpanDto&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to)&&(identical(other.surface, surface) || other.surface == surface));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,from,to,surface);
}

@override
String toString() {
    return 'SurfaceSpanDto(from: $from, to: $to, surface: $surface)';
}


}

/// @nodoc
abstract mixin class _$SurfaceSpanDtoCopyWith<$Res> implements $SurfaceSpanDtoCopyWith<$Res> {
  factory _$SurfaceSpanDtoCopyWith(_SurfaceSpanDto value, $Res Function(_SurfaceSpanDto) _then) = __$SurfaceSpanDtoCopyWithImpl;
@override @useResult
$Res call({
 double from, double to, TrackSurface surface
});




}
/// @nodoc
class __$SurfaceSpanDtoCopyWithImpl<$Res>
    implements _$SurfaceSpanDtoCopyWith<$Res> {
  __$SurfaceSpanDtoCopyWithImpl(this._self, this._then);

  final _SurfaceSpanDto _self;
  final $Res Function(_SurfaceSpanDto) _then;

/// Create a copy of SurfaceSpanDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? from = null,Object? to = null,Object? surface = null,}) {
  return _then(_SurfaceSpanDto(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as double,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as double,surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as TrackSurface,
  ));
}


}

// dart format on
