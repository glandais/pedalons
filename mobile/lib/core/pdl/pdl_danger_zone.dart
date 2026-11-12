import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import 'pdl_button.dart';

/// B16 — Zone de danger : filet, titre rouge, conséquence, bouton contour.
///
/// **Hors carte, et volontairement.** Une suppression de compte enfermée dans
/// la même carte que « Langue » et « Thème » se lit comme un réglage de plus.
/// Le filet supérieur et l'absence de conteneur la détachent du reste de
/// l'écran.
///
/// Le bouton est un [PdlButtonVariant.danger], c'est-à-dire un **contour**
/// rouge : la charte réserve l'aplat coloré à l'action principale, et un aplat
/// rouge pleine largeur en bas d'un écran de réglages attire exactement le
/// mauvais doigt.
///
/// [consequence] n'est pas facultatif dans l'esprit : « Cette action est
/// irréversible et supprime vos inscriptions » est ce qui permet de décider.
class PdlDangerZone extends StatelessWidget {
  const PdlDangerZone({
    super.key,
    required this.title,
    required this.consequence,
    required this.actionLabel,
    required this.onAction,
    this.busy = false,
    this.busyLabel,
    this.padding = const EdgeInsets.symmetric(
      horizontal: PdlSpacing.section,
      vertical: PdlSpacing.section,
    ),
  });

  final String title;
  final String consequence;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool busy;
  final String? busyLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: t.cardTitle.copyWith(color: c.dangerOnSoft)),
          const SizedBox(height: 6),
          Text(consequence, style: t.sub),
          const SizedBox(height: 12),
          PdlButton(
            label: actionLabel,
            loadingLabel: busyLabel,
            loading: busy,
            variant: PdlButtonVariant.danger,
            fullWidth: true,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}
