import 'package:easy_localization/easy_localization.dart';

import '../../../api/generated/export.dart';
import '../../../core/logging/error_reporter.dart';
import '../../../core/material.dart';
import '../../../core/pdl/pdl.dart';
import 'feedback_sheet.dart';

/// « L'app a rencontré un problème la dernière fois. Le signaler ? »
///
/// Posé **une fois**, au lancement qui suit une erreur que personne n'a
/// rattrapée, une fois le membre connecté (le signalement l'exige). Le drapeau
/// s'efface quelle que soit la réponse : une question qui revient à chaque
/// lancement tant qu'on n'y a pas dit oui n'est plus une question.
Future<void> promptUnreportedFatal(
  BuildContext context,
  ErrorReporter reporter,
) async {
  final ClientErrorDto? fatal = reporter.unreportedFatal;
  if (fatal == null) return;
  await reporter.clearUnreportedFatal();
  if (!context.mounted) return;

  final bool? report = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text('feedback.fatalPrompt.title'.tr()),
      content: Text('feedback.fatalPrompt.message'.tr()),
      actions: <Widget>[
        PdlButton(
          variant: PdlButtonVariant.text,
          label: 'feedback.fatalPrompt.dismiss'.tr(),
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PdlButton(
          label: 'feedback.fatalPrompt.report'.tr(),
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  if (report != true || !context.mounted) return;
  await showFeedbackSheet(context, error: fatal);
}
