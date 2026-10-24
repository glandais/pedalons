import 'package:flutter/material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';

/// Un tronçon de [PdlSegmentBar] : une longueur relative et sa teinte.
@immutable
class PdlSegmentBarEntry {
  const PdlSegmentBarEntry({required this.extent, required this.color});

  /// Longueur du tronçon, dans n'importe quelle unité commune à toute la
  /// barre (mètres le long d'un parcours, d'ordinaire). Une valeur nulle ou
  /// négative ne prend aucune place.
  final double extent;

  final Color color;
}

/// Une barre horizontale découpée en tronçons proportionnels à leur longueur.
///
/// Sert au vent le long d'un parcours (un tronçon par segment, teinté face /
/// travers / dos) comme à l'exposition cumulée (trois tronçons). Rayon pilule,
/// fond `neutralSoft` quand il n'y a rien à montrer.
///
/// Ne porte aucun texte et **ne doit pas être seule** : la couleur ne suffit
/// pas à dire le vent (charte, `RelativeWind` toujours doublé du libellé). Le
/// [semanticLabel] résume la barre pour un lecteur d'écran — l'appelant y
/// met ce que la légende voisine affiche.
class PdlSegmentBar extends StatelessWidget {
  const PdlSegmentBar({
    super.key,
    required this.entries,
    this.height = PdlMetrics.segmentBar,
    this.semanticLabel,
  });

  final List<PdlSegmentBarEntry> entries;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final double total = entries.fold<double>(
      0,
      (double sum, PdlSegmentBarEntry e) => sum + (e.extent > 0 ? e.extent : 0),
    );

    // Le rayon pilule est borné à la demi-hauteur : un `ClipRRect` de rayon
    // `PdlRadii.pill` (1000) sur 8 pt n'est pas dessiné par Impeller sur iOS,
    // qui laisse à la place des traînées sous la carte.
    final Widget bar = ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(height / 2)),
      child: SizedBox(
        height: height,
        child: total <= 0
            ? ColoredBox(color: c.neutralSoft)
            // `Expanded` au pour-mille plutôt que des largeurs calculées : la
            // somme de largeurs flottantes dépasse parfois la boîte d'un
            // epsilon, ce qu'une `Row` signale comme un débordement.
            : Row(
                children: <Widget>[
                  for (final PdlSegmentBarEntry e in entries)
                    if (e.extent > 0)
                      Expanded(
                        flex: (e.extent / total * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: e.color),
                      ),
                ],
              ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      container: semanticLabel != null,
      child: ExcludeSemantics(child: bar),
    );
  }
}
