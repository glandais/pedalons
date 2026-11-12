import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';

/// Les trois corps de carte de la charte : `.cb` (16), `.cb--t` (12), aucun.
enum PdlCardPadding {
  /// Aucun rembourrage : la carte porte un bandeau média ou une liste qui
  /// gère le sien.
  none,

  /// `.cb--t` — 12 px.
  tight,

  /// `.cb` — 16 px.
  normal,
}

/// A5 — La carte de la charte.
///
/// Rayon 12 (le seul endroit où ce rayon est employé), bordure 1 px
/// `borderSubtle`, **aucune ombre** : c'est la bordure qui sépare les surfaces,
/// dans les deux modes. `selected` passe la bordure à 2 px `primary`, `flat`
/// remplace la bordure par le fond `surfaceAlt`.
///
/// Quand [onTap] ou [onLongPress] est fourni, la carte reprend l'échelle 0.98
/// au press héritée de `core/animations/animated_card.dart`, et **respecte
/// `PdlMotion.reducedOf`** : c'est la même implémentation, `AnimatedCard`
/// n'est plus qu'une façade au-dessus de celle-ci.
class PdlCard extends StatefulWidget {
  const PdlCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.flat = false,
    this.padding = PdlCardPadding.normal,
    this.borderRadius = PdlRadii.cardAll,
    this.pressedScale = 0.98,
    this.pressDuration = const Duration(milliseconds: 100),
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Bordure 2 px `primary` — carte de groupe choisie, parcours pointé sur la
  /// carte.
  final bool selected;

  /// Fond `surfaceAlt` sans bordure — blocs de statistiques, encarts internes.
  final bool flat;

  final PdlCardPadding padding;
  final BorderRadius borderRadius;
  final double pressedScale;
  final Duration pressDuration;
  final Clip clipBehavior;

  @override
  State<PdlCard> createState() => _PdlCardState();
}

class _PdlCardState extends State<PdlCard> {
  bool _pressed = false;

  bool get _tappable => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  EdgeInsets get _insets => switch (widget.padding) {
    PdlCardPadding.none => EdgeInsets.zero,
    PdlCardPadding.tight => const EdgeInsets.all(PdlSpacing.cardTight),
    PdlCardPadding.normal => const EdgeInsets.all(PdlSpacing.card),
  };

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    final BorderSide side = widget.selected
        ? BorderSide(color: c.primary, width: 2)
        : (widget.flat ? BorderSide.none : BorderSide(color: c.borderSubtle));

    Widget card = Material(
      color: widget.flat ? c.surfaceAlt : c.surface,
      // `elevation: 0` n'est pas un oubli : la charte n'a pas d'ombre de carte.
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: widget.borderRadius,
        side: side,
      ),
      clipBehavior: widget.clipBehavior,
      child: _tappable
          ? InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              borderRadius: widget.borderRadius,
              child: Padding(padding: _insets, child: widget.child),
            )
          : Padding(padding: _insets, child: widget.child),
    );

    if (!_tappable) return card;

    final bool reduceMotion = PdlMotion.reducedOf(context);
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? widget.pressedScale : 1.0,
        duration: reduceMotion ? Duration.zero : widget.pressDuration,
        curve: Curves.easeInOut,
        child: card,
      ),
    );
  }
}
