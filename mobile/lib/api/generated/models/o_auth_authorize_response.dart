// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'o_auth_authorize_response.freezed.dart';
part 'o_auth_authorize_response.g.dart';

/// Where the site sends the browser once an OAuth 2.0 request is approved
@Freezed()
abstract class OAuthAuthorizeResponse with _$OAuthAuthorizeResponse {
  const factory OAuthAuthorizeResponse({
    /// The application's redirect_uri, carrying the authorization code and the state
    required String redirectUri,
  }) = _OAuthAuthorizeResponse;

  factory OAuthAuthorizeResponse.fromJson(Map<String, Object?> json) =>
      _$OAuthAuthorizeResponseFromJson(json);
}
