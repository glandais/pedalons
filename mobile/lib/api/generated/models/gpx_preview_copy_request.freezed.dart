// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gpx_preview_copy_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GpxPreviewCopyRequest {

/// Name of the copy
 String get name;
/// Create a copy of GpxPreviewCopyRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GpxPreviewCopyRequestCopyWith<GpxPreviewCopyRequest> get copyWith => _$GpxPreviewCopyRequestCopyWithImpl<GpxPreviewCopyRequest>(this as GpxPreviewCopyRequest, _$identity);

  /// Serializes this GpxPreviewCopyRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GpxPreviewCopyRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GpxPreviewCopyRequest&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GpxPreviewCopyRequest;
  return Object.hash(runtimeType,_this.name);
}

@override
String toString() {
  final _this = this as GpxPreviewCopyRequest;
  return 'GpxPreviewCopyRequest(name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $GpxPreviewCopyRequestCopyWith<$Res>  {
  factory $GpxPreviewCopyRequestCopyWith(GpxPreviewCopyRequest value, $Res Function(GpxPreviewCopyRequest) _then) = _$GpxPreviewCopyRequestCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$GpxPreviewCopyRequestCopyWithImpl<$Res>
    implements $GpxPreviewCopyRequestCopyWith<$Res> {
  _$GpxPreviewCopyRequestCopyWithImpl(this._self, this._then);

  final GpxPreviewCopyRequest _self;
  final $Res Function(GpxPreviewCopyRequest) _then;

/// Create a copy of GpxPreviewCopyRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,}) {
  return _then(GpxPreviewCopyRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [GpxPreviewCopyRequest].
extension GpxPreviewCopyRequestPatterns on GpxPreviewCopyRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GpxPreviewCopyRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GpxPreviewCopyRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GpxPreviewCopyRequest value)  $default,){
final _that = this;
switch (_that) {
case _GpxPreviewCopyRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GpxPreviewCopyRequest value)?  $default,){
final _that = this;
switch (_that) {
case _GpxPreviewCopyRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GpxPreviewCopyRequest() when $default != null:
return $default(_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name)  $default,) {final _that = this;
switch (_that) {
case _GpxPreviewCopyRequest():
return $default(_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name)?  $default,) {final _that = this;
switch (_that) {
case _GpxPreviewCopyRequest() when $default != null:
return $default(_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GpxPreviewCopyRequest implements GpxPreviewCopyRequest {
  const _GpxPreviewCopyRequest({required this.name});
  factory _GpxPreviewCopyRequest.fromJson(Map<String, dynamic> json) => _$GpxPreviewCopyRequestFromJson(json);

/// Name of the copy
@override final  String name;

/// Create a copy of GpxPreviewCopyRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GpxPreviewCopyRequestCopyWith<_GpxPreviewCopyRequest> get copyWith => __$GpxPreviewCopyRequestCopyWithImpl<_GpxPreviewCopyRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GpxPreviewCopyRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GpxPreviewCopyRequest&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'GpxPreviewCopyRequest(name: $name)';
}


}

/// @nodoc
abstract mixin class _$GpxPreviewCopyRequestCopyWith<$Res> implements $GpxPreviewCopyRequestCopyWith<$Res> {
  factory _$GpxPreviewCopyRequestCopyWith(_GpxPreviewCopyRequest value, $Res Function(_GpxPreviewCopyRequest) _then) = __$GpxPreviewCopyRequestCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class __$GpxPreviewCopyRequestCopyWithImpl<$Res>
    implements _$GpxPreviewCopyRequestCopyWith<$Res> {
  __$GpxPreviewCopyRequestCopyWithImpl(this._self, this._then);

  final _GpxPreviewCopyRequest _self;
  final $Res Function(_GpxPreviewCopyRequest) _then;

/// Create a copy of GpxPreviewCopyRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(_GpxPreviewCopyRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
