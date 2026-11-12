import '../material.dart';

import '../theme/enum_colors.dart' show PdlTone;
import '../theme/pdl_colors.dart';
import '../theme/pdl_typography.dart';
import 'pdl_badge.dart';

/// Une colonne chiffrée d'une ligne de montée : longueur, dénivelé, pente
/// moyenne. La valeur est déjà **formatée par l'appelant** (unités comprises).
@immutable
class PdlClimbFigure {
  const PdlClimbFigure({required this.value, required this.label});

  final String value;
  final String label;
}

/// B13 — Ligne de montée répertoriée.
///
/// Badge **plein** de catégorie (seule série de la charte rendue en aplat), nom
/// de la montée, plage kilométrique, puis trois colonnes chiffrées.
///
/// Au-delà de `textScaler.scale(14) > 17`, les trois colonnes ne tiennent plus
/// à droite d'un nom : elles passent en [Wrap] sous le nom. Une pente moyenne
/// tronquée ne veut rien dire.
class PdlClimbRow extends StatelessWidget {
  const PdlClimbRow({
    super.key,
    required this.categoryLabel,
    required this.categoryTone,
    required this.name,
    this.range,
    this.figures = const <PdlClimbFigure>[],
    this.onTap,
    this.showDivider = true,
  });

  /// Libellé de catégorie — « HC », « Cat. 1 ». Traduit par l'écran.
  final String categoryLabel;

  /// Teinte de la catégorie, dont le [PdlTone.filledStyle] vaut vrai.
  final PdlTone categoryTone;

  final String name;

  /// « 12,4 → 18,1 km », déjà formaté.
  final String? range;

  final List<PdlClimbFigure> figures;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool scaled = MediaQuery.textScalerOf(context).scale(14) > 17;

    final Widget identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.bodyStrong,
        ),
        if (range != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(range!, style: t.mono),
        ],
      ],
    );

    final List<Widget> columns = <Widget>[
      for (final PdlClimbFigure f in figures)
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(f.value, style: t.statValue),
            Text(f.label, style: t.xs),
          ],
        ),
    ];

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              PdlBadge(
                label: categoryLabel,
                tone: categoryTone,
                filled: true,
                size: PdlBadgeSize.lg,
              ),
              const SizedBox(width: 10),
              Expanded(child: identity),
              if (!scaled && columns.isNotEmpty) ...<Widget>[
                const SizedBox(width: 10),
                for (int i = 0; i < columns.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 12),
                  columns[i],
                ],
              ],
            ],
          ),
          if (scaled && columns.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(spacing: 16, runSpacing: 4, children: columns),
          ],
        ],
      ),
    );

    final Widget body = onTap == null
        ? content
        : Semantics(
            button: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, child: content),
            ),
          );

    if (!showDivider) return body;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: body,
    );
  }
}
