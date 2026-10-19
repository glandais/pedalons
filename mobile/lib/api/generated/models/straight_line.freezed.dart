// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'straight_line.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StraightLine {

 GeoPoint get from; GeoPoint get to;
/// Create a copy of StraightLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StraightLineCopyWith<StraightLine> get copyWith => _$StraightLineCopyWithImpl<StraightLine>(this as StraightLine, _$identity);

  /// Serializes this StraightLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as StraightLine;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StraightLine&&(identical(other.from, _this.from) || other.from == _this.from)&&(identical(other.to, _this.to) || other.to == _this.to));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as StraightLine;
  return Object.hash(runtimeType,_this.from,_this.to);
}

@override
String toString() {
  final _this = this as StraightLine;
  return 'StraightLine(from: ${_this.from}, to: ${_this.to})';
}


}

/// @nodoc
abstract mixin class $StraightLineCopyWith<$Res>  {
  factory $StraightLineCopyWith(StraightLine value, $Res Function(StraightLine) _then) = _$StraightLineCopyWithImpl;
@useResult
$Res call({
 GeoPoint from, GeoPoint to
});


$GeoPointCopyWith<$Res> get from;$GeoPointCopyWith<$Res> get to;

}
/// @nodoc
class _$StraightLineCopyWithImpl<$Res>
    implements $StraightLineCopyWith<$Res> {
  _$StraightLineCopyWithImpl(this._self, this._then);

  final StraightLine _self;
  final $Res Function(StraightLine) _then;

/// Create a copy of StraightLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? from = null,Object? to = null,}) {
  return _then(StraightLine(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as GeoPoint,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as GeoPoint,
  ));
}
/// Create a copy of StraightLine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get from {
  
  return $GeoPointCopyWith<$Res>(_self.from, (value) {
    return _then(_self.copyWith(from: value));
  });
}/// Create a copy of StraightLine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get to {
  
  return $GeoPointCopyWith<$Res>(_self.to, (value) {
    return _then(_self.copyWith(to: value));
  });
}
}


/// Adds pattern-matching-related methods to [StraightLine].
extension StraightLinePatterns on StraightLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StraightLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StraightLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StraightLine value)  $default,){
final _that = this;
switch (_that) {
case _StraightLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StraightLine value)?  $default,){
final _that = this;
switch (_that) {
case _StraightLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GeoPoint from,  GeoPoint to)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StraightLine() when $default != null:
return $default(_that.from,_that.to);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GeoPoint from,  GeoPoint to)  $default,) {final _that = this;
switch (_that) {
case _StraightLine():
return $default(_that.from,_that.to);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GeoPoint from,  GeoPoint to)?  $default,) {final _that = this;
switch (_that) {
case _StraightLine() when $default != null:
return $default(_that.from,_that.to);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StraightLine implements StraightLine {
  const _StraightLine({required this.from, required this.to});
  factory _StraightLine.fromJson(Map<String, dynamic> json) => _$StraightLineFromJson(json);

@override final  GeoPoint from;
@override final  GeoPoint to;

/// Create a copy of StraightLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StraightLineCopyWith<_StraightLine> get copyWith => __$StraightLineCopyWithImpl<_StraightLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StraightLineToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StraightLine&&(identical(other.from, from) || other.from == from)&&(identical(other.to, to) || other.to == to));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,from,to);
}

@override
String toString() {
    return 'StraightLine(from: $from, to: $to)';
}


}

/// @nodoc
abstract mixin class _$StraightLineCopyWith<$Res> implements $StraightLineCopyWith<$Res> {
  factory _$StraightLineCopyWith(_StraightLine value, $Res Function(_StraightLine) _then) = __$StraightLineCopyWithImpl;
@override @useResult
$Res call({
 GeoPoint from, GeoPoint to
});


@override $GeoPointCopyWith<$Res> get from;@override $GeoPointCopyWith<$Res> get to;

}
/// @nodoc
class __$StraightLineCopyWithImpl<$Res>
    implements _$StraightLineCopyWith<$Res> {
  __$StraightLineCopyWithImpl(this._self, this._then);

  final _StraightLine _self;
  final $Res Function(_StraightLine) _then;

/// Create a copy of StraightLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? from = null,Object? to = null,}) {
  return _then(_StraightLine(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as GeoPoint,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as GeoPoint,
  ));
}

/// Create a copy of StraightLine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res> get from {
  
  return $GeoPointCopyWith<$Res>(_self.from, (value) {
    return _then(_self.copyWith(from: value));
  });
}/// Create a copy of StraightLine
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
