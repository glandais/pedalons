// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'o_auth_token_response.freezed.dart';
part 'o_auth_token_response.g.dart';

/// OAuth 2.0 token response (RFC 6749 §5.1)
@Freezed()
abstract class OAuthTokenResponse with _$OAuthTokenResponse {
  const factory OAuthTokenResponse({
    /// Access token, sent as « Authorization: Bearer … » on every API call
    @JsonKey(name: 'access_token') required String accessToken,

    /// Always 'Bearer'
    @JsonKey(name: 'token_type') required String tokenType,

    /// Lifetime of the access token, in seconds
    @JsonKey(name: 'expires_in') required int expiresIn,

    /// Refresh token, to keep in place of the one presented: it rotates at every refresh. Absent when the refresh came within the grace of a rotation made by another one — keep the token already held.
    @JsonKey(name: 'refresh_token') String? refreshToken,
  }) = _OAuthTokenResponse;

  factory OAuthTokenResponse.fromJson(Map<String, Object?> json) =>
      _$OAuthTokenResponseFromJson(json);
}
