import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../core/material.dart';
import '../../../core/pdl/pdl.dart';
import '../../../core/theme/pdl_colors.dart';
import '../../../core/theme/pdl_icons.dart';
import '../../../core/theme/pdl_tokens.dart';
import '../../../core/utils/api_error_handler.dart';
import '../../../keys.dart';
import '../../profile/presentation/widgets/confirm_sheet.dart';
import '../data/moderation_repository.dart';
import '../providers/moderation_refresh.dart';
import 'report_sheet.dart';

export 'report_sheet.dart' show ModerationSubject;

/// Ce que le menu `⋯` a produit, pour que l'écran qui l'a ouvert réagisse —
/// un détail signalé se ferme, un fil se recharge.
enum ModerationOutcome { deleted, reported, blocked }

enum _Choice { delete, report, block }

/// Le bouton `⋯` d'un contenu : 44 × 44, icône discrète.
///
/// Une ligne de commentaire n'a pas la place d'un `PdlAppBarAction` rond, et
/// ce bouton ne pose pas d'onde sur tout le fil.
class ModerationMoreButton extends StatelessWidget {
  const ModerationMoreButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(PdlIcons.more, size: 20, color: context.pdl.textDimmed),
      tooltip: 'moderation.more'.tr(),
      constraints: const BoxConstraints.tightFor(
        width: PdlMetrics.tapTarget,
        height: PdlMetrics.tapTarget,
      ),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}

/// Le menu `⋯` : Supprimer, Signaler, Bloquer {nom} — chacun seulement quand
/// il a un sens.
///
/// * **Supprimer** : [onDelete] fourni, c'est-à-dire un commentaire dont on
///   est l'auteur, ou qu'on modère.
/// * **Signaler** : [canReport] — jamais sur son propre contenu.
/// * **Bloquer** : [blockUserId] fourni, c'est-à-dire là où l'auteur est déjà
///   affiché (commentaire, annonce, ligne de membre), et jamais soi-même. Une
///   publication n'expose pas son auteur, et ce menu ne commence pas à le
///   faire.
///
/// Toute la suite se joue ici : la feuille de signalement, la confirmation du
/// blocage, la confirmation affichée et la relecture des listes. Un menu vide
/// ne s'ouvre pas.
Future<ModerationOutcome?> showModerationMenu(
  BuildContext context, {
  required ModerationSubject subject,
  bool canReport = true,
  String? blockUserId,
  String? blockUserName,
  Future<void> Function()? onDelete,
  String? title,
}) async {
  final bool canBlock = blockUserId != null && blockUserName != null;
  if (!canReport && !canBlock && onDelete == null) return null;

  // Pris **avant** le premier `await` : l'écran appelant peut être dépilé
  // pendant la suite, et son contexte avec lui.
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );

  final _Choice? choice = await PdlSheet.show<_Choice>(
    context: context,
    builder: (BuildContext sheetContext) => PdlSheet(
      title: title,
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(top: false, child: SizedBox(height: 8)),
      children: <Widget>[
        if (canReport)
          PdlSettingRow(
            key: keys.moderation.reportAction,
            icon: PdlIcons.report,
            title: subject.type == ReportTargetType.member
                ? 'moderation.reportMember'.tr()
                : 'moderation.report'.tr(),
            trailing: const SizedBox.shrink(),
            onTap: () => Navigator.of(sheetContext).pop(_Choice.report),
          ),
        if (canBlock)
          PdlSettingRow(
            key: keys.moderation.blockAction,
            icon: PdlIcons.block,
            title: 'moderation.block'.tr(
              namedArgs: <String, String>{'name': blockUserName},
            ),
            trailing: const SizedBox.shrink(),
            destructive: true,
            onTap: () => Navigator.of(sheetContext).pop(_Choice.block),
          ),
        if (onDelete != null)
          PdlSettingRow(
            key: keys.moderation.deleteAction,
            icon: PdlIcons.delete,
            title: 'common.delete'.tr(),
            trailing: const SizedBox.shrink(),
            destructive: true,
            onTap: () => Navigator.of(sheetContext).pop(_Choice.delete),
          ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;

  switch (choice) {
    case _Choice.delete:
      await onDelete!();
      return ModerationOutcome.deleted;

    case _Choice.report:
      final bool sent = await showReportSheet(context, subject: subject);
      if (!sent) return null;
      refreshAfterReport(container, subject.type);
      _confirm(
        messenger,
        subject.type == ReportTargetType.member
            ? 'moderation.memberReported'.tr()
            : 'moderation.reported'.tr(),
      );
      return ModerationOutcome.reported;

    case _Choice.block:
      final bool blocked = await blockUser(
        context,
        userId: blockUserId!,
        name: blockUserName!,
      );
      return blocked ? ModerationOutcome.blocked : null;
  }
}

/// Bloquer : une question fermée et sa conséquence, puis l'appel.
///
/// `true` une fois le blocage enregistré. L'échec se dit dans une barre de
/// confirmation, le blocage n'ayant pas d'écran à lui où rester.
Future<bool> blockUser(
  BuildContext context, {
  required String userId,
  required String name,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  final Map<String, String> args = <String, String>{'name': name};

  final bool confirmed = await confirmDestructive(
    context,
    title: 'moderation.blockTitle'.tr(namedArgs: args),
    message: 'moderation.blockMessage'.tr(namedArgs: args),
    confirmLabel: 'moderation.blockConfirm'.tr(),
  );
  if (!confirmed) return false;

  try {
    await container.read(moderationRepositoryProvider).block(userId);
  } catch (error, stackTrace) {
    _confirm(messenger, getErrorMessage(error, stackTrace));
    return false;
  }
  refreshAfterBlockChange(container);
  _confirm(messenger, 'moderation.blocked'.tr(namedArgs: args));
  return true;
}

/// Une barre flottante : elle se pose au-dessus de la barre d'onglets au lieu
/// de glisser dessous.
void _confirm(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

/// Le menu `⋯` d'une page de détail.
///
/// Un contenu signalé — ou dont on vient de bloquer l'auteur — sort des listes
/// du lecteur : la page qui le montre se ferme donc aussi, et l'on retombe sur
/// une liste où il n'est plus. Le détail reste lisible par lien, c'est voulu.
Future<void> showDetailModerationMenu(
  BuildContext context, {
  required ModerationSubject subject,
  bool canReport = true,
  String? blockUserId,
  String? blockUserName,
}) async {
  final ModerationOutcome? outcome = await showModerationMenu(
    context,
    subject: subject,
    canReport: canReport,
    blockUserId: blockUserId,
    blockUserName: blockUserName,
  );
  if (outcome == null || !context.mounted) return;
  await Navigator.of(context).maybePop();
}
