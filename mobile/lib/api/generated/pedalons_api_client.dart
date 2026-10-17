// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart' hide Headers;

import 'clients/admin_beta_signups_client.dart';
import 'clients/admin_domains_client.dart';
import 'clients/admin_reports_client.dart';
import 'clients/admin_teams_client.dart';
import 'clients/admin_thumbnails_client.dart';
import 'clients/admin_users_client.dart';
import 'clients/authentication_client.dart';
import 'clients/passkeys_client.dart';
import 'clients/beta_signups_client.dart';
import 'clients/calendar_client.dart';
import 'clients/configuration_client.dart';
import 'clients/device_user_client.dart';
import 'clients/device_o_auth_client.dart';
import 'clients/device_routes_client.dart';
import 'clients/users_client.dart';
import 'clients/feedback_client.dart';
import 'clients/geocode_client.dart';
import 'clients/gps_services_client.dart';
import 'clients/gpx_previews_client.dart';
import 'clients/invitations_client.dart';
import 'clients/notifications_client.dart';
import 'clients/publications_client.dart';
import 'clients/moderation_client.dart';
import 'clients/router_client.dart';
import 'clients/routes_client.dart';
import 'clients/sitemap_client.dart';
import 'clients/teams_client.dart';
import 'clients/assets_client.dart';
import 'clients/ads_client.dart';
import 'clients/team_invitations_client.dart';
import 'clients/team_members_client.dart';
import 'clients/team_pages_client.dart';
import 'clients/places_client.dart';
import 'clients/posts_client.dart';
import 'clients/post_comments_client.dart';
import 'clients/ride_templates_client.dart';
import 'clients/rides_client.dart';
import 'clients/ride_comments_client.dart';
import 'clients/route_comments_client.dart';
import 'clients/trip_stage_comments_client.dart';
import 'clients/tags_client.dart';
import 'clients/trips_client.dart';
import 'clients/trip_comments_client.dart';
import 'clients/team_webhook_client.dart';
import 'clients/tiles_client.dart';
import 'clients/server_version_client.dart';

/// Pedalons API `v11.6.0`.
///
/// API for Pedalons Cycling Team Management Platform.
class PedalonsApiClient {
  PedalonsApiClient(
    Dio dio, {
    String? baseUrl,
  }) : _dio = dio,
       _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '11.6.0';

  AdminBetaSignupsClient? _adminBetaSignups;
  AdminDomainsClient? _adminDomains;
  AdminReportsClient? _adminReports;
  AdminTeamsClient? _adminTeams;
  AdminThumbnailsClient? _adminThumbnails;
  AdminUsersClient? _adminUsers;
  AuthenticationClient? _authentication;
  PasskeysClient? _passkeys;
  BetaSignupsClient? _betaSignups;
  CalendarClient? _calendar;
  ConfigurationClient? _configuration;
  DeviceUserClient? _deviceUser;
  DeviceOAuthClient? _deviceOAuth;
  DeviceRoutesClient? _deviceRoutes;
  UsersClient? _users;
  FeedbackClient? _feedback;
  GeocodeClient? _geocode;
  GpsServicesClient? _gpsServices;
  GpxPreviewsClient? _gpxPreviews;
  InvitationsClient? _invitations;
  NotificationsClient? _notifications;
  PublicationsClient? _publications;
  ModerationClient? _moderation;
  RouterClient? _router;
  RoutesClient? _routes;
  SitemapClient? _sitemap;
  TeamsClient? _teams;
  AssetsClient? _assets;
  AdsClient? _ads;
  TeamInvitationsClient? _teamInvitations;
  TeamMembersClient? _teamMembers;
  TeamPagesClient? _teamPages;
  PlacesClient? _places;
  PostsClient? _posts;
  PostCommentsClient? _postComments;
  RideTemplatesClient? _rideTemplates;
  RidesClient? _rides;
  RideCommentsClient? _rideComments;
  RouteCommentsClient? _routeComments;
  TripStageCommentsClient? _tripStageComments;
  TagsClient? _tags;
  TripsClient? _trips;
  TripCommentsClient? _tripComments;
  TeamWebhookClient? _teamWebhook;
  TilesClient? _tiles;
  ServerVersionClient? _serverVersion;

  AdminBetaSignupsClient get adminBetaSignups =>
      _adminBetaSignups ??= AdminBetaSignupsClient(_dio, baseUrl: _baseUrl);

  AdminDomainsClient get adminDomains =>
      _adminDomains ??= AdminDomainsClient(_dio, baseUrl: _baseUrl);

  AdminReportsClient get adminReports =>
      _adminReports ??= AdminReportsClient(_dio, baseUrl: _baseUrl);

  AdminTeamsClient get adminTeams =>
      _adminTeams ??= AdminTeamsClient(_dio, baseUrl: _baseUrl);

  AdminThumbnailsClient get adminThumbnails =>
      _adminThumbnails ??= AdminThumbnailsClient(_dio, baseUrl: _baseUrl);

  AdminUsersClient get adminUsers =>
      _adminUsers ??= AdminUsersClient(_dio, baseUrl: _baseUrl);

  AuthenticationClient get authentication =>
      _authentication ??= AuthenticationClient(_dio, baseUrl: _baseUrl);

  PasskeysClient get passkeys =>
      _passkeys ??= PasskeysClient(_dio, baseUrl: _baseUrl);

  BetaSignupsClient get betaSignups =>
      _betaSignups ??= BetaSignupsClient(_dio, baseUrl: _baseUrl);

  CalendarClient get calendar =>
      _calendar ??= CalendarClient(_dio, baseUrl: _baseUrl);

  ConfigurationClient get configuration =>
      _configuration ??= ConfigurationClient(_dio, baseUrl: _baseUrl);

  DeviceUserClient get deviceUser =>
      _deviceUser ??= DeviceUserClient(_dio, baseUrl: _baseUrl);

  DeviceOAuthClient get deviceOAuth =>
      _deviceOAuth ??= DeviceOAuthClient(_dio, baseUrl: _baseUrl);

  DeviceRoutesClient get deviceRoutes =>
      _deviceRoutes ??= DeviceRoutesClient(_dio, baseUrl: _baseUrl);

  UsersClient get users => _users ??= UsersClient(_dio, baseUrl: _baseUrl);

  FeedbackClient get feedback =>
      _feedback ??= FeedbackClient(_dio, baseUrl: _baseUrl);

  GeocodeClient get geocode =>
      _geocode ??= GeocodeClient(_dio, baseUrl: _baseUrl);

  GpsServicesClient get gpsServices =>
      _gpsServices ??= GpsServicesClient(_dio, baseUrl: _baseUrl);

  GpxPreviewsClient get gpxPreviews =>
      _gpxPreviews ??= GpxPreviewsClient(_dio, baseUrl: _baseUrl);

  InvitationsClient get invitations =>
      _invitations ??= InvitationsClient(_dio, baseUrl: _baseUrl);

  NotificationsClient get notifications =>
      _notifications ??= NotificationsClient(_dio, baseUrl: _baseUrl);

  PublicationsClient get publications =>
      _publications ??= PublicationsClient(_dio, baseUrl: _baseUrl);

  ModerationClient get moderation =>
      _moderation ??= ModerationClient(_dio, baseUrl: _baseUrl);

  RouterClient get router => _router ??= RouterClient(_dio, baseUrl: _baseUrl);

  RoutesClient get routes => _routes ??= RoutesClient(_dio, baseUrl: _baseUrl);

  SitemapClient get sitemap =>
      _sitemap ??= SitemapClient(_dio, baseUrl: _baseUrl);

  TeamsClient get teams => _teams ??= TeamsClient(_dio, baseUrl: _baseUrl);

  AssetsClient get assets => _assets ??= AssetsClient(_dio, baseUrl: _baseUrl);

  AdsClient get ads => _ads ??= AdsClient(_dio, baseUrl: _baseUrl);

  TeamInvitationsClient get teamInvitations =>
      _teamInvitations ??= TeamInvitationsClient(_dio, baseUrl: _baseUrl);

  TeamMembersClient get teamMembers =>
      _teamMembers ??= TeamMembersClient(_dio, baseUrl: _baseUrl);

  TeamPagesClient get teamPages =>
      _teamPages ??= TeamPagesClient(_dio, baseUrl: _baseUrl);

  PlacesClient get places => _places ??= PlacesClient(_dio, baseUrl: _baseUrl);

  PostsClient get posts => _posts ??= PostsClient(_dio, baseUrl: _baseUrl);

  PostCommentsClient get postComments =>
      _postComments ??= PostCommentsClient(_dio, baseUrl: _baseUrl);

  RideTemplatesClient get rideTemplates =>
      _rideTemplates ??= RideTemplatesClient(_dio, baseUrl: _baseUrl);

  RidesClient get rides => _rides ??= RidesClient(_dio, baseUrl: _baseUrl);

  RideCommentsClient get rideComments =>
      _rideComments ??= RideCommentsClient(_dio, baseUrl: _baseUrl);

  RouteCommentsClient get routeComments =>
      _routeComments ??= RouteCommentsClient(_dio, baseUrl: _baseUrl);

  TripStageCommentsClient get tripStageComments =>
      _tripStageComments ??= TripStageCommentsClient(_dio, baseUrl: _baseUrl);

  TagsClient get tags => _tags ??= TagsClient(_dio, baseUrl: _baseUrl);

  TripsClient get trips => _trips ??= TripsClient(_dio, baseUrl: _baseUrl);

  TripCommentsClient get tripComments =>
      _tripComments ??= TripCommentsClient(_dio, baseUrl: _baseUrl);

  TeamWebhookClient get teamWebhook =>
      _teamWebhook ??= TeamWebhookClient(_dio, baseUrl: _baseUrl);

  TilesClient get tiles => _tiles ??= TilesClient(_dio, baseUrl: _baseUrl);

  ServerVersionClient get serverVersion =>
      _serverVersion ??= ServerVersionClient(_dio, baseUrl: _baseUrl);
}
