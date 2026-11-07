import 'package:flutter/material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Une cellule de bloc méta : libellé en `xs`, valeur en `statBigValue`
/// (précédée d'une icône quand il y en a une), puis ce qui la complète
/// ([extra]). Le schéma partagé du détail d'une sortie, des chiffres d'un
/// groupe et de la synthèse d'un voyage (ledger `MOB-113`).
class PdlMetaCell extends StatelessWidget {
  const PdlMetaCell({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.extra = const <Widget>[],
  });

  final String label;
  final String value;
  final IconData? icon;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final Widget valueText = Text(value, style: t.statBigValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: t.xs),
        const SizedBox(height: 2),
        if (icon == null)
          valueText
        else
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: c.textDimmed),
              const SizedBox(width: 5),
              Flexible(child: valueText),
            ],
          ),
        ...extra,
      ],
    );
  }
}

/// La grille d'un bloc méta : deux colonnes tant qu'une colonne reste
/// lisible (320 px de large, texte agrandi d'au plus 18/14), une seule
/// au-delà — plutôt que des cellules écrasées.
///
/// [columnInset] retranche une marge à chaque colonne : le détail d'une sortie
/// et les chiffres d'un groupe retiraient `PdlSpacing.card` de leur demi-
/// largeur, la synthèse d'un voyage rien. Gardé tel quel pour ne pas changer
/// leur rendu en les factorisant.
class PdlMetaGrid extends StatelessWidget {
  const PdlMetaGrid({super.key, required this.cells, this.columnInset = 0});

  final List<Widget> cells;
  final double columnInset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumns =
            constraints.maxWidth >= 320 &&
            MediaQuery.textScalerOf(context).scale(14) <= 18;
        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < cells.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: PdlSpacing.meta2V),
                cells[i],
              ],
            ],
          );
        }
        return Wrap(
          spacing: PdlSpacing.meta2H,
          runSpacing: PdlSpacing.meta2V,
          children: <Widget>[
            for (final Widget cell in cells)
              SizedBox(
                width:
                    (constraints.maxWidth - PdlSpacing.meta2H) / 2 -
                    columnInset,
                child: cell,
              ),
          ],
        );
      },
    );
  }
}
