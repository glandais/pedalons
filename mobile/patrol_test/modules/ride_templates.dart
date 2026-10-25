import 'package:flutter_test/flutter_test.dart';

import 'module.dart';

/// The ride templates (ledger `MOB-78`): the list, the form and the menu behind `⋯`, reached from
/// the team dashboard's « Gérer les modèles » or by a link.
final class RideTemplates extends Module {
  RideTemplates(super.$);

  /// The team dashboard (the team page, for an organizer) → « Gérer les modèles » → the list.
  Future<void> openFromDashboard() async {
    await (await scrolledTo(keys.teamDashboard.templatesManageButton)).tap();
    await waitUntilListShown();
  }

  /// The list is on screen once its « + » is — whatever it holds, loaded or not.
  Future<void> waitUntilListShown() async {
    await $(keys.rideTemplates.newButton).waitUntilVisible();
  }

  /// Waits until the list says it holds no template.
  ///
  /// Placed, not visible: Patrol's « visible » (hit-testable at its centre) doesn't hold for an
  /// empty state — it failed so on iOS, while Android let it through.
  Future<void> showsEmpty() async {
    await $(keys.rideTemplates.empty).waitUntilExists();
  }

  /// The refusal a plain member reads instead of the list or the form.
  Future<bool> showsForbidden() async {
    await $(keys.rideTemplates.forbidden).waitUntilExists();
    return !isShown(keys.rideTemplates.newButton) &&
        !isShown(keys.rideTemplateEditor.saveButton);
  }

  /// « Nouveau modèle »: the empty state's button when the list is empty, the app bar's « + »
  /// otherwise.
  Future<void> startNew() async {
    if (isShown(keys.rideTemplates.emptyNewButton)) {
      await $(keys.rideTemplates.emptyNewButton).tap();
    } else {
      await $(keys.rideTemplates.newButton).tap();
    }
    await waitUntilFormShown();
  }

  Future<void> waitUntilFormShown() async {
    await $(keys.rideTemplateEditor.nameField).waitUntilVisible();
  }

  Future<void> enterName(String name) async {
    await $(keys.rideTemplateEditor.nameField).enterText(name);
  }

  Future<void> enterNextNumber(String number) async {
    await $(keys.rideTemplateEditor.nextNumberField).enterText(number);
  }

  Future<void> enterGroupName(int index, String name) async {
    await (await scrolledTo(keys.rideTemplateEditor.groupName(index)))
        .enterText(name);
  }

  Future<void> enterGroupMax(int index, String max) async {
    await (await scrolledTo(keys.rideTemplateEditor.groupMax(index)))
        .enterText(max);
  }

  /// « Enregistrer », then waits for the form to leave: the list is underneath.
  Future<void> save() async {
    await $(keys.rideTemplateEditor.saveButton).tap();
    await waitUntilGone(
      keys.rideTemplateEditor.saveButton,
      timeout: const Duration(seconds: 20),
    );
  }

  // ── On the list ───────────────────────────────────────────────────────

  /// Waits until the card of [slug] reads [text] — after a save, the list reloads.
  Future<void> cardShows(String slug, String text) async {
    await $(keys.rideTemplates.card(slug)).waitUntilVisible();
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!shows(keys.rideTemplates.card(slug), text)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('card $slug never read « $text »');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> openMenu(String slug) async {
    await $(keys.rideTemplates.moreButton(slug)).tap();
    await $(keys.rideTemplates.menuDelete).waitUntilVisible();
  }

  /// Menu → « Créer une sortie depuis ce modèle »: the ride editor opens on the template.
  Future<void> createRideFromMenu(String slug) async {
    await openMenu(slug);
    await $(keys.rideTemplates.menuCreateRide).tap();
    await $(keys.rideEditor.nameField).waitUntilVisible();
  }

  /// Menu → « Modifier le modèle »: the form opens on the template.
  Future<void> editFromMenu(String slug) async {
    await openMenu(slug);
    await $(keys.rideTemplates.menuEdit).tap();
    await waitUntilFormShown();
  }

  /// Menu → « Supprimer le modèle », through its confirmation: the card leaves the list.
  Future<void> deleteFromMenu(String slug) async {
    await openMenu(slug);
    await $(keys.rideTemplates.menuDelete).tap();
    await $(keys.profile.confirmDestructiveButton).waitUntilVisible();
    await $(keys.profile.confirmDestructiveButton).tap();
    await waitUntilGone(
      keys.rideTemplates.card(slug),
      timeout: const Duration(seconds: 20),
    );
  }
}
