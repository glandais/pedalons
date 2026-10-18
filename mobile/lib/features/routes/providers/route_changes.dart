import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../rides/providers/ride_editor_providers.dart';
import '../../tags/providers/team_tags_provider.dart';
import '../../teams/providers/team_dashboard_provider.dart';
import 'route_count_provider.dart';
import 'route_detail_provider.dart';
import 'route_list_provider.dart';

/// **Le** point où l'app dit « un organisateur vient de changer un parcours »
/// — créé, réécrit (GPX compris), renommé d'adresse, supprimé ou restauré
/// (ledger `MOB-79`). Le pendant de `notifyRideChanged` pour les parcours.
///
/// Un parcours paraît dans la liste de son équipe **et** dans l'onglet
/// Parcours de toutes les équipes (les familles `routeListProvider`,
/// `routePreviewProvider`, `routeCountProvider` et `routeBoundsProvider` sont
/// invalidées en entier, quelle que soit leur clé), dans le tableau de bord de
/// l'équipe (« Nouveaux parcours »), dans les compteurs d'usage des tags, et
/// dans les caches de l'éditeur de sortie (le parcours d'un groupe, dont la
/// distance change avec un nouveau GPX). Le détail et les usages du parcours
/// ne le sont que si [routeKey] le nomme. Invalider un provider que personne
/// n'écoute ne coûte rien.
///
/// Deux limites assumées : `teamDetailProvider` n'est **pas** invalidé —
/// l'éditeur l'écoute pendant la sauvegarde —, de sorte que `routeCount`
/// n'est relu qu'au prochain chargement de l'équipe ; et les tuiles `.mvt` de
/// la carte restent gardées par MapLibre, un tracé remplacé n'y apparaît donc
/// qu'une fois le cache de tuiles expiré.
void notifyRouteChanged(
  WidgetRef ref, {
  required String teamSlug,
  RouteKey? routeKey,
}) {
  if (routeKey != null) {
    ref.invalidate(routeDetailProvider(routeKey));
    ref.invalidate(routeUsagesProvider(routeKey));
  }
  ref.invalidate(routeListProvider);
  ref.invalidate(routePreviewProvider);
  ref.invalidate(routeCountProvider);
  ref.invalidate(routeBoundsProvider);
  ref.invalidate(teamDashboardProvider);
  ref.invalidate(teamTagsProvider((teamSlug: teamSlug, type: TagTarget.route)));
  ref.invalidate(editorRouteProvider);
  ref.invalidate(editorGroupRoutesProvider);
}
