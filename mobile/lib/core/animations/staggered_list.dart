import '../material.dart';
import '../theme/pdl_tokens.dart';

/// A widget that animates its child with a staggered entrance effect.
///
/// Each item slides up and fades in with a delay based on its index,
/// creating a ripple effect as items appear in sequence.
class StaggeredListItem extends StatefulWidget {
  /// The index of this item in the list (used for stagger timing).
  final int index;

  /// The child widget to animate.
  final Widget child;

  /// The delay between each item's animation start.
  final Duration staggerDelay;

  /// The duration of the animation.
  final Duration duration;

  /// The vertical offset to slide from (in pixels).
  final double slideOffset;

  /// Whether to animate on first build (default: true).
  final bool animate;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 250),
    this.slideOffset = 20,
    this.animate = true,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.animate) {
      // Start animation after staggered delay
      final delay = widget.staggerDelay * widget.index;
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      // Skip animation
      _controller.value = 1.0;
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

    if (reduceMotion) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// A ListView builder that automatically applies staggered entrance animations.
class StaggeredListView extends StatefulWidget {
  /// The number of items in the list.
  final int itemCount;

  /// Builder function for each item.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Optional padding around the list.
  final EdgeInsetsGeometry? padding;

  /// The delay between each item's animation start.
  final Duration staggerDelay;

  /// The duration of each item's animation.
  final Duration animationDuration;

  /// The physics for the scroll view.
  final ScrollPhysics? physics;

  /// Whether the list should shrink-wrap its content.
  final bool shrinkWrap;

  /// Optional scroll controller.
  final ScrollController? controller;

  const StaggeredListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animationDuration = const Duration(milliseconds: 250),
    this.physics,
    this.shrinkWrap = false,
    this.controller,
  });

  @override
  State<StaggeredListView> createState() => _StaggeredListViewState();
}

class _StaggeredListViewState extends State<StaggeredListView> {
  // Track if we've animated items to avoid re-animating on scroll
  final Set<int> _animatedIndices = {};

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.controller,
      padding: widget.padding,
      itemCount: widget.itemCount,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      itemBuilder: (context, index) {
        final shouldAnimate = !_animatedIndices.contains(index);
        if (shouldAnimate) {
          _animatedIndices.add(index);
        }
        return StaggeredListItem(
          index: index,
          staggerDelay: widget.staggerDelay,
          duration: widget.animationDuration,
          animate: shouldAnimate,
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}

/// A sliver version of StaggeredListView for use in CustomScrollView.
class StaggeredSliverList extends StatefulWidget {
  /// The number of items in the list.
  final int itemCount;

  /// Builder function for each item.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The delay between each item's animation start.
  final Duration staggerDelay;

  /// The duration of each item's animation.
  final Duration animationDuration;

  const StaggeredSliverList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animationDuration = const Duration(milliseconds: 250),
  });

  @override
  State<StaggeredSliverList> createState() => _StaggeredSliverListState();
}

class _StaggeredSliverListState extends State<StaggeredSliverList> {
  final Set<int> _animatedIndices = {};

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index >= widget.itemCount) return null;
        final shouldAnimate = !_animatedIndices.contains(index);
        if (shouldAnimate) {
          _animatedIndices.add(index);
        }
        return StaggeredListItem(
          index: index,
          staggerDelay: widget.staggerDelay,
          duration: widget.animationDuration,
          animate: shouldAnimate,
          child: widget.itemBuilder(context, index),
        );
      }, childCount: widget.itemCount),
    );
  }
}

/// A grid version of StaggeredListView for grid layouts.
class StaggeredGridView extends StatefulWidget {
  /// The number of items in the grid.
  final int itemCount;

  /// Builder function for each item.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// The grid delegate.
  final SliverGridDelegate gridDelegate;

  /// Optional padding around the grid.
  final EdgeInsetsGeometry? padding;

  /// The delay between each item's animation start.
  final Duration staggerDelay;

  /// The duration of each item's animation.
  final Duration animationDuration;

  /// The physics for the scroll view.
  final ScrollPhysics? physics;

  /// Whether the grid should shrink-wrap its content.
  final bool shrinkWrap;

  /// Whether this grid is the primary scroll view of its route.
  ///
  /// Pass false when nesting the grid inside another scrollable: otherwise it
  /// attaches a second position to the route's [PrimaryScrollController], which
  /// the iOS status bar tap would then animate alongside the real one.
  final bool? primary;

  const StaggeredGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.gridDelegate,
    this.padding,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animationDuration = const Duration(milliseconds: 250),
    this.physics,
    this.shrinkWrap = false,
    this.primary,
  });

  @override
  State<StaggeredGridView> createState() => _StaggeredGridViewState();
}

class _StaggeredGridViewState extends State<StaggeredGridView> {
  final Set<int> _animatedIndices = {};

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: widget.padding,
      gridDelegate: widget.gridDelegate,
      itemCount: widget.itemCount,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      primary: widget.primary,
      itemBuilder: (context, index) {
        final shouldAnimate = !_animatedIndices.contains(index);
        if (shouldAnimate) {
          _animatedIndices.add(index);
        }
        return StaggeredListItem(
          index: index,
          staggerDelay: widget.staggerDelay,
          duration: widget.animationDuration,
          animate: shouldAnimate,
          child: widget.itemBuilder(context, index),
        );
      },
    );
  }
}
