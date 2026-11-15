import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';

import 'module.dart';

/// « Signalements » (ledger `MOB-168`): a team's moderation queue — one card per reported target,
/// named `TYPE_id` (`POST_…`, `MEMBER_…`) — and the two decisions.
final class TeamReports extends Module {
  TeamReports(super.$);

  /// The screen is on screen once its tabs are: only someone who moderates the team gets them.
  Future<void> waitUntilShown() async {
    await $(keys.teamReports.tab(ReportQueueStatus.open)).waitUntilVisible();
  }

  /// The refusal someone who does not moderate the team reads instead of the queue.
  Future<bool> showsForbidden() async {
    await $(keys.teamReports.forbidden).waitUntilExists();
    return !isShown(keys.teamReports.tab(ReportQueueStatus.open));
  }

  /// The card's name: the target's type and id, as the queue gives them.
  static String card(String targetType, String targetId) =>
      '${targetType}_$targetId';

  /// Waits for the card of [item] ([card]).
  Future<void> waitUntilCardIsShown(String item) async {
    await scrolledIntoView(keys.teamReports.card(item));
  }

  bool showsCard(String item) => isShown(keys.teamReports.card(item));

  Future<void> waitUntilCardIsGone(String item) =>
      waitUntilGone(keys.teamReports.card(item));

  /// Whether the card shows [text] — a badge as displayed (« 1 SIGNALEMENT », « SUPPRIMÉ »), the
  /// author line, the excerpt.
  bool cardShows(String item, String text) =>
      shows(keys.teamReports.card(item), text);

  /// Whether the card offers « Supprimer le contenu » — never for a reported member.
  bool offersRemove(String item) =>
      isShown(keys.teamReports.removeButton(item));

  /// Whether the card of a reported member links to « Gestion des membres » — administrators
  /// only.
  bool offersMembersLink(String item) =>
      isShown(keys.teamReports.membersLink(item));

  /// The content's name on the card → its page in the app.
  Future<void> openContent(String item) async {
    await (await scrolledTo(keys.teamReports.cardContentLink(item))).tap();
  }

  /// « Rejeter le signalement »: no confirmation; the card leaves « À traiter ».
  Future<void> dismiss(String item) async {
    await (await scrolledTo(keys.teamReports.dismissButton(item))).tap();
    await waitUntilCardIsGone(item);
  }

  /// « Supprimer le contenu » → the confirmation; the card leaves « À traiter ».
  Future<void> removeContent(String item) async {
    await (await scrolledTo(keys.teamReports.removeButton(item))).tap();
    await $(keys.profile.confirmDestructiveButton).waitUntilVisible();
    await $(keys.profile.confirmDestructiveButton).tap();
    await waitUntilCardIsGone(item);
  }

  /// « Traités »: the latest decisions.
  Future<void> openResolved() async {
    await scrolledUpTo(keys.teamReports.tab(ReportQueueStatus.resolved));
    await $(keys.teamReports.tab(ReportQueueStatus.resolved)).tap();
  }

  /// The empty « À traiter »: every report was decided.
  Future<void> waitUntilOpenQueueIsEmpty() async {
    await $(keys.teamReports.emptyOpen).waitUntilVisible();
  }

  /// Leaves a page opened from a card, back to the queue.
  Future<void> backToQueue() async {
    await $.tester.pageBack();
    await waitUntilShown();
  }

  /// Waits until the card of [item] shows [text] — the queue is read again after a decision.
  Future<void> waitUntilCardShows(
    String item,
    String text, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!cardShows(item, text)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('card $item does not show $text after $timeout');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }
}
