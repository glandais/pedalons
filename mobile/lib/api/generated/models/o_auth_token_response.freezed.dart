// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'o_auth_token_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OAuthTokenResponse {

/// Access token, sent as « Authorization: Bearer … » on every API call
@JsonKey(name: 'access_token') String get accessToken;/// Always 'Bearer'
@JsonKey(name: 'token_type') String get tokenType;/// Lifetime of the access token, in seconds
@JsonKey(name: 'expires_in') int get expiresIn;/// Refresh token, to keep in place of the one presented: it rotates at every refresh. Absent when the refresh came within the grace of a rotation made by another one — keep the token already held.
@JsonKey(name: 'refresh_token') String? get refreshToken;
/// Create a copy of OAuthTokenResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OAuthTokenResponseCopyWith<OAuthTokenResponse> get copyWith => _$OAuthTokenResponseCopyWithImpl<OAuthTokenResponse>(this as OAuthTokenResponse, _$identity);

  /// Serializes this OAuthTokenResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OAuthTokenResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OAuthTokenResponse&&(identical(other.accessToken, _this.accessToken) || other.accessToken == _this.accessToken)&&(identical(other.tokenType, _this.tokenType) || other.tokenType == _this.tokenType)&&(identical(other.expiresIn, _this.expiresIn) || other.expiresIn == _this.expiresIn)&&(identical(other.refreshToken, _this.refreshToken) || other.refreshToken == _this.refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OAuthTokenResponse;
  return Object.hash(runtimeType,_this.accessToken,_this.tokenType,_this.expiresIn,_this.refreshToken);
}

@override
String toString() {
  final _this = this as OAuthTokenResponse;
  return 'OAuthTokenResponse(accessToken: ${_this.accessToken}, tokenType: ${_this.tokenType}, expiresIn: ${_this.expiresIn}, refreshToken: ${_this.refreshToken})';
}


}

/// @nodoc
abstract mixin class $OAuthTokenResponseCopyWith<$Res>  {
  factory $OAuthTokenResponseCopyWith(OAuthTokenResponse value, $Res Function(OAuthTokenResponse) _then) = _$OAuthTokenResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'access_token') String accessToken,@JsonKey(name: 'token_type') String tokenType,@JsonKey(name: 'expires_in') int expiresIn,@JsonKey(name: 'refresh_token') String? refreshToken
});




}
/// @nodoc
class _$OAuthTokenResponseCopyWithImpl<$Res>
    implements $OAuthTokenResponseCopyWith<$Res> {
  _$OAuthTokenResponseCopyWithImpl(this._self, this._then);

  final OAuthTokenResponse _self;
  final $Res Function(OAuthTokenResponse) _then;

/// Create a copy of OAuthTokenResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accessToken = null,Object? tokenType = null,Object? expiresIn = null,Object? refreshToken = freezed,}) {
  return _then(OAuthTokenResponse(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,tokenType: null == tokenType ? _self.tokenType : tokenType // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int,refreshToken: freezed == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OAuthTokenResponse].
extension OAuthTokenResponsePatterns on OAuthTokenResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OAuthTokenResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OAuthTokenResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OAuthTokenResponse value)  $default,){
final _that = this;
switch (_that) {
case _OAuthTokenResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OAuthTokenResponse value)?  $default,){
final _that = this;
switch (_that) {
case _OAuthTokenResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'access_token')  String accessToken, @JsonKey(name: 'token_type')  String tokenType, @JsonKey(name: 'expires_in')  int expiresIn, @JsonKey(name: 'refresh_token')  String? refreshToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OAuthTokenResponse() when $default != null:
return $default(_that.accessToken,_that.tokenType,_that.expiresIn,_that.refreshToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'access_token')  String accessToken, @JsonKey(name: 'token_type')  String tokenType, @JsonKey(name: 'expires_in')  int expiresIn, @JsonKey(name: 'refresh_token')  String? refreshToken)  $default,) {final _that = this;
switch (_that) {
case _OAuthTokenResponse():
return $default(_that.accessToken,_that.tokenType,_that.expiresIn,_that.refreshToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'access_token')  String accessToken, @JsonKey(name: 'token_type')  String tokenType, @JsonKey(name: 'expires_in')  int expiresIn, @JsonKey(name: 'refresh_token')  String? refreshToken)?  $default,) {final _that = this;
switch (_that) {
case _OAuthTokenResponse() when $default != null:
return $default(_that.accessToken,_that.tokenType,_that.expiresIn,_that.refreshToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OAuthTokenResponse implements OAuthTokenResponse {
  const _OAuthTokenResponse({@JsonKey(name: 'access_token') required this.accessToken, @JsonKey(name: 'token_type') required this.tokenType, @JsonKey(name: 'expires_in') required this.expiresIn, @JsonKey(name: 'refresh_token') this.refreshToken});
  factory _OAuthTokenResponse.fromJson(Map<String, dynamic> json) => _$OAuthTokenResponseFromJson(json);

/// Access token, sent as « Authorization: Bearer … » on every API call
@override@JsonKey(name: 'access_token') final  String accessToken;
/// Always 'Bearer'
@override@JsonKey(name: 'token_type') final  String tokenType;
/// Lifetime of the access token, in seconds
@override@JsonKey(name: 'expires_in') final  int expiresIn;
/// Refresh token, to keep in place of the one presented: it rotates at every refresh. Absent when the refresh came within the grace of a rotation made by another one — keep the token already held.
@override@JsonKey(name: 'refresh_token') final  String? refreshToken;

/// Create a copy of OAuthTokenResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OAuthTokenResponseCopyWith<_OAuthTokenResponse> get copyWith => __$OAuthTokenResponseCopyWithImpl<_OAuthTokenResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OAuthTokenResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OAuthTokenResponse&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.tokenType, tokenType) || other.tokenType == tokenType)&&(identical(other.expiresIn, expiresIn) || other.expiresIn == expiresIn)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,accessToken,tokenType,expiresIn,refreshToken);
}

@override
String toString() {
    return 'OAuthTokenResponse(accessToken: $accessToken, tokenType: $tokenType, expiresIn: $expiresIn, refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class _$OAuthTokenResponseCopyWith<$Res> implements $OAuthTokenResponseCopyWith<$Res> {
  factory _$OAuthTokenResponseCopyWith(_OAuthTokenResponse value, $Res Function(_OAuthTokenResponse) _then) = __$OAuthTokenResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'access_token') String accessToken,@JsonKey(name: 'token_type') String tokenType,@JsonKey(name: 'expires_in') int expiresIn,@JsonKey(name: 'refresh_token') String? refreshToken
});




}
/// @nodoc
class __$OAuthTokenResponseCopyWithImpl<$Res>
    implements _$OAuthTokenResponseCopyWith<$Res> {
  __$OAuthTokenResponseCopyWithImpl(this._self, this._then);

  final _OAuthTokenResponse _self;
  final $Res Function(_OAuthTokenResponse) _then;

/// Create a copy of OAuthTokenResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accessToken = null,Object? tokenType = null,Object? expiresIn = null,Object? refreshToken = freezed,}) {
  return _then(_OAuthTokenResponse(
accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,tokenType: null == tokenType ? _self.tokenType : tokenType // ignore: cast_nullable_to_non_nullable
as String,expiresIn: null == expiresIn ? _self.expiresIn : expiresIn // ignore: cast_nullable_to_non_nullable
as int,refreshToken: freezed == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
