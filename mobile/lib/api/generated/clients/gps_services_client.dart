// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;
import 'package:retrofit/retrofit.dart';
import 'package:retrofit/error_logger.dart';

import '../models/gps_auto_sync_request.dart';
import '../models/gps_connect_return.dart';
import '../models/gps_o_auth_url_response.dart';
import '../models/gps_service_connection_dto.dart';
import '../models/gps_service_type.dart';
import '../models/route_upload_response.dart';

part 'gps_services_client.g.dart';

@RestApi()
abstract class GpsServicesClient {
  factory GpsServicesClient(Dio dio, {String? baseUrl}) = _GpsServicesClient;

  /// Get available GPS services.
  ///
  /// Get list of GPS service types configured for this domain.
  @GET('/api/gps/available')
  Future<List<GpsServiceType>> getAvailableServices();

  /// OAuth callback.
  ///
  /// Handles OAuth callback from GPS service and redirects to the frontend page chosen by the returnTo of the connect call (the profile by default). OAuth 2.0 brings code and state; OAuth 1.0a (Garmin, when the domain's credential says so) brings oauth_token and oauth_verifier.
  ///
  /// [serviceType] - GPS service type.
  ///
  /// [oauthToken] - OAuth 1.0a request token.
  ///
  /// [oauthVerifier] - OAuth 1.0a verifier.
  @GET('/api/gps/callback/{serviceType}')
  Future<void> handleCallback({
    @Path('serviceType') required GpsServiceType serviceType,
    @Query('code') String? code,
    @Query('error') String? error,
    @Query('oauth_token') String? oauthToken,
    @Query('oauth_verifier') String? oauthVerifier,
    @Query('state') String? state,
  });

  /// Get OAuth authorization URL.
  ///
  /// Get the OAuth authorization URL to connect a GPS service.
  ///
  /// [serviceType] - GPS service type.
  ///
  /// [returnTo] - Where the OAuth callback sends the browser back to. PROFILE when absent.
  @GET('/api/gps/connect/{serviceType}')
  Future<GpsOAuthUrlResponse> getConnectUrl({
    @Path('serviceType') required GpsServiceType serviceType,
    @Query('returnTo') GpsConnectReturn? returnTo,
  });

  /// Turn the automatic route sync on or off.
  ///
  /// Turns on or off, for one connected service, the automatic sending of the routes of the rides the user is registered in (from 7 days before the departure until a day after it), kept in sync with their changes. Turning it off removes from the service the upcoming routes it sent. A RECONNECT_REQUIRED state is only cleared by connecting the service again.
  ///
  /// [serviceType] - GPS service type.
  ///
  /// [body] - Name not received - field will be skipped.
  @PUT('/api/gps/connections/{serviceType}/auto-sync')
  Future<GpsServiceConnectionDto> setGpsAutoSync({
    @Path('serviceType') required GpsServiceType serviceType,
    @Body() required GpsAutoSyncRequest body,
  });

  /// Disconnect GPS service.
  ///
  /// Disconnect a connected GPS service.
  ///
  /// [serviceType] - GPS service type.
  @DELETE('/api/gps/disconnect/{serviceType}')
  Future<void> disconnect({
    @Path('serviceType') required GpsServiceType serviceType,
  });

  /// Upload route to GPS service.
  ///
  /// Upload a route to a connected GPS service.
  ///
  /// [routeSlug] - Route URL slug.
  ///
  /// [serviceType] - GPS service type.
  ///
  /// [teamSlug] - Team URL slug.
  @POST('/api/gps/upload/{serviceType}/{teamSlug}/{routeSlug}')
  Future<RouteUploadResponse> uploadRoute({
    @Path('routeSlug') required String routeSlug,
    @Path('serviceType') required GpsServiceType serviceType,
    @Path('teamSlug') required String teamSlug,
  });
}
