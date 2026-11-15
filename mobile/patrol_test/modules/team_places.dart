import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'module.dart';

/// « Lieux » (ledger `MOB-168`): the team's start and end points, their search, and the sheet
/// that creates or edits one.
final class TeamPlaces extends Module {
  TeamPlaces(super.$);

  /// The screen is on screen once its search field is: only an organizer gets it.
  Future<void> waitUntilShown() async {
    await $(keys.teamPlaces.searchField).waitUntilVisible();
  }

  /// The refusal someone who does not organize the team reads instead of the list.
  Future<bool> showsForbidden() async {
    await $(keys.teamPlaces.forbidden).waitUntilExists();
    return !isShown(keys.teamPlaces.searchField);
  }

  // ── List ────────────────────────────────────────────────────────────────

  /// Waits for the row of the place [placeId].
  Future<void> waitUntilPlaceIsShown(String placeId) async {
    await scrolledTo(keys.teamPlaces.rowEdit(placeId));
  }

  bool showsPlace(String placeId) => isShown(keys.teamPlaces.row(placeId));

  Future<void> waitUntilPlaceIsGone(String placeId) =>
      waitUntilGone(keys.teamPlaces.row(placeId));

  /// Whether the row of [placeId] shows [text] — its name, its address.
  bool placeShows(String placeId, String text) =>
      shows(keys.teamPlaces.row(placeId), text);

  /// Waits until the row of [placeId] shows [text] — an edited place is rewritten where it is.
  Future<void> waitUntilPlaceShows(
    String placeId,
    String text, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!placeShows(placeId, text)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('place $placeId does not show $text after $timeout');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Whether the row carries its « Départ » / « Arrivée » badge.
  bool isStart(String placeId) => isShown(keys.teamPlaces.rowStart(placeId));

  bool isEnd(String placeId) => isShown(keys.teamPlaces.rowEnd(placeId));

  /// Types [text] in the search field; the list is read again once the typing settles.
  Future<void> search(String text) async {
    await scrolledUpTo(keys.teamPlaces.searchField);
    await $(keys.teamPlaces.searchField).enterText(text);
  }

  /// The search that matched nothing: « Aucun lieu trouvé ».
  Future<void> waitUntilSearchIsEmpty() async {
    await $(keys.teamPlaces.searchEmpty).waitUntilVisible();
  }

  // ── Form sheet ──────────────────────────────────────────────────────────

  /// « Ajouter un lieu » → the empty form.
  Future<void> openNewForm() async {
    await scrolledUpTo(keys.teamPlaces.addButton);
    await $(keys.teamPlaces.addButton).tap();
    await $(keys.teamPlaces.formName).waitUntilVisible();
  }

  /// The pencil of the row of [placeId] → its form, pre-filled.
  Future<void> openEditForm(String placeId) async {
    await (await scrolledTo(keys.teamPlaces.rowEdit(placeId))).tap();
    await $(keys.teamPlaces.formName).waitUntilVisible();
  }

  Future<void> enterName(String name) async {
    await $(keys.teamPlaces.formName).enterText(name);
  }

  Future<void> enterAddress(String address) async {
    await $(keys.teamPlaces.formAddress).enterText(address);
  }

  /// Flips « Peut servir d'arrivée », lower in the sheet.
  Future<void> toggleEnd() async {
    await (await $(keys.teamPlaces.formEndSwitch).scrollTo(view: _sheetList))
        .tap();
  }

  /// « Ajouter » / « Enregistrer », in the sheet's footer: always on screen. Does not wait for the
  /// sheet to close: an invalid or refused form keeps it open.
  Future<void> submit() async {
    await $(keys.teamPlaces.formSubmit).tap();
  }

  /// The sheet closed: the place was saved.
  Future<void> waitUntilFormIsGone() =>
      waitUntilGone(keys.teamPlaces.formSheet);

  /// Whether the sheet, still open, shows [text] in its banner — an invalid form, or what the
  /// server refused.
  Future<bool> formErrorShows(String text) async {
    await $(keys.teamPlaces.formErrorBanner).waitUntilVisible();
    return shows(keys.teamPlaces.formErrorBanner, text);
  }

  /// « Fermer », in the sheet's header: nothing is saved.
  Future<void> closeForm() async {
    await $(keys.teamPlaces.formClose).tap();
    await waitUntilFormIsGone();
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  /// The bin of the row of [placeId] → the confirmation; the row is gone after.
  Future<void> delete(String placeId) async {
    await (await scrolledTo(keys.teamPlaces.rowDelete(placeId))).tap();
    await $(keys.profile.confirmDestructiveButton).waitUntilVisible();
    await $(keys.profile.confirmDestructiveButton).tap();
    await waitUntilPlaceIsGone(placeId);
  }

  /// The form's own list, not the screen's underneath.
  Finder get _sheetList => find
      .descendant(
        of: find.byKey(keys.teamPlaces.formSheet),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      )
      .first;
}
