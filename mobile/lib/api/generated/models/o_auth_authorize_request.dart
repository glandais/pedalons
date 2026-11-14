// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'o_auth_authorize_request.freezed.dart';
part 'o_auth_authorize_request.g.dart';

/// Approval of an OAuth 2.0 authorization request by the signed-in user
@Freezed()
abstract class OAuthAuthorizeRequest with _$OAuthAuthorizeRequest {
  const factory OAuthAuthorizeRequest({
    /// The name the application gave itself (client_id). Free text: applications are not registered.
    required String clientId,

    /// Where the code is sent (redirect_uri): any absolute URL or deep link, without a fragment. Not checked against anything.
    required String redirectUri,

    /// PKCE challenge (code_challenge): BASE64URL(SHA-256(code_verifier))
    required String codeChallenge,

    /// PKCE method (code_challenge_method): S256 only
    required String codeChallengeMethod,

    /// Must be true: the user explicitly confirmed, on a screen naming the application and where the code goes
    required bool confirmed,

    /// Opaque value given back to the application with the code (state)
    String? state,
  }) = _OAuthAuthorizeRequest;

  factory OAuthAuthorizeRequest.fromJson(Map<String, Object?> json) =>
      _$OAuthAuthorizeRequestFromJson(json);
}
