import '../material.dart';
import '../theme/pdl_tokens.dart';

/// A widget that adds a gentle floating animation to empty state icons.
///
/// Creates a subtle up/down movement that makes empty states feel more
/// alive and inviting rather than static.
class AnimatedEmptyState extends StatefulWidget {
  /// The child widget (typically an icon) to animate.
  final Widget child;

  /// The vertical movement range in pixels.
  final double floatOffset;

  /// The duration of one complete float cycle (up and down).
  final Duration duration;

  /// Whether to enable the animation (default: true).
  final bool animate;

  const AnimatedEmptyState({
    super.key,
    required this.child,
    this.floatOffset = 8.0,
    this.duration = const Duration(seconds: 2),
    this.animate = true,
  });

  @override
  State<AnimatedEmptyState> createState() => _AnimatedEmptyStateState();
}

class _AnimatedEmptyStateState extends State<AnimatedEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _animation = Tween<double>(
      begin: 0,
      end: widget.floatOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedEmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect user's motion preferences
    final reduceMotion = PdlMotion.reducedOf(context);

    if (reduceMotion || !widget.animate) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
