import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';

/// Les deux bords voilés d'un hero cartographique.
enum PdlScrimEdge {
  /// 150 px, `.90 → .55 à 45 % → 0` — sous la barre supérieure translucide.
  top,

  /// 90 px, `.75 → 0` — sous un titre posé en bas d'image.
  bottom,
}

/// A18 — Voile de lisibilité.
///
/// Règle non négociable de la charte : **jamais de texte posé directement sur
/// une tuile cartographique ou une photo**. Une tuile claire un jour d'été et
/// un titre blanc, et il n'y a plus de titre. Le voile passe par ici, et il est
/// [IgnorePointer] : il ne doit pas voler le geste de panoramique de la carte
/// qu'il recouvre.
///
/// À poser dans un [Stack], en `Positioned` sur le bord concerné.
class PdlScrim extends StatelessWidget {
  const PdlScrim({super.key, required this.edge, this.height});

  const PdlScrim.top({super.key, this.height}) : edge = PdlScrimEdge.top;

  const PdlScrim.bottom({super.key, this.height}) : edge = PdlScrimEdge.bottom;

  final PdlScrimEdge edge;

  /// Hauteur imposée ; à défaut, celle de la charte (150 en haut, 90 en bas).
  final double? height;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final bool isTop = edge == PdlScrimEdge.top;

    return IgnorePointer(
      child: Container(
        height: height ?? (isTop ? 150 : 90),
        decoration: BoxDecoration(
          gradient: isTop
              ? PdlGradients.scrimTop(c)
              : PdlGradients.scrimBottom(c),
        ),
      ),
    );
  }
}
