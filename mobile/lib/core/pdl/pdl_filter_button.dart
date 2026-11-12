import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';

/// A20 — Bouton d'ouverture des filtres, 44 × 44, portant le nombre de filtres
/// actifs.
///
/// Le compteur n'est pas décoratif : en vue carte, les chips de filtres
/// disparaissent et **ce bouton devient le seul témoin** qu'une liste est
/// filtrée. Sans lui, une carte vide se lit comme « il n'y a rien ici » au lieu
/// de « vos filtres ne laissent rien passer ».
class PdlFilterButton extends StatelessWidget {
  const PdlFilterButton({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
    this.activeCount = 0,
    this.icon = PdlIcons.filter,
  });

  final VoidCallback? onPressed;

  /// Libellé d'accessibilité — `core/pdl` ne traduit rien.
  final String semanticLabel;

  final int activeCount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    final Widget button = Material(
      color: c.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: PdlRadii.mdAll,
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: PdlRadii.mdAll,
        child: SizedBox(
          width: PdlMetrics.tapTarget,
          height: PdlMetrics.tapTarget,
          child: Icon(icon, size: 20, color: c.text),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: semanticLabel,
      value: activeCount > 0 ? '$activeCount' : null,
      child: activeCount > 0
          ? Badge.count(
              count: activeCount,
              backgroundColor: c.primary,
              textColor: c.onPrimary,
              child: button,
            )
          : button,
    );
  }
}
