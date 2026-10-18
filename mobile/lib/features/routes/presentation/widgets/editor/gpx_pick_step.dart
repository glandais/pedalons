import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../keys.dart';
import '../../../domain/gpx_check.dart';
import 'gpx_refused_banner.dart';

/// L'étape 1 de la création d'un parcours : envoyer un fichier GPX (ledger
/// `MOB-79`). Le tracé ne se dessine pas dans l'app, et l'écran le dit avant
/// de proposer le sélecteur.
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
  });

  final VoidCallback onPick;
  final bool busy;
  final GpxRefused? refused;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final GpxRefused? refusal = refused;

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
                title: 'routes.editor.pickTitle'.tr(),
                message: 'routes.editor.pickMessage'.tr(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: PdlSpacing.section),
              PdlButton(
                key: keys.routeEditor.pickButton,
                label: 'routes.editor.pickButton'.tr(),
                icon: PdlIcons.fileAdd,
                fullWidth: true,
                loading: busy,
                loadingLabel: 'routes.editor.reading'.tr(),
                onPressed: onPick,
              ),
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
