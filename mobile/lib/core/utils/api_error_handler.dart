import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../logging/app_log.dart';

/// Why a call failed, at the granularity the UI needs to react.
enum ApiErrorKind {
  /// The request never reached the server, or the server never answered in
  /// time: no connectivity, DNS failure, connect/send/receive timeout.
  offline,

  /// The server answered with an error payload carrying a business code.
  api,

  /// Anything else: an HTTP failure without a usable code, or an exception
  /// that is not a [DioException] at all (deserialization, cast, bug).
  unknown,
}

/// A resolved, user-presentable error.
///
/// [message] is always localized and safe to display as-is. [title] is only
/// set when the reason deserves its own heading (offline). [code] carries the
/// backend business code when there was one, so callers can special-case
/// e.g. `GROUP_FULL` without re-parsing the exception.
class ApiError {
  const ApiError({
    required this.kind,
    required this.message,
    this.title,
    this.code,
  });

  final ApiErrorKind kind;
  final String message;
  final String? title;
  final String? code;

  bool get isOffline => kind == ApiErrorKind.offline;

  @override
  String toString() => 'ApiError(kind: $kind, code: $code, message: $message)';
}

const Set<DioExceptionType> _offlineTypes = {
  DioExceptionType.connectionError,
  DioExceptionType.connectionTimeout,
  DioExceptionType.sendTimeout,
  DioExceptionType.receiveTimeout,
};

/// Resolves any thrown object into a localized [ApiError].
///
/// Connection and timeout failures produce [ApiErrorKind.offline] with their
/// own copy, distinct from the generic `common.error`. Anything that is not a
/// [DioException] is logged with its real runtime type and stack trace instead
/// of being silently folded into the generic message — a bare "Erreur" with no
/// trace is exactly what makes deserialization failures impossible to diagnose.
ApiError resolveApiError(Object error, [StackTrace? stackTrace]) {
  if (error is DioException) {
    if (_offlineTypes.contains(error.type)) {
      return ApiError(
        kind: ApiErrorKind.offline,
        title: 'errors.offline.title'.tr(),
        message: 'errors.offline.message'.tr(),
      );
    }

    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final code = responseData['code'];
      if (code is String) {
        final key = 'errors.api.$code';
        final translated = key.tr(
          namedArgs: _detailArgs(responseData['errorDetails']),
        );
        if (translated != key) {
          return ApiError(
            kind: ApiErrorKind.api,
            message: translated,
            code: code,
          );
        }
        return ApiError(
          kind: ApiErrorKind.unknown,
          message: 'common.error'.tr(),
          code: code,
        );
      }
    }

    return ApiError(kind: ApiErrorKind.unknown, message: 'common.error'.tr());
  }

  log(
    'Non-Dio error surfaced to the UI: ${error.runtimeType}: $error',
    name: 'ApiErrorHandler',
    error: error,
    stackTrace: stackTrace ?? StackTrace.current,
  );
  AppLog.instance.error('error', '${error.runtimeType}: $error');
  return ApiError(kind: ApiErrorKind.unknown, message: 'common.error'.tr());
}

/// The scalar fields of an error's `errorDetails`, as named arguments of its
/// translation: `TEAM_MEMBER_LIMIT_REACHED` carries `{limit, current}`, and
/// its copy reads « L'équipe a atteint {limit} membres… ». A message without
/// placeholders ignores them; nested values and the `type` discriminator are
/// left out.
Map<String, String> _detailArgs(Object? details) {
  if (details is! Map) return const <String, String>{};
  return <String, String>{
    for (final MapEntry<dynamic, dynamic> e in details.entries)
      if (e.key is String &&
          e.key != 'type' &&
          (e.value is String || e.value is num || e.value is bool))
        e.key as String: '${e.value}',
  };
}

/// Vrai quand le serveur a **refusé** l'accès (403) — un refus, pas une panne.
///
/// Même lecture que `teamAccessProbeProvider` : le statut de la réponse. Un
/// écran de liste s'en sert pour dire « Réservées aux membres » ou « Liste non
/// partagée » plutôt qu'« Erreur de chargement » et un « Réessayer » qui
/// rendrait le même refus.
bool isForbiddenError(Object error) =>
    error is DioException && error.response?.statusCode == 403;

/// Extracts a user-friendly, localized error message from an exception.
///
/// A screen that renders a code itself reads it **before** falling back to
/// this message, so the person never reads both: `INCOMPATIBLE_VISIBILITY`
/// opens the alignment or refusal sheet of `features/visibility`
/// (`incompatibleVisibilityOf`, docs/LEDGER_*.md MOB-137). Elsewhere — a
/// refusal without its list, an older screen — its translation is the clear
/// message.
///
/// Convenience wrapper over [resolveApiError] for callers that only render a
/// single line of text.
String getErrorMessage(Object error, [StackTrace? stackTrace]) =>
    resolveApiError(error, stackTrace).message;
