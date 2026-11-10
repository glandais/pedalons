import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

export 'package:pedalons/keys.dart';

abstract class Module {
  Module(this.$);

  final PatrolIntegrationTester $;

  /// The widget of [key], scrolled into view in the screen's vertical list.
  ///
  /// Patrol's own `scrollTo` drives the first `Scrollable` it meets, and most screens start with a
  /// horizontal one (a chip row, a carousel): the vertical list is named here instead.
  ///
  /// A screen still loading may have no list yet (a skeleton, an error): the list is waited for
  /// first, so that the scroll does not fail on a list that is about to be built.
  Future<PatrolFinder> scrolledTo(Key key) async {
    await _waitForVerticalList(key);
    return $(key).scrollTo(view: _verticalScrollable.first);
  }

  Future<void> _waitForVerticalList(Key key) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (_verticalScrollable.evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('no vertical list on screen to scroll to $key');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Scrolls the screen's vertical list until the widget of [key] is built, then brings it into
  /// view — for a widget that is not hit-testable at its centre (a section whose content leaves
  /// its middle empty), which [scrolledTo] would never call visible.
  Future<void> scrolledIntoView(Key key) async {
    await _waitForVerticalList(key);
    await $.tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable: _verticalScrollable.first,
    );
    await $.pump(const Duration(milliseconds: 300));
  }

  /// Scrolls the screen's vertical list **back up** until the widget of [key] is visible — for a
  /// block near the top of a long page ([scrolledTo] only scrolls down). Already visible, nothing
  /// moves.
  Future<void> scrolledUpTo(Key key) async {
    await _waitForVerticalList(key);
    await $.tester.scrollUntilVisible(
      find.byKey(key),
      -300,
      scrollable: _verticalScrollable.first,
    );
    await $.pump(const Duration(milliseconds: 300));
  }

  /// Whether a widget of [key] is currently on screen — for the absence checks, made once the
  /// screen is known to be loaded.
  bool isShown(Key key) => $(key).exists;

  /// Waits until no widget of [key] is left in the tree.
  Future<void> waitUntilGone(
    Key key, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while ($(key).exists) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('$key still shown after $timeout');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Waits until one of [keys] is on screen, and returns it.
  Future<Key> waitUntilAnyIsShown(
    List<Key> keys, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      for (final key in keys) {
        if ($(key).visible) return key;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('none of $keys shown after $timeout');
      }
      await $.pump(const Duration(milliseconds: 200));
    }
  }

  /// Whether the widget of [key] shows [text] somewhere inside it — or is itself a `Text` that
  /// does. Rich text counts too: markdown and `Text.rich` render as `RichText`.
  bool shows(Key key, String text) => find
      .descendant(
        of: find.byKey(key),
        matching: find.textContaining(text, findRichText: true),
        matchRoot: true,
      )
      .evaluate()
      .isNotEmpty;

  static final Finder _verticalScrollable = find.byWidgetPredicate(
    (Widget widget) =>
        widget is Scrollable &&
        axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
  );
}
