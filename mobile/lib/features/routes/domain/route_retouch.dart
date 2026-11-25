import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import 'route_generator.dart';

/// Retoucher un parcours enregistré dans l'app (docs/LEDGER_*.md MOB-185) :
/// les règles du site (`frontend/src/lib/routeRetouch.ts`), sans l'écran.

/// Un écart plus petit que ceci depuis une borne se lit comme sur elle
/// (arrondi d'affichage).
const double _boundEpsilonKm = 0.05;

/// Les bornes du champ de distance, lues dans l'offre, jamais tapées ici.
@immutable
class RetouchBounds {
  const RetouchBounds({
    required this.currentKm,
    required this.minKm,
    required this.maxKm,
    required this.minChangeKm,
    required this.maxChangeShare,
  });

  /// La longueur du parcours, km.
  final double currentKm;
  final double minKm;
  final double maxKm;

  /// Le plus petit écart, km, au-dessus ou au-dessous de la longueur.
  final double minChangeKm;

  /// Le plus grand écart, en part de la longueur, 0 à 1.
  final double maxChangeShare;
}

/// Les bornes de l'offre ; `null` quand elle n'en porte pas.
RetouchBounds? retouchBounds(RouteRetouchOfferDto? offer) {
  if (offer == null || !offer.available) return null;
  final double? distance = offer.originalDistanceM;
  final double? min = offer.minDistanceKm;
  final double? max = offer.maxDistanceKm;
  if (distance == null || min == null || max == null) return null;
  return RetouchBounds(
    currentKm: distance / 1000,
    minKm: min,
    maxKm: max,
    minChangeKm: offer.minChangeKm ?? 1,
    maxChangeShare: offer.maxChangeShare ?? 0.3,
  );
}

/// La retouche est-elle offerte dans le menu, et comment ?
enum RetouchEntry {
  /// Rien à montrer.
  none,

  /// Montrée, désactivée : le parcours est encore en cours d'analyse.
  notReady,

  /// Offerte.
  available,
}

RetouchEntry retouchEntryOf(RouteRetouchOfferDto? offer) {
  if (offer == null) return RetouchEntry.none;
  if (!offer.available) {
    return offer.unavailableReason == RouteRetouchUnavailable.notReady.json
        ? RetouchEntry.notReady
        : RetouchEntry.none;
  }
  return offer.operations.isEmpty ? RetouchEntry.none : RetouchEntry.available;
}

/// La cible trop proche de la longueur du parcours : la « zone morte ».
bool isDeadZone(double targetKm, RetouchBounds bounds) =>
    (targetKm - bounds.currentKm).abs() < bounds.minChangeKm - 1e-9;

/// La cible hors des bornes de l'offre.
bool isOutOfRange(double targetKm, RetouchBounds bounds) =>
    targetKm < bounds.minKm - _boundEpsilonKm ||
    targetKm > bounds.maxKm + _boundEpsilonKm;

/// La cible ramenée dans les bornes.
double clampTarget(double targetKm, RetouchBounds bounds) =>
    targetKm.clamp(bounds.minKm, bounds.maxKm);

/// Raccourcir : refusé plus souvent que les autres retouches.
bool isShortening(double targetKm, double currentKm) => targetKm < currentKm;

/// Ce qu'on demande : une distance, ou une arrivée (un point ou un lieu).
@immutable
sealed class RetouchTarget {
  const RetouchTarget();
}

class RetouchResize extends RetouchTarget {
  const RetouchResize(this.targetKm);
  final double targetKm;

  @override
  bool operator ==(Object other) =>
      other is RetouchResize && other.targetKm == targetKm;

  @override
  int get hashCode => targetKm.hashCode;
}

class RetouchMoveEnd extends RetouchTarget {
  const RetouchMoveEnd({this.point, this.placeId})
    : assert((point == null) != (placeId == null));
  final GeoPoint? point;
  final String? placeId;

  @override
  bool operator ==(Object other) =>
      other is RetouchMoveEnd &&
      other.point == point &&
      other.placeId == placeId;

  @override
  int get hashCode => Object.hash(point, placeId);
}

/// La requête : exactement une distance ou une arrivée, et une clé d'arrivée.
RouteRetouchRequest routeRetouchRequest(RetouchTarget target, int seed) =>
    switch (target) {
      RetouchResize(:final double targetKm) => RouteRetouchRequest(
        discovery: kGeneratorDefaultDiscovery,
        seed: seed,
        targetDistanceKm: (targetKm * 10).round() / 10,
      ),
      RetouchMoveEnd(:final GeoPoint? point, :final String? placeId) =>
        RouteRetouchRequest(
          discovery: kGeneratorDefaultDiscovery,
          seed: seed,
          end: placeId != null
              ? RouteRetouchEnd(placeId: placeId)
              : RouteRetouchEnd(point: point),
        ),
    };

/// Le tronçon neuf d'une proposition : `coords[startIndex..endIndex]`, bornés
/// à la ligne ; vide quand les indices ne décrivent pas de tronçon.
List<T> changedCoords<T>(List<T> coords, int startIndex, int endIndex) {
  final int from = startIndex < 0 ? 0 : startIndex;
  final int to = endIndex > coords.length - 1 ? coords.length - 1 : endIndex;
  if (coords.isEmpty || from > to) return <T>[];
  return coords.sublist(from, to + 1);
}

/// Une proposition qui ne fait que couper le parcours : rien de neuf à tracer.
bool isTruncation(RetouchedRouteDto candidate) =>
    candidate.kind == RetouchKind.truncate.json;

/// Le type de sortie de l'offre ; ROAD par défaut.
RouteGeneratorType retouchRideType(RouteRetouchOfferDto offer) {
  final String? type = offer.rideType;
  if (type == null) return RouteGeneratorType.road;
  final RouteGeneratorType parsed = RouteGeneratorType.fromJson(type);
  return parsed == RouteGeneratorType.$unknown
      ? RouteGeneratorType.road
      : parsed;
}

/// Ce que l'éditeur et le planificateur reçoivent (`load.generated`).
GeneratedHandoff retouchHandoff(
  RetouchedRouteDto candidate,
  RouteRetouchOfferDto offer,
  String name,
) => GeneratedHandoff(
  polyline: candidate.polyline,
  type: retouchRideType(offer),
  distanceM: candidate.distanceM,
  name: name,
);

/// Ce que l'écran de retouche rend à la fiche.
enum RetouchOpening {
  /// « Remplacer le tracé » : l'éditeur de ce parcours, tracé remplacé.
  edit,

  /// « Ouvrir dans l’éditeur » : une création dans le planificateur.
  newRoute,

  /// « Ouvrir le générateur ».
  generator,
}

@immutable
class RetouchChoice {
  const RetouchChoice(this.opening, [this.handoff, this.generator]);
  final RetouchOpening opening;
  final GeneratedHandoff? handoff;

  /// Les réglages du générateur, pour « Ouvrir le générateur ».
  final GeneratorSettings? generator;
}

/// Le générateur ouvert depuis une retouche part du départ du parcours, de la
/// distance demandée (sinon la longueur du parcours) bornée au curseur, et du
/// type de sortie de l'offre — ce que le site met dans l'adresse
/// (`generatorLinkFor`, docs/LEDGER_*.md MOB-186).
GeneratorSettings retouchGeneratorSettings({
  required List<double>? start,
  required double? targetKm,
  required RouteRetouchOfferDto offer,
}) => GeneratorSettings(
  start: start == null || start.length < 2
      ? null
      : GeneratorPoint(
          lng: start[0],
          lat: start[1],
          kind: GeneratorPointKind.picked,
        ),
  distanceKm: targetKm == null || !targetKm.isFinite
      ? kGeneratorDefaultKm
      : targetKm.roundToDouble().clamp(kGeneratorMinKm, kGeneratorMaxKm),
  type: offer.rideType == null ? null : retouchRideType(offer),
);

// ── Erreurs ───────────────────────────────────────────────────────────────

/// Les codes de la retouche ; une table typée, jamais une clé bâtie depuis le
/// code (docs/LEDGER_*.md WEB-84).
const Map<String, String> _errorKeys = <String, String>{
  'ROUTE_RETOUCH_NOT_READY': 'routeRetouch.errors.notReady',
  'ROUTE_RETOUCH_UNSUPPORTED': 'routeRetouch.errors.unsupported',
  'ROUTE_RETOUCH_ORDER_ANOMALY': 'routeRetouch.errors.orderAnomaly',
  'ROUTE_RETOUCH_NO_PROPOSAL': 'routeRetouch.errors.noProposal',
  'ROUTE_RETOUCH_END_UNREACHABLE': 'routeRetouch.errors.endUnreachable',
  'GENERATOR_END_TOO_FAR': 'routeRetouch.errors.endTooFar',
  'GENERATOR_OUT_OF_COVERAGE': 'routeRetouch.errors.outOfCoverage',
  'GENERATOR_UNAVAILABLE': 'routeGenerator.errors.unavailable',
  'ROUTE_GENERATOR_BUSY': 'routeGenerator.errors.busy',
  'ROUTE_PLANNER_DISABLED': 'routeGenerator.errors.disabled',
};

/// Les refus qui sont une réponse, pas une panne : en bleu.
const Set<String> _infoCodes = <String>{
  'ROUTE_RETOUCH_NO_SHORTER',
  'ROUTE_RETOUCH_CHANGE_TOO_LARGE',
  'ROUTE_RETOUCH_ORDER_ANOMALY',
  'ROUTE_RETOUCH_UNSUPPORTED',
  'ROUTE_RETOUCH_NO_PROPOSAL',
  'ROUTE_RETOUCH_END_UNREACHABLE',
  'ROUTE_RETOUCH_CHANGE_TOO_SMALL',
};

/// Les refus qu'une seconde requête identique rencontrerait encore.
const Set<String> _nonRetryable = <String>{
  'ROUTE_RETOUCH_NOT_READY',
  'ROUTE_RETOUCH_UNSUPPORTED',
  'ROUTE_RETOUCH_ORDER_ANOMALY',
  'ROUTE_RETOUCH_CHANGE_TOO_SMALL',
  'ROUTE_RETOUCH_CHANGE_TOO_LARGE',
  'ROUTE_RETOUCH_NO_SHORTER',
  'ROUTE_RETOUCH_NO_PROPOSAL',
  'ROUTE_RETOUCH_END_UNREACHABLE',
  'GENERATOR_END_TOO_FAR',
  'GENERATOR_OUT_OF_COVERAGE',
  'ROUTE_GENERATOR_RATE_LIMITED',
  'ROUTE_PLANNER_DISABLED',
  'VALIDATION',
};

bool _isNetworkError(Object error) =>
    error is DioException &&
    const <DioExceptionType>{
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    }.contains(error.type);

/// « Réessayer » aide sur une panne de réseau, un serveur occupé ou inconnu.
bool isRetryableRetouchError(Object error) {
  if (_isNetworkError(error)) return true;
  final String? code = generatorErrorCode(error);
  return code == null || !_nonRetryable.contains(code);
}

/// Une réponse (bleu, avec des suites) plutôt qu'une panne (rouge).
bool isInfoRetouchError(Object error) =>
    _infoCodes.contains(generatorErrorCode(error));

/// Un raccourcissement sans proposition : l'écran offre l'arrivée et le
/// générateur.
bool isNoShorter(Object error) =>
    generatorErrorCode(error) == 'ROUTE_RETOUCH_NO_SHORTER';

/// Un refus qu'une autre graine peut changer en propositions.
bool isOtherSeedUseful(Object error) => const <String>{
  'ROUTE_RETOUCH_NO_PROPOSAL',
  'ROUTE_RETOUCH_NO_SHORTER',
}.contains(generatorErrorCode(error));

/// Le message d'un appel échoué ; épicène, chaque phrase dit quoi faire.
String routeRetouchErrorMessage(
  Object error, {
  required String distance,
  required String current,
  required String min,
  required String percent,
}) {
  if (_isNetworkError(error)) return 'routeGenerator.errors.network'.tr();
  final String? code = generatorErrorCode(error);
  switch (code) {
    case 'ROUTE_GENERATOR_RATE_LIMITED':
      final String? header = error is DioException
          ? error.response?.headers.value('retry-after')
          : null;
      final int? seconds = header == null ? null : int.tryParse(header.trim());
      if (seconds != null) {
        final int minutes = seconds <= 60 ? 1 : (seconds / 60).ceil();
        return 'routeGenerator.errors.rateLimitedWait'.plural(minutes);
      }
      return 'routeGenerator.errors.rateLimited'.tr();
    case 'ROUTE_RETOUCH_CHANGE_TOO_SMALL':
      return 'routeRetouch.errors.changeTooSmall'.tr(
        namedArgs: <String, String>{'min': min, 'current': current},
      );
    case 'ROUTE_RETOUCH_CHANGE_TOO_LARGE':
      return 'routeRetouch.errors.changeTooLarge'.tr(
        namedArgs: <String, String>{'percent': percent},
      );
    case 'ROUTE_RETOUCH_NO_SHORTER':
      return 'routeRetouch.errors.noShorter'.tr(
        namedArgs: <String, String>{'distance': distance},
      );
    case 'VALIDATION':
      return 'routeRetouch.errors.invalidRequest'.tr();
  }
  final String? key = code == null ? null : _errorKeys[code];
  return (key ?? 'routeRetouch.errors.generic').tr();
}
