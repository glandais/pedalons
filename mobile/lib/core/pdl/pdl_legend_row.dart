import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_typography.dart';
import 'pdl_color_track.dart';

/// Une entrée de légende : une couleur de tracé et son nom.
@immutable
class PdlLegendEntry {
  const PdlLegendEntry({required this.color, required this.label, this.onTap});

  /// Couleur issue de `kMultiTrackPalette`, jamais d'une teinte de rôle.
  final Color color;

  final String label;
  final VoidCallback? onTap;
}

/// B12 — Légende de tracés, défilante horizontalement.
///
/// Le trait fait 14 × 3 ([PdlColorTrackShape.legend]) : c'est le même objet
/// que le rappel de 4 × 20 posé devant un titre de groupe, à l'orientation
/// près. L'entrée active passe en `text` et 600 — la couleur seule ne suffit
/// pas à dire « c'est celui-ci que vous regardez ».
class PdlLegendRow extends StatelessWidget {
  const PdlLegendRow({
    super.key,
    required this.entries,
    this.activeIndex,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.gap = 12,
  });

  final List<PdlLegendEntry> entries;
  final int? activeIndex;
  final EdgeInsetsGeometry padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < entries.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: gap),
            _Entry(
              entry: entries[i],
              active: activeIndex == i,
              style: activeIndex == i
                  ? t.xs.copyWith(color: c.text, fontWeight: FontWeight.w600)
                  : t.xs,
            ),
          ],
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.entry,
    required this.active,
    required this.style,
  });

  final PdlLegendEntry entry;
  final bool active;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PdlColorTrack(color: entry.color, shape: PdlColorTrackShape.legend),
        const SizedBox(width: 6),
        Text(entry.label, maxLines: 1, style: style),
      ],
    );

    if (entry.onTap == null) return content;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: entry.onTap,
        // 12 px de haut de part et d'autre : la légende reste fine à l'œil,
        // la zone de geste tient dans les 44 px du contrat.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: content,
        ),
      ),
    );
  }
}
