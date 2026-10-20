import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';

/// À quelle cadence la fiche redemande le parcours tant que l'altitude précise
/// (HD) n'est pas arrivée — la même que le site (`useElevationRefetchInterval`,
/// ledgers `WEB-102`, `MOB-76`).
const Duration kElevationPollInterval = Duration(seconds: 30);

/// Le serveur recalcule dans les ~10 minutes qui suivent le dernier
/// enregistrement : on renonce un peu après.
const Duration kElevationPollGiveUp = Duration(minutes: 15);

/// `elevationState` vaut `PENDING` : le profil affiché est l'altitude rapide,
/// et le recalcul HD est programmé (`API-131`). `FAST` veut dire « abandonné »
/// et `HD` « définitif » : rien à attendre dans les deux cas.
bool isElevationPending(String? state) => state == ElevationState.pending.json;

/// Redemande le parcours toutes les [kElevationPollInterval] tant qu'il est
/// `PENDING` (altitude, ou revêtement des pistes — `MOB-81`), et s'arrête dès qu'il ne l'est plus — ou au bout de
/// [kElevationPollGiveUp] depuis le premier `PENDING` vu par cet écran.
///
/// Une fois la fenêtre écoulée, un parcours encore `PENDING` ne la relance
/// pas : un écran resté ouvert si longtemps n'a plus besoin du rafraîchissement,
/// et le rouvrir en ouvre une nouvelle (comme au site).
class ElevationRefreshPoller {
  ElevationRefreshPoller({required this.refresh, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Redemande le parcours (`ref.invalidate` du détail, côté écran).
  final VoidCallback refresh;
  final DateTime Function() _now;

  Timer? _timer;
  DateTime? _pendingSince;

  @visibleForTesting
  bool get isPolling => _timer?.isActive ?? false;

  /// À appeler à chaque nouvelle valeur du parcours.
  void update(String? elevationState) =>
      updatePending(isElevationPending(elevationState));

  /// Comme [update], pour un état d'attente déjà calculé : l'altitude
  /// provisoire **ou** un revêtement en cours de calcul (`MOB-81`).
  void updatePending(bool pending) {
    if (!pending) {
      _stop();
      _pendingSince = null;
      return;
    }
    _pendingSince ??= _now();
    if (_expired) {
      _stop();
      return;
    }
    _timer ??= Timer.periodic(kElevationPollInterval, (_) {
      if (_expired) {
        _stop();
        return;
      }
      refresh();
    });
  }

  bool get _expired =>
      _now().difference(_pendingSince!) >= kElevationPollGiveUp;

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => _stop();
}
