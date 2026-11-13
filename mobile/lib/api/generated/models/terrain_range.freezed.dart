// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'terrain_range.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TerrainRange {

@JsonKey(name: 'from_m') double? get fromM;@JsonKey(name: 'to_m') double? get toM; String? get origin; bool? get measured;@JsonKey(name: 'fallback_after_error') bool? get fallbackAfterError;
/// Create a copy of TerrainRange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TerrainRangeCopyWith<TerrainRange> get copyWith => _$TerrainRangeCopyWithImpl<TerrainRange>(this as TerrainRange, _$identity);

  /// Serializes this TerrainRange to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TerrainRange;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TerrainRange&&(identical(other.fromM, _this.fromM) || other.fromM == _this.fromM)&&(identical(other.toM, _this.toM) || other.toM == _this.toM)&&(identical(other.origin, _this.origin) || other.origin == _this.origin)&&(identical(other.measured, _this.measured) || other.measured == _this.measured)&&(identical(other.fallbackAfterError, _this.fallbackAfterError) || other.fallbackAfterError == _this.fallbackAfterError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TerrainRange;
  return Object.hash(runtimeType,_this.fromM,_this.toM,_this.origin,_this.measured,_this.fallbackAfterError);
}

@override
String toString() {
  final _this = this as TerrainRange;
  return 'TerrainRange(fromM: ${_this.fromM}, toM: ${_this.toM}, origin: ${_this.origin}, measured: ${_this.measured}, fallbackAfterError: ${_this.fallbackAfterError})';
}


}

/// @nodoc
abstract mixin class $TerrainRangeCopyWith<$Res>  {
  factory $TerrainRangeCopyWith(TerrainRange value, $Res Function(TerrainRange) _then) = _$TerrainRangeCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'from_m') double? fromM,@JsonKey(name: 'to_m') double? toM, String? origin, bool? measured,@JsonKey(name: 'fallback_after_error') bool? fallbackAfterError
});




}
/// @nodoc
class _$TerrainRangeCopyWithImpl<$Res>
    implements $TerrainRangeCopyWith<$Res> {
  _$TerrainRangeCopyWithImpl(this._self, this._then);

  final TerrainRange _self;
  final $Res Function(TerrainRange) _then;

/// Create a copy of TerrainRange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fromM = freezed,Object? toM = freezed,Object? origin = freezed,Object? measured = freezed,Object? fallbackAfterError = freezed,}) {
  return _then(TerrainRange(
fromM: freezed == fromM ? _self.fromM : fromM // ignore: cast_nullable_to_non_nullable
as double?,toM: freezed == toM ? _self.toM : toM // ignore: cast_nullable_to_non_nullable
as double?,origin: freezed == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String?,measured: freezed == measured ? _self.measured : measured // ignore: cast_nullable_to_non_nullable
as bool?,fallbackAfterError: freezed == fallbackAfterError ? _self.fallbackAfterError : fallbackAfterError // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [TerrainRange].
extension TerrainRangePatterns on TerrainRange {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TerrainRange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TerrainRange() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TerrainRange value)  $default,){
final _that = this;
switch (_that) {
case _TerrainRange():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TerrainRange value)?  $default,){
final _that = this;
switch (_that) {
case _TerrainRange() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM,  String? origin,  bool? measured, @JsonKey(name: 'fallback_after_error')  bool? fallbackAfterError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TerrainRange() when $default != null:
return $default(_that.fromM,_that.toM,_that.origin,_that.measured,_that.fallbackAfterError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM,  String? origin,  bool? measured, @JsonKey(name: 'fallback_after_error')  bool? fallbackAfterError)  $default,) {final _that = this;
switch (_that) {
case _TerrainRange():
return $default(_that.fromM,_that.toM,_that.origin,_that.measured,_that.fallbackAfterError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'from_m')  double? fromM, @JsonKey(name: 'to_m')  double? toM,  String? origin,  bool? measured, @JsonKey(name: 'fallback_after_error')  bool? fallbackAfterError)?  $default,) {final _that = this;
switch (_that) {
case _TerrainRange() when $default != null:
return $default(_that.fromM,_that.toM,_that.origin,_that.measured,_that.fallbackAfterError);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TerrainRange implements TerrainRange {
  const _TerrainRange({@JsonKey(name: 'from_m') this.fromM, @JsonKey(name: 'to_m') this.toM, this.origin, this.measured, @JsonKey(name: 'fallback_after_error') this.fallbackAfterError});
  factory _TerrainRange.fromJson(Map<String, dynamic> json) => _$TerrainRangeFromJson(json);

@override@JsonKey(name: 'from_m') final  double? fromM;
@override@JsonKey(name: 'to_m') final  double? toM;
@override final  String? origin;
@override final  bool? measured;
@override@JsonKey(name: 'fallback_after_error') final  bool? fallbackAfterError;

/// Create a copy of TerrainRange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TerrainRangeCopyWith<_TerrainRange> get copyWith => __$TerrainRangeCopyWithImpl<_TerrainRange>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TerrainRangeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TerrainRange&&(identical(other.fromM, fromM) || other.fromM == fromM)&&(identical(other.toM, toM) || other.toM == toM)&&(identical(other.origin, origin) || other.origin == origin)&&(identical(other.measured, measured) || other.measured == measured)&&(identical(other.fallbackAfterError, fallbackAfterError) || other.fallbackAfterError == fallbackAfterError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,fromM,toM,origin,measured,fallbackAfterError);
}

@override
String toString() {
    return 'TerrainRange(fromM: $fromM, toM: $toM, origin: $origin, measured: $measured, fallbackAfterError: $fallbackAfterError)';
}


}

/// @nodoc
abstract mixin class _$TerrainRangeCopyWith<$Res> implements $TerrainRangeCopyWith<$Res> {
  factory _$TerrainRangeCopyWith(_TerrainRange value, $Res Function(_TerrainRange) _then) = __$TerrainRangeCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'from_m') double? fromM,@JsonKey(name: 'to_m') double? toM, String? origin, bool? measured,@JsonKey(name: 'fallback_after_error') bool? fallbackAfterError
});




}
/// @nodoc
class __$TerrainRangeCopyWithImpl<$Res>
    implements _$TerrainRangeCopyWith<$Res> {
  __$TerrainRangeCopyWithImpl(this._self, this._then);

  final _TerrainRange _self;
  final $Res Function(_TerrainRange) _then;

/// Create a copy of TerrainRange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fromM = freezed,Object? toM = freezed,Object? origin = freezed,Object? measured = freezed,Object? fallbackAfterError = freezed,}) {
  return _then(_TerrainRange(
fromM: freezed == fromM ? _self.fromM : fromM // ignore: cast_nullable_to_non_nullable
as double?,toM: freezed == toM ? _self.toM : toM // ignore: cast_nullable_to_non_nullable
as double?,origin: freezed == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as String?,measured: freezed == measured ? _self.measured : measured // ignore: cast_nullable_to_non_nullable
as bool?,fallbackAfterError: freezed == fallbackAfterError ? _self.fallbackAfterError : fallbackAfterError // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
