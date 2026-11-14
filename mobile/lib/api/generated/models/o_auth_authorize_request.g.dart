// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'o_auth_authorize_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OAuthAuthorizeRequest _$OAuthAuthorizeRequestFromJson(
  Map<String, dynamic> json,
) => _OAuthAuthorizeRequest(
  clientId: json['clientId'] as String,
  redirectUri: json['redirectUri'] as String,
  codeChallenge: json['codeChallenge'] as String,
  codeChallengeMethod: json['codeChallengeMethod'] as String,
  confirmed: json['confirmed'] as bool,
  state: json['state'] as String?,
);

Map<String, dynamic> _$OAuthAuthorizeRequestToJson(
  _OAuthAuthorizeRequest instance,
) => <String, dynamic>{
  'clientId': instance.clientId,
  'redirectUri': instance.redirectUri,
  'codeChallenge': instance.codeChallenge,
  'codeChallengeMethod': instance.codeChallengeMethod,
  'confirmed': instance.confirmed,
  'state': instance.state,
};
