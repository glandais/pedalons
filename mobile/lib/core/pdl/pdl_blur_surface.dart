import 'dart:ui' as ui;

import '../material.dart';

import '../theme/pdl_tokens.dart';

/// A19 — Surface floutée : `ClipRect` + `BackdropFilter`.
///
/// **Coûteux. Interdit dans une liste défilante.** Un `BackdropFilter`
/// déclenche une passe de rendu hors écran à chaque image ; multiplié par les
/// éléments visibles d'un `ListView`, il fait chuter le défilement sous les
/// 60 fps sur un appareil d'entrée de gamme. Son emploi est réservé aux
/// surfaces **fixes et peu nombreuses** :
///
/// * les barres épinglées — `PdlPinnedToolbar`, `PdlActionBar`, `PdlBottomTabs` ;
/// * les boutons posés sur une carte (σ 6 au lieu de σ 12).
///
/// Le `ClipRect` n'est pas optionnel : sans lui, le filtre s'applique à tout
/// l'arbre au-dessus et non à la seule boîte.
class PdlBlurSurface extends StatelessWidget {
  const PdlBlurSurface({
    super.key,
    required this.child,
    required this.color,
    this.sigma = PdlMotion.blurToolbar,
    this.borderRadius,
    this.border,
  });

  final Widget child;

  /// Voile posé au-dessus du flou : `overlay` (barre d'onglets) ou
  /// `overlaySolid` (barres d'outils et d'action).
  final Color color;

  final double sigma;
  final BorderRadius? borderRadius;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}
