import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_typography.dart';
import 'pdl_card.dart';

/// Une cellule de [PdlStatCellRow].
@immutable
class PdlStatCell {
  const PdlStatCell({
    required this.value,
    required this.label,
    this.onTap,
    this.semanticLabel,
  });

  /// Valeur déjà formatée — 17/600.
  final String value;

  final String label;

  /// Rend la cellule cliquable et lui ajoute un chevron.
  final VoidCallback? onTap;

  final String? semanticLabel;
}

/// B14 — Rangée de cellules chiffrées dans une carte plate.
///
/// `PdlCard(flat)`, cellules `Expanded` de largeur égale séparées d'un filet
/// vertical. Les cellules cliquables portent un chevron : sans lui, rien ne
/// distingue « 12 sorties à venir » — un lien — de « 340 km » — un chiffre.
class PdlStatCellRow extends StatelessWidget {
  const PdlStatCellRow({super.key, required this.cells});

  final List<PdlStatCell> cells;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    return PdlCard(
      flat: true,
      padding: PdlCardPadding.none,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < cells.length; i++) ...<Widget>[
              if (i > 0)
                VerticalDivider(width: 1, thickness: 1, color: c.borderSubtle),
              Expanded(child: _Cell(cell: cells[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final PdlStatCell cell;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  cell.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.statBigValue,
                ),
              ),
              if (cell.onTap != null)
                Icon(PdlIcons.chevronRight, size: 16, color: c.textPlaceholder),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            cell.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.xs,
          ),
        ],
      ),
    );

    if (cell.onTap == null) return content;
    return Semantics(
      button: true,
      label: cell.semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: cell.onTap, child: content),
      ),
    );
  }
}
