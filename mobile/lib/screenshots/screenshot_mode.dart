import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../features/auth/providers/auth_provider.dart';

/// Store screenshot mode — compiled in only by `--dart-define=SCREENSHOTS=true`
/// (`mobile/screenshots/capture.sh`). Everywhere else the constant is false and
/// the functions below are no-ops the compiler drops, so no release build reads
/// a screen or a password from anywhere.
///
/// A capture is one launch: the script names the account and the screen, the
/// app signs in if needed and opens that screen through the deep-link path, so
/// the page comes with its real ancestors and nothing depends on a tap.
const bool kScreenshotMode = bool.fromEnvironment('SCREENSHOTS');

/// Before each launch the capture script writes `Documents/screenshot.json`
/// into the app's container — `{"screen", "email", "password"}` — and deletes
/// it at the end. Nothing lighter reaches Dart on iOS: `Platform.environment`
/// is empty there, `shared_preferences` ignores launch arguments, and the
/// simulator's `cfprefsd` caches the app's defaults over any edit of the file.
Map<String, String> _launch = const {};

/// Reads the launch file. Call once, before `runApp`.
Future<void> loadScreenshotLaunch() async {
  if (!kScreenshotMode) return;
  try {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/screenshot.json');
    if (!file.existsSync()) {
      debugPrint('[screenshots] no ${file.path}');
      return;
    }
    final Map<String, dynamic> json =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    _launch = json.map((String k, dynamic v) => MapEntry(k, '$v'));
  } catch (error) {
    debugPrint('[screenshots] unreadable launch file: $error');
  }
}

/// The path to open at launch, e.g. `/equipes/demo/sorties/…`.
String? screenshotInitialPath() => kScreenshotMode ? _launch['screen'] : null;

/// Signs the demo account in before the screen opens, switching accounts when
/// the previous capture ran under another one (one account per locale).
Future<void> screenshotSignIn(WidgetRef ref) async {
  if (!kScreenshotMode) return;
  final String? email = _launch['email'];
  final String? password = _launch['password'];
  if (email == null || password == null) return;

  final AuthNotifier auth = ref.read(authProvider.notifier);
  final String? current = ref.read(authProvider).user?.email;
  if (current == email) return;
  if (current != null) await auth.logout();
  try {
    await auth.loginWithPassword(email, password);
  } catch (error) {
    debugPrint('[screenshots] sign-in failed: $error');
  }
}

/// The screen to push over [screenshotInitialPath] once it has loaded, for a
/// page whose URL depends on data the plan does not know —
/// `rideGroupWeather`, the Météo tab of the selected group's page, pushed
/// from a ride's detail (ledger `MOB-67`) — or, for a single-group ride, which has no group page,
/// a scroll of the detail down to its weather (ledger `MOB-69`). True once for [name], so a rebuild of the page
/// underneath does not push it a second time.
bool screenshotTakePush(String name) {
  if (!kScreenshotMode || _launch['push'] != name) return false;
  _launch = Map<String, String>.of(_launch)..remove('push');
  return true;
}
