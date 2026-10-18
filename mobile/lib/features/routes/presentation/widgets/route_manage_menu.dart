import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../data/route_repository.dart';
import '../../providers/route_changes.dart';
import '../../providers/route_detail_provider.dart';
import '../route_editor_location.dart';

/// Les gestes d'un organisateur sur un parcours, depuis le `⋯` de sa fiche —
/// ceux du menu du site (`RouteDetailPage`) : modifier, remplacer le GPX,
/// supprimer, restaurer, et signaler (ledger `MOB-79`).
enum RouteManageAction { edit, replaceGpx, delete, restore, report }

/// Les gestes offerts pour [route], dans l'ordre du menu. Un parcours supprimé
/// n'offre que sa restauration ; [canReport] est faux pour son propre
/// parcours, qu'on ne se signale pas à soi-même.
List<RouteManageAction> routeManageActions(
  RouteDetailDto route, {
  required bool canReport,
}) {
  if (route.deleted) {
    return const <RouteManageAction>[RouteManageAction.restore];
  }
  return <RouteManageAction>[
    RouteManageAction.edit,
    RouteManageAction.replaceGpx,
    RouteManageAction.delete,
    if (canReport) RouteManageAction.report,
  ];
}

/// Ouvre le menu « Gérer le parcours » et exécute le geste choisi.
Future<void> showRouteManageMenu(
  BuildContext context,
  WidgetRef ref,
  RouteDetailDto route, {
  required bool canReport,
}) async {
  final List<RouteManageAction> actions = routeManageActions(
    route,
    canReport: canReport,
  );
  final RouteManageAction? action = await PdlSheet.show<RouteManageAction>(
    context: context,
    builder: (BuildContext sheetContext) => PdlSheet(
      title: 'routes.manage.menuTitle'.tr(),
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(
        top: false,
        child: SizedBox(height: PdlSpacing.chipGap),
      ),
      children: <Widget>[
        for (final RouteManageAction a in actions)
          PdlSettingRow(
            key: _key(a),
            icon: _icon(a),
            title: 'routes.manage.${_label(a)}'.tr(),
            destructive: a == RouteManageAction.delete,
            // Le séparateur de la maquette : entre le geste destructif et
            // « Signaler », qui est celui de la modération.
            showDivider:
                a == RouteManageAction.delete &&
                actions.contains(RouteManageAction.report),
            trailing: const SizedBox.shrink(),
            onTap: () => Navigator.of(sheetContext).pop(a),
          ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  await runRouteManageAction(context, ref, route, action);
}

/// Exécute [action] sur [route] : la navigation pour modifier, la confirmation
/// d'abord pour la suppression, puis l'appel, l'invalidation des vues et le
/// message.
Future<void> runRouteManageAction(
  BuildContext context,
  WidgetRef ref,
  RouteDetailDto route,
  RouteManageAction action,
) async {
  final String team = route.team.slug;
  if (action == RouteManageAction.edit) {
    await context.push(Paths.routeEdit(team, route.slug));
    return;
  }
  if (action == RouteManageAction.replaceGpx) {
    // L'écriture exige la requête entière : on ouvre le formulaire, qui lance
    // le sélecteur, plutôt que d'envoyer un GPX sans rien relire.
    await context.push(routeEditLocation(team, route.slug, replaceGpx: true));
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

String _label(RouteManageAction a) => switch (a) {
  RouteManageAction.edit => 'edit',
  RouteManageAction.replaceGpx => 'replaceGpx',
  RouteManageAction.delete => 'delete',
  RouteManageAction.restore => 'restore',
  RouteManageAction.report => 'report',
};

IconData _icon(RouteManageAction a) => switch (a) {
  RouteManageAction.edit => PdlIcons.edit,
  RouteManageAction.replaceGpx => PdlIcons.gpx,
  RouteManageAction.delete => PdlIcons.delete,
  RouteManageAction.restore => PdlIcons.restore,
  RouteManageAction.report => PdlIcons.report,
};

Key _key(RouteManageAction a) => switch (a) {
  RouteManageAction.edit => keys.routeManage.edit,
  RouteManageAction.replaceGpx => keys.routeManage.replaceGpx,
  RouteManageAction.delete => keys.routeManage.delete,
  RouteManageAction.restore => keys.routeManage.restore,
  RouteManageAction.report => keys.routeManage.report,
};
