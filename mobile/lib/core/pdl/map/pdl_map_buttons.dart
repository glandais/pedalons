/// Les voiles de lisibilité d'une carte (brief §5, plan §1.3.2).
///
/// Règle absolue et non négociable : **jamais de texte posé directement sur une
/// tuile**. Une tuile claire un jour d'été et un libellé gris, et il n'y a plus
/// de libellé ; une tuile satellite et un libellé noir, pareil. Tout ce qui
/// s'écrit au-dessus d'une carte passe donc par l'un des quatre composants de
/// ce fichier, tous adossés à `PdlColors.overlaySolid` (95 % d'opacité) et
/// bordés.
///
/// `PdlScrim` (vague A) complète le jeu pour les bords haut et bas.
library;

import '../../material.dart';

import '../../theme/pdl_colors.dart';
import '../../theme/pdl_tokens.dart';
import '../../theme/pdl_typography.dart';
import '../pdl_blur_surface.dart';

/// Bouton de carte — 44 × 44 sur `overlaySolid`.
///
/// La taille n'est pas négociable : c'est la cible tactile du brief §5, et un
/// bouton de carte est justement celui qu'on presse en roulant, d'une main.
class PdlMapButton extends StatelessWidget {
  const PdlMapButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Libellé d'accessibilité déjà localisé — `core/pdl` ne traduit rien.
  final String semanticLabel;

  /// Rend l'état actif d'une bascule (plein écran engagé, « autour de moi »
  /// armé).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: PdlBlurSurface(
        // σ 6 et non 12 : un bouton de carte est petit et nombreux, le flou
        // large des barres épinglées y coûterait sans se voir.
        sigma: PdlMotion.blurOverlayButton,
        color: selected ? c.primarySoft : c.overlaySolid,
        borderRadius: PdlRadii.mdAll,
        border: Border.all(color: c.borderSubtle),
        child: SizedBox(
          width: PdlMetrics.tapTarget,
          height: PdlMetrics.tapTarget,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              borderRadius: PdlRadii.mdAll,
              child: Icon(
                icon,
                size: 20,
                color: selected ? c.primaryOnSoft : c.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La colonne de boutons posée à droite d'une carte (`.mapbtns`).
class PdlMapButtonColumn extends StatelessWidget {
  const PdlMapButtonColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: PdlSpacing.chipGap),
          children[i],
        ],
      ],
    );
  }
}

/// Pilule opaque posée sur une carte (`.mappill`) — 14/600.
///
/// « Rechercher dans cette zone », « 12 parcours ici ». Quand [onPressed] est
/// fourni, la pilule reste visuellement compacte mais sa cible tactile est
/// portée à 44 px, comme la pastille de `PdlChip`.
class PdlMapPill extends StatelessWidget {
  const PdlMapPill({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.onPressed,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;

  /// Élément de tête quand une icône ne suffit pas — le trait de rappel de
  /// couleur du tracé sélectionné, sur la carte d'une sortie. Prime sur [icon].
  final Widget? leading;

  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: 6),
          ] else if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: c.text),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.pdlText.chipActive.copyWith(color: c.text),
            ),
          ),
        ],
      ),
    );

    final Widget pill = PdlBlurSurface(
      sigma: PdlMotion.blurOverlayButton,
      color: c.overlaySolid,
      borderRadius: PdlRadii.pillAll,
      border: Border.all(color: c.borderSubtle),
      child: onPressed == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onPressed,
                borderRadius: PdlRadii.pillAll,
                child: content,
              ),
            ),
    );

    if (onPressed == null) {
      return Semantics(label: semanticLabel ?? label, child: pill);
    }

    // Le visuel reste à ~32 px ; la cible, elle, ne descend jamais sous 44.
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: SizedBox(
        height: PdlMetrics.tapTarget,
        child: Center(child: pill),
      ),
    );
  }
}

/// Carte flottante posée en bas d'une carte (`.fcard`), à la sélection d'un
/// tracé.
///
/// Opaque et floutée : c'est la seule façon de poser un titre et des
/// statistiques au-dessus d'une tuile sans jouer la lisibilité aux dés.
class PdlMapFloatingCard extends StatelessWidget {
  const PdlMapFloatingCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(10),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final Widget body = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: PdlRadii.cardAll,
        boxShadow: PdlShadows.sheet,
      ),
      child: PdlBlurSurface(
        color: c.overlaySolid,
        borderRadius: PdlRadii.cardAll,
        border: Border.all(color: c.borderSubtle),
        child: onTap == null
            ? body
            : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: PdlRadii.cardAll,
                  child: body,
                ),
              ),
      ),
    );
  }
}
