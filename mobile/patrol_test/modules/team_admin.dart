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

  /// « Paramètres », the last row — an administrator's — opens the settings in the app (ledger
  /// `MOB-166`).
  Future<void> openSettings() async {
    await (await scrolledTo(keys.teamAdmin.settings)).tap();
  }

  /// « Membres » — an administrator's — opens the members screen in the app (ledger
  /// `MOB-167`).
  Future<void> openMembers() async {
    await (await scrolledTo(keys.teamAdmin.members)).tap();
  }

  /// « Lieux » — every organizer's — opens the places screen in the app (ledger `MOB-168`).
  Future<void> openPlaces() async {
    await (await scrolledTo(keys.teamAdmin.places)).tap();
  }

  /// « Signalements » — every organizer's — opens the moderation queue in the app (ledger
  /// `MOB-168`).
  Future<void> openReports() async {
    await (await scrolledTo(keys.teamAdmin.reports)).tap();
  }

  /// « Tags » — an administrator's — opens the tag vocabulary in the app (ledger `MOB-169`).
  Future<void> openTags() async {
    await (await scrolledTo(keys.teamAdmin.tags)).tap();
  }

  /// « Pages » — an administrator's — opens the team's custom pages in the app (ledger
  /// `MOB-169`).
  Future<void> openPages() async {
    await (await scrolledTo(keys.teamAdmin.pages)).tap();
  }

  bool _all(List<Key> rows) => rows.every(isShown);
}
