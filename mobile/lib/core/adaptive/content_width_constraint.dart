import '../material.dart';

import 'breakpoints.dart';

/// Centers and constrains content width on larger screens for better readability.
///
/// On compact screens, content fills the full width.
/// On medium screens, content is constrained to 720px.
/// On expanded screens, content is constrained to 960px.
class ContentWidthConstraint extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ContentWidthConstraint({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sizeClass = Breakpoints.getWindowSizeClass(width);
    final maxWidth = Breakpoints.contentMaxWidth(sizeClass);

    Widget content = child;

    if (maxWidth != null) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
    }

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return content;
  }
}

// There used to be a `SliverContentWidthConstraint` here. It was removed with
// wave C of the component library: it wrapped the sliver in a
// `SliverToBoxAdapter` and handed it straight back, so it constrained nothing
// while reading as if it did — and putting a real sliver inside a box adapter
// throws. A sliver tree that must be constrained goes through
// `PdlScreenScaffold(constrainWidth: true)`, which clamps the whole scroll
// view, or through a `SliverPadding` with computed horizontal padding.
