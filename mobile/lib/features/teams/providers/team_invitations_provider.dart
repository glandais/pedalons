import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../data/team_invitations_repository.dart';

/// Les invitations en attente d'une équipe, pour l'écran « Gestion des
/// membres » (docs/LEDGER_*.md MOB-167).
///
/// **Réservé à l'administration de l'équipe** : le serveur répond 403 à
/// quiconque d'autre. L'écran ne l'écoute qu'une fois le droit établi.
final teamInvitationsProvider = FutureProvider.autoDispose
    .family<List<TeamInvitationDto>, String>((ref, teamSlug) {
      return ref.watch(teamInvitationsRepositoryProvider).listPending(teamSlug);
    });
