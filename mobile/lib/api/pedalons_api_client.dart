import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../config/app_config.dart';
import 'generated/export.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/client_log_interceptor.dart';
import 'interceptors/locale_interceptor.dart';

/// Simple token holder to avoid circular dependency
/// This provider doesn't depend on any other provider that uses Dio
final accessTokenHolderProvider = StateProvider<String?>((ref) => null);

/// Provider for a basic Dio client without auth interceptor (for auth endpoints)
///
/// `Accept-Language` n'est **pas** dans les `BaseOptions` : il suit la locale
/// courante, requête par requête, via [LocaleInterceptor].
final baseDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(const LocaleInterceptor());
  dio.interceptors.add(ClientLogInterceptor());

  return dio;
});

/// Provider for the Dio HTTP client with auth interceptor (for protected endpoints)
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Même règle que le client nu : la langue se lit à la requête.
  dio.interceptors.add(const LocaleInterceptor());
  // Avant l'intercepteur d'auth : un 401 suivi d'un rafraîchissement réussi
  // reste visible au journal, et c'est une information.
  dio.interceptors.add(ClientLogInterceptor());

  // Add auth interceptor that reads token from the simple holder
  dio.interceptors.add(AuthInterceptor(ref, dio));

  return dio;
});

// ============================================================================
// Generated API Client Providers
// ============================================================================

/// Provider for the generated PedalonsApiClient (unauthenticated, for login/register)
final baseApiClientProvider = Provider<PedalonsApiClient>((ref) {
  final dio = ref.watch(baseDioProvider);
  return PedalonsApiClient(dio, baseUrl: AppConfig.apiBaseUrl);
});

/// Provider for the generated PedalonsApiClient (authenticated, for protected endpoints)
final apiClientProvider = Provider<PedalonsApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return PedalonsApiClient(dio, baseUrl: AppConfig.apiBaseUrl);
});

// ============================================================================
// Individual Client Providers (Unauthenticated)
// ============================================================================

final authenticationClientProvider = Provider<AuthenticationClient>((ref) {
  return ref.watch(baseApiClientProvider).authentication;
});

/// Only `authenticate` goes through this client, and that endpoint is public —
/// the authenticated passkey calls go through `PasskeyManagementRepository`, on
/// [apiClientProvider]. Keeping this one on the base client is what keeps the auth tree
/// independent from [apiClientProvider], which gets invalidated on every
/// identity change.
final passkeysClientProvider = Provider<PasskeysClient>((ref) {
  return ref.watch(baseApiClientProvider).passkeys;
});

// ============================================================================
// Individual Client Providers (Authenticated)
// ============================================================================

final usersClientProvider = Provider<UsersClient>((ref) {
  return ref.watch(apiClientProvider).users;
});

final teamsClientProvider = Provider<TeamsClient>((ref) {
  return ref.watch(apiClientProvider).teams;
});

final teamMembersClientProvider = Provider<TeamMembersClient>((ref) {
  return ref.watch(apiClientProvider).teamMembers;
});

final ridesClientProvider = Provider<RidesClient>((ref) {
  return ref.watch(apiClientProvider).rides;
});

final routesClientProvider = Provider<RoutesClient>((ref) {
  return ref.watch(apiClientProvider).routes;
});

final tilesClientProvider = Provider<TilesClient>((ref) {
  return ref.watch(apiClientProvider).tiles;
});

final calendarClientProvider = Provider<CalendarClient>((ref) {
  return ref.watch(apiClientProvider).calendar;
});

final postsClientProvider = Provider<PostsClient>((ref) {
  return ref.watch(apiClientProvider).posts;
});

final tripsClientProvider = Provider<TripsClient>((ref) {
  return ref.watch(apiClientProvider).trips;
});

final assetsClientProvider = Provider<AssetsClient>((ref) {
  return ref.watch(apiClientProvider).assets;
});

final configurationClientProvider = Provider<ConfigurationClient>((ref) {
  return ref.watch(apiClientProvider).configuration;
});

final serverVersionClientProvider = Provider<ServerVersionClient>((ref) {
  return ref.watch(apiClientProvider).serverVersion;
});

final publicationsClientProvider = Provider<PublicationsClient>((ref) {
  return ref.watch(apiClientProvider).publications;
});

final gpsServicesClientProvider = Provider<GpsServicesClient>((ref) {
  return ref.watch(apiClientProvider).gpsServices;
});

final adsClientProvider = Provider<AdsClient>((ref) {
  return ref.watch(apiClientProvider).ads;
});

final teamPagesClientProvider = Provider<TeamPagesClient>((ref) {
  return ref.watch(apiClientProvider).teamPages;
});

final tagsClientProvider = Provider<TagsClient>((ref) {
  return ref.watch(apiClientProvider).tags;
});

final placesClientProvider = Provider<PlacesClient>((ref) {
  return ref.watch(apiClientProvider).places;
});

final rideTemplatesClientProvider = Provider<RideTemplatesClient>((ref) {
  return ref.watch(apiClientProvider).rideTemplates;
});

// Les quatre clients de commentaires. Ils partagent la même forme d'API mais
// pas d'interface commune côté généré : c'est `CommentRepository` qui les
// unifie derrière un `CommentTarget`.
final rideCommentsClientProvider = Provider<RideCommentsClient>((ref) {
  return ref.watch(apiClientProvider).rideComments;
});

final postCommentsClientProvider = Provider<PostCommentsClient>((ref) {
  return ref.watch(apiClientProvider).postComments;
});

final routeCommentsClientProvider = Provider<RouteCommentsClient>((ref) {
  return ref.watch(apiClientProvider).routeComments;
});

final tripCommentsClientProvider = Provider<TripCommentsClient>((ref) {
  return ref.watch(apiClientProvider).tripComments;
});

final tripStageCommentsClientProvider = Provider<TripStageCommentsClient>((
  ref,
) {
  return ref.watch(apiClientProvider).tripStageComments;
});

final notificationsClientProvider = Provider<NotificationsClient>((ref) {
  return ref.watch(apiClientProvider).notifications;
});

final invitationsClientProvider = Provider<InvitationsClient>((ref) {
  return ref.watch(apiClientProvider).invitations;
});

final moderationClientProvider = Provider<ModerationClient>((ref) {
  return ref.watch(apiClientProvider).moderation;
});

/// Signalements et rapports d'erreur : les deux endpoints exigent un membre
/// connecté.
final feedbackClientProvider = Provider<FeedbackClient>((ref) {
  return ref.watch(apiClientProvider).feedback;
});
