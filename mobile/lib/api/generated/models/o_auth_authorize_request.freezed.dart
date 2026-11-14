// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'o_auth_authorize_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OAuthAuthorizeRequest {

/// The name the application gave itself (client_id). Free text: applications are not registered.
 String get clientId;/// Where the code is sent (redirect_uri): any absolute URL or deep link, without a fragment. Not checked against anything.
 String get redirectUri;/// PKCE challenge (code_challenge): BASE64URL(SHA-256(code_verifier))
 String get codeChallenge;/// PKCE method (code_challenge_method): S256 only
 String get codeChallengeMethod;/// Must be true: the user explicitly confirmed, on a screen naming the application and where the code goes
 bool get confirmed;/// Opaque value given back to the application with the code (state)
 String? get state;
/// Create a copy of OAuthAuthorizeRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OAuthAuthorizeRequestCopyWith<OAuthAuthorizeRequest> get copyWith => _$OAuthAuthorizeRequestCopyWithImpl<OAuthAuthorizeRequest>(this as OAuthAuthorizeRequest, _$identity);

  /// Serializes this OAuthAuthorizeRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OAuthAuthorizeRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OAuthAuthorizeRequest&&(identical(other.clientId, _this.clientId) || other.clientId == _this.clientId)&&(identical(other.redirectUri, _this.redirectUri) || other.redirectUri == _this.redirectUri)&&(identical(other.codeChallenge, _this.codeChallenge) || other.codeChallenge == _this.codeChallenge)&&(identical(other.codeChallengeMethod, _this.codeChallengeMethod) || other.codeChallengeMethod == _this.codeChallengeMethod)&&(identical(other.confirmed, _this.confirmed) || other.confirmed == _this.confirmed)&&(identical(other.state, _this.state) || other.state == _this.state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OAuthAuthorizeRequest;
  return Object.hash(runtimeType,_this.clientId,_this.redirectUri,_this.codeChallenge,_this.codeChallengeMethod,_this.confirmed,_this.state);
}

@override
String toString() {
  final _this = this as OAuthAuthorizeRequest;
  return 'OAuthAuthorizeRequest(clientId: ${_this.clientId}, redirectUri: ${_this.redirectUri}, codeChallenge: ${_this.codeChallenge}, codeChallengeMethod: ${_this.codeChallengeMethod}, confirmed: ${_this.confirmed}, state: ${_this.state})';
}


}

/// @nodoc
abstract mixin class $OAuthAuthorizeRequestCopyWith<$Res>  {
  factory $OAuthAuthorizeRequestCopyWith(OAuthAuthorizeRequest value, $Res Function(OAuthAuthorizeRequest) _then) = _$OAuthAuthorizeRequestCopyWithImpl;
@useResult
$Res call({
 String clientId, String redirectUri, String codeChallenge, String codeChallengeMethod, bool confirmed, String? state
});




}
/// @nodoc
class _$OAuthAuthorizeRequestCopyWithImpl<$Res>
    implements $OAuthAuthorizeRequestCopyWith<$Res> {
  _$OAuthAuthorizeRequestCopyWithImpl(this._self, this._then);

  final OAuthAuthorizeRequest _self;
  final $Res Function(OAuthAuthorizeRequest) _then;

/// Create a copy of OAuthAuthorizeRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? clientId = null,Object? redirectUri = null,Object? codeChallenge = null,Object? codeChallengeMethod = null,Object? confirmed = null,Object? state = freezed,}) {
  return _then(OAuthAuthorizeRequest(
clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,redirectUri: null == redirectUri ? _self.redirectUri : redirectUri // ignore: cast_nullable_to_non_nullable
as String,codeChallenge: null == codeChallenge ? _self.codeChallenge : codeChallenge // ignore: cast_nullable_to_non_nullable
as String,codeChallengeMethod: null == codeChallengeMethod ? _self.codeChallengeMethod : codeChallengeMethod // ignore: cast_nullable_to_non_nullable
as String,confirmed: null == confirmed ? _self.confirmed : confirmed // ignore: cast_nullable_to_non_nullable
as bool,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OAuthAuthorizeRequest].
extension OAuthAuthorizeRequestPatterns on OAuthAuthorizeRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OAuthAuthorizeRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OAuthAuthorizeRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OAuthAuthorizeRequest value)  $default,){
final _that = this;
switch (_that) {
case _OAuthAuthorizeRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OAuthAuthorizeRequest value)?  $default,){
final _that = this;
switch (_that) {
case _OAuthAuthorizeRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String clientId,  String redirectUri,  String codeChallenge,  String codeChallengeMethod,  bool confirmed,  String? state)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OAuthAuthorizeRequest() when $default != null:
return $default(_that.clientId,_that.redirectUri,_that.codeChallenge,_that.codeChallengeMethod,_that.confirmed,_that.state);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String clientId,  String redirectUri,  String codeChallenge,  String codeChallengeMethod,  bool confirmed,  String? state)  $default,) {final _that = this;
switch (_that) {
case _OAuthAuthorizeRequest():
return $default(_that.clientId,_that.redirectUri,_that.codeChallenge,_that.codeChallengeMethod,_that.confirmed,_that.state);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String clientId,  String redirectUri,  String codeChallenge,  String codeChallengeMethod,  bool confirmed,  String? state)?  $default,) {final _that = this;
switch (_that) {
case _OAuthAuthorizeRequest() when $default != null:
return $default(_that.clientId,_that.redirectUri,_that.codeChallenge,_that.codeChallengeMethod,_that.confirmed,_that.state);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OAuthAuthorizeRequest implements OAuthAuthorizeRequest {
  const _OAuthAuthorizeRequest({required this.clientId, required this.redirectUri, required this.codeChallenge, required this.codeChallengeMethod, required this.confirmed, this.state});
  factory _OAuthAuthorizeRequest.fromJson(Map<String, dynamic> json) => _$OAuthAuthorizeRequestFromJson(json);

/// The name the application gave itself (client_id). Free text: applications are not registered.
@override final  String clientId;
/// Where the code is sent (redirect_uri): any absolute URL or deep link, without a fragment. Not checked against anything.
@override final  String redirectUri;
/// PKCE challenge (code_challenge): BASE64URL(SHA-256(code_verifier))
@override final  String codeChallenge;
/// PKCE method (code_challenge_method): S256 only
@override final  String codeChallengeMethod;
/// Must be true: the user explicitly confirmed, on a screen naming the application and where the code goes
@override final  bool confirmed;
/// Opaque value given back to the application with the code (state)
@override final  String? state;

/// Create a copy of OAuthAuthorizeRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OAuthAuthorizeRequestCopyWith<_OAuthAuthorizeRequest> get copyWith => __$OAuthAuthorizeRequestCopyWithImpl<_OAuthAuthorizeRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OAuthAuthorizeRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OAuthAuthorizeRequest&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.redirectUri, redirectUri) || other.redirectUri == redirectUri)&&(identical(other.codeChallenge, codeChallenge) || other.codeChallenge == codeChallenge)&&(identical(other.codeChallengeMethod, codeChallengeMethod) || other.codeChallengeMethod == codeChallengeMethod)&&(identical(other.confirmed, confirmed) || other.confirmed == confirmed)&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,clientId,redirectUri,codeChallenge,codeChallengeMethod,confirmed,state);
}

@override
String toString() {
    return 'OAuthAuthorizeRequest(clientId: $clientId, redirectUri: $redirectUri, codeChallenge: $codeChallenge, codeChallengeMethod: $codeChallengeMethod, confirmed: $confirmed, state: $state)';
}


}

/// @nodoc
abstract mixin class _$OAuthAuthorizeRequestCopyWith<$Res> implements $OAuthAuthorizeRequestCopyWith<$Res> {
  factory _$OAuthAuthorizeRequestCopyWith(_OAuthAuthorizeRequest value, $Res Function(_OAuthAuthorizeRequest) _then) = __$OAuthAuthorizeRequestCopyWithImpl;
@override @useResult
$Res call({
 String clientId, String redirectUri, String codeChallenge, String codeChallengeMethod, bool confirmed, String? state
});




}
/// @nodoc
class __$OAuthAuthorizeRequestCopyWithImpl<$Res>
    implements _$OAuthAuthorizeRequestCopyWith<$Res> {
  __$OAuthAuthorizeRequestCopyWithImpl(this._self, this._then);

  final _OAuthAuthorizeRequest _self;
  final $Res Function(_OAuthAuthorizeRequest) _then;

/// Create a copy of OAuthAuthorizeRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? clientId = null,Object? redirectUri = null,Object? codeChallenge = null,Object? codeChallengeMethod = null,Object? confirmed = null,Object? state = freezed,}) {
  return _then(_OAuthAuthorizeRequest(
clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,redirectUri: null == redirectUri ? _self.redirectUri : redirectUri // ignore: cast_nullable_to_non_nullable
as String,codeChallenge: null == codeChallenge ? _self.codeChallenge : codeChallenge // ignore: cast_nullable_to_non_nullable
as String,codeChallengeMethod: null == codeChallengeMethod ? _self.codeChallengeMethod : codeChallengeMethod // ignore: cast_nullable_to_non_nullable
as String,confirmed: null == confirmed ? _self.confirmed : confirmed // ignore: cast_nullable_to_non_nullable
as bool,state: freezed == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
