import 'package:easy_localization/easy_localization.dart';

import '../../../../../core/material.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../keys.dart';
import '../../../domain/planner_quota.dart';

/// Pourquoi tracer sur la carte est fermé pour le mois (docs/LEDGER_*.md
/// BILL-10) — les trois phrases du site (`PlannerQuotaMessage`) : la raison de
/// la limite, l'import de GPX qui reste et le jour où le compteur repart, et
/// comment la limite se lève. Partagé par l'aide d'un bouton désactivé
/// ([help] : petit et atténué) et la feuille d'un refus.
class PlannerQuotaMessage extends StatelessWidget {
  const PlannerQuotaMessage({
    super.key,
    required this.refusal,
    this.help = false,
  });

  final PlannerQuotaRefusal refusal;
  final bool help;

  /// Le mois où le compteur repart, en toutes lettres (« décembre »). La
  /// phrase dit « le 1er » autour : `resetsOn` est toujours un premier du mois.
  static String _month(String resetsOn) {
    final int? month = monthOfLocalDate(resetsOn);
    return month == null
        ? resetsOn
        : DateFormat.LLLL().format(DateTime(2000, month));
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final TextStyle style = help ? t.xs.copyWith(color: c.textDimmed) : t.sub;
    final List<String> lines = <String>[
      refusal.team
          ? 'routes.planner.quota.team'.tr(
              namedArgs: <String, String>{
                'teamName': refusal.teamName ?? '',
                'limit': '${refusal.limit}',
              },
            )
          : 'routes.planner.quota.personal'.tr(
              namedArgs: <String, String>{'limit': '${refusal.limit}'},
            ),
      'routes.planner.quota.alternative'.tr(
        namedArgs: <String, String>{'month': _month(refusal.resetsOn)},
      ),
      (refusal.team
              ? 'routes.planner.quota.teamLift'
              : 'routes.planner.quota.personalLift')
          .tr(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final (int i, String line) in lines.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : PdlSpacing.badgeGap),
            child: Text(line, style: style),
          ),
      ],
    );
  }
}

/// La feuille d'un refus `PLANNER_QUOTA_REACHED`, quel que soit l'appel qui
/// l'a reçu : un calcul dans le planificateur, ou l'enregistrement. Le quota
/// s'est épuisé entre-temps (une autre personne de l'équipe a enregistré) :
/// le bouton d'entrée ne se ferme que s'il l'est déjà au chargement.
Future<void> showPlannerQuotaSheet(
  BuildContext context,
  PlannerQuotaRefusal refusal,
) {
  return PdlSheet.show<void>(
    context: context,
    builder: (BuildContext sheetContext) => PdlSheet(
      key: keys.routeEditor.quotaSheet,
      title: 'routes.planner.quota.title'.tr(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        child: PlannerQuotaMessage(refusal: refusal),
      ),
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(PdlSpacing.section),
          child: PdlButton(
            key: keys.routeEditor.quotaClose,
            label: 'common.close'.tr(),
            fullWidth: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    ),
  );
}
