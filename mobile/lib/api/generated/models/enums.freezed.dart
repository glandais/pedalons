// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'enums.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Enums {

 List<String>? get profiles;@JsonKey(name: 'surface_detail') List<String>? get surfaceDetail;
/// Create a copy of Enums
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EnumsCopyWith<Enums> get copyWith => _$EnumsCopyWithImpl<Enums>(this as Enums, _$identity);

  /// Serializes this Enums to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Enums;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Enums&&const DeepCollectionEquality().equals(other.profiles, _this.profiles)&&const DeepCollectionEquality().equals(other.surfaceDetail, _this.surfaceDetail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Enums;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.profiles),const DeepCollectionEquality().hash(_this.surfaceDetail));
}

@override
String toString() {
  final _this = this as Enums;
  return 'Enums(profiles: ${_this.profiles}, surfaceDetail: ${_this.surfaceDetail})';
}


}

/// @nodoc
abstract mixin class $EnumsCopyWith<$Res>  {
  factory $EnumsCopyWith(Enums value, $Res Function(Enums) _then) = _$EnumsCopyWithImpl;
@useResult
$Res call({
 List<String>? profiles,@JsonKey(name: 'surface_detail') List<String>? surfaceDetail
});




}
/// @nodoc
class _$EnumsCopyWithImpl<$Res>
    implements $EnumsCopyWith<$Res> {
  _$EnumsCopyWithImpl(this._self, this._then);

  final Enums _self;
  final $Res Function(Enums) _then;

/// Create a copy of Enums
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profiles = freezed,Object? surfaceDetail = freezed,}) {
  return _then(Enums(
profiles: freezed == profiles ? _self.profiles : profiles // ignore: cast_nullable_to_non_nullable
as List<String>?,surfaceDetail: freezed == surfaceDetail ? _self.surfaceDetail : surfaceDetail // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [Enums].
extension EnumsPatterns on Enums {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Enums value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Enums() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Enums value)  $default,){
final _that = this;
switch (_that) {
case _Enums():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Enums value)?  $default,){
final _that = this;
switch (_that) {
case _Enums() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String>? profiles, @JsonKey(name: 'surface_detail')  List<String>? surfaceDetail)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Enums() when $default != null:
return $default(_that.profiles,_that.surfaceDetail);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String>? profiles, @JsonKey(name: 'surface_detail')  List<String>? surfaceDetail)  $default,) {final _that = this;
switch (_that) {
case _Enums():
return $default(_that.profiles,_that.surfaceDetail);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String>? profiles, @JsonKey(name: 'surface_detail')  List<String>? surfaceDetail)?  $default,) {final _that = this;
switch (_that) {
case _Enums() when $default != null:
return $default(_that.profiles,_that.surfaceDetail);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Enums implements Enums {
  const _Enums({ List<String>? profiles, @JsonKey(name: 'surface_detail')  List<String>? surfaceDetail}): _profiles = profiles,_surfaceDetail = surfaceDetail;
  factory _Enums.fromJson(Map<String, dynamic> json) => _$EnumsFromJson(json);

 final  List<String>? _profiles;
@override List<String>? get profiles {
  final value = _profiles;
  if (value == null) return null;
  if (_profiles is EqualUnmodifiableListView) return _profiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<String>? _surfaceDetail;
@override@JsonKey(name: 'surface_detail') List<String>? get surfaceDetail {
  final value = _surfaceDetail;
  if (value == null) return null;
  if (_surfaceDetail is EqualUnmodifiableListView) return _surfaceDetail;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of Enums
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EnumsCopyWith<_Enums> get copyWith => __$EnumsCopyWithImpl<_Enums>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EnumsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Enums&&const DeepCollectionEquality().equals(other.profiles, _profiles)&&const DeepCollectionEquality().equals(other.surfaceDetail, _surfaceDetail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_profiles),const DeepCollectionEquality().hash(_surfaceDetail));
}

@override
String toString() {
    return 'Enums(profiles: $profiles, surfaceDetail: $surfaceDetail)';
}


}

/// @nodoc
abstract mixin class _$EnumsCopyWith<$Res> implements $EnumsCopyWith<$Res> {
  factory _$EnumsCopyWith(_Enums value, $Res Function(_Enums) _then) = __$EnumsCopyWithImpl;
@override @useResult
$Res call({
 List<String>? profiles,@JsonKey(name: 'surface_detail') List<String>? surfaceDetail
});




}
/// @nodoc
class __$EnumsCopyWithImpl<$Res>
    implements _$EnumsCopyWith<$Res> {
  __$EnumsCopyWithImpl(this._self, this._then);

  final _Enums _self;
  final $Res Function(_Enums) _then;

/// Create a copy of Enums
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profiles = freezed,Object? surfaceDetail = freezed,}) {
  return _then(_Enums(
profiles: freezed == profiles ? _self._profiles : profiles // ignore: cast_nullable_to_non_nullable
as List<String>?,surfaceDetail: freezed == surfaceDetail ? _self._surfaceDetail : surfaceDetail // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}

// dart format on
