import 'package:flutter_test/flutter_test.dart';

import 'module.dart';

/// The ride editor (ledger `MOB-76`) and the organizer's gestures on a ride page: the pencil,
/// and the « Gérer la sortie » menu behind `⋯`.
final class RideEditor extends Module {
  RideEditor(super.$);

  Future<void> waitUntilShown() async {
    await $(keys.rideEditor.nameField).waitUntilVisible();
  }

  /// The refusal a plain member reads instead of the form.
  Future<bool> showsForbidden() async {
    await $(keys.rideEditor.forbidden).waitUntilExists();
    return !isShown(keys.rideEditor.saveButton);
  }

  Future<void> enterName(String name) async {
    await $(keys.rideEditor.nameField).enterText(name);
  }

  /// Waits until the name field reads [name] — a ride started from a template (ledger `MOB-78`)
  /// is titled « Template #n » once the template is loaded.
  Future<void> waitUntilNameReads(String name) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!shows(keys.rideEditor.nameField, name)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('the name field never read « $name »');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Opens the ride's route picker and picks the route [routeSlug].
  Future<void> pickRoute(String routeSlug) async {
    await (await scrolledTo(keys.rideEditor.routeRow)).tap();
    await $(keys.rideEditor.pickerOption(routeSlug)).waitUntilVisible();
    await $(keys.rideEditor.pickerOption(routeSlug)).tap();
    await waitUntilGone(keys.rideEditor.pickerOption(routeSlug));
  }

  /// Whether the ride's route row names [routeName] — at once: the name picked in the sheet
  /// shows before the route's detail is loaded.
  bool routeRowShows(String routeName) =>
      shows(keys.rideEditor.routeRow, routeName);

  /// « Créer la sortie » or « Enregistrer », then waits for the editor to leave.
  Future<void> save() async {
    await $(keys.rideEditor.saveButton).tap();
    await waitUntilGone(
      keys.rideEditor.saveButton,
      timeout: const Duration(seconds: 20),
    );
  }

  // ── On the ride page ──────────────────────────────────────────────────

  /// Waits until the ride page's title reads [name] — after a save, the page reloads.
  Future<void> waitUntilRideTitleIs(String name) async {
    await $(keys.ride.title).waitUntilVisible();
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!shows(keys.ride.title, name)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('ride title never read « $name »');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  bool get offersEdit => isShown(keys.rideManage.editButton);

  Future<void> openEditor() async {
    await $(keys.rideManage.editButton).tap();
    await waitUntilShown();
  }

  /// Publishes a draft from the « Gérer la sortie » menu.
  Future<void> publish() async {
    await _openMenu();
    await $(keys.rideManage.publish).tap();
    await waitUntilGone(keys.rideManage.publish);
  }

  /// Deletes the ride from the menu, through its confirmation.
  Future<void> delete() async {
    await _openMenu();
    await $(keys.rideManage.delete).tap();
    await $(keys.profile.confirmDestructiveButton).waitUntilVisible();
    await $(keys.profile.confirmDestructiveButton).tap();
    await waitUntilGone(keys.ride.title, timeout: const Duration(seconds: 20));
  }

  Future<void> _openMenu() async {
    await $(keys.ride.moreButton).tap();
    await $(keys.rideManage.delete).waitUntilVisible();
  }
}
