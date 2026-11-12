import '../material.dart';

import 'breakpoints.dart';

/// A responsive grid that switches between ListView and GridView
/// based on available width.
///
/// - Compact: Single column ListView
/// - Medium: 2-column GridView
/// - Expanded: 3-column GridView
class ResponsiveGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final double childAspectRatio;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  const ResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 12,
    this.childAspectRatio = 1.0,
    this.controller,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = Breakpoints.getWindowSizeClass(constraints.maxWidth);
        final columns = Breakpoints.gridColumns(sizeClass);

        if (columns == 1) {
          // Use ListView for single column (better performance)
          return ListView.separated(
            controller: controller,
            physics: physics,
            padding: padding,
            itemCount: itemCount,
            separatorBuilder: (_, _) => SizedBox(height: spacing),
            itemBuilder: itemBuilder,
          );
        }

        // Use GridView for multiple columns
        return GridView.builder(
          controller: controller,
          physics: physics,
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

/// A responsive sliver grid for use in CustomScrollView.
class ResponsiveSliverGrid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double spacing;
  final double childAspectRatio;

  const ResponsiveSliverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 12,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sizeClass = Breakpoints.getWindowSizeClass(width);
    final columns = Breakpoints.gridColumns(sizeClass);

    if (columns == 1) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: EdgeInsets.only(
              bottom: index < itemCount - 1 ? spacing : 0,
            ),
            child: itemBuilder(context, index),
          ),
          childCount: itemCount,
        ),
      );
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(itemBuilder, childCount: itemCount),
    );
  }
}
