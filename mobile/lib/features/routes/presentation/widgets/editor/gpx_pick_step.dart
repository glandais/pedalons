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
    this.busyLabel,
    this.refused,
    this.onDraw,
    this.onGenerate,
    this.quotaSpent,
    this.onOpenProposal,
  });

  final VoidCallback onPick;
  final bool busy;

  /// Ce que dit le bouton d'import pendant [busy] ; `null` : « Lecture du
  /// fichier… ». Un import de plusieurs fichiers y met sa progression.
  final String? busyLabel;
  final GpxRefused? refused;

  /// Ouvre le planificateur ; nul, il n'est pas proposé.
  final VoidCallback? onDraw;

  /// Ouvre le générateur de parcours (ledger `MOB-154`) ; nul, il n'est pas
  /// proposé. Il garde son résultat par le planificateur : le même quota le
  /// ferme.
  final VoidCallback? onGenerate;

  /// Le quota épuisé qui ferme « Tracer sur la carte », s'il l'est.
  final PlannerQuotaRefusal? quotaSpent;

  /// Une proposition (générateur, retouche) attend dans le planificateur,
  /// quitté sans « Terminer » : la page le dit et la rouvre, au lieu de la
  /// cacher (ledger `MOB-187`). Nul : rien n'attend.
  final VoidCallback? onOpenProposal;

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
        if (onOpenProposal != null) ...<Widget>[
          PdlBanner(
            tone: PdlBannerTone.info,
            icon: PdlIcons.generate,
            message: 'routes.editor.proposalWaiting'.tr(),
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          PdlButton(
            key: keys.routeEditor.proposalButton,
            label: 'routes.editor.proposalOpen'.tr(),
            icon: PdlIcons.map,
            fullWidth: true,
            enabled: !busy,
            onPressed: onOpenProposal,
          ),
          const SizedBox(height: PdlSpacing.section),
        ],
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
              // L'ordre des menus « Créer » : tracer, importer, générer.
              if (draw != null) ...<Widget>[
                PdlButton(
                  key: keys.routeEditor.drawButton,
                  label: 'routes.editor.drawButton'.tr(),
                  icon: PdlIcons.map,
                  fullWidth: true,
                  enabled: !busy && quota == null,
                  onPressed: draw,
                ),
                const SizedBox(height: PdlSpacing.chipGap),
              ],
              PdlButton(
                key: keys.routeEditor.pickButton,
                label: 'routes.editor.importMany'.tr(),
                icon: PdlIcons.fileAdd,
                variant: draw == null
                    ? PdlButtonVariant.fill
                    : PdlButtonVariant.outline,
                fullWidth: true,
                loading: busy,
                loadingLabel: busyLabel ?? 'routes.editor.reading'.tr(),
                onPressed: onPick,
              ),
              if (draw != null) ...<Widget>[
                if (onGenerate != null) ...<Widget>[
                  const SizedBox(height: PdlSpacing.chipGap),
                  PdlButton(
                    key: keys.routeEditor.generateButton,
                    label: 'routeGenerator.title'.tr(),
                    icon: PdlIcons.generate,
                    variant: PdlButtonVariant.outline,
                    fullWidth: true,
                    enabled: !busy && quota == null,
                    onPressed: onGenerate,
                  ),
                ],
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
