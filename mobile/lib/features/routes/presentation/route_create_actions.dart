import 'package:easy_localization/easy_localization.dart';

import '../../../api/generated/export.dart';
import '../../../config/paths.dart';
import '../../../core/lists/create_split_button.dart';
import '../../../core/material.dart';
import '../../../core/theme/pdl_icons.dart';
import 'route_editor_location.dart';

/// Les créations de parcours d'une équipe : tracer sur la carte (quand
/// l'équipe a le planificateur, ledger `MOB-170`), importer un GPX, et
/// générer (ledger `MOB-154`). Chaque entrée ouvre l'éditeur sur son geste,
/// sans passer par sa page de choix. La section Parcours du bouton « Créer »
/// du tableau de bord, et le bouton « Créer » de la liste des parcours.
List<CreateAction> routeCreateActions(
  TeamDetailDto team, {
  required Key importKey,
  required Key drawKey,
  required Key generateKey,
}) {
  if (!team.enableRoutes) return const <CreateAction>[];
  return <CreateAction>[
    if (team.enableRoutePlanner)
      CreateAction(
        key: drawKey,
        label: 'routes.editor.drawButton'.tr(),
        icon: PdlIcons.route,
        location: routeNewLocation(team.slug, start: RouteNewStart.draw),
      ),
    CreateAction(
      key: importKey,
      label: 'routes.create.importGpx'.tr(),
      icon: PdlIcons.fileAdd,
      location: routeNewLocation(team.slug, start: RouteNewStart.importGpx),
    ),
    if (team.enableRoutePlanner)
      CreateAction(
        key: generateKey,
        label: 'routeGenerator.title'.tr(),
        icon: PdlIcons.generate,
        location: Paths.routeGenerate(team.slug),
        subtitle: 'routeGenerator.subtitle'.tr(),
      ),
  ];
}

/// L'adresse de la première création de parcours de [team] : le tracé sur la
/// carte, sinon l'import d'un GPX — pour les entrées qui n'en offrent qu'une
/// (les premières étapes du tableau de bord, l'état vide de la liste).
String firstRouteCreateLocation(TeamDetailDto team) => routeNewLocation(
  team.slug,
  start: team.enableRoutePlanner ? RouteNewStart.draw : RouteNewStart.importGpx,
);
