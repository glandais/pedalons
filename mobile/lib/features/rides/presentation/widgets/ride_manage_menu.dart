import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../data/ride_repository.dart';
import '../../providers/ride_changes.dart';
import '../../providers/ride_detail_provider.dart';

/// Les gestes d'un organisateur sur une sortie, selon son statut — ceux du
/// menu de la fiche au site (`RideDetailPage`) : publier un brouillon,
/// dépublier ou annuler une sortie publiée, rétablir une sortie annulée,
/// supprimer, restaurer une sortie supprimée (ledger `MOB-76`).
enum RideManageAction {
  publish,
  unpublish,
  cancel,
  reinstate,
  delete,
  restore,
  report,
}

/// Les gestes offerts pour [ride], dans l'ordre du menu. Une sortie
/// supprimée n'offre que sa restauration.
List<RideManageAction> rideManageActions(RideDto ride) {
  if (ride.deleted) return const <RideManageAction>[RideManageAction.restore];
  return <RideManageAction>[
    if (ride.status == Status.draft.json) RideManageAction.publish,
    if (ride.status == Status.published.json) ...<RideManageAction>[
      RideManageAction.unpublish,
      RideManageAction.cancel,
    ],
    if (ride.status == Status.cancelled.json) RideManageAction.reinstate,
    RideManageAction.delete,
    RideManageAction.report,
  ];
}

/// Ouvre le menu « Gérer la sortie » et exécute le geste choisi.
Future<void> showRideManageMenu(
  BuildContext context,
  WidgetRef ref,
  RideDto ride,
) async {
  final RideManageAction? action = await PdlSheet.show<RideManageAction>(
    context: context,
    builder: (BuildContext sheetContext) => PdlSheet(
      title: 'rides.manage.menuTitle'.tr(),
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(top: false, child: SizedBox(height: 8)),
      children: <Widget>[
        for (final RideManageAction a in rideManageActions(ride))
          PdlSettingRow(
            key: _key(a),
            icon: _icon(a),
            title: 'rides.manage.${_label(a)}'.tr(),
            destructive: a == RideManageAction.delete,
            trailing: const SizedBox.shrink(),
            onTap: () => Navigator.of(sheetContext).pop(a),
          ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  await runRideManageAction(context, ref, ride, action);
}

/// Exécute [action] sur [ride] : confirmation d'abord pour ce qui retire la
/// sortie aux membres, puis l'appel, l'invalidation des vues, le message.
Future<void> runRideManageAction(
  BuildContext context,
  WidgetRef ref,
  RideDto ride,
  RideManageAction action,
) async {
  if (action == RideManageAction.report) {
    await showDetailModerationMenu(
      context,
      subject: ModerationSubject(
        teamSlug: ride.team.slug,
        type: ReportTargetType.ride,
        id: ride.id,
        teamName: ride.team.name,
      ),
    );
    return;
  }

  final ({String title, String message})? confirm = switch (action) {
    RideManageAction.unpublish => (
      title: 'rides.manage.unpublishTitle'.tr(),
      message: 'rides.manage.unpublishMessage'.tr(),
    ),
    RideManageAction.cancel => (
      title: 'rides.manage.cancelTitle'.tr(),
      message: 'rides.manage.cancelMessage'.tr(),
    ),
    RideManageAction.delete => (
      title: 'rides.manage.deleteTitle'.tr(),
      message: 'rides.manage.deleteMessage'.tr(),
    ),
    _ => null,
  };
  if (confirm != null) {
    final bool ok = await confirmDestructive(
      context,
      title: confirm.title,
      message: confirm.message,
      confirmLabel: 'rides.manage.${_label(action)}'.tr(),
    );
    if (!ok || !context.mounted) return;
  }

  final RideRepository repo = ref.read(rideRepositoryProvider);
  final String team = ride.team.slug;
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final GoRouter router = GoRouter.of(context);
  try {
    switch (action) {
      case RideManageAction.publish:
        await repo.changeStatus(team, ride.slug, Status.published);
      case RideManageAction.unpublish:
        await repo.changeStatus(team, ride.slug, Status.draft);
      case RideManageAction.cancel:
        await repo.changeStatus(team, ride.slug, Status.cancelled);
      case RideManageAction.reinstate:
        await repo.changeStatus(team, ride.slug, Status.published);
      case RideManageAction.delete:
        await repo.deleteRide(team, ride.slug);
      case RideManageAction.restore:
        await repo.undeleteRide(team, ride.slug);
      case RideManageAction.report:
        return;
    }
  } catch (error, stackTrace) {
    messenger?.showSnackBar(
      SnackBar(content: Text(getErrorMessage(error, stackTrace))),
    );
    return;
  }

  notifyRideChanged(
    ref,
    rideKey: RideKey(teamSlug: team, rideSlug: ride.slug),
  );
  messenger?.showSnackBar(
    SnackBar(content: Text('rides.manage.${_done(action)}'.tr())),
  );
  if (action == RideManageAction.delete) {
    // La fiche d'une sortie supprimée n'a plus lieu d'être ouverte : retour
    // à ce qui était dessous, sinon à l'Agenda de l'équipe (comme au site).
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Paths.teamAgenda(team));
    }
  }
}

String _label(RideManageAction a) => switch (a) {
  RideManageAction.publish => 'publish',
  RideManageAction.unpublish => 'unpublish',
  RideManageAction.cancel => 'cancel',
  RideManageAction.reinstate => 'reinstate',
  RideManageAction.delete => 'delete',
  RideManageAction.restore => 'restore',
  RideManageAction.report => 'report',
};

String _done(RideManageAction a) => switch (a) {
  RideManageAction.publish => 'published',
  RideManageAction.unpublish => 'unpublished',
  RideManageAction.cancel => 'cancelled',
  RideManageAction.reinstate => 'reinstated',
  RideManageAction.delete => 'deleted',
  RideManageAction.restore => 'restored',
  RideManageAction.report => 'report',
};

IconData _icon(RideManageAction a) => switch (a) {
  RideManageAction.publish => PdlIcons.publish,
  RideManageAction.unpublish => PdlIcons.unpublish,
  RideManageAction.cancel => PdlIcons.cancelled,
  RideManageAction.reinstate => PdlIcons.refresh,
  RideManageAction.delete => PdlIcons.delete,
  RideManageAction.restore => PdlIcons.restore,
  RideManageAction.report => PdlIcons.report,
};

Key _key(RideManageAction a) => switch (a) {
  RideManageAction.publish => keys.rideManage.publish,
  RideManageAction.unpublish => keys.rideManage.unpublish,
  RideManageAction.cancel => keys.rideManage.cancel,
  RideManageAction.reinstate => keys.rideManage.reinstate,
  RideManageAction.delete => keys.rideManage.delete,
  RideManageAction.restore => keys.rideManage.restore,
  RideManageAction.report => keys.rideManage.report,
};
