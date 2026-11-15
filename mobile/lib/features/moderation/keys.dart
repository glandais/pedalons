import 'package:flutter/widgets.dart';

import '../../api/generated/export.dart';

class _ModerationKey extends ValueKey<String> {
  const _ModerationKey(String value) : super('moderation_$value');
}

class ModerationKeys {
  /// Les lignes du menu `⋯`.
  final reportAction = const _ModerationKey('reportAction');
  final blockAction = const _ModerationKey('blockAction');
  final deleteAction = const _ModerationKey('deleteAction');

  /// La feuille de signalement.
  final sendReportButton = const _ModerationKey('sendReportButton');

  ValueKey<String> reason(ReportReason reason) =>
      _ModerationKey('reason_${reason.toJson()}');

  /// « Personnes bloquées », depuis le profil.
  final blockedUsersRow = const _ModerationKey('blockedUsersRow');

  ValueKey<String> unblockButton(String userId) =>
      _ModerationKey('unblock_$userId');
}

class _TeamReportsKey extends ValueKey<String> {
  const _TeamReportsKey(String value) : super('teamReports_$value');
}

/// « Signalements » : la file de modération d'une équipe (ledger `MOB-168`).
/// Une carte se nomme par sa cible, `TYPE_identifiant` (`moderationItemKey`).
class TeamReportsKeys {
  final loadError = const _TeamReportsKey('loadError');

  /// Le refus rendu à qui ne modère pas l'équipe, et son « Retour ».
  final forbidden = const _TeamReportsKey('forbidden');
  final forbiddenBack = const _TeamReportsKey('forbiddenBack');

  /// Un onglet — `OPEN` (à traiter), `RESOLVED` (traités).
  ValueKey<String> tab(ReportQueueStatus status) =>
      _TeamReportsKey('tab_${status.toJson()}');

  /// La file n'a pas pu être lue.
  final listError = const _TeamReportsKey('listError');
  final emptyOpen = const _TeamReportsKey('emptyOpen');
  final emptyResolved = const _TeamReportsKey('emptyResolved');

  /// Ce que le serveur a refusé à une décision.
  final errorBanner = const _TeamReportsKey('errorBanner');

  ValueKey<String> card(String item) => _TeamReportsKey('card_$item');

  /// Les badges d'une carte : type de cible, nombre de signalements, « Masqué
  /// aux membres », décision rendue.
  ValueKey<String> cardType(String item) => _TeamReportsKey('cardType_$item');
  ValueKey<String> cardCount(String item) => _TeamReportsKey('cardCount_$item');
  ValueKey<String> cardHidden(String item) =>
      _TeamReportsKey('cardHidden_$item');
  ValueKey<String> cardStatus(String item) =>
      _TeamReportsKey('cardStatus_$item');

  /// Le contenu : en lien quand l'app en a l'écran, en texte sinon, ou « Le
  /// contenu n'existe plus. ».
  ValueKey<String> cardContentLink(String item) =>
      _TeamReportsKey('cardContentLink_$item');
  ValueKey<String> cardContentName(String item) =>
      _TeamReportsKey('cardContentName_$item');
  ValueKey<String> cardContentGone(String item) =>
      _TeamReportsKey('cardContentGone_$item');

  /// « Par … » ou « Membre signalé : … ».
  ValueKey<String> cardUser(String item) => _TeamReportsKey('cardUser_$item');
  ValueKey<String> cardExcerpt(String item) =>
      _TeamReportsKey('cardExcerpt_$item');
  ValueKey<String> cardReason(String item, ReportReason reason) =>
      _TeamReportsKey('cardReason_${item}_${reason.toJson()}');

  /// « Supprimer le contenu », « Rejeter le signalement ».
  ValueKey<String> removeButton(String item) =>
      _TeamReportsKey('removeButton_$item');
  ValueKey<String> dismissButton(String item) =>
      _TeamReportsKey('dismissButton_$item');

  /// Sous un membre signalé : le renvoi vers la gestion des membres, et son
  /// lien pour qui administre.
  ValueKey<String> memberHint(String item) =>
      _TeamReportsKey('memberHint_$item');
  ValueKey<String> membersLink(String item) =>
      _TeamReportsKey('membersLink_$item');
}
