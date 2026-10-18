import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/secure_storage.dart';
import '../credential_scope.dart';
import '../generated/export.dart';
import '../pedalons_api_client.dart';

/// Whether a 401 on [path] is worth a refresh-and-retry.
///
/// Everything outside `/api/auth/` is. Inside it, only the endpoints that
/// require the access token are: `logout-all` and the passkey management
/// calls (list, delete, registration). They used to be excluded along with
/// the public ones — login, refresh, passkey authentication — so an expired
/// access token failed them with a 401 instead of being refreshed
/// (`docs/LEDGER_*.md MOB-32`).
@visibleForTesting
bool refreshesOn401(String path) {
  if (!path.contains('/api/auth/')) return true;
  if (path.contains('/api/auth/logout-all')) return true;
  // `authenticate` and `authentication-options` are public: they sign in.
  return path.contains('/api/auth/passkeys') && !path.contains('authenticat');
}

/// Les options à rejouer après un 401.
///
/// Un `FormData` (avatar, assets, GPX d'un parcours) est **finalisé** par le
/// premier envoi : le rejouer tel quel lève `StateError`, que le `catch` du
/// rejeu prendrait pour un échec du rafraîchissement et déconnecterait
/// l'utilisateur. On rejoue donc une copie neuve (docs/LEDGER_*.md MOB-79).
@visibleForTesting
RequestOptions retryableOptions(RequestOptions options) {
  final Object? data = options.data;
  if (data is FormData) options.data = data.clone();
  return options;
}

/// Interceptor that handles authentication tokens and refresh
/// Mirrors frontend/src/lib/axiosInstance.ts
class AuthInterceptor extends Interceptor {
  final Ref _ref;
  final Dio _dio;

  // Adaptateur du Dio de rafraîchissement : null en production (réseau réel),
  // un faux dans les tests.
  final HttpClientAdapter? _refreshAdapter;

  // Track if we're currently refreshing to avoid multiple refresh calls
  bool _isRefreshing = false;

  // Queue of failed requests to retry after refresh
  final List<_QueuedRequest> _failedQueue = [];

  AuthInterceptor(
    this._ref,
    this._dio, {
    @visibleForTesting HttpClientAdapter? refreshAdapter,
  }) : _refreshAdapter = refreshAdapter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add auth token if available - read from simple token holder to avoid circular dep.
    // Only towards the API's origin: an absolute URL on another host (a
    // download, an image) must not receive it (docs/LEDGER_*.md SEC-3).
    final accessToken = _ref.read(accessTokenHolderProvider);
    if (accessToken != null && carriesCredentials(options.uri)) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    // Add language header
    options.headers['Accept-Language'] =
        'fr'; // Default to French like frontend

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final requestOptions = err.requestOptions;

    // Only try to refresh on 401 errors
    if (response?.statusCode != 401) {
      return handler.next(err);
    }

    // Don't try to refresh the public auth endpoints: their 401 means bad
    // credentials, not an expired token.
    if (!refreshesOn401(requestOptions.path)) {
      return handler.next(err);
    }

    // A 401 from another host says nothing about our token, and the retry
    // would carry the fresh one there.
    if (!carriesCredentials(requestOptions.uri)) {
      return handler.next(err);
    }

    // Check if this request was already retried
    if (requestOptions.extra['_retry'] == true) {
      return handler.next(err);
    }

    // If already refreshing, queue this request
    if (_isRefreshing) {
      final completer = Completer<Response>();
      _failedQueue.add(
        _QueuedRequest(requestOptions: requestOptions, completer: completer),
      );
      try {
        final queuedResponse = await completer.future;
        return handler.resolve(queuedResponse);
      } catch (e) {
        return handler.next(err);
      }
    }

    // Mark as retrying
    requestOptions.extra['_retry'] = true;
    _isRefreshing = true;

    final String newAccessToken;
    try {
      final storage = _ref.read(secureStorageProvider);
      final refreshToken = await storage.getRefreshToken();

      if (refreshToken == null) {
        _processQueue(err);
        _clearAuth();
        return handler.next(err);
      }

      // Create a fresh Dio instance for refresh to avoid interceptor loops
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: requestOptions.baseUrl,
          headers: {'Content-Type': 'application/json'},
        ),
      );
      if (_refreshAdapter != null) {
        refreshDio.httpClientAdapter = _refreshAdapter;
      }

      final refreshResponse = await refreshDio.post(
        '/api/auth/refresh',
        options: Options(headers: {'X-Refresh-Token': refreshToken}),
      );

      final authResponse = AuthResponse.fromJson(refreshResponse.data);
      final String? fresh = authResponse.accessToken;
      // Une réponse sans jeton vaut un rafraîchissement raté.
      if (fresh == null) throw StateError('refresh sans jeton d\'accès');

      // Update token in the simple holder
      _ref.read(accessTokenHolderProvider.notifier).state = fresh;

      // Save new refresh token if provided
      if (authResponse.refreshToken != null) {
        await storage.saveRefreshToken(authResponse.refreshToken!);
      }

      newAccessToken = fresh;

      // Process queued requests
      _processQueue(null, newAccessToken);
    } catch (e) {
      // Seul l'échec du rafraîchissement déconnecte.
      _processQueue(err);
      _clearAuth();
      return handler.next(err);
    } finally {
      _isRefreshing = false;
    }

    // Rejeu de la requête d'origine, **hors** du try du rafraîchissement : le
    // jeton est bon, une erreur du rejeu (400 GPX_FAILURE, 413, coupure réseau
    // pendant l'envoi d'un fichier) est celle de la requête, pas une session
    // perdue. Elle remonte telle quelle, sans déconnecter (docs/LEDGER_*.md
    // MOB-79).
    requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
    try {
      final retryResponse = await _dio.fetch(retryableOptions(requestOptions));
      return handler.resolve(retryResponse);
    } on DioException catch (e) {
      return handler.next(e);
    } catch (e) {
      return handler.next(
        DioException(requestOptions: requestOptions, error: e),
      );
    }
  }

  void _processQueue(DioException? error, [String? token]) {
    for (final request in _failedQueue) {
      if (error != null) {
        request.completer.completeError(error);
      } else if (token != null) {
        request.requestOptions.headers['Authorization'] = 'Bearer $token';
        _dio
            .fetch(retryableOptions(request.requestOptions))
            .then(
              request.completer.complete,
              onError: request.completer.completeError,
            );
      }
    }
    _failedQueue.clear();
  }

  void _clearAuth() {
    // Clear the token - navigation will be handled by router
    _ref.read(accessTokenHolderProvider.notifier).state = null;
    _ref.read(secureStorageProvider).deleteRefreshToken();
  }
}

class _QueuedRequest {
  final RequestOptions requestOptions;
  final Completer<Response> completer;

  _QueuedRequest({required this.requestOptions, required this.completer});
}
