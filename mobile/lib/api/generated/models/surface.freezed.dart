// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'surface.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Surface {

@JsonKey(name: 'class') String? get classField; String? get detail; String? get source;
/// Create a copy of Surface
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SurfaceCopyWith<Surface> get copyWith => _$SurfaceCopyWithImpl<Surface>(this as Surface, _$identity);

  /// Serializes this Surface to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Surface;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Surface&&(identical(other.classField, _this.classField) || other.classField == _this.classField)&&(identical(other.detail, _this.detail) || other.detail == _this.detail)&&(identical(other.source, _this.source) || other.source == _this.source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Surface;
  return Object.hash(runtimeType,_this.classField,_this.detail,_this.source);
}

@override
String toString() {
  final _this = this as Surface;
  return 'Surface(classField: ${_this.classField}, detail: ${_this.detail}, source: ${_this.source})';
}


}

/// @nodoc
abstract mixin class $SurfaceCopyWith<$Res>  {
  factory $SurfaceCopyWith(Surface value, $Res Function(Surface) _then) = _$SurfaceCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'class') String? classField, String? detail, String? source
});




}
/// @nodoc
class _$SurfaceCopyWithImpl<$Res>
    implements $SurfaceCopyWith<$Res> {
  _$SurfaceCopyWithImpl(this._self, this._then);

  final Surface _self;
  final $Res Function(Surface) _then;

/// Create a copy of Surface
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? classField = freezed,Object? detail = freezed,Object? source = freezed,}) {
  return _then(Surface(
classField: freezed == classField ? _self.classField : classField // ignore: cast_nullable_to_non_nullable
as String?,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Surface].
extension SurfacePatterns on Surface {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Surface value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Surface() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Surface value)  $default,){
final _that = this;
switch (_that) {
case _Surface():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Surface value)?  $default,){
final _that = this;
switch (_that) {
case _Surface() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'class')  String? classField,  String? detail,  String? source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Surface() when $default != null:
return $default(_that.classField,_that.detail,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'class')  String? classField,  String? detail,  String? source)  $default,) {final _that = this;
switch (_that) {
case _Surface():
return $default(_that.classField,_that.detail,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'class')  String? classField,  String? detail,  String? source)?  $default,) {final _that = this;
switch (_that) {
case _Surface() when $default != null:
return $default(_that.classField,_that.detail,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Surface implements Surface {
  const _Surface({@JsonKey(name: 'class') this.classField, this.detail, this.source});
  factory _Surface.fromJson(Map<String, dynamic> json) => _$SurfaceFromJson(json);

@override@JsonKey(name: 'class') final  String? classField;
@override final  String? detail;
@override final  String? source;

/// Create a copy of Surface
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SurfaceCopyWith<_Surface> get copyWith => __$SurfaceCopyWithImpl<_Surface>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SurfaceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Surface&&(identical(other.classField, classField) || other.classField == classField)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,classField,detail,source);
}

@override
String toString() {
    return 'Surface(classField: $classField, detail: $detail, source: $source)';
}


}

/// @nodoc
abstract mixin class _$SurfaceCopyWith<$Res> implements $SurfaceCopyWith<$Res> {
  factory _$SurfaceCopyWith(_Surface value, $Res Function(_Surface) _then) = __$SurfaceCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'class') String? classField, String? detail, String? source
});




}
/// @nodoc
class __$SurfaceCopyWithImpl<$Res>
    implements _$SurfaceCopyWith<$Res> {
  __$SurfaceCopyWithImpl(this._self, this._then);

  final _Surface _self;
  final $Res Function(_Surface) _then;

/// Create a copy of Surface
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? classField = freezed,Object? detail = freezed,Object? source = freezed,}) {
  return _then(_Surface(
classField: freezed == classField ? _self.classField : classField // ignore: cast_nullable_to_non_nullable
as String?,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
