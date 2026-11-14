// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'o_auth_token_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OAuthTokenResponse _$OAuthTokenResponseFromJson(Map<String, dynamic> json) =>
    _OAuthTokenResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
      refreshToken: json['refresh_token'] as String?,
    );

Map<String, dynamic> _$OAuthTokenResponseToJson(_OAuthTokenResponse instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'token_type': instance.tokenType,
      'expires_in': instance.expiresIn,
      'refresh_token': instance.refreshToken,
    };
