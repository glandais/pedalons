import 'package:easy_localization/easy_localization.dart';

import '../../../../../core/material.dart';

import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../keys.dart';
import '../../../domain/gpx_check.dart';
import '../../../domain/planner_quota.dart';
import 'gpx_refused_banner.dart';
import 'planner_quota_message.dart';

/// L'étape 1 de la création d'un parcours : d'où vient le tracé (ledgers
/// `MOB-79`, `MOB-170`).
///
/// * Planificateur fermé à l'équipe ([onDraw] nul) : envoyer un fichier GPX,
///   et l'écran dit que le tracé ne se dessine pas dans l'app.
/// * Planificateur ouvert : « Importer un fichier GPX » ou « Tracer sur la
///   carte ». Quota du mois épuisé ([quotaSpent]) : le second reste en vue,
///   désactivé, avec sa raison — l'import reste.
///
/// [busy] : le fichier choisi est en cours de lecture. [refused] : le
/// précédent a été refusé, son bandeau passe au-dessus ; « Choisir un autre
/// fichier » rouvre le sélecteur comme le bouton principal.
class GpxPickStep extends StatelessWidget {
  const GpxPickStep({
    super.key,
    required this.onPick,
    required this.busy,
    this.refused,
    this.onDraw,
    this.quotaSpent,
  });

  final VoidCallback onPick;
  final bool busy;
  final GpxRefused? refused;

  /// Ouvre le planificateur ; nul, il n'est pas proposé.
  final VoidCallback? onDraw;

  /// Le quota épuisé qui ferme « Tracer sur la carte », s'il l'est.
  final PlannerQuotaRefusal? quotaSpent;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final GpxRefused? refusal = refused;
    final VoidCallback? draw = onDraw;
    final PlannerQuotaRefusal? quota = quotaSpent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (refusal != null) ...<Widget>[
          GpxRefusedBanner(refused: refusal, onPickAnother: onPick, busy: busy),
          const SizedBox(height: PdlSpacing.section),
        ],
        PdlCard(
          key: keys.routeEditor.pickStep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PdlEmptyState(
                variant: PdlEmptyVariant.empty,
                icon: PdlIcons.gpx,
                title: draw == null
                    ? 'routes.editor.pickTitle'.tr()
                    : 'routes.editor.pickTitlePlanner'.tr(),
                message: draw == null
                    ? 'routes.editor.pickMessage'.tr()
                    : 'routes.editor.pickMessagePlanner'.tr(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: PdlSpacing.section),
              PdlButton(
                key: keys.routeEditor.pickButton,
                label: draw == null
                    ? 'routes.editor.pickButton'.tr()
                    : 'routes.editor.importButton'.tr(),
                icon: PdlIcons.fileAdd,
                fullWidth: true,
                loading: busy,
                loadingLabel: 'routes.editor.reading'.tr(),
                onPressed: onPick,
              ),
              if (draw != null) ...<Widget>[
                const SizedBox(height: PdlSpacing.chipGap),
                PdlButton(
                  key: keys.routeEditor.drawButton,
                  label: 'routes.editor.drawButton'.tr(),
                  icon: PdlIcons.map,
                  variant: PdlButtonVariant.outline,
                  fullWidth: true,
                  enabled: !busy && quota == null,
                  onPressed: draw,
                ),
                if (quota != null) ...<Widget>[
                  const SizedBox(height: PdlSpacing.chipGap),
                  PlannerQuotaMessage(
                    key: keys.routeEditor.quotaMessage,
                    refusal: quota,
                    help: true,
                  ),
                ],
              ],
              const SizedBox(height: PdlSpacing.chipGap),
              Text(
                'routes.editor.pickHint'.tr(),
                textAlign: TextAlign.center,
                style: t.xs.copyWith(color: c.textDimmed),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
