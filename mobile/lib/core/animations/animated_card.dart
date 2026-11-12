import '../material.dart';

import '../pdl/pdl_card.dart';
import '../theme/pdl_tokens.dart';

/// A card widget with tap feedback animation.
///
/// Provides a subtle scale-down effect (0.98x) when pressed,
/// making the app feel more responsive.
///
/// Façade historique au-dessus de [PdlCard], qui porte désormais l'unique
/// implémentation de l'échelle au press et du respect de
/// `PdlMotion.reducedOf`. Les nouveaux écrans emploient [PdlCard]
/// directement : il sait aussi rendre les variantes `selected` et `flat`.
class AnimatedCard extends StatelessWidget {
  /// The child widget to wrap.
  final Widget child;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Called when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// The border radius for the ink ripple effect.
  final BorderRadius borderRadius;

  /// The duration of the scale animation.
  final Duration duration;

  /// The scale factor when pressed (default: 0.98).
  final double pressedScale;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = PdlRadii.cardAll,
    this.duration = const Duration(milliseconds: 100),
    this.pressedScale = 0.98,
  });

  @override
  Widget build(BuildContext context) {
    return PdlCard(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius,
      pressDuration: duration,
      pressedScale: pressedScale,
      // Les appelants historiques posent leur propre `Padding` dans [child].
      padding: PdlCardPadding.none,
      child: child,
    );
  }
}
