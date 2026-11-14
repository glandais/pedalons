// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'oauth_token_request.freezed.dart';
part 'oauth_token_request.g.dart';

@Freezed()
abstract class OauthTokenRequest with _$OauthTokenRequest {
  const factory OauthTokenRequest({
    @JsonKey(name: 'grant_type') String? grantType,
    String? code,
    @JsonKey(name: 'client_id') String? clientId,
    @JsonKey(name: 'redirect_uri') String? redirectUri,
    @JsonKey(name: 'code_verifier') String? codeVerifier,
    @JsonKey(name: 'refresh_token') String? refreshToken,
  }) = _OauthTokenRequest;

  factory OauthTokenRequest.fromJson(Map<String, Object?> json) =>
      _$OauthTokenRequestFromJson(json);
}
