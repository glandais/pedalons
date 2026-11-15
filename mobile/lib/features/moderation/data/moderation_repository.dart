import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((Ref ref) {
  return ModerationRepository(ref.watch(moderationClientProvider));
});

/// Signaler et bloquer — les deux gestes qu'un membre fait lui-même —, et la
/// file de modération d'une équipe, où qui l'organise décide
/// (docs/LEDGER_*.md MOB-168).
class ModerationRepository {
  ModerationRepository(this._client);

  final ModerationClient _client;

  /// Idempotent côté serveur : signaler deux fois la même cible ne crée rien de
  /// neuf, et ne lève pas d'erreur.
  Future<void> report({
    required String teamSlug,
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? message,
  }) {
    final String? text = message?.trim();
    return _client.reportContent(
      body: ReportRequest(
        teamSlug: teamSlug,
        targetType: targetType.toJson(),
        targetId: targetId,
        reason: reason.toJson(),
        message: text == null || text.isEmpty ? null : text,
      ),
    );
  }

  /// La file de modération de [teamSlug] : une entrée par cible signalée.
  /// Réservée à qui organise l'équipe et à l'admin de plateforme ; les
  /// personnes qui signalent n'y figurent jamais.
  Future<List<ModerationItemDto>> listTeamReports(
    String teamSlug, {
    required ReportQueueStatus status,
  }) async =>
      (await _client.listTeamReports(teamSlug: teamSlug, status: status)).items;

  /// Applique [action] à tous les signalements ouverts de la cible.
  /// `REMOVE_CONTENT` supprime le contenu (refusé sur un membre) ; `DISMISS`
  /// le garde, et le remontre si les signalements l'avaient masqué.
  ///
  /// `teamSlug` part aussi dans le corps, comme au site : la décision porte
  /// sur cette file, pas sur les signalements de la cible dans ses autres
  /// équipes.
  Future<void> resolveTeamReports(
    String teamSlug, {
    required String targetType,
    required String targetId,
    required ModerationAction action,
  }) {
    return _client.resolveTeamReports(
      teamSlug: teamSlug,
      body: ModerationDecisionRequest(
        targetType: targetType,
        targetId: targetId,
        action: action.toJson(),
        teamSlug: teamSlug,
      ),
    );
  }

  Future<List<PublicUserDto>> listBlocked() async =>
      (await _client.listMyBlockedUsers()).users;

  Future<void> block(String userId) => _client.blockUser(userId: userId);

  Future<void> unblock(String userId) => _client.unblockUser(userId: userId);
}

/// Les membres que l'utilisateur a bloqués, les plus récents d'abord.
///
/// Relu après chaque blocage ou déblocage ; il disparaît avec la session,
/// puisqu'il dépend du client authentifié.
final blockedUsersProvider = FutureProvider.autoDispose<List<PublicUserDto>>((
  Ref ref,
) {
  return ref.watch(moderationRepositoryProvider).listBlocked();
});
