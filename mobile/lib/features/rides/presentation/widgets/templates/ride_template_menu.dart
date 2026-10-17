import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../config/paths.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/utils/api_error_handler.dart';
import '../../../../../keys.dart';
import '../../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../data/ride_template_repository.dart';
import '../../../providers/ride_template_providers.dart';
import '../../ride_editor_location.dart';

/// Les gestes du menu d'un modèle de sortie (ledger `MOB-78`).
enum RideTemplateAction { createRide, edit, delete }

/// Ouvre le menu d'un modèle — créer une sortie depuis lui, le modifier, le
/// supprimer — et exécute le geste choisi.
Future<void> showRideTemplateMenu(
  BuildContext context,
  WidgetRef ref, {
  required String teamSlug,
  required RideTemplateDto template,
}) async {
  final RideTemplateAction? action = await PdlSheet.show<RideTemplateAction>(
    context: context,
    builder: (BuildContext sheetContext) => PdlSheet(
      title: template.name,
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(
        top: false,
        child: SizedBox(height: PdlSpacing.chipGap),
      ),
      children: <Widget>[
        for (final RideTemplateAction a in RideTemplateAction.values)
          PdlSettingRow(
            key: _key(a),
            icon: _icon(a),
            title: 'rides.templates.${a.name}'.tr(),
            destructive: a == RideTemplateAction.delete,
            trailing: const SizedBox.shrink(),
            onTap: () => Navigator.of(sheetContext).pop(a),
          ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  await runRideTemplateAction(
    context,
    ref,
    teamSlug: teamSlug,
    template: template,
    action: action,
  );
}

/// Exécute [action] sur [template] : la navigation pour créer une sortie ou
/// modifier le modèle ; pour le supprimer, la confirmation, l'appel,
/// l'invalidation des vues et le message.
Future<void> runRideTemplateAction(
  BuildContext context,
  WidgetRef ref, {
  required String teamSlug,
  required RideTemplateDto template,
  required RideTemplateAction action,
}) async {
  switch (action) {
    case RideTemplateAction.createRide:
      await context.push(
        rideNewLocation(teamSlug, templateSlug: template.slug),
      );
    case RideTemplateAction.edit:
      await context.push(Paths.rideTemplateEdit(teamSlug, template.slug));
    case RideTemplateAction.delete:
      await _delete(context, ref, teamSlug, template);
  }
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  String teamSlug,
  RideTemplateDto template,
) async {
  final bool ok = await confirmDestructive(
    context,
    title: 'rides.templates.deleteTitle'.tr(),
    message: 'rides.templates.deleteMessage'.tr(
      namedArgs: <String, String>{'name': template.name},
    ),
    confirmLabel: 'rides.templates.deleteConfirm'.tr(),
  );
  if (!ok || !context.mounted) return;

  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  // Pris avant l'`await` : la liste peut être quittée pendant la requête, et
  // son `WidgetRef` avec elle.
  final ProviderContainer container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  final RideTemplateRepository repo = ref.read(rideTemplateRepositoryProvider);
  try {
    await repo.delete(teamSlug, template.slug);
  } catch (error, stackTrace) {
    messenger?.showSnackBar(
      SnackBar(content: Text(getErrorMessage(error, stackTrace))),
    );
    return;
  }
  notifyRideTemplatesChanged(container);
  messenger?.showSnackBar(
    SnackBar(content: Text('rides.templates.deleted'.tr())),
  );
}

IconData _icon(RideTemplateAction a) => switch (a) {
  RideTemplateAction.createRide => PdlIcons.ride,
  RideTemplateAction.edit => PdlIcons.edit,
  RideTemplateAction.delete => PdlIcons.delete,
};

Key _key(RideTemplateAction a) => switch (a) {
  RideTemplateAction.createRide => keys.rideTemplates.menuCreateRide,
  RideTemplateAction.edit => keys.rideTemplates.menuEdit,
  RideTemplateAction.delete => keys.rideTemplates.menuDelete,
};
