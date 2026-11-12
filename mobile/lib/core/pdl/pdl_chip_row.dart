import '../material.dart';

import '../theme/pdl_tokens.dart';

/// B1 — Rangée de chips défilante horizontalement.
///
/// **La hauteur est mesurée, jamais figée.** C'est le défaut F-DE-3 : une
/// rangée de chips à `SizedBox(height: 44)` se fait rogner dès que
/// l'agrandissement typographique dépasse 130 %, et la chip active — celle qui
/// dit à l'utilisateur ce qu'il regarde — est la première à disparaître. Le
/// défilement passe donc par un [SingleChildScrollView] sur une [Row], qui
/// prend la hauteur de son contenu, et non par un [ListView] horizontal qui
/// exigerait une contrainte verticale.
///
/// Le fondu des 28 derniers pixels (`mask-image` de `.chiprow`) n'est pas
/// décoratif : il dit qu'il reste des chips à droite. Sans lui, une chip
/// coupée net se lit comme une chip tronquée.
class PdlChipRow extends StatelessWidget {
  const PdlChipRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
    this.gap = PdlSpacing.chipGap,
    this.fadeWidth = 28,
    this.controller,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double gap;

  /// Largeur du fondu de bord droit. `0` le supprime.
  final double fadeWidth;

  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    // Alignée au début de la ligne, qu'elle déborde ou non (règle RL6 des
    // listes) : une rangée plus courte que l'écran se centrait dans une
    // colonne centrée, et le fondu tombait alors sur sa dernière chip.
    final Widget row = Align(
      alignment: AlignmentDirectional.centerStart,
      // La hauteur reste celle des chips : seule la largeur s'étend.
      heightFactor: 1,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) SizedBox(width: gap),
              children[i],
            ],
          ],
        ),
      ),
    );

    if (fadeWidth <= 0) return row;

    return ShaderMask(
      // `dstIn` ne peint pas : il ne garde du contenu que l'alpha du dégradé.
      // Les deux couleurs ci-dessous sont donc un canal de transparence et
      // non des teintes — c'est la seule raison pour laquelle elles ne
      // viennent pas de `context.pdl`.
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        final double stop = bounds.width <= fadeWidth
            ? 0
            : 1 - fadeWidth / bounds.width;
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: <double>[0, stop, 1],
          colors: const <Color>[Colors.black, Colors.black, Colors.transparent],
        ).createShader(bounds);
      },
      child: row,
    );
  }
}
