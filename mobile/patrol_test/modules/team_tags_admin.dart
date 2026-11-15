import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';

import 'module.dart';

/// « Tags » of the team's administration (ledger `MOB-169`): the vocabulary, one kind of content
/// at a time, and the sheet that creates, renames or recolours a tag.
final class TeamTagsAdmin extends Module {
  TeamTagsAdmin(super.$);

  /// The screen is on screen once « Nouveau tag » is: only an administrator gets it.
  Future<void> waitUntilShown() async {
    await $(keys.teamTags.addButton).waitUntilVisible();
  }

  /// The refusal someone who does not administer the team reads instead of the vocabulary.
  Future<bool> showsForbidden() async {
    await $(keys.teamTags.forbidden).waitUntilExists();
    return !isShown(keys.teamTags.addButton);
  }

  // ── Kinds ───────────────────────────────────────────────────────────────

  /// Whether the kind [type] (`RIDE`, `POST`, `TRIP`, `ROUTE`, `AD`) has its chip.
  bool offersKind(String type) => isShown(keys.teamTags.kind(type));

  /// The label of the chip of [type], count included — « Parcours (1) ».
  String kindLabel(String type) =>
      $.tester.widget<PdlChip>(find.byKey(keys.teamTags.kind(type))).label;

  /// Opens the kind [type]; the chips scroll sideways.
  Future<void> openKind(String type) async {
    final Finder chip = find.byKey(keys.teamTags.kind(type));
    await $.tester.ensureVisible(chip);
    await $.pump(const Duration(milliseconds: 300));
    await $(keys.teamTags.kind(type)).tap();
  }

  /// Waits until the chip of [type] reads [label] — a write was answered and the vocabulary read
  /// again.
  Future<void> waitUntilKindReads(
    String type,
    String label, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (kindLabel(type) != label) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure(
          'the $type chip reads ${kindLabel(type)}, not $label, after $timeout',
        );
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// « n / 100 tags pour ce type », above the rows.
  bool limitShows(String text) => shows(keys.teamTags.limit, text);

  // ── Rows ────────────────────────────────────────────────────────────────

  /// Waits for the row of the tag [tagId].
  Future<void> waitUntilTagIsShown(String tagId) async {
    await scrolledTo(keys.teamTags.rowEdit(tagId));
  }

  bool showsTag(String tagId) => isShown(keys.teamTags.row(tagId));

  Future<void> waitUntilTagIsGone(String tagId) =>
      waitUntilGone(keys.teamTags.row(tagId));

  /// Whether the row of [tagId] shows [text] — its label, its usage.
  bool tagShows(String tagId, String text) =>
      shows(keys.teamTags.row(tagId), text);

  /// Waits until the row of [tagId] shows [text] — a renamed tag.
  Future<void> waitUntilTagShows(
    String tagId,
    String text, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!tagShows(tagId, text)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('tag $tagId does not show $text after $timeout');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  // ── Form sheet ──────────────────────────────────────────────────────────

  /// « Nouveau tag » → the empty form, for the kind that is open.
  Future<void> openNewForm() async {
    await scrolledUpTo(keys.teamTags.addButton);
    await $(keys.teamTags.addButton).tap();
    await $(keys.teamTags.formLabel).waitUntilVisible();
  }

  /// The pencil of the row of [tagId] → its form, pre-filled.
  Future<void> openEditForm(String tagId) async {
    await (await scrolledTo(keys.teamTags.rowEdit(tagId))).tap();
    await $(keys.teamTags.formLabel).waitUntilVisible();
  }

  Future<void> enterLabel(String label) async {
    await $(keys.teamTags.formLabel).enterText(label);
  }

  /// Picks the colour [color] (`GREEN`, `RED`… the contract's value).
  Future<void> pickColor(String color) async {
    await $(keys.teamTags.formColor(color)).tap();
  }

  /// Whether the sheet previews the tag as [label].
  bool previewShows(String label) => shows(keys.teamTags.formPreview, label);

  /// « Créer » / « Enregistrer », in the sheet's footer. Does not wait for the sheet to close: an
  /// invalid or refused form keeps it open.
  Future<void> submit() async {
    await $(keys.teamTags.formSubmit).tap();
  }

  /// The sheet closed: the tag was saved.
  Future<void> waitUntilFormIsGone() => waitUntilGone(keys.teamTags.formSheet);

  /// Whether the label field, still on screen, shows [text] — its error.
  Future<bool> labelShows(String text) async {
    await $(keys.teamTags.formLabel).waitUntilVisible();
    return shows(keys.teamTags.formLabel, text);
  }

  /// Whether the sheet, still open, shows [text] in its banner — what the server refused.
  Future<bool> formErrorShows(String text) async {
    await $(keys.teamTags.formErrorBanner).waitUntilVisible();
    return shows(keys.teamTags.formErrorBanner, text);
  }

  /// « Fermer », in the sheet's header: nothing is saved.
  Future<void> closeForm() async {
    await $(keys.teamTags.formClose).tap();
    await waitUntilFormIsGone();
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  /// The bin of the row of [tagId] → the confirmation, which shows the tag's chip.
  Future<void> openDelete(String tagId) async {
    await (await scrolledTo(keys.teamTags.rowDelete(tagId))).tap();
    await $(keys.profile.confirmDestructiveButton).waitUntilVisible();
  }

  /// Whether the open confirmation shows the chip of the tag as [label].
  bool deleteChipShows(String label) => shows(keys.teamTags.deleteChip, label);

  /// Whether the open confirmation says [text] — how many contents lose the tag.
  bool deleteMessageShows(String text) =>
      shows(keys.profile.confirmDestructiveMessage, text);

  /// Confirms the open deletion; the row of [tagId] is gone after.
  Future<void> confirmDelete(String tagId) async {
    await $(keys.profile.confirmDestructiveButton).tap();
    await waitUntilTagIsGone(tagId);
  }
}
