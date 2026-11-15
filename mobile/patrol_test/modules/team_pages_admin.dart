import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';

import 'module.dart';

/// « Pages de l'équipe » of the team's administration (ledger `MOB-169`): the list of the team's
/// custom pages — reorder, delete, restore — and the editor of one page.
final class TeamPagesAdmin extends Module {
  TeamPagesAdmin(super.$);

  // ── List ────────────────────────────────────────────────────────────────

  /// The list is on screen once its « n pages sur 3 maximum » is: only an administrator gets it.
  Future<void> waitUntilShown() async {
    await $(keys.teamPages.count).waitUntilVisible();
  }

  /// The refusal someone who does not administer the team reads instead of the list.
  Future<bool> showsForbidden() async {
    await $(keys.teamPages.forbidden).waitUntilExists();
    return !isShown(keys.teamPages.count);
  }

  /// « n pages sur 3 maximum ».
  bool countShows(String text) => shows(keys.teamPages.count, text);

  /// Waits until the count reads [text] — a write was answered and the list read again.
  Future<void> waitUntilCountShows(
    String text, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!countShows(text)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('the page count does not read $text after $timeout');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Whether « Ajouter une page » is offered — gone at three pages.
  bool get offersAdd => isShown(keys.teamPages.addButton);

  /// Waits for the row of the page [pageId].
  Future<void> waitUntilPageIsShown(String pageId) async {
    await scrolledIntoView(keys.teamPages.row(pageId));
  }

  bool showsPage(String pageId) => isShown(keys.teamPages.row(pageId));

  /// Whether the row of [pageId] shows [text] — its title.
  bool pageShows(String pageId, String text) =>
      shows(keys.teamPages.row(pageId), text);

  /// Waits until the row of [pageId] shows [text] — a renamed page.
  Future<void> waitUntilPageShows(
    String pageId,
    String text, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!pageShows(pageId, text)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('page $pageId does not show $text after $timeout');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Whether the row offers « monter » / « descendre »: the first row has no way up, the last no
  /// way down.
  bool canMoveUp(String pageId) => isShown(keys.teamPages.rowMoveUp(pageId));

  bool canMoveDown(String pageId) =>
      isShown(keys.teamPages.rowMoveDown(pageId));

  /// Whether the row of [pageId] is above the row of [otherId] on screen.
  bool isAbove(String pageId, String otherId) =>
      $.tester.getTopLeft(find.byKey(keys.teamPages.row(pageId))).dy <
      $.tester.getTopLeft(find.byKey(keys.teamPages.row(otherId))).dy;

  /// « Monter » on the row of [pageId]; waits until it stands above [otherId].
  Future<void> moveUp(String pageId, {required String above}) async {
    await (await scrolledTo(keys.teamPages.rowMoveUp(pageId))).tap();
    await _waitUntilAbove(pageId, above);
  }

  /// « Descendre » on the row of [pageId]; waits until it stands below [otherId].
  Future<void> moveDown(String pageId, {required String below}) async {
    await (await scrolledTo(keys.teamPages.rowMoveDown(pageId))).tap();
    await _waitUntilAbove(below, pageId);
  }

  Future<void> _waitUntilAbove(String pageId, String otherId) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!isAbove(pageId, otherId)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('page $pageId is not above $otherId after 15 s');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Whether the row of [pageId] carries « Supprimé » — and then offers « Restaurer » only.
  bool isDeleted(String pageId) => isShown(keys.teamPages.rowDeleted(pageId));

  /// The bin of the row of [pageId] → the confirmation, which names the page.
  Future<void> openDelete(String pageId) async {
    await (await scrolledTo(keys.teamPages.rowDelete(pageId))).tap();
    await $(keys.profile.confirmDestructiveButton).waitUntilVisible();
  }

  /// Whether the open confirmation says [text] — the page's title.
  bool deleteMessageShows(String text) =>
      shows(keys.profile.confirmDestructiveMessage, text);

  /// Confirms the open deletion; the row of [pageId] is marked deleted after — it stays in the
  /// list, to be restored.
  Future<void> confirmDelete(String pageId) async {
    await $(keys.profile.confirmDestructiveButton).tap();
    await $(keys.teamPages.rowDeleted(pageId)).waitUntilVisible();
  }

  /// « Restaurer » on the row of [pageId]; the row is a live page again after.
  Future<void> restore(String pageId) async {
    await (await scrolledTo(keys.teamPages.rowRestore(pageId))).tap();
    await waitUntilGone(keys.teamPages.rowDeleted(pageId));
  }

  /// « Ajouter une page », atop the list → the editor, empty.
  Future<void> openNew() async {
    await scrolledUpTo(keys.teamPages.addButton);
    await $(keys.teamPages.addButton).tap();
    await waitUntilEditorIsShown();
  }

  /// The pencil of the row of [pageId] → the editor, pre-filled.
  Future<void> openEdit(String pageId) async {
    await (await scrolledTo(keys.teamPages.rowEdit(pageId))).tap();
    await waitUntilEditorIsShown();
  }

  // ── Editor ──────────────────────────────────────────────────────────────

  /// The editor is on screen once its title field is.
  Future<void> waitUntilEditorIsShown() async {
    await $(keys.teamPageEditor.titleField).waitUntilVisible();
  }

  /// The refusal someone who may not edit the page reads instead of the form.
  Future<bool> editorShowsForbidden() async {
    await $(keys.teamPageEditor.forbidden).waitUntilExists();
    return !isShown(keys.teamPageEditor.titleField);
  }

  Future<void> enterTitle(String title) async {
    await $(keys.teamPageEditor.titleField).enterText(title);
  }

  /// What the title field holds.
  String get title =>
      $.tester
          .widget<TextField>(find.byKey(keys.teamPageEditor.titleField))
          .controller
          ?.text ??
      '';

  /// Whether the title field carries its error (« Entre 1 et 100 caractères »).
  bool titleShows(String text) => shows(keys.teamPageEditor.titleField, text);

  /// Whether the address row (edit mode only) shows [slug].
  bool slugShows(String slug) => shows(keys.teamPageEditor.slugRow, slug);

  /// Picks the visibility [visibility] (`TEAM`, `PUBLIC_UNLISTED`, `PUBLIC`), lower in the form.
  Future<void> pickVisibility(String visibility) async {
    await (await scrolledTo(keys.visibility.option(visibility))).tap();
  }

  /// Whether the editor offers the visibility [visibility] at all.
  bool offersVisibility(String visibility) =>
      isShown(keys.visibility.option(visibility));

  /// « Créer la page » / « Enregistrer », in the action bar: always on screen. Does not wait for
  /// the editor to close: an invalid or refused form keeps it open.
  Future<void> save() async {
    await $(keys.teamPageEditor.saveButton).tap();
  }

  /// The editor closed: the page was saved and the list is back.
  Future<void> waitUntilEditorIsGone() =>
      waitUntilGone(keys.teamPageEditor.saveButton);

  /// Waits for the banner atop the form — an invalid form, or what the server refused.
  Future<void> waitUntilEditorErrorIsShown() async {
    await scrolledUpTo(keys.teamPageEditor.errorBanner);
  }

  bool editorErrorShows(String text) =>
      shows(keys.teamPageEditor.errorBanner, text);
}
