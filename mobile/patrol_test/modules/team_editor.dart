import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';

import 'module.dart';

/// The team form (ledger `MOB-165`): creating a team from « Mes équipes ». The team settings
/// (ledger `MOB-166`) will reuse the same screen and the same keys.
final class TeamEditor extends Module {
  TeamEditor(super.$);

  /// « Créer une équipe » in the empty state of « Mes équipes » — someone who belongs to no team.
  Future<void> openFromEmptyTeams() async {
    await $(keys.teams.emptyCreateButton).tap();
    await waitUntilShown();
  }

  /// « Créer une équipe », the « + » of the bar of « Mes équipes » — always there.
  Future<void> openFromTeamsBar() async {
    await $(keys.teams.createButton).tap();
    await waitUntilShown();
  }

  /// The form is on screen once its name field is.
  Future<void> waitUntilShown() async {
    await $(keys.teamEditor.nameField).waitUntilVisible();
  }

  Future<void> enterName(String name) async {
    await $(keys.teamEditor.nameField).enterText(name);
  }

  /// What the name field holds — a refused creation must keep it.
  String get name =>
      $.tester
          .widget<TextField>(find.byKey(keys.teamEditor.nameField))
          .controller
          ?.text ??
      '';

  /// Whether the name field carries its error (« Entre 1 et 200 caractères »).
  bool nameShows(String text) => shows(keys.teamEditor.nameField, text);

  /// Flips « Activer les annonces », lower in the form.
  Future<void> toggleAds() async {
    await (await scrolledTo(keys.teamEditor.enableAds)).tap();
  }

  /// « Créer l'équipe », in the action bar: always on screen.
  Future<void> save() async {
    await $(keys.teamEditor.saveButton).tap();
  }

  /// Waits for the banner atop the form — an invalid form, or what the server refused.
  Future<void> waitUntilErrorIsShown() async {
    await scrolledUpTo(keys.teamEditor.errorBanner);
  }

  bool errorShows(String text) => shows(keys.teamEditor.errorBanner, text);
}
