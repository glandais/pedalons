import '../../../api/generated/export.dart';
import '../providers/ride_detail_provider.dart';

/// L'action offerte par une carte de groupe.
///
/// **Toutes dérivées de champs serveur** : `registered` et `full` sont
/// calculés par l'API depuis la 1.3.0, `registeredGroupId` dit où l'on est
/// inscrit. Rien ici ne parcourt `participants[]`, qui est vide sans droit de
/// lecture et tronqué au-delà de cinq entrées — c'était la cause de
/// « Participer » proposé à un inscrit, puis du 409 qui suivait.
///
/// Combinées au drapeau `pending` de `RideGroupCard`, elles donnent les états
/// visuels d'une carte : rien, « Rejoindre » (en chargement ou non),
/// « Changer pour {groupe} », « Complet » désactivé, et — inscrite ici — le
/// badge « J'y vais » et le lien « Quitter le groupe » en pied de carte
/// (docs/LEDGER_*.md MOB-134, lot 8). Les écrans les lisent au travers de
/// `rideRegistrationControlAction`, qui juge chaque groupe sur son départ.
enum RideGroupAction {
  /// Aucune action : sortie passée ou annulée, ou utilisateur non membre.
  none,

  /// `PdlButton(fill, sm)` « Rejoindre ».
  join,

  /// « Changer pour {groupe} » : l'utilisateur est inscrit dans un **autre**
  /// groupe de la sortie, et celui-ci est ouvert — ni complet, ni parti, jugé
  /// sur **son** départ (`startAt`, ledger `API-170`). Un seul appel,
  /// `RideRegistrationController.switchGroup` (ledger `API-171`).
  switchTo,

  /// L'utilisateur est dans **ce** groupe : badge « J'y vais », et le lien
  /// « Quitter le groupe ».
  leave,

  /// `PdlButton(sm)` désactivé « Complet ».
  full,
}

/// Dérive l'action d'un groupe, sans heuristique.
///
/// [canRegister] est le droit que le backend calcule pour la sortie
/// (`permissions.canRegister`, docs/LEDGER_*.md MOB-137) : sans lui — non-
/// membre, sortie non publiée —, aucun bouton ; un bandeau prend sa place à
/// l'échelle de l'écran. [now] ne sert
/// qu'aux tests.
RideGroupAction rideGroupAction({
  required RideDto ride,
  required RideGroupDto group,
  required bool canRegister,
  DateTime? now,
}) {
  // Une sortie annulée ne propose rien, **pas même « Quitter »** : elle n'a
  // plus lieu, se désinscrire n'a plus de sens.
  if (ride.isCancelled || ride.isPast) return RideGroupAction.none;
  if (group.registered) return RideGroupAction.leave;
  if (!canRegister) return RideGroupAction.none;
  if (group.full) return RideGroupAction.full;
  final RideGroupDto? mine = ride.joinedGroup;
  if (mine != null && mine.id != group.id && !_hasLeft(group, now)) {
    return RideGroupAction.switchTo;
  }
  return RideGroupAction.join;
}

/// Le groupe est-il parti ? Sur son propre départ : un groupe plus tardif
/// reste ouvert quand le premier a quitté le rendez-vous (ledger `API-170`).
bool _hasLeft(RideGroupDto group, DateTime? now) {
  final DateTime? start = DateTime.tryParse(group.startAt);
  if (start == null) return false;
  return !start.isAfter((now ?? DateTime.now()).toUtc());
}
