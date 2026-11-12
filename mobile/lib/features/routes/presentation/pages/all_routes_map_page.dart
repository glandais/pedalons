import '../../../../core/material.dart';

import '../../domain/route_filters.dart';
import 'routes_page.dart';

/// Map view of the cross-team route library.
///
/// La même page que `/parcours`, ouverte sur la vue Carte : l'URL dit une vue,
/// pas un écran. Basculer sur Liste depuis ici ne change donc pas d'adresse —
/// c'est voulu, la vue est un état persisté et non une route.
class AllRoutesMapPage extends StatelessWidget {
  const AllRoutesMapPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const RoutesPage(teamSlug: null, initialView: RouteViewMode.map);
}
