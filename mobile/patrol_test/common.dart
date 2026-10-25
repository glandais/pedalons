import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/app.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/notifications/providers/push_provider.dart';
import 'package:pedalons/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_clients.dart';
import 'api/backend_client.dart';
import 'config.dart';
import 'modules/modules.dart';

export 'package:flutter_test/flutter_test.dart'
    show
        expect,
        isNull,
        isNotNull,
        isTrue,
        isFalse,
        isNot,
        contains,
        equals,
        isEmpty;
export 'package:pedalons/config/paths.dart' show Paths;

export 'api/backend_client.dart' show Json, TestUser, unique;

typedef TestAppCallback = Future<void> Function(
  PatrolIntegrationTester $,
  Modules modules,
  ApiClients apiClients,
);

/// The wrapper every test goes through: one test per file, run by `patrol test`.
void testApp(String description, TestAppCallback callback) {
  patrolTest(description, ($) async {
    E2eConfig.ensureLocalStack();
    await callback($, Modules($), ApiClients());
  });
}

/// A test that pins a defect of the app: it must fail today, for the documented [defect].
///
/// The Patrol counterpart of Playwright's `test.fail` in the web suite. The body is written as the
/// fixed app should behave; while it fails, the test passes. The day the defect is fixed the body
/// passes, and this wrapper fails, asking for the marker to be dropped — the assertions are never
/// loosened to make it pass.
void testAppKnownDefect(
  String description,
  TestAppCallback callback, {
  required String defect,
}) {
  patrolTest('$description [known defect]', ($) async {
    E2eConfig.ensureLocalStack();
    try {
      await callback($, Modules($), ApiClients());
    } catch (error) {
      debugPrint('Known defect reproduced ($defect): $error');
      return;
    }
    fail(
      'The known defect is fixed: "$defect". Replace testAppKnownDefect with testApp in this '
      'file.',
    );
  });
}

/// Mounts the app as a fresh install would find it: no session, no stored preference.
///
/// The keychain outlives the app on the simulator — and the app is not reinstalled between
/// tests — so a session left by the previous test would otherwise skip the login screen.
Future<void> openApp(PatrolIntegrationTester $) async {
  await _forgetPreviousTest();
  await _pumpApp($);
}

/// Mounts the app already signed in as [user], as if they had logged in on an earlier launch.
Future<void> openAppSignedIn(PatrolIntegrationTester $, TestUser user) async {
  await _forgetPreviousTest();
  await SecureTokenStorage().saveRefreshToken(user.refreshToken);
  await _pumpApp($);
}

/// Opens [path] in the running app as a shared link does — a web link tapped in another app, or a
/// push notification: `main.dart` waits for the session and the router, then rebuilds the path's
/// ancestors underneath it. [path] is an app path, `Paths.ride(team, ride)` for instance.
Future<void> openLink(PatrolIntegrationTester $, String path) async {
  final container = ProviderScope.containerOf(
    $.tester.element(find.byType(PedalonsApp)),
  );
  container.read(pendingPushRouteProvider.notifier).state = path;
  await $.pump();
}

/// The access token the running app sends — the one its authentication interceptor reads.
String? currentAccessToken(PatrolIntegrationTester $) =>
    _container($).read(accessTokenHolderProvider);

/// Swaps the running app's access token for [token], as if it had expired while the app sat open:
/// the refresh token in the keychain is left alone, so the next 401 can be recovered from.
void replaceAccessToken(PatrolIntegrationTester $, String token) {
  _container($).read(accessTokenHolderProvider.notifier).state = token;
}

ProviderContainer _container(PatrolIntegrationTester $) =>
    ProviderScope.containerOf($.tester.element(find.byType(PedalonsApp)));

/// Polls [read] until it returns a value [until] accepts, and returns that value.
///
/// For what the backend does on its own schedule — the notification dispatcher runs every 15 s,
/// so the default leaves room for two cycles and a slow tick.
Future<T> eventually<T>(
  Future<T> Function() read, {
  required bool Function(T value) until,
  String? description,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final value = await read();
    if (until(value)) return value;
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out after $timeout waiting for ${description ?? 'a condition'} '
        '(last value: $value)',
      );
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

Future<void> _forgetPreviousTest() async {
  await SecureTokenStorage().clearAll();
  final preferences = await SharedPreferences.getInstance();
  await preferences.clear();
  // The tests read the app's French wording. A test user never chose a language, so the app would
  // follow the device: French on the iOS simulator, English on a stock Android emulator, where
  // every « shows(key, 'Réessayez…') » came back false. This is easy_localization's own saved
  // choice (`EasyLocalizationController._saveLocale`), read by `ensureInitialized` in `createApp`.
  await preferences.setString('locale', 'fr');
}

Future<void> _pumpApp(PatrolIntegrationTester $) async {
  final Widget app = await createApp(installErrorHandlers: false);
  // A second launch in the same test must start from nothing: pumped over the previous tree, the
  // new app would be matched to it and keep its `ProviderScope` — the previous user's cache
  // included. An empty frame in between unmounts it.
  await $.pumpWidget(const SizedBox.shrink());
  // Not `pumpWidgetAndSettle`: a signed-in home keeps animating while it loads, so it never
  // settles. Each action waits for its own widget instead.
  await $.pumpWidget(app);
}
