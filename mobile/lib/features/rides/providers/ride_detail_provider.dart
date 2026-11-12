import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../core/utils/formatters.dart';
import '../data/ride_repository.dart';

/// Ce qui identifie une sortie : son équipe et son slug.
@immutable
class RideKey {
  const RideKey({required this.teamSlug, required this.rideSlug});

  final String teamSlug;
  final String rideSlug;

  @override
  bool operator ==(Object other) =>
      other is RideKey &&
      other.teamSlug == teamSlug &&
      other.rideSlug == rideSlug;

  @override
  int get hashCode => Object.hash(teamSlug, rideSlug);

  @override
  String toString() => 'RideKey($teamSlug/$rideSlug)';
}

/// Le détail d'une sortie, `groups[]` peuplées.
///
/// Point d'entrée **unique** du détail : l'écran 12, le contrôleur
/// d'inscription et le bloc « Ma prochaine sortie » de l'accueil (S11-1) le
/// partagent, si bien qu'ouvrir la sortie depuis l'accueil ne recharge rien.
///
/// Non `autoDispose` : le garder vivant est précisément ce qui rend ce partage
/// utile ; l'invalidation est explicite après une inscription ou un
/// pull-to-refresh.
final rideDetailProvider = FutureProvider.family<RideDto, RideKey>(
  (Ref ref, RideKey key) =>
      ref.watch(rideRepositoryProvider).getRide(key.teamSlug, key.rideSlug),
);

/// Une sortie a-t-elle eu lieu ?
///
/// C'est le serveur qui le dit, par `RideDto.finished` (`docs/LEDGER_*.md
/// API-16`) : l'app le dérivait de l'horloge de l'appareil, faute de champ, et
/// chaque client avait sa variante. `finished` est indépendant du statut : une
/// sortie annulée et passée est les deux. Les écrans 11, 12 et 13 lisent tous
/// [isPast].
extension RideTiming on RideDto {
  /// Le départ, à l'heure murale du **fuseau de la sortie** : c'est un
  /// rendez-vous (docs/LEDGER_*.md API-60, plan §7). La mention éventuelle se
  /// calcule sur [dateTime], l'instant du contrat.
  DateTime? get startsAt => AppFormatters.tryParseZoneTime(dateTime, timezone);

  bool get isPast => finished;

  bool get isCancelled => status == 'CANCELLED';

  /// Le groupe rejoint par l'utilisateur, ou `null`.
  ///
  /// Lu sur `registeredGroupId` : **jamais** en parcourant `participants[]`,
  /// qui est vide sans droit de lecture et donnait de faux négatifs. Cherché
  /// d'abord dans `groups` — que la bascule optimiste tient à jour —, puis
  /// dans `registeredGroup`, seul porteur du groupe sur une ligne de liste
  /// (`docs/LEDGER_*.md API-4`, `groups` y est vide).
  RideGroupDto? get joinedGroup {
    final String? id = registeredGroupId;
    if (id == null) return null;
    for (final RideGroupDto group in groups) {
      if (group.id == id) return group;
    }
    final RideGroupDto? carried = registeredGroup;
    return carried != null && carried.id == id ? carried : null;
  }
}
