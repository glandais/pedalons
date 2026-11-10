import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';

/// Le bouton « GPS » : contour, icône d'appareil, et la feuille GPS derrière
/// (`showGpsSheet`, via `GpsExportRunner.openGpsSheet`). Le même partout où
/// un parcours s'exporte (KIT §8, « Export du parcours »).
///
/// [onPressed] reçoit le contexte **du bouton** : c'est sur lui que s'ancre la
/// feuille de partage sur iPad (`shareOriginOf`), la feuille GPS étant déjà
/// refermée quand le fichier arrive.
///
/// [compact] resserre typographie et gouttières pour une carte (taille `sm`
/// de `PdlButton`), jamais la cible de 44 px.
class GpsButton extends StatelessWidget {
  const GpsButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
  });

  final ValueChanged<BuildContext>? onPressed;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool interactive = onPressed != null && !loading;
    // Le libellé « GPS » seul dit mal ce que fait le bouton à un lecteur
    // d'écran : il prend une phrase, et garde son action.
    return Semantics(
      container: true,
      button: true,
      enabled: interactive,
      label: 'routes.gpsSheet.buttonSemantics'.tr(),
      onTap: interactive ? () => onPressed!(context) : null,
      excludeSemantics: true,
      child: PdlButton(
        label: 'routes.gpsSheet.button'.tr(),
        loadingLabel: 'routes.downloading'.tr(),
        icon: PdlIcons.device,
        variant: PdlButtonVariant.outline,
        size: compact ? PdlButtonSize.sm : PdlButtonSize.md,
        loading: loading,
        onPressed: onPressed == null ? null : () => onPressed!(context),
      ),
    );
  }
}
