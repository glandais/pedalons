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
