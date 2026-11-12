import 'dart:math' as math;

import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import 'pdl_blur_surface.dart';

/// C4 — La barre d'action basse.
///
/// `padding: 10 16 22`, fond `overlaySolid` + flou σ 12, bordure haute, une à
/// quatre actions. Elle se pose **sous** le contenu et **au-dessus** de la
/// barre d'onglets ; [PdlScreenScaffold] garantit cet ordre.
///
/// Les 22 px du bas de la maquette sont son inset système présumé. Sur un
/// appareil réel il vaut 34, ou zéro : la barre prend donc l'inset réel plus
/// ses 10 px de gouttière, avec 22 pour plancher — elle n'est jamais plus
/// serrée que la planche, jamais plus lâche que l'appareil.
///
/// [expand] répartit les actions à parts égales. Une action qui doit garder sa
/// largeur naturelle — un bouton icône, un prix — se passe de lui.
class PdlActionBar extends StatelessWidget {
  const PdlActionBar({
    super.key,
    required this.children,
    this.expand = true,
    this.gap = PdlSpacing.chipGap,
  }) : assert(
         children.length >= 1 && children.length <= 4,
         'La barre d\'action porte de 1 à 4 actions : au-delà, ce sont des '
         'réglages, et ils vont dans une feuille.',
       );

  final List<Widget> children;
  final bool expand;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final double inset = MediaQuery.viewPaddingOf(context).bottom;
    final double bottom = math.max(22, inset + PdlMetrics.toolbarPadding);

    return PdlBlurSurface(
      color: c.overlaySolid,
      sigma: PdlMotion.blurToolbar,
      border: Border(top: BorderSide(color: c.borderSubtle)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          PdlSpacing.section,
          PdlMetrics.toolbarPadding,
          PdlSpacing.section,
          bottom,
        ),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) SizedBox(width: gap),
              if (expand)
                Expanded(child: children[i])
              else
                Flexible(child: children[i]),
            ],
          ],
        ),
      ),
    );
  }
}
