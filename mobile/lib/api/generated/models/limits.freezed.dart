// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'limits.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Limits {

@JsonKey(name: 'max_points') int? get maxPoints;@JsonKey(name: 'max_length_m') double? get maxLengthM;
/// Create a copy of Limits
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LimitsCopyWith<Limits> get copyWith => _$LimitsCopyWithImpl<Limits>(this as Limits, _$identity);

  /// Serializes this Limits to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Limits;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Limits&&(identical(other.maxPoints, _this.maxPoints) || other.maxPoints == _this.maxPoints)&&(identical(other.maxLengthM, _this.maxLengthM) || other.maxLengthM == _this.maxLengthM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Limits;
  return Object.hash(runtimeType,_this.maxPoints,_this.maxLengthM);
}

@override
String toString() {
  final _this = this as Limits;
  return 'Limits(maxPoints: ${_this.maxPoints}, maxLengthM: ${_this.maxLengthM})';
}


}

/// @nodoc
abstract mixin class $LimitsCopyWith<$Res>  {
  factory $LimitsCopyWith(Limits value, $Res Function(Limits) _then) = _$LimitsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'max_points') int? maxPoints,@JsonKey(name: 'max_length_m') double? maxLengthM
});




}
/// @nodoc
class _$LimitsCopyWithImpl<$Res>
    implements $LimitsCopyWith<$Res> {
  _$LimitsCopyWithImpl(this._self, this._then);

  final Limits _self;
  final $Res Function(Limits) _then;

/// Create a copy of Limits
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? maxPoints = freezed,Object? maxLengthM = freezed,}) {
  return _then(Limits(
maxPoints: freezed == maxPoints ? _self.maxPoints : maxPoints // ignore: cast_nullable_to_non_nullable
as int?,maxLengthM: freezed == maxLengthM ? _self.maxLengthM : maxLengthM // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [Limits].
extension LimitsPatterns on Limits {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Limits value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Limits() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Limits value)  $default,){
final _that = this;
switch (_that) {
case _Limits():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Limits value)?  $default,){
final _that = this;
switch (_that) {
case _Limits() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'max_points')  int? maxPoints, @JsonKey(name: 'max_length_m')  double? maxLengthM)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Limits() when $default != null:
return $default(_that.maxPoints,_that.maxLengthM);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'max_points')  int? maxPoints, @JsonKey(name: 'max_length_m')  double? maxLengthM)  $default,) {final _that = this;
switch (_that) {
case _Limits():
return $default(_that.maxPoints,_that.maxLengthM);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'max_points')  int? maxPoints, @JsonKey(name: 'max_length_m')  double? maxLengthM)?  $default,) {final _that = this;
switch (_that) {
case _Limits() when $default != null:
return $default(_that.maxPoints,_that.maxLengthM);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Limits implements Limits {
  const _Limits({@JsonKey(name: 'max_points') this.maxPoints, @JsonKey(name: 'max_length_m') this.maxLengthM});
  factory _Limits.fromJson(Map<String, dynamic> json) => _$LimitsFromJson(json);

@override@JsonKey(name: 'max_points') final  int? maxPoints;
@override@JsonKey(name: 'max_length_m') final  double? maxLengthM;

/// Create a copy of Limits
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LimitsCopyWith<_Limits> get copyWith => __$LimitsCopyWithImpl<_Limits>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LimitsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Limits&&(identical(other.maxPoints, maxPoints) || other.maxPoints == maxPoints)&&(identical(other.maxLengthM, maxLengthM) || other.maxLengthM == maxLengthM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,maxPoints,maxLengthM);
}

@override
String toString() {
    return 'Limits(maxPoints: $maxPoints, maxLengthM: $maxLengthM)';
}


}

/// @nodoc
abstract mixin class _$LimitsCopyWith<$Res> implements $LimitsCopyWith<$Res> {
  factory _$LimitsCopyWith(_Limits value, $Res Function(_Limits) _then) = __$LimitsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'max_points') int? maxPoints,@JsonKey(name: 'max_length_m') double? maxLengthM
});




}
/// @nodoc
class __$LimitsCopyWithImpl<$Res>
    implements _$LimitsCopyWith<$Res> {
  __$LimitsCopyWithImpl(this._self, this._then);

  final _Limits _self;
  final $Res Function(_Limits) _then;

/// Create a copy of Limits
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? maxPoints = freezed,Object? maxLengthM = freezed,}) {
  return _then(_Limits(
maxPoints: freezed == maxPoints ? _self.maxPoints : maxPoints // ignore: cast_nullable_to_non_nullable
as int?,maxLengthM: freezed == maxLengthM ? _self.maxLengthM : maxLengthM // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
