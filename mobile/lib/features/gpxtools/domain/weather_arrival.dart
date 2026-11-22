import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';

/// À quelle cadence la fiche d'un aperçu redemande sa météo tant qu'elle
/// arrive, et quand elle renonce — celles du site (`useGpxPreviewWeather`) :
/// le travailleur du serveur passe chaque minute.
const Duration kWeatherArrivalInterval = Duration(seconds: 15);
const Duration kWeatherArrivalGiveUp = Duration(minutes: 3);

/// Une prévision en chemin : le cache est vide (`UNAVAILABLE`), ou un long
/// tracé arrive par morceaux (`STALE`).
bool weatherArriving(String? status) =>
    status == WeatherStatus.unavailable.json ||
    status == WeatherStatus.stale.json;

/// Redemande la météo d'un aperçu toutes les [kWeatherArrivalInterval] tant
/// qu'elle arrive ([weatherArriving]), pendant [kWeatherArrivalGiveUp] au
/// plus depuis l'ouverture de la fenêtre ; [retry] la rouvre (« Réessayer »).
/// [waiting] reste vrai tant que la fenêtre est ouverte : la fiche dit alors
/// « Récupération des prévisions en cours » plutôt que « indisponible ».
class WeatherArrivalPoller {
  WeatherArrivalPoller({
    required this.refresh,
    this.onGaveUp,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _openedAt = _now();
  }

  final VoidCallback refresh;

  /// La fenêtre s'est refermée sur une météo toujours en chemin : l'écran
  /// passe de « en cours » à « indisponible », avec « Réessayer ».
  final VoidCallback? onGaveUp;
  final DateTime Function() _now;

  late DateTime _openedAt;
  Timer? _timer;

  bool get waiting => _now().difference(_openedAt) < kWeatherArrivalGiveUp;

  @visibleForTesting
  bool get isPolling => _timer?.isActive ?? false;

  /// À appeler à chaque nouvelle valeur de la météo.
  void update(String? status) {
    if (!weatherArriving(status) || !waiting) {
      _stop();
      return;
    }
    _timer ??= Timer.periodic(kWeatherArrivalInterval, (_) {
      if (!waiting) {
        _stop();
        onGaveUp?.call();
        return;
      }
      refresh();
    });
  }

  /// Rouvre la fenêtre et redemande tout de suite.
  void retry() {
    _openedAt = _now();
    refresh();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => _stop();
}
