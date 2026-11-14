// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'oauth_token_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OauthTokenRequest {

@JsonKey(name: 'grant_type') String? get grantType; String? get code;@JsonKey(name: 'client_id') String? get clientId;@JsonKey(name: 'redirect_uri') String? get redirectUri;@JsonKey(name: 'code_verifier') String? get codeVerifier;@JsonKey(name: 'refresh_token') String? get refreshToken;
/// Create a copy of OauthTokenRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OauthTokenRequestCopyWith<OauthTokenRequest> get copyWith => _$OauthTokenRequestCopyWithImpl<OauthTokenRequest>(this as OauthTokenRequest, _$identity);

  /// Serializes this OauthTokenRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OauthTokenRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OauthTokenRequest&&(identical(other.grantType, _this.grantType) || other.grantType == _this.grantType)&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.clientId, _this.clientId) || other.clientId == _this.clientId)&&(identical(other.redirectUri, _this.redirectUri) || other.redirectUri == _this.redirectUri)&&(identical(other.codeVerifier, _this.codeVerifier) || other.codeVerifier == _this.codeVerifier)&&(identical(other.refreshToken, _this.refreshToken) || other.refreshToken == _this.refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OauthTokenRequest;
  return Object.hash(runtimeType,_this.grantType,_this.code,_this.clientId,_this.redirectUri,_this.codeVerifier,_this.refreshToken);
}

@override
String toString() {
  final _this = this as OauthTokenRequest;
  return 'OauthTokenRequest(grantType: ${_this.grantType}, code: ${_this.code}, clientId: ${_this.clientId}, redirectUri: ${_this.redirectUri}, codeVerifier: ${_this.codeVerifier}, refreshToken: ${_this.refreshToken})';
}


}

/// @nodoc
abstract mixin class $OauthTokenRequestCopyWith<$Res>  {
  factory $OauthTokenRequestCopyWith(OauthTokenRequest value, $Res Function(OauthTokenRequest) _then) = _$OauthTokenRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'grant_type') String? grantType, String? code,@JsonKey(name: 'client_id') String? clientId,@JsonKey(name: 'redirect_uri') String? redirectUri,@JsonKey(name: 'code_verifier') String? codeVerifier,@JsonKey(name: 'refresh_token') String? refreshToken
});




}
/// @nodoc
class _$OauthTokenRequestCopyWithImpl<$Res>
    implements $OauthTokenRequestCopyWith<$Res> {
  _$OauthTokenRequestCopyWithImpl(this._self, this._then);

  final OauthTokenRequest _self;
  final $Res Function(OauthTokenRequest) _then;

/// Create a copy of OauthTokenRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? grantType = freezed,Object? code = freezed,Object? clientId = freezed,Object? redirectUri = freezed,Object? codeVerifier = freezed,Object? refreshToken = freezed,}) {
  return _then(OauthTokenRequest(
grantType: freezed == grantType ? _self.grantType : grantType // ignore: cast_nullable_to_non_nullable
as String?,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,redirectUri: freezed == redirectUri ? _self.redirectUri : redirectUri // ignore: cast_nullable_to_non_nullable
as String?,codeVerifier: freezed == codeVerifier ? _self.codeVerifier : codeVerifier // ignore: cast_nullable_to_non_nullable
as String?,refreshToken: freezed == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OauthTokenRequest].
extension OauthTokenRequestPatterns on OauthTokenRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OauthTokenRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OauthTokenRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OauthTokenRequest value)  $default,){
final _that = this;
switch (_that) {
case _OauthTokenRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OauthTokenRequest value)?  $default,){
final _that = this;
switch (_that) {
case _OauthTokenRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'grant_type')  String? grantType,  String? code, @JsonKey(name: 'client_id')  String? clientId, @JsonKey(name: 'redirect_uri')  String? redirectUri, @JsonKey(name: 'code_verifier')  String? codeVerifier, @JsonKey(name: 'refresh_token')  String? refreshToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OauthTokenRequest() when $default != null:
return $default(_that.grantType,_that.code,_that.clientId,_that.redirectUri,_that.codeVerifier,_that.refreshToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'grant_type')  String? grantType,  String? code, @JsonKey(name: 'client_id')  String? clientId, @JsonKey(name: 'redirect_uri')  String? redirectUri, @JsonKey(name: 'code_verifier')  String? codeVerifier, @JsonKey(name: 'refresh_token')  String? refreshToken)  $default,) {final _that = this;
switch (_that) {
case _OauthTokenRequest():
return $default(_that.grantType,_that.code,_that.clientId,_that.redirectUri,_that.codeVerifier,_that.refreshToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'grant_type')  String? grantType,  String? code, @JsonKey(name: 'client_id')  String? clientId, @JsonKey(name: 'redirect_uri')  String? redirectUri, @JsonKey(name: 'code_verifier')  String? codeVerifier, @JsonKey(name: 'refresh_token')  String? refreshToken)?  $default,) {final _that = this;
switch (_that) {
case _OauthTokenRequest() when $default != null:
return $default(_that.grantType,_that.code,_that.clientId,_that.redirectUri,_that.codeVerifier,_that.refreshToken);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OauthTokenRequest implements OauthTokenRequest {
  const _OauthTokenRequest({@JsonKey(name: 'grant_type') this.grantType, this.code, @JsonKey(name: 'client_id') this.clientId, @JsonKey(name: 'redirect_uri') this.redirectUri, @JsonKey(name: 'code_verifier') this.codeVerifier, @JsonKey(name: 'refresh_token') this.refreshToken});
  factory _OauthTokenRequest.fromJson(Map<String, dynamic> json) => _$OauthTokenRequestFromJson(json);

@override@JsonKey(name: 'grant_type') final  String? grantType;
@override final  String? code;
@override@JsonKey(name: 'client_id') final  String? clientId;
@override@JsonKey(name: 'redirect_uri') final  String? redirectUri;
@override@JsonKey(name: 'code_verifier') final  String? codeVerifier;
@override@JsonKey(name: 'refresh_token') final  String? refreshToken;

/// Create a copy of OauthTokenRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OauthTokenRequestCopyWith<_OauthTokenRequest> get copyWith => __$OauthTokenRequestCopyWithImpl<_OauthTokenRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OauthTokenRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OauthTokenRequest&&(identical(other.grantType, grantType) || other.grantType == grantType)&&(identical(other.code, code) || other.code == code)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.redirectUri, redirectUri) || other.redirectUri == redirectUri)&&(identical(other.codeVerifier, codeVerifier) || other.codeVerifier == codeVerifier)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,grantType,code,clientId,redirectUri,codeVerifier,refreshToken);
}

@override
String toString() {
    return 'OauthTokenRequest(grantType: $grantType, code: $code, clientId: $clientId, redirectUri: $redirectUri, codeVerifier: $codeVerifier, refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class _$OauthTokenRequestCopyWith<$Res> implements $OauthTokenRequestCopyWith<$Res> {
  factory _$OauthTokenRequestCopyWith(_OauthTokenRequest value, $Res Function(_OauthTokenRequest) _then) = __$OauthTokenRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'grant_type') String? grantType, String? code,@JsonKey(name: 'client_id') String? clientId,@JsonKey(name: 'redirect_uri') String? redirectUri,@JsonKey(name: 'code_verifier') String? codeVerifier,@JsonKey(name: 'refresh_token') String? refreshToken
});




}
/// @nodoc
class __$OauthTokenRequestCopyWithImpl<$Res>
    implements _$OauthTokenRequestCopyWith<$Res> {
  __$OauthTokenRequestCopyWithImpl(this._self, this._then);

  final _OauthTokenRequest _self;
  final $Res Function(_OauthTokenRequest) _then;

/// Create a copy of OauthTokenRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? grantType = freezed,Object? code = freezed,Object? clientId = freezed,Object? redirectUri = freezed,Object? codeVerifier = freezed,Object? refreshToken = freezed,}) {
  return _then(_OauthTokenRequest(
grantType: freezed == grantType ? _self.grantType : grantType // ignore: cast_nullable_to_non_nullable
as String?,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String?,clientId: freezed == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String?,redirectUri: freezed == redirectUri ? _self.redirectUri : redirectUri // ignore: cast_nullable_to_non_nullable
as String?,codeVerifier: freezed == codeVerifier ? _self.codeVerifier : codeVerifier // ignore: cast_nullable_to_non_nullable
as String?,refreshToken: freezed == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
