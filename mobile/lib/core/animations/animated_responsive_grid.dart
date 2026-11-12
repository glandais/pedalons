import '../adaptive/breakpoints.dart';
import '../material.dart';
import 'staggered_list.dart';

/// A responsive grid with staggered entrance animations.
///
/// This widget combines the responsive behavior of ResponsiveGrid
/// with staggered fade+slide animations for list items.
class AnimatedResponsiveGrid extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final double childAspectRatio;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final Duration staggerDelay;
  final Duration animationDuration;

  const AnimatedResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 12,
    this.childAspectRatio = 1.0,
    this.controller,
    this.physics,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animationDuration = const Duration(milliseconds: 250),
  });

  @override
  State<AnimatedResponsiveGrid> createState() => _AnimatedResponsiveGridState();
}

class _AnimatedResponsiveGridState extends State<AnimatedResponsiveGrid> {
  // Track which indices have been animated
  final Set<int> _animatedIndices = {};

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = Breakpoints.getWindowSizeClass(constraints.maxWidth);
        final columns = Breakpoints.gridColumns(sizeClass);

        if (columns == 1) {
          // Use ListView for single column (better performance)
          return ListView.separated(
            controller: widget.controller,
            physics: widget.physics,
            padding: widget.padding,
            itemCount: widget.itemCount,
            separatorBuilder: (_, _) => SizedBox(height: widget.spacing),
            itemBuilder: (context, index) => _buildAnimatedItem(context, index),
          );
        }

        // Use GridView for multiple columns
        return GridView.builder(
          controller: widget.controller,
          physics: widget.physics,
          padding: widget.padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: widget.spacing,
            mainAxisSpacing: widget.spacing,
            childAspectRatio: widget.childAspectRatio,
          ),
          itemCount: widget.itemCount,
          itemBuilder: (context, index) => _buildAnimatedItem(context, index),
        );
      },
    );
  }

  Widget _buildAnimatedItem(BuildContext context, int index) {
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
  }
}

/// A responsive sliver grid with staggered entrance animations.
class AnimatedResponsiveSliverGrid extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double spacing;
  final double childAspectRatio;
  final Duration staggerDelay;
  final Duration animationDuration;

  const AnimatedResponsiveSliverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 12,
    this.childAspectRatio = 1.0,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animationDuration = const Duration(milliseconds: 250),
  });

  @override
  State<AnimatedResponsiveSliverGrid> createState() =>
      _AnimatedResponsiveSliverGridState();
}

class _AnimatedResponsiveSliverGridState
    extends State<AnimatedResponsiveSliverGrid> {
  final Set<int> _animatedIndices = {};

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sizeClass = Breakpoints.getWindowSizeClass(width);
    final columns = Breakpoints.gridColumns(sizeClass);

    if (columns == 1) {
      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final shouldAnimate = !_animatedIndices.contains(index);
          if (shouldAnimate) {
            _animatedIndices.add(index);
          }
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < widget.itemCount - 1 ? widget.spacing : 0,
            ),
            child: StaggeredListItem(
              index: index,
              staggerDelay: widget.staggerDelay,
              duration: widget.animationDuration,
              animate: shouldAnimate,
              child: widget.itemBuilder(context, index),
            ),
          );
        }, childCount: widget.itemCount),
      );
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: widget.spacing,
        mainAxisSpacing: widget.spacing,
        childAspectRatio: widget.childAspectRatio,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
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
