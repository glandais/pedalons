import '../material.dart';

import '../theme/pdl_tokens.dart';

/// Les deux formats du trait de rappel de couleur de tracé.
enum PdlColorTrackShape {
  /// 4 × 20, vertical — devant le titre d'une carte de groupe.
  bar,

  /// 14 × 3, horizontal — dans une légende de tracés.
  legend,
}

/// A9 — Trait de rappel de la couleur d'un tracé.
///
/// C'est le lien visuel entre un groupe (ou une étape) et sa polyligne sur la
/// carte : la couleur vient de `kMultiTrackPalette`, jamais d'une teinte de
/// rôle. Un rectangle plein de rayon 2, sans bordure ni texte.
class PdlColorTrack extends StatelessWidget {
  const PdlColorTrack({
    super.key,
    required this.color,
    this.shape = PdlColorTrackShape.bar,
  });

  final Color color;
  final PdlColorTrackShape shape;

  @override
  Widget build(BuildContext context) {
    final bool vertical = shape == PdlColorTrackShape.bar;
    return Container(
      width: vertical ? 4 : 14,
      height: vertical ? 20 : 3,
      decoration: BoxDecoration(color: color, borderRadius: PdlRadii.trackAll),
    );
  }
}
