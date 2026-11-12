import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// A11 — Chip de filtre, de portée ou de tri.
///
/// **La pastille mesure 34 px, la cible tactile 44.** C'est le compromis que la
/// maquette écrit noir sur blanc (`.chip::after` déborde de 5 px en haut et en
/// bas) : une barre de chips de 44 px de haut serait deux fois trop lourde en
/// tête d'écran, mais un doigt ne vise pas 34 px. Le widget rend donc une
/// pastille de 34 centrée dans une boîte de [PdlMetrics.tapTarget].
///
/// C'est aussi la raison pour laquelle `chipTheme` n'existe pas dans le thème :
/// un `Chip` Material mesure 48 px et impose sa forme.
///
/// Trois états : inactif (contour `border`, texte `textDimmed`), actif
/// (`primarySoft` / `primaryOnSoft` / 600), et la variante [sortStyle] au
/// contour `text` qui distingue le sélecteur de portée des filtres.
/// [onRemoved] ajoute la croix de retrait, et **toute la pastille** devient
/// alors la cible du retrait : viser une croix de 16 px dans une chip de 34
/// est hors de portée d'un pouce, et une chip retirable n'a pas d'autre action.
class PdlChip extends StatelessWidget {
  const PdlChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemoved,
    this.icon,
    this.trailingIcon,
    this.sortStyle = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Rend la croix de retrait et l'action associée.
  final VoidCallback? onRemoved;

  final IconData? icon;

  /// Une icône après le libellé — le chevron d'une chip qui ouvre une feuille
  /// de choix (la portée). Ignorée quand [onRemoved] pose sa croix.
  final IconData? trailingIcon;

  /// Contour `text` : sélecteur de portée ou de tri, à distinguer des filtres.
  final bool sortStyle;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final Color foreground = selected
        ? c.primaryOnSoft
        : (sortStyle ? c.text : c.textDimmed);
    final TextStyle style = (selected ? t.chipActive : t.chip).copyWith(
      color: foreground,
    );

    final Widget pill = Container(
      height: PdlMetrics.chipVisual,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? c.primarySoft : null,
        borderRadius: PdlRadii.pillAll,
        border: selected
            ? null
            : Border.all(color: sortStyle ? c.text : c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (onRemoved != null) ...<Widget>[
            const SizedBox(width: 6),
            Icon(PdlIcons.remove, size: 16, color: foreground),
          ] else if (trailingIcon != null) ...<Widget>[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 16, color: foreground),
          ],
        ],
      ),
    );

    final VoidCallback? action = onRemoved ?? onTap;
    // Les 5 px au-dessus et au-dessous de la pastille font partie de la cible :
    // sans ce détecteur, seul l'`InkWell` de la pastille répondrait, et la
    // cible réelle retomberait à 34 px. Un toucher sur la pastille, lui, reste
    // à l'`InkWell` (le détecteur le plus profond gagne) et garde son effet.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: action,
      child: SizedBox(
        height: PdlMetrics.tapTarget,
        child: Center(
          child: Semantics(
            button: action != null,
            selected: selected,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: action,
                borderRadius: PdlRadii.pillAll,
                child: pill,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
