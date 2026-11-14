import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../data/ad_repository.dart';
import '../../providers/ad_providers.dart';

/// Les gestes de l'auteur d'une annonce (et de l'administration de l'équipe)
/// depuis le `⋯` de son écran — ceux du menu du site (`AdDetailPage`) :
/// publier un brouillon, dépublier, supprimer, restaurer, et signaler
/// (ledger `MOB-158`). Modifier est le crayon de la barre.
enum AdManageAction { publish, unpublish, delete, restore, report }

/// Les gestes offerts pour [ad], dans l'ordre du menu. Une annonce supprimée
/// n'offre que sa restauration ; [canReport] est faux pour sa propre annonce,
/// qu'on ne se signale pas à soi-même.
///
/// Chaque geste suit le droit que le backend calcule pour **cette** annonce
/// (`permissions`, docs/LEDGER_*.md MOB-137).
List<AdManageAction> adManageActions(AdDto ad, {required bool canReport}) {
  final bool edit = ad.permissions.canEdit;
  final bool delete = ad.permissions.canDelete;
  if (ad.deleted) {
    return <AdManageAction>[if (delete) AdManageAction.restore];
  }
  return <AdManageAction>[
    if (edit && ad.status == Status.draft.json) AdManageAction.publish,
    if (edit && ad.status == Status.published.json) AdManageAction.unpublish,
    if (delete) AdManageAction.delete,
    if (canReport) AdManageAction.report,
  ];
}

/// Le `⋯` de l'écran ouvre-t-il « Gérer l'annonce » plutôt que la seule
/// modération ?
bool adHasManageActions(AdDto ad) =>
    ad.permissions.canEdit || ad.permissions.canDelete;

/// Ouvre le menu « Gérer l'annonce » et exécute le geste choisi.
Future<void> showAdManageMenu(
  BuildContext context,
  WidgetRef ref,
  AdDto ad, {
  required bool canReport,
}) async {
  final List<AdManageAction> actions = adManageActions(
    ad,
    canReport: canReport,
  );
  final AdManageAction? action = await PdlSheet.show<AdManageAction>(
    context: context,
    builder: (BuildContext sheetContext) => PdlSheet(
      title: 'ads.manage.menuTitle'.tr(),
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(
        top: false,
        child: SizedBox(height: PdlSpacing.chipGap),
      ),
      children: <Widget>[
        for (final AdManageAction a in actions)
          PdlSettingRow(
            key: _key(a),
            icon: _icon(a),
            title: 'ads.manage.${_label(a)}'.tr(),
            destructive: a == AdManageAction.delete,
            showDivider:
                a == AdManageAction.delete &&
                actions.contains(AdManageAction.report),
            trailing: const SizedBox.shrink(),
            onTap: () => Navigator.of(sheetContext).pop(a),
          ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  await runAdManageAction(context, ref, ad, action);
}

/// Exécute [action] sur [ad] : confirmation d'abord pour ce qui retire
/// l'annonce aux membres, puis l'appel, l'invalidation des vues, le message.
Future<void> runAdManageAction(
  BuildContext context,
  WidgetRef ref,
  AdDto ad,
  AdManageAction action,
) async {
  final String team = ad.team.slug;
  if (action == AdManageAction.report) {
    await showDetailModerationMenu(
      context,
      subject: ModerationSubject(
        teamSlug: team,
        type: ReportTargetType.ad,
        id: ad.id,
        teamName: ad.team.name,
      ),
      blockUserId: ad.createdById,
      blockUserName: ad.createdByDisplayName,
    );
    return;
  }

  final ({String title, String message})? confirm = switch (action) {
    AdManageAction.unpublish => (
      title: 'ads.manage.unpublishTitle'.tr(),
      message: 'ads.manage.unpublishMessage'.tr(),
    ),
    AdManageAction.delete => (
      title: 'ads.manage.deleteTitle'.tr(),
      message: 'ads.manage.deleteMessage'.tr(),
    ),
    _ => null,
  };
  if (confirm != null) {
    final bool ok = await confirmDestructive(
      context,
      title: confirm.title,
      message: confirm.message,
      confirmLabel: 'ads.manage.${_label(action)}'.tr(),
    );
    if (!ok || !context.mounted) return;
  }

  final AdRepository repo = ref.read(adRepositoryProvider);
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final GoRouter router = GoRouter.of(context);
  try {
    switch (action) {
      // Par `PATCH …/status`, jamais un PUT recopié du détail : il renverrait
      // la position floutée, et effacerait la vraie.
      case AdManageAction.publish:
        await repo.changeStatus(team, ad.slug, Status.published);
      case AdManageAction.unpublish:
        await repo.changeStatus(team, ad.slug, Status.draft);
      case AdManageAction.delete:
        await repo.deleteAd(team, ad.slug);
      case AdManageAction.restore:
        await repo.undeleteAd(team, ad.slug);
      case AdManageAction.report:
        return;
    }
  } catch (error, stackTrace) {
    messenger?.showSnackBar(
      SnackBar(content: Text(getErrorMessage(error, stackTrace))),
    );
    return;
  }

  notifyAdChanged(
    ref,
    teamSlug: team,
    adKey: (teamSlug: team, adSlug: ad.slug),
  );
  messenger?.showSnackBar(
    SnackBar(content: Text('ads.manage.${_done(action)}'.tr())),
  );
  if (action == AdManageAction.delete) {
    // L'écran d'une annonce supprimée n'a plus lieu d'être ouvert : retour à
    // ce qui était dessous, sinon aux annonces de l'équipe.
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Paths.teamAds(team));
    }
  }
}

String _label(AdManageAction a) => switch (a) {
  AdManageAction.publish => 'publish',
  AdManageAction.unpublish => 'unpublish',
  AdManageAction.delete => 'delete',
  AdManageAction.restore => 'restore',
  AdManageAction.report => 'report',
};

String _done(AdManageAction a) => switch (a) {
  AdManageAction.publish => 'published',
  AdManageAction.unpublish => 'unpublished',
  AdManageAction.delete => 'deleted',
  AdManageAction.restore => 'restored',
  AdManageAction.report => 'report',
};

IconData _icon(AdManageAction a) => switch (a) {
  AdManageAction.publish => PdlIcons.publish,
  AdManageAction.unpublish => PdlIcons.unpublish,
  AdManageAction.delete => PdlIcons.delete,
  AdManageAction.restore => PdlIcons.restore,
  AdManageAction.report => PdlIcons.report,
};

Key _key(AdManageAction a) => switch (a) {
  AdManageAction.publish => keys.adManage.publish,
  AdManageAction.unpublish => keys.adManage.unpublish,
  AdManageAction.delete => keys.adManage.delete,
  AdManageAction.restore => keys.adManage.restore,
  AdManageAction.report => keys.adManage.report,
};
