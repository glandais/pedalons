import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Un tag à rendre : son libellé et l'aplat de sa famille de couleur.
///
/// La couleur arrive déjà résolue : `core/pdl` ne connaît pas `TagColor`,
/// c'est l'appelant qui passe la famille par `PdlFamilyTone.soft(c).fill`
/// (`core/theme/enum_colors.dart`).
@immutable
class PdlTagEntry {
  const PdlTagEntry({required this.label, required this.color});

  final String label;

  /// L'aplat de la famille — rendu en pastille, jamais en fond.
  final Color color;
}

/// Un tag d'équipe posé sur un contenu (ledger `MOB-39`).
///
/// **Délibérément pas un badge** (plan des tags, D10) : un badge est un fond
/// doux de la famille et un libellé en capitales de la même famille, ce qui
/// est la forme du code couleur métier. Un tag vert rendu ainsi se lirait
/// « Publié ». Le tag est donc un contour neutre, une **pastille** de la
/// famille, et un libellé en texte neutre, casse respectée — la couleur ne
/// porte que l'identité du tag, jamais un état.
class PdlTag extends StatelessWidget {
  const PdlTag({super.key, required this.label, required this.color});

  final String label;

  /// L'aplat de la famille du tag.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _TagPill(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(child: _TagText(label)),
      ],
    );
  }
}

/// Les tags d'un contenu, en rangée qui passe à la ligne.
///
/// Deux modes (D19) : **tronqué** en carte de liste — [maxVisible] tags puis
/// une pastille « +n », dès qu'au moins deux tags seraient cachés —,
/// **complet** en fiche ([maxVisible] nul). L'ordre est
/// celui de l'appelant, que l'API rend déjà alphabétique.
///
/// Rien n'est rendu pour une liste vide : la plupart des contenus n'ont pas
/// de tag, et un bloc vide décalerait la carte pour rien.
class PdlTagRow extends StatelessWidget {
  const PdlTagRow({
    super.key,
    required this.tags,
    this.maxVisible,
    this.gap = PdlSpacing.badgeGap,
  });

  final List<PdlTagEntry> tags;

  /// Nombre de tags montrés avant la pastille « +n » ; nul pour tous.
  final int? maxVisible;

  final double gap;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    // Tronquer pour ne cacher qu'un tag dépenserait une pastille pour n'en
    // gagner aucune : jusqu'à maxVisible + 1, tout est montré. Même règle que
    // le web (`TagList`), pour qu'un contenu ait la même carte partout.
    final int? max = maxVisible;
    final int shown = max == null || tags.length <= max + 1 ? tags.length : max;
    final int hidden = tags.length - shown;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: <Widget>[
        for (int i = 0; i < shown; i++)
          PdlTag(label: tags[i].label, color: tags[i].color),
        if (hidden > 0)
          // « +n » n'est pas une chaîne traduite : un nombre et un signe, que
          // toutes les langues de l'app écrivent pareil.
          _TagPill(children: <Widget>[_TagText('+$hidden')]),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // `minHeight` et non `height`, comme le badge : à fort agrandissement
    // typographique le tag grandit au lieu de rogner son libellé.
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: PdlRadii.pillAll,
        border: Border.all(color: context.pdl.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _TagText extends StatelessWidget {
  const _TagText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.xs.copyWith(color: context.pdl.text),
    );
  }
}
