// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sampling.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Sampling {

 String? get mode;
/// Create a copy of Sampling
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SamplingCopyWith<Sampling> get copyWith => _$SamplingCopyWithImpl<Sampling>(this as Sampling, _$identity);

  /// Serializes this Sampling to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Sampling;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Sampling&&(identical(other.mode, _this.mode) || other.mode == _this.mode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Sampling;
  return Object.hash(runtimeType,_this.mode);
}

@override
String toString() {
  final _this = this as Sampling;
  return 'Sampling(mode: ${_this.mode})';
}


}

/// @nodoc
abstract mixin class $SamplingCopyWith<$Res>  {
  factory $SamplingCopyWith(Sampling value, $Res Function(Sampling) _then) = _$SamplingCopyWithImpl;
@useResult
$Res call({
 String? mode
});




}
/// @nodoc
class _$SamplingCopyWithImpl<$Res>
    implements $SamplingCopyWith<$Res> {
  _$SamplingCopyWithImpl(this._self, this._then);

  final Sampling _self;
  final $Res Function(Sampling) _then;

/// Create a copy of Sampling
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = freezed,}) {
  return _then(Sampling(
mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Sampling].
extension SamplingPatterns on Sampling {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Sampling value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Sampling() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Sampling value)  $default,){
final _that = this;
switch (_that) {
case _Sampling():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Sampling value)?  $default,){
final _that = this;
switch (_that) {
case _Sampling() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? mode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Sampling() when $default != null:
return $default(_that.mode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? mode)  $default,) {final _that = this;
switch (_that) {
case _Sampling():
return $default(_that.mode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? mode)?  $default,) {final _that = this;
switch (_that) {
case _Sampling() when $default != null:
return $default(_that.mode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Sampling implements Sampling {
  const _Sampling({this.mode});
  factory _Sampling.fromJson(Map<String, dynamic> json) => _$SamplingFromJson(json);

@override final  String? mode;

/// Create a copy of Sampling
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SamplingCopyWith<_Sampling> get copyWith => __$SamplingCopyWithImpl<_Sampling>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SamplingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Sampling&&(identical(other.mode, mode) || other.mode == mode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,mode);
}

@override
String toString() {
    return 'Sampling(mode: $mode)';
}


}

/// @nodoc
abstract mixin class _$SamplingCopyWith<$Res> implements $SamplingCopyWith<$Res> {
  factory _$SamplingCopyWith(_Sampling value, $Res Function(_Sampling) _then) = __$SamplingCopyWithImpl;
@override @useResult
$Res call({
 String? mode
});




}
/// @nodoc
class __$SamplingCopyWithImpl<$Res>
    implements _$SamplingCopyWith<$Res> {
  __$SamplingCopyWithImpl(this._self, this._then);

  final _Sampling _self;
  final $Res Function(_Sampling) _then;

/// Create a copy of Sampling
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = freezed,}) {
  return _then(_Sampling(
mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
