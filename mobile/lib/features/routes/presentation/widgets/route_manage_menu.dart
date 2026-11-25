import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/widgets/duplicate_name_sheet.dart';
import '../../../../keys.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../data/planner_load.dart' show isSingleTrack;
import '../../data/route_repository.dart';
import '../../domain/route_retouch.dart';
import '../../providers/route_changes.dart';
import '../../providers/route_detail_provider.dart';
import '../pages/route_retouch_page.dart';
import '../route_editor_location.dart';

/// Les gestes d'un organisateur sur un parcours, depuis le `⋯` de sa fiche —
/// ceux du menu du site (`RouteDetailPage`) : modifier, remplacer le GPX,
/// dupliquer, supprimer, restaurer, et signaler (ledger `MOB-79`) ; retoucher
/// (docs/LEDGER_*.md MOB-185) quand l'offre du moteur le permet.
///
/// Les libellés, l'ordre et les groupes sont ceux du « Modifier ▾ » du site :
/// modifier, puis « Tracé » (ajuster la distance, déplacer l'arrivée,
/// remplacer le fichier GPX), dupliquer, supprimer — [retouch] n'est que la
/// ligne grisée d'un parcours encore en cours d'analyse.
enum RouteManageAction {
  edit,
  retouch,
  resize,
  moveEnd,
  replaceGpx,
  duplicate,
  delete,
  restore,
  report,
}

/// Les gestes offerts pour [route], dans l'ordre du menu. Un parcours supprimé
/// n'offre que sa restauration ; [canReport] est faux pour son propre
/// parcours, qu'on ne se signale pas à soi-même. [retouch] dit ce que l'offre
/// de retouche (`GET …/retouch`) ajoute : une ligne par opération de
/// [operations] quand elle est possible, la ligne grisée tant que le parcours
/// est en cours d'analyse.
List<RouteManageAction> routeManageActions(
  RouteDetailDto route, {
  required bool canReport,
  RetouchEntry retouch = RetouchEntry.none,
  List<RouteRetouchOperation> operations = const <RouteRetouchOperation>[],
}) {
  // Le droit de **ce** parcours, calculé par le backend (docs/LEDGER_*.md
  // MOB-137) : modifier et remplacer le GPX demandent `canEdit`, supprimer
  // et restaurer `canDelete`.
  final bool edit = route.permissions.canEdit;
  final bool delete = route.permissions.canDelete;
  if (route.deleted) {
    return <RouteManageAction>[if (delete) RouteManageAction.restore];
  }
  return <RouteManageAction>[
    if (edit) ...<RouteManageAction>[
      RouteManageAction.edit,
      if (retouch == RetouchEntry.notReady) RouteManageAction.retouch,
      if (retouch == RetouchEntry.available) ...<RouteManageAction>[
        if (operations.contains(RouteRetouchOperation.resize))
          RouteManageAction.resize,
        if (operations.contains(RouteRetouchOperation.moveEnd))
          RouteManageAction.moveEnd,
      ],
      RouteManageAction.replaceGpx,
      // Comme au site : qui peut modifier le parcours peut le copier.
      RouteManageAction.duplicate,
    ],
    if (delete) RouteManageAction.delete,
    if (canReport) RouteManageAction.report,
  ];
}

/// Le `⋯` de la fiche ouvre-t-il « Gérer le parcours » plutôt que la seule
/// modération ?
bool routeHasManageActions(RouteDetailDto route) =>
    route.permissions.canEdit || route.permissions.canDelete;

/// Ouvre le menu « Gérer le parcours » et exécute le geste choisi.
Future<void> showRouteManageMenu(
  BuildContext context,
  WidgetRef ref,
  RouteDetailDto route, {
  required bool canReport,
  RouteRetouchOfferDto? retouchOffer,
}) async {
  final RetouchEntry retouch = retouchEntryOf(retouchOffer);
  final List<RouteManageAction> actions = routeManageActions(
    route,
    canReport: canReport,
    retouch: retouch,
    operations: retouchOffer?.operations ?? const <RouteRetouchOperation>[],
  );
  final RouteManageAction? action = await PdlSheet.show<RouteManageAction>(
    context: context,
    builder: (BuildContext sheetContext) {
      final List<Widget> rows = <Widget>[];
      for (int i = 0; i < actions.length; i++) {
        final RouteManageAction a = actions[i];
        final _Group group = _group(a);
        // « Tracé », comme au site : le titre de la section qui change le
        // tracé.
        if (group == _Group.track &&
            (i == 0 || _group(actions[i - 1]) != _Group.track)) {
          rows.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'routes.manage.track'.tr(),
                style: sheetContext.pdlText.sub,
              ),
            ),
          );
        }
        rows.add(
          PdlSettingRow(
            key: _key(a),
            icon: _icon(a),
            title: _title(a),
            // Le parcours encore en cours d'analyse : la ligne est là,
            // désactivée, avec sa raison.
            subtitle: a == RouteManageAction.retouch
                ? 'routeRetouch.notReadyHint'.tr()
                : null,
            destructive: a == RouteManageAction.delete,
            // Un filet entre les groupes, comme les `Menu.Divider` du site.
            showDivider:
                i < actions.length - 1 && _group(actions[i + 1]) != group,
            trailing: const SizedBox.shrink(),
            onTap: a == RouteManageAction.retouch
                ? null
                : () => Navigator.of(sheetContext).pop(a),
          ),
        );
      }
      return PdlSheet(
        title: 'routes.manage.menuTitle'.tr(),
        bodyPadding: EdgeInsets.zero,
        footer: const SafeArea(
          top: false,
          child: SizedBox(height: PdlSpacing.chipGap),
        ),
        children: rows,
      );
    },
  );
  if (action == null || !context.mounted) return;
  await runRouteManageAction(
    context,
    ref,
    route,
    action,
    retouchOffer: retouchOffer,
  );
}

/// Exécute [action] sur [route] : la navigation pour modifier, la confirmation
/// d'abord pour la suppression, puis l'appel, l'invalidation des vues et le
/// message.
Future<void> runRouteManageAction(
  BuildContext context,
  WidgetRef ref,
  RouteDetailDto route,
  RouteManageAction action, {
  RouteRetouchOfferDto? retouchOffer,
}) async {
  final String team = route.team.slug;
  if (action == RouteManageAction.edit) {
    await context.push(Paths.routeEdit(team, route.slug));
    return;
  }
  if (action == RouteManageAction.resize ||
      action == RouteManageAction.moveEnd) {
    if (retouchOffer == null) return;
    await _retouch(
      context,
      route,
      retouchOffer,
      action == RouteManageAction.resize
          ? RouteRetouchOperation.resize
          : RouteRetouchOperation.moveEnd,
    );
    return;
  }
  if (action == RouteManageAction.replaceGpx) {
    // L'écriture exige la requête entière : on ouvre le formulaire, qui lance
    // le sélecteur, plutôt que d'envoyer un GPX sans rien relire.
    await context.push(routeEditLocation(team, route.slug, replaceGpx: true));
    return;
  }
  if (action == RouteManageAction.duplicate) {
    await _duplicate(context, ref, route);
    return;
  }
  if (action == RouteManageAction.report) {
    await showDetailModerationMenu(
      context,
      subject: ModerationSubject(
        teamSlug: team,
        type: ReportTargetType.route,
        id: route.id,
        teamName: route.team.name,
      ),
    );
    return;
  }

  if (action == RouteManageAction.delete) {
    final bool ok = await confirmDestructive(
      context,
      title: 'routes.manage.deleteTitle'.tr(),
      message: 'routes.manage.deleteMessage'.tr(
        namedArgs: <String, String>{'name': route.name},
      ),
      confirmLabel: 'routes.manage.delete'.tr(),
    );
    if (!ok || !context.mounted) return;
  }

  final RouteRepository repo = ref.read(routeRepositoryProvider);
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final GoRouter router = GoRouter.of(context);
  try {
    if (action == RouteManageAction.delete) {
      await repo.deleteRoute(team, route.slug);
    } else {
      await repo.undeleteRoute(team, route.slug);
    }
  } catch (error, stackTrace) {
    messenger?.showSnackBar(
      SnackBar(content: Text(getErrorMessage(error, stackTrace))),
    );
    return;
  }

  notifyRouteChanged(
    ref,
    teamSlug: team,
    routeKey: RouteKey(teamSlug: team, routeSlug: route.slug),
  );
  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        action == RouteManageAction.delete
            ? 'routes.manage.deleted'.tr()
            : 'routes.manage.restored'.tr(),
      ),
    ),
  );
  if (action == RouteManageAction.delete) {
    // La fiche d'un parcours supprimé n'a plus lieu d'être ouverte : retour à
    // ce qui était dessous, sinon à la liste des parcours de l'équipe.
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Paths.routes(team));
    }
  }
}

/// « Dupliquer le parcours » : le nom de la copie, puis son formulaire,
/// comme au site (docs/LEDGER_*.md WEB-168).
Future<void> _duplicate(
  BuildContext context,
  WidgetRef ref,
  RouteDetailDto route,
) async {
  final String team = route.team.slug;
  final RouteDto? copy = await PdlSheet.show<RouteDto>(
    context: context,
    builder: (BuildContext _) => DuplicateNameSheet<RouteDto>(
      key: keys.routeManage.duplicateSheet,
      title: 'routes.manage.duplicateTitle'.tr(),
      nameLabel: 'routes.manage.duplicateNameLabel'.tr(),
      submitLabel: 'routes.manage.duplicateSubmit'.tr(),
      initialName: 'routes.manage.duplicateDefaultName'.tr(
        namedArgs: <String, String>{'name': route.name},
      ),
      nameKey: keys.routeManage.duplicateName,
      submitKey: keys.routeManage.duplicateSubmit,
      onSubmit: (String name) => ref
          .read(routeRepositoryProvider)
          .duplicateRoute(team, route.slug, name: name),
    ),
  );
  if (copy == null || !context.mounted) return;
  notifyRouteChanged(ref, teamSlug: team);
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text('routes.manage.duplicated'.tr())));
  // La fiche de la copie remplace celle de l'original, et son formulaire
  // s'ouvre dessus : « Enregistrer » ramène sur la copie, comme au site
  // (docs/LEDGER_*.md MOB-186) — sur l'original, on croyait l'avoir modifié.
  final GoRouter router = GoRouter.of(context);
  router.pushReplacement(Paths.route(team, copy.slug));
  await router.push(Paths.routeEdit(team, copy.slug));
}

/// La retouche, puis ce qu'elle a choisi d'ouvrir : l'éditeur de ce parcours
/// (tracé remplacé), une création, ou le générateur. Rien n'est enregistré
/// sans « Enregistrer » dans l'éditeur.
Future<void> _retouch(
  BuildContext context,
  RouteDetailDto route,
  RouteRetouchOfferDto offer,
  RouteRetouchOperation mode,
) async {
  final String team = route.team.slug;
  final RetouchChoice? choice = await openRouteRetouch(
    context,
    route: route,
    offer: offer,
    initialMode: mode,
    canEdit: route.permissions.canEdit && isSingleTrack(route),
  );
  if (choice == null || !context.mounted) return;
  switch (choice.opening) {
    case RetouchOpening.edit:
      await context.push(
        Paths.routeEdit(team, route.slug),
        extra: choice.handoff,
      );
    case RetouchOpening.newRoute:
      // Le parcours créé s'ouvre par-dessus la fiche de l'original
      // (ledger `MOB-187`).
      final String? saved = await context.push<String>(
        Paths.routeNew(team),
        extra: choice.handoff,
      );
      if (saved != null && context.mounted) {
        await context.push(Paths.route(team, saved));
      }
    case RetouchOpening.generator:
      await context.push(Paths.routeGenerate(team), extra: choice.generator);
  }
}

/// Les libellés du « Modifier ▾ » du site.
String _title(RouteManageAction a) => switch (a) {
  RouteManageAction.edit => 'routes.manage.edit'.tr(),
  RouteManageAction.retouch => 'routes.manage.retouch'.tr(),
  RouteManageAction.resize => 'routeRetouch.resize.action'.tr(),
  RouteManageAction.moveEnd => 'routeRetouch.moveEnd.action'.tr(),
  RouteManageAction.replaceGpx => 'routes.manage.replaceGpx'.tr(),
  RouteManageAction.duplicate => 'routes.manage.duplicate'.tr(),
  RouteManageAction.delete => 'routes.manage.delete'.tr(),
  RouteManageAction.restore => 'routes.manage.restore'.tr(),
  RouteManageAction.report => 'routes.manage.report'.tr(),
};

enum _Group { edit, track, copy, remove, report }

_Group _group(RouteManageAction a) => switch (a) {
  RouteManageAction.edit => _Group.edit,
  RouteManageAction.retouch ||
  RouteManageAction.resize ||
  RouteManageAction.moveEnd ||
  RouteManageAction.replaceGpx => _Group.track,
  RouteManageAction.duplicate => _Group.copy,
  RouteManageAction.delete || RouteManageAction.restore => _Group.remove,
  RouteManageAction.report => _Group.report,
};

IconData _icon(RouteManageAction a) => switch (a) {
  RouteManageAction.edit => PdlIcons.edit,
  RouteManageAction.retouch => PdlIcons.generate,
  RouteManageAction.resize => PdlIcons.distance,
  RouteManageAction.moveEnd => PdlIcons.placeEnd,
  RouteManageAction.replaceGpx => PdlIcons.fileAdd,
  RouteManageAction.duplicate => PdlIcons.copy,
  RouteManageAction.delete => PdlIcons.delete,
  RouteManageAction.restore => PdlIcons.restore,
  RouteManageAction.report => PdlIcons.report,
};

Key _key(RouteManageAction a) => switch (a) {
  RouteManageAction.edit => keys.routeManage.edit,
  RouteManageAction.retouch => keys.routeManage.retouch,
  RouteManageAction.resize => keys.routeManage.resize,
  RouteManageAction.moveEnd => keys.routeManage.moveEnd,
  RouteManageAction.replaceGpx => keys.routeManage.replaceGpx,
  RouteManageAction.duplicate => keys.routeManage.duplicate,
  RouteManageAction.delete => keys.routeManage.delete,
  RouteManageAction.restore => keys.routeManage.restore,
  RouteManageAction.report => keys.routeManage.report,
};
