import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../core/utils/formatters.dart';
import '../data/trip_repository.dart';

/// Ce qui identifie un voyage : son équipe et son slug.
@immutable
class TripKey {
  const TripKey({required this.teamSlug, required this.tripSlug});

  final String teamSlug;
  final String tripSlug;

  @override
  bool operator ==(Object other) =>
      other is TripKey &&
      other.teamSlug == teamSlug &&
      other.tripSlug == tripSlug;

  @override
  int get hashCode => Object.hash(teamSlug, tripSlug);

  @override
  String toString() => 'TripKey($teamSlug/$tripSlug)';
}

/// Le détail d'un voyage, `stages[]` peuplées.
///
/// Point d'entrée **unique** : l'écran 24, l'écran 25 — qui n'a pas d'endpoint
/// dédié et n'en a pas besoin, son rail d'étapes veut de toute façon la liste
/// complète — et le contrôleur de participation le partagent. Passer d'une
/// étape à l'autre ne recharge donc rien.
///
/// `autoDispose`, contrairement au détail d'une sortie : ce partage n'a besoin
/// que des écrans ouverts. L'écran 25 se pose **sur** l'écran 24 (un lien
/// profond reconstruit la pile, `ancestorsForDeepLink`), qui garde donc le
/// détail vivant tant qu'on passe d'une étape à l'autre ; une fois le voyage
/// refermé, rien ne le retient. Gardé pour la vie de l'app, un voyage annulé
/// ou modifié par l'organisateur restait affiché tel quel jusqu'au prochain
/// lancement. Le tirer-pour-rafraîchir de l'écran 24 l'invalide aussi.
final tripDetailProvider = FutureProvider.autoDispose.family<TripDto, TripKey>(
  (Ref ref, TripKey key) =>
      ref.watch(tripRepositoryProvider).getTrip(key.teamSlug, key.tripSlug),
);

/// Les dérivés temporels d'un voyage.
///
/// Comme pour les sorties, « passé » vient du serveur (`TripDto.finished`,
/// `docs/LEDGER_*.md API-16`). Il se juge sur la **dernière étape** quand il y
/// en a une : une traversée de sept jours n'est pas « passée » le lendemain de
/// son départ.
///
/// Les dates d'un voyage sont des rendez-vous : elles se lisent à l'heure
/// murale du fuseau de l'entité, jamais en UTC (docs/LEDGER_*.md API-60,
/// plan §7). Un voyage multi-fuseaux prend son départ dans le fuseau de sa
/// première étape (`timezone`), sa fin dans celui de sa dernière.
extension TripTiming on TripDto {
  DateTime? get startsAt => AppFormatters.tryParseZoneTime(dateTime, timezone);

  /// Le fuseau de la fin : celui de l'étape **la plus tardive** quand les
  /// étapes sont chargées (le détail), celui du voyage sinon (une ligne de
  /// liste, où `TripDto.endDate` est documenté dans `timezone`).
  ///
  /// La plus tardive par instant, pas la dernière par ordre : `endDate` est le
  /// plus grand `dateTime` des étapes, quel que soit l'ordre que
  /// l'organisateur leur a donné — la règle du web (`tripEndZone`) et du
  /// backend (docs/LEDGER_*.md API-60).
  String get endTimezone {
    TripStageDto? latest;
    DateTime? latestAt;
    for (final TripStageDto stage in stages) {
      final DateTime? at = DateTime.tryParse(stage.dateTime);
      if (at == null) continue;
      if (latestAt == null || !at.isBefore(latestAt)) {
        latest = stage;
        latestAt = at;
      }
    }
    return latest?.timezone ?? timezone;
  }

  DateTime? get endsAt => AppFormatters.tryParseZoneTime(endDate, endTimezone);

  bool get isPast => finished;

  bool get isCancelled => status == 'CANCELLED';

  /// Les étapes dans l'ordre d'affichage.
  ///
  /// `stageIndex` est le rang **imprimable** livré en 1.5.0 ; `sortOrder` est un
  /// rang persistant qui peut avoir des trous. Le tri se fait donc sur le
  /// premier, et la couleur d'une étape s'indexe sur `stageIndex - 1`, pas sur
  /// sa position dans la liste reçue.
  List<TripStageDto> get orderedStages {
    final List<TripStageDto> ordered = List<TripStageDto>.of(stages)
      ..sort((TripStageDto a, TripStageDto b) {
        final int byIndex = a.stageIndex.compareTo(b.stageIndex);
        return byIndex != 0 ? byIndex : a.sortOrder.compareTo(b.sortOrder);
      });
    return ordered;
  }
}

extension TripStageTiming on TripStageDto {
  /// Le départ de l'étape dans **son** fuseau, qui peut différer de celui du
  /// voyage (docs/LEDGER_*.md API-60).
  DateTime? get startsAt => AppFormatters.tryParseZoneTime(dateTime, timezone);

  /// Le rang à partir de zéro — l'index de palette de l'étape.
  int get paletteIndex => stageIndex - 1;
}
