import 'package:flutter/widgets.dart';

import 'module.dart';

/// « Gestion de l'équipe » (ledger `MOB-165`): the hub an organizer reaches from the team header,
/// one row per administration screen.
final class TeamAdmin extends Module {
  TeamAdmin(super.$);

  /// Whether the team header offers « Gérer l'équipe » — organizers and administrators only.
  bool get offeredInHeader => isShown(keys.team.manageButton);

  /// The team header's « Gérer l'équipe » → the hub.
  Future<void> openFromHeader() async {
    await $(keys.team.manageButton).tap();
    await waitUntilShown();
  }

  /// The hub is on screen once its first row is: every organizer has « Modèles de sortie ».
  Future<void> waitUntilShown() async {
    await $(keys.teamAdmin.rideTemplates).waitUntilVisible();
  }

  /// The refusal a plain member reads instead of the rows.
  Future<bool> showsForbidden() async {
    await $(keys.teamAdmin.forbidden).waitUntilExists();
    return !isShown(keys.teamAdmin.rideTemplates);
  }

  /// The rows every organizer gets.
  bool get showsOrganizerRows => _all(<Key>[
    keys.teamAdmin.rideTemplates,
    keys.teamAdmin.places,
    keys.teamAdmin.reports,
  ]);

  /// The rows only an administrator gets.
  bool get showsAdminRows => _all(<Key>[
    keys.teamAdmin.tags,
    keys.teamAdmin.pages,
    keys.teamAdmin.members,
    keys.teamAdmin.settings,
  ]);

  bool _all(List<Key> rows) => rows.every(isShown);
}
