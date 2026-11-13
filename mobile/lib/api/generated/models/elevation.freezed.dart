// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'elevation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Elevation {

@JsonKey(name: 'smoothing_m') double? get smoothingM;
/// Create a copy of Elevation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ElevationCopyWith<Elevation> get copyWith => _$ElevationCopyWithImpl<Elevation>(this as Elevation, _$identity);

  /// Serializes this Elevation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Elevation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Elevation&&(identical(other.smoothingM, _this.smoothingM) || other.smoothingM == _this.smoothingM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Elevation;
  return Object.hash(runtimeType,_this.smoothingM);
}

@override
String toString() {
  final _this = this as Elevation;
  return 'Elevation(smoothingM: ${_this.smoothingM})';
}


}

/// @nodoc
abstract mixin class $ElevationCopyWith<$Res>  {
  factory $ElevationCopyWith(Elevation value, $Res Function(Elevation) _then) = _$ElevationCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'smoothing_m') double? smoothingM
});




}
/// @nodoc
class _$ElevationCopyWithImpl<$Res>
    implements $ElevationCopyWith<$Res> {
  _$ElevationCopyWithImpl(this._self, this._then);

  final Elevation _self;
  final $Res Function(Elevation) _then;

/// Create a copy of Elevation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? smoothingM = freezed,}) {
  return _then(Elevation(
smoothingM: freezed == smoothingM ? _self.smoothingM : smoothingM // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [Elevation].
extension ElevationPatterns on Elevation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Elevation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Elevation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Elevation value)  $default,){
final _that = this;
switch (_that) {
case _Elevation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Elevation value)?  $default,){
final _that = this;
switch (_that) {
case _Elevation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'smoothing_m')  double? smoothingM)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Elevation() when $default != null:
return $default(_that.smoothingM);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'smoothing_m')  double? smoothingM)  $default,) {final _that = this;
switch (_that) {
case _Elevation():
return $default(_that.smoothingM);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'smoothing_m')  double? smoothingM)?  $default,) {final _that = this;
switch (_that) {
case _Elevation() when $default != null:
return $default(_that.smoothingM);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Elevation implements Elevation {
  const _Elevation({@JsonKey(name: 'smoothing_m') this.smoothingM});
  factory _Elevation.fromJson(Map<String, dynamic> json) => _$ElevationFromJson(json);

@override@JsonKey(name: 'smoothing_m') final  double? smoothingM;

/// Create a copy of Elevation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ElevationCopyWith<_Elevation> get copyWith => __$ElevationCopyWithImpl<_Elevation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ElevationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Elevation&&(identical(other.smoothingM, smoothingM) || other.smoothingM == smoothingM));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,smoothingM);
}

@override
String toString() {
    return 'Elevation(smoothingM: $smoothingM)';
}


}

/// @nodoc
abstract mixin class _$ElevationCopyWith<$Res> implements $ElevationCopyWith<$Res> {
  factory _$ElevationCopyWith(_Elevation value, $Res Function(_Elevation) _then) = __$ElevationCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'smoothing_m') double? smoothingM
});




}
/// @nodoc
class __$ElevationCopyWithImpl<$Res>
    implements _$ElevationCopyWith<$Res> {
  __$ElevationCopyWithImpl(this._self, this._then);

  final _Elevation _self;
  final $Res Function(_Elevation) _then;

/// Create a copy of Elevation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? smoothingM = freezed,}) {
  return _then(_Elevation(
smoothingM: freezed == smoothingM ? _self.smoothingM : smoothingM // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
