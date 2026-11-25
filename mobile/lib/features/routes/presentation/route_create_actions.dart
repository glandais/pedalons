import 'package:easy_localization/easy_localization.dart';

import '../../../api/generated/export.dart';
import '../../../config/paths.dart';
import '../../../core/lists/create_split_button.dart';
import '../../../core/material.dart';
import '../../../core/theme/enum_colors.dart';
import '../../../core/theme/pdl_colors.dart';
import '../../../core/theme/pdl_icons.dart';
import '../domain/planner_quota.dart';
import 'route_editor_location.dart';

/// Les créations de parcours d'une équipe : tracer sur la carte (quand
/// l'équipe a le planificateur, ledger `MOB-170`), importer un GPX, et
/// générer (ledger `MOB-154`). Chaque entrée ouvre l'éditeur sur son geste,
/// sans passer par sa page de choix. La section Parcours du bouton « Créer »
/// du tableau de bord, et le bouton « Créer » de la liste des parcours.
///
/// Quota du mois épuisé : tracer et générer restent en vue, fermés, avec la
/// raison, comme au site (ledger `MOB-189`) ; [platformAdmin] n'en a pas.
List<CreateAction> routeCreateActions(
  TeamDetailDto team, {
  required Key importKey,
  required Key drawKey,
  required Key generateKey,
  bool platformAdmin = false,
}) {
  if (!team.enableRoutes) return const <CreateAction>[];
  final String? quotaSpent =
      isPlannerQuotaSpent(team.plannerQuota, platformAdmin: platformAdmin)
      ? 'routeGenerator.quotaSpent'.tr()
      : null;
  return <CreateAction>[
    if (team.enableRoutePlanner)
      CreateAction(
        key: drawKey,
        label: 'routes.editor.drawButton'.tr(),
        icon: PdlIcons.map,
        tone: _routeTone,
        location: routeNewLocation(team.slug, start: RouteNewStart.draw),
        disabledReason: quotaSpent,
      ),
    CreateAction(
      key: importKey,
      label: 'routes.create.importGpx'.tr(),
      subtitle: 'routes.create.importHint'.tr(),
      icon: PdlIcons.fileAdd,
      tone: _routeTone,
      location: routeNewLocation(team.slug, start: RouteNewStart.importGpx),
    ),
    if (team.enableRoutePlanner)
      CreateAction(
        key: generateKey,
        label: 'routeGenerator.title'.tr(),
        icon: PdlIcons.generate,
        tone: _routeTone,
        location: Paths.routeGenerate(team.slug),
        subtitle: 'routeGenerator.subtitle'.tr(),
        disabledReason: quotaSpent,
      ),
  ];
}

/// Les parcours en indigo, comme au site.
PdlTone _routeTone(PdlColors c) => PdlFamily.indigo.soft(c);

/// L'adresse de la première création de parcours de [team] : le tracé sur la
/// carte, sinon l'import d'un GPX — pour les entrées qui n'en offrent qu'une
/// (les premières étapes du tableau de bord, l'état vide de la liste).
String firstRouteCreateLocation(
  TeamDetailDto team, {
  bool platformAdmin = false,
}) => routeNewLocation(
  team.slug,
  start:
      team.enableRoutePlanner &&
          !isPlannerQuotaSpent(team.plannerQuota, platformAdmin: platformAdmin)
      ? RouteNewStart.draw
      : RouteNewStart.importGpx,
);
