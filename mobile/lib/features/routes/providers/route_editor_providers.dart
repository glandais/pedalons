import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rides/domain/ride_permissions.dart';
import '../../rides/providers/ride_editor_providers.dart';

/// L'utilisateur peut-il créer, modifier ou supprimer les parcours de
/// [teamSlug] ? `null` tant que « Mes équipes » n'est pas chargé et qu'il
/// n'est pas admin de plateforme : l'écran n'affiche alors ni bouton ni refus
/// (docs/LEDGER_*.md MOB-79).
///
/// La règle est celle du serveur (`RouteAccessChecker`) : organisateur ou
/// administrateur, module parcours actif — [canManageTeamRoutes].
final canManageRoutesProvider = Provider.family<bool?, String>(
  (Ref ref, String teamSlug) => teamManagePermission(
    ref,
    teamSlug,
    (team, {required teamRole, required platformAdmin}) => canManageTeamRoutes(
      team,
      teamRole: teamRole,
      platformAdmin: platformAdmin,
    ),
  ),
);
