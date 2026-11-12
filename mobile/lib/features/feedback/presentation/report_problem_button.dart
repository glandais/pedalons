import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/logging/client_error.dart';
import '../../../core/pdl/pdl.dart';
import 'feedback_sheet.dart';

/// « Signaler un problème », sous le « Réessayer » d'un écran d'erreur — le
/// même libellé que l'entrée du profil et que la feuille qu'il ouvre (règle
/// RL11 des listes).
///
/// La feuille s'ouvre avec l'erreur jointe. **Rien quand on est hors ligne**
/// ou quand l'objet n'existe pas : le premier ne se signale pas (et le
/// signalement ne partirait pas), le second n'est pas un problème de l'app.
///
/// Un widget de *feature* et non de `core/pdl` : il traduit, et il connaît
/// l'API de retours.
class ReportProblemButton extends StatelessWidget {
  const ReportProblemButton({super.key, this.error, this.stackTrace});

  final Object? error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    final Object? error = this.error;
    if (error != null && !isReportable(error)) return const SizedBox.shrink();
    return PdlButton(
      label: 'feedback.reportProblem'.tr(),
      variant: PdlButtonVariant.text,
      onPressed: () => showFeedbackSheet(
        context,
        error: error == null ? null : clientErrorFrom(error, stackTrace),
      ),
    );
  }
}

/// Vrai sauf pour une requête qui n'a pas atteint le serveur ou un objet
/// introuvable. Ne passe pas par `resolveApiError`, qui note au journal : un
/// `build` n'écrit rien.
bool isReportable(Object error) {
  if (error is! DioException) return true;
  if (error.response == null) {
    return error.type != DioExceptionType.connectionError &&
        error.type != DioExceptionType.connectionTimeout &&
        error.type != DioExceptionType.sendTimeout &&
        error.type != DioExceptionType.receiveTimeout &&
        error.type != DioExceptionType.cancel;
  }
  return error.response!.statusCode != 404 &&
      backendErrorCode(error) != 'NOT_FOUND';
}
