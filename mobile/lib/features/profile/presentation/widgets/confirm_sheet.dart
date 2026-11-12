import 'package:easy_localization/easy_localization.dart';

import '../../../../core/material.dart';

import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';

/// Une confirmation destructive : **question fermée, puis conséquence**.
///
/// La maquette ne l'applique qu'à la suppression de compte ; le plan l'étend à
/// supprimer une clé d'accès et déconnecter un appareil GPS — deux actions qu'on ne défait pas d'un geste et dont on ne mesure pas la
/// portée sans qu'on la dise.
///
/// L'action est un **contour rouge, jamais un aplat** : un aplat rouge pleine
/// largeur se touche par réflexe.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final bool? confirmed = await PdlSheet.show<bool>(
    context: context,
    builder: (BuildContext sheetContext) {
      final PdlColors c = sheetContext.pdl;
      final PdlTypography t = sheetContext.pdlText;
      return PdlSheet(
        header: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: Text(
            title,
            style: t.sectionTitle.copyWith(color: c.dangerOnSoft),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            8,
            PdlSpacing.section,
            0,
          ),
          child: Text(
            message,
            key: keys.profile.confirmDestructiveMessage,
            style: t.sub,
          ),
        ),
        footer: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: PdlButton(
                    label: 'common.cancel'.tr(),
                    variant: PdlButtonVariant.outline,
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                  ),
                ),
                const SizedBox(width: PdlSpacing.chipGap),
                Expanded(
                  child: PdlButton(
                    key: keys.profile.confirmDestructiveButton,
                    label: confirmLabel,
                    variant: PdlButtonVariant.danger,
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}
