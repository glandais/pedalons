// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/o_auth_authorize_request.dart';
import '../models/o_auth_authorize_response.dart';
import '../models/o_auth_token_response.dart';
import '../models/oauth_token_request.dart';

part 'o_auth_client.g.dart';

@RestApi()
abstract class OAuthClient {
  factory OAuthClient(Dio dio, {String? baseUrl}) = _OAuthClient;

  /// Approve an OAuth authorization request.
  ///
  /// Called by the site's consent screen once the signed-in user pressed « Autoriser »: mints a single-use authorization code and returns the redirect_uri to send the browser to. Not for applications — they send the browser to /oauth/authorize.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/oauth/authorize')
  Future<OAuthAuthorizeResponse> oauthAuthorize({
    @Body() required OAuthAuthorizeRequest body,
  });

  /// Exchange an authorization code, or refresh an access token.
  ///
  /// The OAuth 2.0 token endpoint (RFC 6749 §3.2), form-encoded. grant_type=authorization_code takes code, client_id, redirect_uri (both as sent to /oauth/authorize) and code_verifier (PKCE); a code is good once, for five minutes. grant_type=refresh_token takes refresh_token, which rotates: keep the one of the answer. Access tokens last 15 minutes, a refresh token 90 days after its last use, until the user revokes the application from their profile.
  @FormUrlEncoded()
  @POST('/api/oauth/token')
  Future<OAuthTokenResponse> oauthToken({
    @Body() required OauthTokenRequest body,
  });
}
