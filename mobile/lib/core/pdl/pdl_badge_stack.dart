import '../material.dart';

import '../theme/pdl_tokens.dart';

/// B20 — Pile de badges alignée à droite (`.badges`).
///
/// Colonne, gouttière 4, alignée sur le bord droit de la carte.
///
/// **L'ordre est une convention de lecture, pas un tri** : type de contenu,
/// puis statut, puis visibilité. C'est l'appelant qui range ses badges dans cet
/// ordre — le widget ne sait rien de ce qu'ils portent, et un tri automatique
/// exigerait qu'il le sache.
///
/// La pile est [Flexible] côté appelant : posée à droite d'un titre, elle ne
/// doit jamais pousser celui-ci hors de la carte.
class PdlBadgeStack extends StatelessWidget {
  const PdlBadgeStack({
    super.key,
    required this.badges,
    this.alignment = CrossAxisAlignment.end,
    this.gap = PdlSpacing.badgeGap,
  });

  /// Dans l'ordre type → statut → visibilité.
  final List<Widget> badges;

  final CrossAxisAlignment alignment;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: <Widget>[
        for (int i = 0; i < badges.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: gap),
          badges[i],
        ],
      ],
    );
  }
}
