import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/team_permissions.dart';
import 'team_providers.dart';

/// La personne connectée est-elle admin de plateforme ?
final isPlatformAdminProvider = Provider<bool>(
  (Ref ref) => ref.watch(
    authProvider.select(
      (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
    ),
  ),
);

bool? _teamPermission(
  Ref ref,
  String teamSlug,
  bool Function({required TeamRole? teamRole, bool platformAdmin}) rule,
) {
  final TeamDetailDto? team = ref.watch(teamDetailProvider(teamSlug)).value;
  if (team == null) return null;
  return rule(
    teamRole: teamRoleOf(team),
    platformAdmin: ref.watch(isPlatformAdminProvider),
  );
}

/// La personne peut-elle agir en organisateur de [teamSlug] ([isTeamOrganizer]) ?
///
/// Lu sur la **fiche de l'équipe** ([teamDetailProvider]), pas sur « Mes
/// équipes » : un admin de plateforme qui n'est pas membre y est donc traité
/// comme les autres, une fois la fiche là (docs/LEDGER_*.md MOB-165 — le
/// défaut de `MOB-96` ne se reproduit pas ici).
///
/// `null` tant que la fiche n'est pas chargée (ou a échoué) : l'écran ne
/// montre alors ni bouton ni refus.
final isTeamOrganizerProvider = Provider.family<bool?, String>(
  (Ref ref, String teamSlug) => _teamPermission(ref, teamSlug, isTeamOrganizer),
);

/// La personne peut-elle agir en administrateur de [teamSlug] ([isTeamAdmin]) ?
/// Mêmes source et sens de `null` que [isTeamOrganizerProvider].
final isTeamAdminProvider = Provider.family<bool?, String>(
  (Ref ref, String teamSlug) => _teamPermission(ref, teamSlug, isTeamAdmin),
);
