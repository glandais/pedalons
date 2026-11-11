// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_duplicate_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteDuplicateRequest {

/// Name of the copy
 String get name;
/// Create a copy of RouteDuplicateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteDuplicateRequestCopyWith<RouteDuplicateRequest> get copyWith => _$RouteDuplicateRequestCopyWithImpl<RouteDuplicateRequest>(this as RouteDuplicateRequest, _$identity);

  /// Serializes this RouteDuplicateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RouteDuplicateRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteDuplicateRequest&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RouteDuplicateRequest;
  return Object.hash(runtimeType,_this.name);
}

@override
String toString() {
  final _this = this as RouteDuplicateRequest;
  return 'RouteDuplicateRequest(name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $RouteDuplicateRequestCopyWith<$Res>  {
  factory $RouteDuplicateRequestCopyWith(RouteDuplicateRequest value, $Res Function(RouteDuplicateRequest) _then) = _$RouteDuplicateRequestCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$RouteDuplicateRequestCopyWithImpl<$Res>
    implements $RouteDuplicateRequestCopyWith<$Res> {
  _$RouteDuplicateRequestCopyWithImpl(this._self, this._then);

  final RouteDuplicateRequest _self;
  final $Res Function(RouteDuplicateRequest) _then;

/// Create a copy of RouteDuplicateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,}) {
  return _then(RouteDuplicateRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteDuplicateRequest].
extension RouteDuplicateRequestPatterns on RouteDuplicateRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteDuplicateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteDuplicateRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteDuplicateRequest value)  $default,){
final _that = this;
switch (_that) {
case _RouteDuplicateRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteDuplicateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _RouteDuplicateRequest() when $default != null:
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
case _RouteDuplicateRequest() when $default != null:
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
case _RouteDuplicateRequest():
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
case _RouteDuplicateRequest() when $default != null:
return $default(_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteDuplicateRequest implements RouteDuplicateRequest {
  const _RouteDuplicateRequest({required this.name});
  factory _RouteDuplicateRequest.fromJson(Map<String, dynamic> json) => _$RouteDuplicateRequestFromJson(json);

/// Name of the copy
@override final  String name;

/// Create a copy of RouteDuplicateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteDuplicateRequestCopyWith<_RouteDuplicateRequest> get copyWith => __$RouteDuplicateRequestCopyWithImpl<_RouteDuplicateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteDuplicateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteDuplicateRequest&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name);
}

@override
String toString() {
    return 'RouteDuplicateRequest(name: $name)';
}


}

/// @nodoc
abstract mixin class _$RouteDuplicateRequestCopyWith<$Res> implements $RouteDuplicateRequestCopyWith<$Res> {
  factory _$RouteDuplicateRequestCopyWith(_RouteDuplicateRequest value, $Res Function(_RouteDuplicateRequest) _then) = __$RouteDuplicateRequestCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class __$RouteDuplicateRequestCopyWithImpl<$Res>
    implements _$RouteDuplicateRequestCopyWith<$Res> {
  __$RouteDuplicateRequestCopyWithImpl(this._self, this._then);

  final _RouteDuplicateRequest _self;
  final $Res Function(_RouteDuplicateRequest) _then;

/// Create a copy of RouteDuplicateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(_RouteDuplicateRequest(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
