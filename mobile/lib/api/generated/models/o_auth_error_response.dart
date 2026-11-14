// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'o_auth_error_response.freezed.dart';
part 'o_auth_error_response.g.dart';

/// OAuth 2.0 token error (RFC 6749 §5.2)
@Freezed()
abstract class OAuthErrorResponse with _$OAuthErrorResponse {
  const factory OAuthErrorResponse({
    /// invalid_request, invalid_grant or unsupported_grant_type
    required String error,

    /// What was wrong, for the developer
    @JsonKey(name: 'error_description') required String errorDescription,
  }) = _OAuthErrorResponse;

  factory OAuthErrorResponse.fromJson(Map<String, Object?> json) =>
      _$OAuthErrorResponseFromJson(json);
}
