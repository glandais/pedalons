import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../visibility/domain/incompatible_visibility.dart';
import '../../../visibility/presentation/visibility_refusal.dart';
import '../../data/trip_repository.dart';
import '../../providers/trip_detail_provider.dart';
import '../../providers/trip_editor_providers.dart';

/// Les gestes d'un organisateur sur un voyage, selon son statut — ceux du
/// menu de la fiche au site (`TripDetailPage`) : publier un brouillon,
/// dépublier ou annuler un voyage publié, rétablir un voyage annulé,
/// supprimer, restaurer un voyage supprimé (ledger `MOB-162`, sur le modèle
/// de `ride_manage_menu.dart`).
enum TripManageAction {
  publish,
  unpublish,
  cancel,
  reinstate,
  delete,
  restore,
  report,
}

/// Les gestes offerts pour [trip], dans l'ordre du menu. Un voyage supprimé
/// n'offre que sa restauration.
///
/// Chaque geste suit le droit que le backend calcule pour **ce** voyage
/// (`permissions`, docs/LEDGER_*.md MOB-137) : changer le statut demande
/// `canEdit`, supprimer et restaurer `canDelete`. Signaler reste à tout le
/// monde.
List<TripManageAction> tripManageActions(TripDto trip) {
  final bool edit = trip.permissions.canEdit;
  final bool delete = trip.permissions.canDelete;
  if (trip.deleted) {
    return <TripManageAction>[if (delete) TripManageAction.restore];
  }
  return <TripManageAction>[
    if (edit && trip.status == Status.draft.json) TripManageAction.publish,
    if (edit && trip.status == Status.published.json) ...<TripManageAction>[
      TripManageAction.unpublish,
      TripManageAction.cancel,
    ],
    if (edit && trip.status == Status.cancelled.json)
      TripManageAction.reinstate,
    if (delete) TripManageAction.delete,
    TripManageAction.report,
  ];
}

/// Le menu « Gérer le voyage » a-t-il un geste de gestion à offrir ? Sinon
/// la fiche n'ouvre que le signalement.
bool tripHasManageActions(TripDto trip) =>
    trip.permissions.canEdit || trip.permissions.canDelete;

/// Ouvre le menu « Gérer le voyage » et exécute le geste choisi.
Future<void> showTripManageMenu(
  BuildContext context,
  WidgetRef ref,
  TripDto trip,
) async {
  final TripManageAction? action = await PdlSheet.show<TripManageAction>(
    context: context,
    builder: (BuildContext sheetContext) => PdlSheet(
      title: 'trips.manage.menuTitle'.tr(),
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(top: false, child: SizedBox(height: 8)),
      children: <Widget>[
        for (final TripManageAction a in tripManageActions(trip))
          PdlSettingRow(
            key: _key(a),
            icon: _icon(a),
            title: 'trips.manage.${_label(a)}'.tr(),
            destructive: a == TripManageAction.delete,
            trailing: const SizedBox.shrink(),
            onTap: () => Navigator.of(sheetContext).pop(a),
          ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  await runTripManageAction(context, ref, trip, action);
}

/// Exécute [action] sur [trip] : confirmation d'abord pour ce qui retire le
/// voyage aux membres, puis l'appel, l'invalidation des vues, le message.
Future<void> runTripManageAction(
  BuildContext context,
  WidgetRef ref,
  TripDto trip,
  TripManageAction action,
) async {
  if (action == TripManageAction.report) {
    await showDetailModerationMenu(
      context,
      subject: ModerationSubject(
        teamSlug: trip.team.slug,
        type: ReportTargetType.trip,
        id: trip.id,
        teamName: trip.team.name,
      ),
    );
    return;
  }

  final ({String title, String message})? confirm = switch (action) {
    TripManageAction.unpublish => (
      title: 'trips.manage.unpublishTitle'.tr(),
      message: 'trips.manage.unpublishMessage'.tr(),
    ),
    TripManageAction.cancel => (
      title: 'trips.manage.cancelTitle'.tr(),
      message: 'trips.manage.cancelMessage'.tr(),
    ),
    TripManageAction.delete => (
      title: 'trips.manage.deleteTitle'.tr(),
      message: 'trips.manage.deleteMessage'.tr(),
    ),
    _ => null,
  };
  if (confirm != null) {
    final bool ok = await confirmDestructive(
      context,
      title: confirm.title,
      message: confirm.message,
      confirmLabel: 'trips.manage.${_label(action)}'.tr(),
    );
    if (!ok || !context.mounted) return;
  }

  final TripRepository repo = ref.read(tripRepositoryProvider);
  final String team = trip.team.slug;
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final GoRouter router = GoRouter.of(context);
  try {
    switch (action) {
      case TripManageAction.publish:
        await repo.changeStatus(team, trip.slug, Status.published);
      case TripManageAction.unpublish:
        await repo.changeStatus(team, trip.slug, Status.draft);
      case TripManageAction.cancel:
        await repo.changeStatus(team, trip.slug, Status.cancelled);
      case TripManageAction.reinstate:
        await repo.changeStatus(team, trip.slug, Status.published);
      case TripManageAction.delete:
        await repo.deleteTrip(team, trip.slug);
      case TripManageAction.restore:
        await repo.undeleteTrip(team, trip.slug);
      case TripManageAction.report:
        return;
    }
  } catch (error, stackTrace) {
    // Restaurer un voyage visible hors de l'équipe dont des parcours sont
    // passés en « Équipe » entre-temps : refusé avec leur liste, sans
    // alignement possible (pas de corps de requête, plan §4.4). La feuille
    // le dit, pas le message générique. Un refus sans liste garde le message,
    // qui nomme le code (`errors.api.INCOMPATIBLE_VISIBILITY`).
    final IncompatibleVisibility? incompatible = incompatibleVisibilityOf(
      error,
    );
    if (incompatible != null &&
        incompatible.routes.isNotEmpty &&
        context.mounted) {
      await showRestoreRefusal(
        context,
        teamSlug: team,
        kind: AlignedKind.trip,
        routes: incompatible.routes,
      );
      return;
    }
    messenger?.showSnackBar(
      SnackBar(content: Text(getErrorMessage(error, stackTrace))),
    );
    return;
  }

  notifyTripChanged(
    ref,
    teamSlug: team,
    tripKey: TripKey(teamSlug: team, tripSlug: trip.slug),
  );
  messenger?.showSnackBar(
    SnackBar(content: Text('trips.manage.${_done(action)}'.tr())),
  );
  if (action == TripManageAction.delete) {
    // L'écran d'un voyage supprimé n'a plus lieu d'être ouvert : retour
    // à ce qui était dessous, sinon à l'Agenda de l'équipe (comme au site).
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Paths.teamAgenda(team));
    }
  }
}

String _label(TripManageAction a) => switch (a) {
  TripManageAction.publish => 'publish',
  TripManageAction.unpublish => 'unpublish',
  TripManageAction.cancel => 'cancel',
  TripManageAction.reinstate => 'reinstate',
  TripManageAction.delete => 'delete',
  TripManageAction.restore => 'restore',
  TripManageAction.report => 'report',
};

String _done(TripManageAction a) => switch (a) {
  TripManageAction.publish => 'published',
  TripManageAction.unpublish => 'unpublished',
  TripManageAction.cancel => 'cancelled',
  TripManageAction.reinstate => 'reinstated',
  TripManageAction.delete => 'deleted',
  TripManageAction.restore => 'restored',
  TripManageAction.report => 'report',
};

IconData _icon(TripManageAction a) => switch (a) {
  TripManageAction.publish => PdlIcons.publish,
  TripManageAction.unpublish => PdlIcons.unpublish,
  TripManageAction.cancel => PdlIcons.cancelled,
  TripManageAction.reinstate => PdlIcons.refresh,
  TripManageAction.delete => PdlIcons.delete,
  TripManageAction.restore => PdlIcons.restore,
  TripManageAction.report => PdlIcons.report,
};

Key _key(TripManageAction a) => switch (a) {
  TripManageAction.publish => keys.tripManage.publish,
  TripManageAction.unpublish => keys.tripManage.unpublish,
  TripManageAction.cancel => keys.tripManage.cancel,
  TripManageAction.reinstate => keys.tripManage.reinstate,
  TripManageAction.delete => keys.tripManage.delete,
  TripManageAction.restore => keys.tripManage.restore,
  TripManageAction.report => keys.tripManage.report,
};
