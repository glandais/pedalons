import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'module.dart';

/// The system share sheet (`SharePlus`), which the app opens on a file it downloaded — a GPX or
/// FIT export. It is native: read through Patrol's native UI tree, on iOS and on Android.
final class ShareSheet extends Module {
  ShareSheet(super.$);

  /// Waits until the share sheet is up — whatever the device's language — and returns whether it
  /// presents a GPX file, then closes it.
  ///
  /// Each system says so its own way, never with the app's own « GPX » button (which the native
  /// tree also carries): iOS captions the file with its type and size, « GPX • 17 ko »; Android 14
  /// (`com.android.intentresolver`) names the file itself, « parcours-est-….gpx ».
  Future<bool> waitUntilSharesGpxFile({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final shown = await _waitUntilShownAndCheck(
      Platform.isAndroid ? '.gpx' : 'GPX •',
      timeout,
    );
    // Android leaves the chooser above the app otherwise; iOS dismisses it with the test.
    if (Platform.isAndroid) await $.platform.android.pressBack();
    return shown;
  }

  Future<bool> _waitUntilShownAndCheck(String text, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final roots = await _nativeRoots();
      final up = roots.any((view) => view.isShareSheet);
      // The sheet comes up before its file caption: iOS fills « GPX • 17 ko » in a moment later.
      if (up && roots.any((view) => view.contains(text))) return true;
      if (DateTime.now().isAfter(deadline)) {
        final dump = StringBuffer();
        for (final view in roots) {
          view.dump(0, dump);
        }
        if (!up) {
          throw TestFailure(
            'no share sheet after $timeout; native tree:\n$dump',
          );
        }
        // ignore: avoid_print
        print(
          'share sheet without « $text » after $timeout; native tree:\n$dump',
        );
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<List<_View>> _nativeRoots() async => Platform.isAndroid
      ? [
          for (final view in (await $.platform.android.getNativeViews(
            null,
          )).roots)
            _View.android(view),
        ]
      : [
          for (final view in (await $.platform.ios.getNativeViews(null)).roots)
            _View.ios(view),
        ];
}

/// One node of the native tree, iOS or Android, reduced to what the sheet is recognised by.
final class _View {
  _View.ios(IOSNativeView view)
    : texts = [view.label, view.title, ?view.value, view.identifier],
      description = '${view.elementType} id=${view.identifier}',
      // UIKit's list of activities.
      isSheetNode = view.identifier.contains('ActivityListView'),
      children = [for (final child in view.children) _View.ios(child)];

  _View.android(AndroidNativeView view)
    : texts = [?view.text, ?view.contentDescription, ?view.resourceName],
      description = '${view.className} pkg=${view.applicationPackage}',
      // The chooser's list of targets, the framework's own id whatever the package serving it.
      isSheetNode = view.resourceName == 'android:id/resolver_list',
      children = [for (final child in view.children) _View.android(child)];

  final List<String> texts;
  final String description;
  final bool isSheetNode;
  final List<_View> children;

  bool get isShareSheet =>
      isSheetNode || children.any((child) => child.isShareSheet);

  bool contains(String text) =>
      texts.any((t) => t.contains(text)) ||
      children.any((child) => child.contains(text));

  void dump(int depth, StringBuffer out) {
    out.writeln('${'  ' * depth}$description ${texts.join(' | ')}');
    for (final child in children) {
      child.dump(depth + 1, out);
    }
  }
}
