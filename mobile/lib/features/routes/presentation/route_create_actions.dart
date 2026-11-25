import 'package:easy_localization/easy_localization.dart';

import '../../../api/generated/export.dart';
import '../../../config/paths.dart';
import '../../../core/lists/create_split_button.dart';
import '../../../core/material.dart';
import '../../../core/theme/pdl_icons.dart';
import 'route_editor_location.dart';

/// Les créations de parcours d'une équipe, dans l'ordre du site
/// (`useRouteCreateActions`) : le formulaire (importer un GPX ou tracer sur
/// la carte), puis, quand [importKey] est donné, l'import d'un GPX, et le
/// générateur quand l'équipe a le planificateur (ledger `MOB-154`). La section
/// Parcours du bouton « Créer » du tableau de bord, et le bouton « Créer » de
/// la liste des parcours (qui ajoute l'import), comme sur le site.
List<CreateAction> routeCreateActions(
  TeamDetailDto team, {
  required Key createKey,
  required Key generateKey,
  Key? importKey,
}) {
  if (!team.enableRoutes) return const <CreateAction>[];
  return <CreateAction>[
    CreateAction(
      key: createKey,
      label: 'lists.createLabel.route'.tr(),
      icon: PdlIcons.route,
      location: Paths.routeNew(team.slug),
      // Tracer sur la carte passe par le planificateur (ledger `MOB-170`).
      subtitle: team.enableRoutePlanner
          ? 'teams.dashboard.create.routeHint'.tr()
          : null,
    ),
    if (importKey != null)
      CreateAction(
        key: importKey,
        label: 'routes.create.importGpx'.tr(),
        icon: PdlIcons.fileAdd,
        location: routeNewLocation(team.slug, importGpx: true),
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
