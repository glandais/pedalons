import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../../core/geo/polyline_index.dart';

/// Le générateur de parcours dans l'app (docs/LEDGER_*.md MOB-154) : les
/// règles du site (`frontend/src/lib/routeGenerator.ts`), sans l'écran.

/// Bornes et valeurs par défaut du site (`routeGeneratorFilters.ts`).
const double kGeneratorMinKm = 10;
const double kGeneratorMaxKm = 200;
const double kGeneratorDefaultKm = 50;
const double kGeneratorDefaultDiscovery = 0.25;

/// Le curseur « Routes de l'équipe ↔ Découverte » a cinq crans, de 0 à 1.
const int kDiscoveryStops = 4;

/// D'où vient un point de départ ou d'arrivée.
enum GeneratorPointKind {
  /// La localisation de l'équipe.
  team,

  /// Un lieu de l'équipe.
  place,

  /// Un point touché sur la carte.
  picked,
}

/// Un départ ou une arrivée.
@immutable
class GeneratorPoint {
  const GeneratorPoint({
    required this.lng,
    required this.lat,
    required this.kind,
    this.name,
  });

  final double lng;
  final double lat;
  final GeneratorPointKind kind;

  /// Le nom du lieu, pour [GeneratorPointKind.place].
  final String? name;

  GeoPoint get geoPoint => GeoPoint(lng: lng, lat: lat);
  LngLat get lngLat => LngLat(lng, lat);

  @override
  bool operator ==(Object other) =>
      other is GeneratorPoint &&
      other.lng == lng &&
      other.lat == lat &&
      other.kind == kind &&
      other.name == name;

  @override
  int get hashCode => Object.hash(lng, lat, kind, name);
}

/// La localisation de l'équipe, départ par défaut ; `null` si elle n'en a pas.
GeneratorPoint? teamGeneratorPoint(TeamDetailDto team) {
  final List<double>? c = team.geometry?.coordinates;
  if (c == null || c.length < 2) return null;
  return GeneratorPoint(lng: c[0], lat: c[1], kind: GeneratorPointKind.team);
}

/// Un lieu de l'équipe offert comme départ ou arrivée ; `null` sans position.
GeneratorPoint? placeGeneratorPoint(PlaceDetailDto place) {
  final List<double>? c = place.geometry?.coordinates;
  if (c == null || c.length < 2) return null;
  return GeneratorPoint(
    lng: c[0],
    lat: c[1],
    kind: GeneratorPointKind.place,
    name: place.name,
  );
}

/// Les réglages de l'écran.
@immutable
class GeneratorSettings {
  const GeneratorSettings({
    this.start,
    this.end,
    this.loop = true,
    this.bearing,
    this.distanceKm = kGeneratorDefaultKm,
    this.discovery = kGeneratorDefaultDiscovery,
    this.type,
    this.unpaved = RouteGeneratorUnpaved.usual,
    this.seed = 0,
  });

  /// `null` : la localisation de l'équipe, que le serveur prend d'office.
  final GeneratorPoint? start;

  /// L'arrivée choisie, lue seulement quand [loop] est faux.
  final GeneratorPoint? end;

  /// Vrai : le parcours revient au départ (« Au départ »).
  final bool loop;

  /// `null` : peu importe.
  final CompassPoint? bearing;
  final double distanceKm;
  final double discovery;

  /// `null` : le type le plus fréquent dans les parcours de l'équipe.
  final RouteGeneratorType? type;
  final RouteGeneratorUnpaved unpaved;
  final int seed;

  /// L'arrivée réellement envoyée.
  GeneratorPoint? get effectiveEnd => loop ? null : end;

  GeneratorSettings copyWith({
    GeneratorPoint? start,
    GeneratorPoint? end,
    bool? loop,
    CompassPoint? Function()? bearing,
    double? distanceKm,
    double? discovery,
    RouteGeneratorType? type,
    RouteGeneratorUnpaved? unpaved,
    int? seed,
  }) => GeneratorSettings(
    start: start ?? this.start,
    end: end ?? this.end,
    loop: loop ?? this.loop,
    bearing: bearing == null ? this.bearing : bearing(),
    distanceKm: distanceKm ?? this.distanceKm,
    discovery: discovery ?? this.discovery,
    type: type ?? this.type,
    unpaved: unpaved ?? this.unpaved,
    seed: seed ?? this.seed,
  );
}

/// L'arrivée est loin quand la ligne droite depuis le départ fait au moins la
/// moitié de la distance voulue : la règle du moteur (`BearingV1`), qui ignore
/// alors la direction.
bool isEndFar(GeneratorPoint? start, GeneratorPoint? end, double distanceKm) {
  if (start == null || end == null) return false;
  return haversineMeters(start.lngLat, end.lngLat) >= distanceKm * 1000 / 2;
}

/// Le type des parcours les plus nombreux de l'équipe ; ROAD > GRAVEL > MTB à
/// égalité, ROAD sans compte.
RouteGeneratorType dominantGeneratorType({int? road, int? gravel, int? mtb}) {
  RouteGeneratorType best = RouteGeneratorType.road;
  int bestCount = road ?? 0;
  if ((gravel ?? 0) > bestCount) {
    best = RouteGeneratorType.gravel;
    bestCount = gravel!;
  }
  if ((mtb ?? 0) > bestCount) best = RouteGeneratorType.mtb;
  return best;
}

/// La requête des réglages, comme le site la bâtit : le départ et l'arrivée
/// omis quand absents, la direction omise quand l'arrivée est loin, la part
/// de chemins omise pour la route et quand elle est l'habituelle.
RouteGeneratorRequest buildGeneratorRequest(
  GeneratorSettings settings,
  RouteGeneratorType type, {
  GeneratorPoint? resolvedStart,
}) {
  final GeneratorPoint? start = settings.start;
  final GeneratorPoint? end = settings.effectiveEnd;
  final bool far = isEndFar(start ?? resolvedStart, end, settings.distanceKm);
  final bool offRoad = type != RouteGeneratorType.road;
  return RouteGeneratorRequest(
    distanceKm: settings.distanceKm,
    discovery: settings.discovery,
    type: type.json,
    seed: settings.seed,
    start: start?.geoPoint,
    end: end?.geoPoint,
    bearing: far ? null : settings.bearing?.json,
    unpaved: offRoad && settings.unpaved != RouteGeneratorUnpaved.usual
        ? settings.unpaved.json
        : null,
  );
}

/// Le revêtement du parcours créé à partir d'une proposition.
SurfaceType surfaceTypeOfGenerated(RouteGeneratorType type) => switch (type) {
  RouteGeneratorType.gravel => SurfaceType.gravel,
  RouteGeneratorType.mtb => SurfaceType.mtb,
  _ => SurfaceType.road,
};

/// Ce que l'écran du générateur passe à l'éditeur de parcours : la
/// proposition choisie, que le planificateur embarqué importe à l'ouverture
/// (`load.generated`).
@immutable
class GeneratedHandoff {
  const GeneratedHandoff({
    required this.polyline,
    required this.type,
    required this.distanceM,
    required this.name,
  });

  /// Polyligne de précision 6 (`GeneratedRouteDto.polyline`).
  final String polyline;
  final RouteGeneratorType type;
  final double distanceM;

  /// « Parcours généré de 82 km ».
  final String name;
}

// ── Erreurs ───────────────────────────────────────────────────────────────

/// Les codes que le générateur formule à sa façon ; une table typée, jamais
/// une clé bâtie depuis le code (docs/LEDGER_*.md WEB-84).
const Map<String, String> _errorKeys = <String, String>{
  'GENERATOR_START_TOO_FAR': 'routeGenerator.errors.startTooFar',
  'GENERATOR_END_TOO_FAR': 'routeGenerator.errors.endTooFar',
  'GENERATOR_OUT_OF_COVERAGE': 'routeGenerator.errors.outOfCoverage',
  'GENERATOR_NETWORK_NOT_READY': 'routeGenerator.errors.networkNotReady',
  'GENERATOR_UNAVAILABLE': 'routeGenerator.errors.unavailable',
  'ROUTE_GENERATOR_BUSY': 'routeGenerator.errors.busy',
  'ROUTE_PLANNER_DISABLED': 'routeGenerator.errors.disabled',
};

/// Les refus qu'une seconde requête identique rencontrerait encore :
/// « Réessayer » n'est pas offert.
const Set<String> _nonRetryable = <String>{
  'GENERATOR_START_TOO_FAR',
  'GENERATOR_END_TOO_FAR',
  'GENERATOR_DISTANCE_TOO_SHORT',
  'GENERATOR_NO_ROUTE',
  'GENERATOR_NETWORK_TOO_SMALL',
  'GENERATOR_OUT_OF_COVERAGE',
  'GENERATOR_NETWORK_NOT_READY',
  'ROUTE_GENERATOR_RATE_LIMITED',
  'ROUTE_PLANNER_DISABLED',
  'VALIDATION',
};

const Set<DioExceptionType> _networkTypes = <DioExceptionType>{
  DioExceptionType.connectionError,
  DioExceptionType.connectionTimeout,
  DioExceptionType.sendTimeout,
  DioExceptionType.receiveTimeout,
};

bool _isNetworkError(Object error) =>
    error is DioException && _networkTypes.contains(error.type);

/// Le code d'erreur de l'API, s'il y en a un.
String? generatorErrorCode(Object error) {
  if (error is! DioException) return null;
  final Object? data = error.response?.data;
  if (data is Map && data['code'] is String) return data['code'] as String;
  return null;
}

/// Les erreurs qui suggèrent de toucher aux réglages : distance, départ,
/// découverte (« Essayer plutôt »).
bool isSettingsGeneratorError(Object error) => const <String>{
  'GENERATOR_NO_ROUTE',
  'GENERATOR_NETWORK_TOO_SMALL',
  'GENERATOR_DISTANCE_TOO_SHORT',
  'GENERATOR_NETWORK_NOT_READY',
  'GENERATOR_START_TOO_FAR',
}.contains(generatorErrorCode(error));

/// « Réessayer » aide sur une panne de réseau, un serveur occupé ou inconnu.
bool isRetryableGeneratorError(Object error) {
  if (_isNetworkError(error)) return true;
  final String? code = generatorErrorCode(error);
  return code == null || !_nonRetryable.contains(code);
}

/// Les champs qu'un refus `VALIDATION` nomme.
List<String> _validationFields(Object error) {
  if (error is! DioException) return const <String>[];
  final Object? data = error.response?.data;
  if (data is! Map) return const <String>[];
  final Object? details = data['errorDetails'];
  if (details is! Map) return const <String>[];
  final Object? fields = details['fieldErrors'];
  if (fields is! List) return const <String>[];
  return <String>[
    for (final Object? f in fields)
      if (f is Map && f['field'] is String) f['field'] as String,
  ];
}

/// Les secondes du `Retry-After` d'un refus 429, s'il y en a.
int? _retryAfterSeconds(Object error) {
  if (error is! DioException) return null;
  final String? header = error.response?.headers.value('retry-after');
  return header == null ? null : int.tryParse(header.trim());
}

/// Le message d'un appel échoué. [distance] est la distance demandée, dans
/// l'unité de la personne (« 120 km »).
String generatorErrorMessage(
  Object error, {
  required String distance,
  required String minDistance,
  required String maxDistance,
}) {
  if (_isNetworkError(error)) return 'routeGenerator.errors.network'.tr();
  final String? code = generatorErrorCode(error);
  switch (code) {
    case 'VALIDATION':
      return _validationFields(error).contains('distanceKm')
          ? 'routeGenerator.errors.distanceOutOfRange'.tr(
              namedArgs: <String, String>{
                'min': minDistance,
                'max': maxDistance,
              },
            )
          : 'routeGenerator.errors.invalidRequest'.tr();
    case 'GENERATOR_NETWORK_TOO_SMALL':
      return 'routeGenerator.errors.networkTooSmall'.tr(
        namedArgs: <String, String>{'distance': distance},
      );
    case 'GENERATOR_DISTANCE_TOO_SHORT':
      return 'routeGenerator.errors.distanceTooShort'.tr(
        namedArgs: <String, String>{'distance': distance},
      );
    case 'GENERATOR_NO_ROUTE':
      return 'routeGenerator.errors.noRoute'.tr(
        namedArgs: <String, String>{'distance': distance},
      );
    case 'ROUTE_GENERATOR_RATE_LIMITED':
      final int? seconds = _retryAfterSeconds(error);
      if (seconds != null) {
        final int minutes = seconds <= 60 ? 1 : (seconds / 60).ceil();
        return 'routeGenerator.errors.rateLimitedWait'.plural(minutes);
      }
      return 'routeGenerator.errors.rateLimited'.tr();
  }
  final String? key = code == null ? null : _errorKeys[code];
  return (key ?? 'routeGenerator.errors.generic').tr();
}
