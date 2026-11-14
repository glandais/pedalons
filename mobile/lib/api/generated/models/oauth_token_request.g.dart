// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oauth_token_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OauthTokenRequest _$OauthTokenRequestFromJson(Map<String, dynamic> json) =>
    _OauthTokenRequest(
      grantType: json['grant_type'] as String?,
      code: json['code'] as String?,
      clientId: json['client_id'] as String?,
      redirectUri: json['redirect_uri'] as String?,
      codeVerifier: json['code_verifier'] as String?,
      refreshToken: json['refresh_token'] as String?,
    );

Map<String, dynamic> _$OauthTokenRequestToJson(_OauthTokenRequest instance) =>
    <String, dynamic>{
      'grant_type': instance.grantType,
      'code': instance.code,
      'client_id': instance.clientId,
      'redirect_uri': instance.redirectUri,
      'code_verifier': instance.codeVerifier,
      'refresh_token': instance.refreshToken,
    };
