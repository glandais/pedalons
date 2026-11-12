import '../material.dart';

import '../pdl/pdl_skeleton.dart';
import '../theme/pdl_tokens.dart';

/// A shimmer animation placeholder for loading states.
///
/// Creates a gradient animation that sweeps across the widget,
/// providing a more polished loading experience than a spinner.
///
/// Façade historique au-dessus de [PdlSkeleton], qui porte désormais l'unique
/// implémentation du scintillement — dégradé `neutralSoft → disabledBg`,
/// 1400 ms, coupé par `PdlMotion.reducedOf`. Les nouveaux écrans
/// emploient [PdlSkeleton] directement.
class ShimmerPlaceholder extends StatelessWidget {
  /// The width of the shimmer placeholder.
  final double? width;

  /// The height of the shimmer placeholder.
  final double? height;

  /// The border radius of the shimmer placeholder.
  final BorderRadius borderRadius;

  /// Optional child widget to use as a template (e.g., an icon shape).
  final Widget? child;

  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius = PdlRadii.mdAll,
    this.child,
  });

  /// Creates a circular shimmer placeholder (for avatars).
  const ShimmerPlaceholder.circle({
    super.key,
    required double radius,
    this.child,
  }) : width = radius * 2,
       height = radius * 2,
       borderRadius = PdlRadii.pillAll;

  /// Creates a text-line shimmer placeholder.
  const ShimmerPlaceholder.text({
    super.key,
    required this.width,
    double? height,
  }) : height = height ?? 14,
       borderRadius = PdlRadii.smAll,
       child = null;

  @override
  Widget build(BuildContext context) {
    return PdlSkeleton(
      width: width,
      height: height,
      borderRadius: borderRadius,
      child: child,
    );
  }
}

/// A card-shaped shimmer placeholder.
class ShimmerCard extends StatelessWidget {
  /// The height of the card.
  final double height;

  /// Optional padding inside the card.
  final EdgeInsetsGeometry padding;

  const ShimmerCard({
    super.key,
    this.height = 80,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            const ShimmerPlaceholder.circle(radius: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerPlaceholder.text(width: 150, height: 16),
                  const SizedBox(height: 8),
                  ShimmerPlaceholder.text(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A list of shimmer card placeholders.
class ShimmerCardList extends StatelessWidget {
  /// The number of shimmer cards to display.
  final int itemCount;

  /// The padding around each card.
  final EdgeInsetsGeometry padding;

  /// The height of each card.
  final double cardHeight;

  const ShimmerCardList({
    super.key,
    this.itemCount = 3,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.cardHeight = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: padding,
          child: ShimmerCard(height: cardHeight),
        ),
      ),
    );
  }
}

/// An event card shimmer placeholder (for home/calendar pages).
class ShimmerEventCard extends StatelessWidget {
  const ShimmerEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Date badge placeholder
            ShimmerPlaceholder(
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 12),
            // Event info placeholder
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerPlaceholder.text(width: 180, height: 16),
                  const SizedBox(height: 6),
                  ShimmerPlaceholder.text(width: 120, height: 12),
                ],
              ),
            ),
            // Icon placeholder
            const ShimmerPlaceholder.circle(radius: 12),
          ],
        ),
      ),
    );
  }
}

/// A team card shimmer placeholder.
class ShimmerTeamCard extends StatelessWidget {
  const ShimmerTeamCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const ShimmerPlaceholder.circle(radius: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerPlaceholder.text(width: 140, height: 18),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const ShimmerPlaceholder.circle(radius: 8),
                      const SizedBox(width: 4),
                      ShimmerPlaceholder.text(width: 80, height: 12),
                    ],
                  ),
                ],
              ),
            ),
            const ShimmerPlaceholder.circle(radius: 12),
          ],
        ),
      ),
    );
  }
}

/// A route grid item shimmer placeholder.
class ShimmerRouteGridItem extends StatelessWidget {
  const ShimmerRouteGridItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail placeholder
          const Expanded(
            flex: 3,
            child: ShimmerPlaceholder(
              width: double.infinity,
              borderRadius: BorderRadius.zero,
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShimmerPlaceholder.text(width: 120, height: 14),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ShimmerPlaceholder.text(width: 60, height: 10),
                      const SizedBox(width: 12),
                      ShimmerPlaceholder.text(width: 60, height: 10),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A team chip shimmer placeholder.
class ShimmerTeamChip extends StatelessWidget {
  const ShimmerTeamChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ShimmerPlaceholder.circle(radius: 20),
            const SizedBox(height: 8),
            ShimmerPlaceholder.text(width: 60, height: 12),
          ],
        ),
      ),
    );
  }
}
