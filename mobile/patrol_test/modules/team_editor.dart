import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';

import 'module.dart';

/// The team form: creating a team from « Mes équipes » (ledger `MOB-165`), and its settings —
/// the same screen in edit mode, with the address, the visibility, the webhook and the danger
/// zone (ledger `MOB-166`).
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

  // ── Settings (ledger `MOB-166`) ─────────────────────────────────────────

  /// The refusal someone who does not administer the team reads instead of the form.
  Future<bool> showsForbidden() async {
    await $(keys.teamEditor.forbidden).waitUntilExists();
    return !isShown(keys.teamEditor.nameField);
  }

  /// The address row shows the team's current slug.
  bool slugShows(String slug) => shows(keys.teamEditor.slugRow, slug);

  /// « Adresse » → the sheet → [slug] → « Enregistrer ». The form must be untouched, or the app
  /// asks to discard it first.
  Future<void> changeSlug(String slug) async {
    await (await scrolledTo(keys.teamEditor.slugRow)).tap();
    await $(keys.teamEditor.slugField).waitUntilVisible();
    await $(keys.teamEditor.slugField).enterText(slug);
    await $(keys.teamEditor.slugSave).tap();
    await waitUntilGone(keys.teamEditor.slugSave);
  }

  /// Whether the visibility is only read — a badge, for a team whose administrators may not
  /// change it.
  Future<bool> visibilityIsReadOnly() async {
    await scrolledTo(keys.teamEditor.visibilityRow);
    return isShown(keys.teamEditor.visibilityBadge);
  }

  /// The visibility row → its sheet → [visibility] (`TEAM`, `PUBLIC_UNLISTED`, `PUBLIC`).
  Future<void> pickVisibility(String visibility) async {
    await (await scrolledTo(keys.teamEditor.visibilityRow)).tap();
    await $(keys.teamEditor.visibilityOption(visibility)).tap();
    await waitUntilGone(keys.teamEditor.visibilityOption(visibility));
  }

  /// Confirms the sheet a destructive step opens — « Rendre privée », « Oui, supprimer l'équipe ».
  Future<void> confirm() async {
    await $(keys.profile.confirmDestructiveButton).waitUntilVisible();
    await $(keys.profile.confirmDestructiveButton).tap();
    await waitUntilGone(keys.profile.confirmDestructiveButton);
  }

  /// Whether the confirmation on screen says [text] (« Rendre l'équipe privée ? » has the
  /// consequence in its message).
  Future<bool> confirmationShows(String text) async {
    await $(keys.profile.confirmDestructiveMessage).waitUntilVisible();
    return shows(keys.profile.confirmDestructiveMessage, text);
  }

  /// « Supprimer l'équipe », at the very bottom, in the danger zone.
  Future<void> delete() async {
    await (await scrolledTo(keys.teamEditor.deleteButton)).tap();
  }

  // ── Webhook sheet ───────────────────────────────────────────────────────

  /// The « Webhook » row → its sheet, once its URL field is there.
  Future<void> openWebhook() async {
    await (await scrolledTo(keys.teamEditor.webhookRow)).tap();
    await $(keys.teamWebhook.urlField).waitUntilVisible();
  }

  /// Whether the webhook sheet offers to test or delete a webhook — only once one is saved.
  bool get webhookIsConfigured => isShown(keys.teamWebhook.testButton);

  Future<void> enterWebhookUrl(String url) async {
    await $(keys.teamWebhook.urlField).enterText(url);
  }

  /// « Fermer », in the sheet's header: back to the settings.
  Future<void> closeWebhook() async {
    await $(keys.teamWebhook.closeButton).tap();
    await waitUntilGone(keys.teamWebhook.sheet);
  }

  Future<void> saveWebhook() async {
    await $(keys.teamWebhook.saveButton).tap();
  }

  /// Waits for what the server refused, atop the webhook sheet.
  Future<bool> webhookErrorShows(String text) async {
    await $(keys.teamWebhook.errorBanner).waitUntilVisible();
    return shows(keys.teamWebhook.errorBanner, text);
  }
}
