// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/auth_response.dart';
import '../models/passkey_authentication_request.dart';
import '../models/passkey_dto.dart';

part 'passkeys_client.g.dart';

@RestApi()
abstract class PasskeysClient {
  factory PasskeysClient(Dio dio, {String? baseUrl}) = _PasskeysClient;

  /// List passkeys.
  ///
  /// List all passkeys registered for the current user.
  @GET('/api/auth/passkeys')
  Future<List<PasskeyDto>> listPasskeys();

  /// Authenticate with passkey.
  ///
  /// Authenticate using a passkey.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/auth/passkeys/authenticate')
  Future<AuthResponse> authenticate({
    @Body() required Map<String, dynamic> body,
    @Header('X-Forwarded-For') String? xForwardedFor,
    @Header('X-Real-IP') String? xRealIp,
  });

  /// Get authentication options.
  ///
  /// Get WebAuthn options for authenticating with a passkey.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/auth/passkeys/authentication-options')
  Future<void> getAuthenticationOptions({
    @Body() required PasskeyAuthenticationRequest body,
  });

  /// Register passkey.
  ///
  /// Verify and register a new passkey for the current user.
  ///
  /// [body] - Name not received - field will be skipped.
  @POST('/api/auth/passkeys/register')
  Future<PasskeyDto> registerPasskey({
    @Body() required Map<String, dynamic> body,
    @Query('deviceName') String? deviceName,
  });

  /// Get registration options.
  ///
  /// Get WebAuthn options for registering a new passkey.
  @GET('/api/auth/passkeys/registration-options')
  Future<void> getRegistrationOptions();

  /// Delete passkey.
  ///
  /// Delete a passkey.
  @DELETE('/api/auth/passkeys/{id}')
  Future<void> deletePasskey({
    @Path('id') required String id,
  });
}
