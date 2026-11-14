// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'o_auth_authorize_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OAuthAuthorizeResponse {

/// The application's redirect_uri, carrying the authorization code and the state
 String get redirectUri;
/// Create a copy of OAuthAuthorizeResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OAuthAuthorizeResponseCopyWith<OAuthAuthorizeResponse> get copyWith => _$OAuthAuthorizeResponseCopyWithImpl<OAuthAuthorizeResponse>(this as OAuthAuthorizeResponse, _$identity);

  /// Serializes this OAuthAuthorizeResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OAuthAuthorizeResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OAuthAuthorizeResponse&&(identical(other.redirectUri, _this.redirectUri) || other.redirectUri == _this.redirectUri));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OAuthAuthorizeResponse;
  return Object.hash(runtimeType,_this.redirectUri);
}

@override
String toString() {
  final _this = this as OAuthAuthorizeResponse;
  return 'OAuthAuthorizeResponse(redirectUri: ${_this.redirectUri})';
}


}

/// @nodoc
abstract mixin class $OAuthAuthorizeResponseCopyWith<$Res>  {
  factory $OAuthAuthorizeResponseCopyWith(OAuthAuthorizeResponse value, $Res Function(OAuthAuthorizeResponse) _then) = _$OAuthAuthorizeResponseCopyWithImpl;
@useResult
$Res call({
 String redirectUri
});




}
/// @nodoc
class _$OAuthAuthorizeResponseCopyWithImpl<$Res>
    implements $OAuthAuthorizeResponseCopyWith<$Res> {
  _$OAuthAuthorizeResponseCopyWithImpl(this._self, this._then);

  final OAuthAuthorizeResponse _self;
  final $Res Function(OAuthAuthorizeResponse) _then;

/// Create a copy of OAuthAuthorizeResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? redirectUri = null,}) {
  return _then(OAuthAuthorizeResponse(
redirectUri: null == redirectUri ? _self.redirectUri : redirectUri // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OAuthAuthorizeResponse].
extension OAuthAuthorizeResponsePatterns on OAuthAuthorizeResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OAuthAuthorizeResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OAuthAuthorizeResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OAuthAuthorizeResponse value)  $default,){
final _that = this;
switch (_that) {
case _OAuthAuthorizeResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OAuthAuthorizeResponse value)?  $default,){
final _that = this;
switch (_that) {
case _OAuthAuthorizeResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String redirectUri)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OAuthAuthorizeResponse() when $default != null:
return $default(_that.redirectUri);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String redirectUri)  $default,) {final _that = this;
switch (_that) {
case _OAuthAuthorizeResponse():
return $default(_that.redirectUri);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String redirectUri)?  $default,) {final _that = this;
switch (_that) {
case _OAuthAuthorizeResponse() when $default != null:
return $default(_that.redirectUri);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OAuthAuthorizeResponse implements OAuthAuthorizeResponse {
  const _OAuthAuthorizeResponse({required this.redirectUri});
  factory _OAuthAuthorizeResponse.fromJson(Map<String, dynamic> json) => _$OAuthAuthorizeResponseFromJson(json);

/// The application's redirect_uri, carrying the authorization code and the state
@override final  String redirectUri;

/// Create a copy of OAuthAuthorizeResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OAuthAuthorizeResponseCopyWith<_OAuthAuthorizeResponse> get copyWith => __$OAuthAuthorizeResponseCopyWithImpl<_OAuthAuthorizeResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OAuthAuthorizeResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OAuthAuthorizeResponse&&(identical(other.redirectUri, redirectUri) || other.redirectUri == redirectUri));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,redirectUri);
}

@override
String toString() {
    return 'OAuthAuthorizeResponse(redirectUri: $redirectUri)';
}


}

/// @nodoc
abstract mixin class _$OAuthAuthorizeResponseCopyWith<$Res> implements $OAuthAuthorizeResponseCopyWith<$Res> {
  factory _$OAuthAuthorizeResponseCopyWith(_OAuthAuthorizeResponse value, $Res Function(_OAuthAuthorizeResponse) _then) = __$OAuthAuthorizeResponseCopyWithImpl;
@override @useResult
$Res call({
 String redirectUri
});




}
/// @nodoc
class __$OAuthAuthorizeResponseCopyWithImpl<$Res>
    implements _$OAuthAuthorizeResponseCopyWith<$Res> {
  __$OAuthAuthorizeResponseCopyWithImpl(this._self, this._then);

  final _OAuthAuthorizeResponse _self;
  final $Res Function(_OAuthAuthorizeResponse) _then;

/// Create a copy of OAuthAuthorizeResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? redirectUri = null,}) {
  return _then(_OAuthAuthorizeResponse(
redirectUri: null == redirectUri ? _self.redirectUri : redirectUri // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
