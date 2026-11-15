import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'membership_scoped_content.dart';
import 'team_dashboard_provider.dart';
import 'team_discovery_provider.dart';
import 'team_providers.dart';

/// **Le** point où l'app dit « l'équipe [slug] vient de changer » — créée,
/// réécrite, renommée, supprimée, ou l'une de ses listes d'administration
/// (membres, pages…) modifiée (docs/LEDGER_*.md MOB-165).
///
/// Sont invalidés : la fiche de l'équipe (dont dépendent ses droits,
/// `isTeamOrganizerProvider` / `isTeamAdminProvider`, et sa page), « Mes
/// équipes » (la liste paginée de l'onglet l'écoute), son tableau de bord et
/// la découverte. Invalider un provider que personne n'écoute ne coûte rien.
///
/// [contentScopeChanged] : la visibilité ou le fuseau de l'équipe a changé.
/// Les détails d'entité déjà lus (sorties, voyages, publications, parcours)
/// portent alors une visibilité, des droits ou des heures d'avant : ils sont
/// relus aussi.
///
/// Après un changement de slug, appeler une fois pour l'ancien et une fois
/// pour le nouveau.
///
/// Prend le **conteneur**, pas un `WidgetRef`, comme
/// `notifyRideTemplatesChanged` : l'écriture est une requête, et l'écran qui
/// l'a lancée peut être quitté avant sa réponse. Le conteneur, pris avant le
/// premier `await` (`ProviderScope.containerOf(context, listen: false)`),
/// survit à l'écran.
void notifyTeamChanged(
  ProviderContainer container,
  String slug, {
  bool contentScopeChanged = false,
}) {
  container.invalidate(teamDetailProvider(slug));
  container.invalidate(myTeamsProvider);
  container.invalidate(teamDashboardProvider(slug));
  container.invalidate(teamDiscoveryProvider);
  if (contentScopeChanged) {
    invalidateMembershipScopedContent(container.invalidate);
  }
}
