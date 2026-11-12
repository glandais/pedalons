import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/widgets/markdown_content.dart';

/// On iOS, tapping the status bar scrolls the primary scroll view back to the
/// top. [Scaffold] implements it by animating the [PrimaryScrollController] of
/// its own route, so a page only gets the behaviour when its scroll view is the
/// route's primary one — i.e. a vertical scrollable with no explicit
/// `controller:`, under a [Scaffold] living in that same route.
///
/// Regression guard for markdown pages: rendering markdown must not introduce a
/// scroll view of its own, otherwise the page's scrollable is no longer the one
/// the user actually scrolls and the gesture silently does nothing.
void main() {
  final markdown = '# Title\n\n${'Lorem ipsum dolor sit amet.\n\n' * 60}';

  /// Both the status bar slot of [Scaffold] and the automatic
  /// [PrimaryScrollController] inheritance key off the platform, which
  /// [MaterialScrollBehavior] reads from the theme.
  Widget iosApp(Widget home) => MaterialApp(
    theme: ThemeData(platform: TargetPlatform.iOS),
    home: MediaQuery(
      // The status bar hit-test region is sized from the top padding: with
      // no padding the Scaffold ignores the tap.
      data: const MediaQueryData(padding: EdgeInsets.only(top: 47)),
      child: home,
    ),
  );

  /// Simulates the `handleScrollToTop` message the iOS embedder sends when the
  /// status bar is tapped.
  Future<void> tapStatusBar(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.statusBar.name,
      SystemChannels.statusBar.codec.encodeMethodCall(
        const MethodCall('handleScrollToTop'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  testWidgets('MarkdownContent adds no scroll view of its own', (tester) async {
    await tester.pumpWidget(
      iosApp(
        Scaffold(
          body: SingleChildScrollView(child: MarkdownContent(data: markdown)),
        ),
      ),
    );

    expect(
      find.byType(Scrollable),
      findsOneWidget,
      reason:
          'MarkdownContent must not introduce a scroll view of its own, so '
          'that the page scrollable stays the primary one of its route',
    );
    expect(
      tester.widget<Scrollable>(find.byType(Scrollable)).controller,
      same(
        PrimaryScrollController.of(
          tester.element(find.byType(SingleChildScrollView)),
        ),
      ),
    );
  });

  testWidgets('status bar tap scrolls a markdown page back to top', (
    tester,
  ) async {
    await tester.pumpWidget(
      iosApp(
        Scaffold(
          body: SingleChildScrollView(child: MarkdownContent(data: markdown)),
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.pixels, greaterThan(0));

    await tapStatusBar(tester);

    expect(position.pixels, 0);
  });
}
