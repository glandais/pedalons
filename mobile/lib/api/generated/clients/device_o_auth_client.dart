// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/complete_request.dart';
import '../models/deny_request.dart';
import '../models/device_code_response.dart';
import '../models/device_request.dart';
import '../models/device_token_request.dart';
import '../models/device_token_response.dart';
import '../models/verify_response.dart';

part 'device_o_auth_client.g.dart';

@RestApi()
abstract class DeviceOAuthClient {
  factory DeviceOAuthClient(Dio dio, {String? baseUrl}) = _DeviceOAuthClient;

  /// Complete device authorization.
  ///
  /// Called by frontend after user authenticates via OTP.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/device/oauth/complete')
  Future<void> deviceComplete({
    @Body() required CompleteRequest body,
  });

  /// Deny device authorization.
  ///
  /// The signed-in user refuses to pair the device showing this code: the code expires at once, and the device polling /token is told TOKEN_EXPIRED.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/device/oauth/deny')
  Future<void> deviceDeny({
    @Body() required DenyRequest body,
  });

  /// Request device code.
  ///
  /// Start device code flow - returns user code and verification URL.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/device/oauth/device')
  Future<DeviceCodeResponse> device({
    @Body() required DeviceRequest body,
  });

  /// Exchange code for tokens.
  ///
  /// Exchange device code or refresh token for access tokens. Returns 'authorization_pending' error while waiting for user.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/device/oauth/token')
  Future<DeviceTokenResponse> deviceToken({
    @Body() required DeviceTokenRequest body,
  });

  /// Check user code validity.
  ///
  /// Frontend uses this to verify user code before showing auth flow.
  @GET('/api/device/oauth/verify')
  Future<VerifyResponse> verify({
    @Query('code') String? code,
  });
}
