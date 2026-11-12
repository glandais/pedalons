import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';

/// B18 — Points de position d'une galerie.
///
/// Points de 6 px, point actif étiré en pilule de 18 × 6. L'étirement, plutôt
/// qu'un simple changement d'opacité, se lit **du coin de l'œil** pendant le
/// balayage : c'est le seul repère de position sur une image plein cadre.
///
/// Les points sont posés sur une photo : ils sont blancs, et les inactifs sont
/// le même blanc à 45 %. C'est la seule couleur qui tienne sur une image
/// quelconque, dans les deux modes.
class PdlGalleryDots extends StatelessWidget {
  const PdlGalleryDots({
    super.key,
    required this.count,
    required this.index,
    this.semanticLabel,
  });

  final int count;
  final int index;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    if (count <= 1) return const SizedBox.shrink();

    return Semantics(
      label: semanticLabel,
      value: '${index + 1} / $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < count; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: PdlMotion.stateChange,
              curve: PdlMotion.stateChangeCurve,
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index
                    ? c.onPrimary
                    : c.onPrimary.withValues(alpha: 0.45),
                borderRadius: PdlRadii.pillAll,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
