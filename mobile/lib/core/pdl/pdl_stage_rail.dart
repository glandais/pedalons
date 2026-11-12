import 'package:scroll_to_index/scroll_to_index.dart';

import '../material.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Une pastille du rail : une étiquette courte, un nom facultatif.
@immutable
class PdlStageRailItem {
  const PdlStageRailItem({required this.label, this.sublabel});

  /// Ligne haute : « Aperçu », « J1 », « J2 ».
  final String label;

  /// Ligne basse : le nom de l'étape. Tronqué si besoin — voir
  /// [PdlStageRail.maxSublabelCharacters].
  final String? sublabel;
}

/// C9 — Le rail de navigation frère-à-frère.
///
/// Une rangée horizontale de pastilles bi-ligne, à épingler sous la barre
/// supérieure avec [PdlPinnedToolbar]. Elle sert aux étapes d'un voyage, où
/// naviguer d'une étape à l'autre par « retour puis nouvelle étape » coûte deux
/// gestes et une page de chargement.
///
/// **La pastille active est recentrée automatiquement** (`scroll_to_index`,
/// [AutoScrollPosition.middle]) : sur un voyage de sept étapes, arriver sur la
/// J6 sans recentrage donne un rail qui commence à J1, c'est-à-dire un rail qui
/// ne montre pas où l'on est.
///
/// **La troncature passe par `characters`, jamais par `substring`.**
/// `substring` compte des unités UTF-16 : il coupe « Saint-Étienne » au milieu
/// d'un accent composé et un emoji en deux moitiés, et rend un caractère de
/// remplacement. `characters` compte des *clusters de graphèmes*, ce que
/// l'utilisateur appelle une lettre.
class PdlStageRail extends StatefulWidget {
  const PdlStageRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.maxSublabelCharacters = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
  });

  final List<PdlStageRailItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Longueur maximale du nom, en clusters de graphèmes.
  final int maxSublabelCharacters;

  final EdgeInsetsGeometry padding;

  /// Tronque à [max] clusters de graphèmes, en ajoutant une ellipse.
  ///
  /// Exposée pour le test : c'est la règle qu'on veut voir tenir sur un nom
  /// accentué et sur un emoji.
  static String truncate(String value, int max) {
    final Characters graphemes = value.characters;
    if (graphemes.length <= max) return value;
    return '${graphemes.take(max)}…';
  }

  @override
  State<PdlStageRail> createState() => _PdlStageRailState();
}

class _PdlStageRailState extends State<PdlStageRail> {
  late final AutoScrollController _controller = AutoScrollController(
    axis: Axis.horizontal,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center());
  }

  @override
  void didUpdateWidget(PdlStageRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _center();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _center() {
    if (!mounted || !_controller.hasClients) return;
    if (widget.selectedIndex < 0 ||
        widget.selectedIndex >= widget.items.length) {
      return;
    }
    _controller.scrollToIndex(
      widget.selectedIndex,
      preferPosition: AutoScrollPosition.middle,
      duration: PdlMotion.stateChange,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Comme la rangée de chips : un défileur sur une `Row`, jamais un
    // `ListView` horizontal — celui-ci exigerait une hauteur bornée, et la
    // hauteur est justement ce qui doit rester mesurée.
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: PdlMetrics.stageRail),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < widget.items.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: PdlSpacing.chipGap),
              AutoScrollTag(
                key: ValueKey<int>(i),
                controller: _controller,
                index: i,
                child: _StagePill(
                  item: widget.items[i],
                  selected: i == widget.selectedIndex,
                  maxSublabelCharacters: widget.maxSublabelCharacters,
                  onTap: () => widget.onSelected(i),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({
    required this.item,
    required this.selected,
    required this.maxSublabelCharacters,
    required this.onTap,
  });

  final PdlStageRailItem item;
  final bool selected;
  final int maxSublabelCharacters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final Color foreground = selected ? c.onPrimary : c.textDimmed;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(minHeight: PdlMetrics.tapTarget),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? c.primary : null,
              borderRadius: PdlRadii.pillAll,
              border: Border.all(color: selected ? c.primary : c.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  item.label,
                  maxLines: 1,
                  style: t.count.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.sublabel != null)
                  Text(
                    PdlStageRail.truncate(
                      item.sublabel!,
                      maxSublabelCharacters,
                    ),
                    maxLines: 1,
                    style: t.xs.copyWith(color: foreground),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
