import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/config/router.dart';
import 'package:pedalons/core/utils/link_launcher.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/auth/providers/pending_sign_in_link.dart';

/// A deep link opened while signed out survives the login.
///
/// The link — a device's QR code (`/garmin?code=…`), a shared ride, a tapped
/// notification — goes through the login page; once signed in, the user lands
/// on it with its ancestors underneath, exactly as if they had opened it
/// signed in. Without a pending link, signing in still goes home.
void main() {
  late _RecordingRouter router;
  late PendingSignInLink pending;

  setUp(() {
    router = _RecordingRouter();
    pending = PendingSignInLink();
  });

  group('openDeepLink', () {
    test('signed in, a link opens with its ancestors', () {
      final garmin = '${PathVariants.deviceVerifyGarmin()['en']!}?code=ABC123';

      openDeepLink(router, garmin, signedIn: true, pending: pending);

      expect(router.calls, ['go ${PathVariants.home()['en']}', 'push $garmin']);
      expect(pending.location, isNull);
    });

    test('signed out, a link waits for the login instead of being lost', () {
      final garmin = '${PathVariants.deviceVerifyGarmin()['en']!}?code=ABC123';

      openDeepLink(router, garmin, signedIn: false, pending: pending);

      expect(router.calls, ['go ${Paths.login()}']);
      expect(pending.location, garmin, reason: 'the query string survives');
    });

    test('signed out, the latest link wins', () {
      final karoo = '${PathVariants.deviceVerifyKaroo()['en']!}?code=K1';
      final ride = PathVariants.ride('velo-club', 'dimanche')['fr']!;

      openDeepLink(router, karoo, signedIn: false, pending: pending);
      openDeepLink(router, ride, signedIn: false, pending: pending);

      expect(pending.location, ride);
    });

    test('pages open without a session never become the pending link', () {
      final adjacent = [
        ...PathVariants.login().values,
        ...PathVariants.register().values,
        '${PathVariants.verifyEmail()['en']!}?token=t0k3n',
        '${PathVariants.resetPassword()['fr']!}?token=t0k3n',
        ...PathVariants.forgotPassword().values,
        ...PathVariants.terms().values,
        ...PathVariants.privacy().values,
        ...PathVariants.apps().values,
      ];
      for (final path in adjacent) {
        router.calls.clear();
        openDeepLink(router, path, signedIn: false, pending: pending);

        expect(pending.location, isNull, reason: path);
        expect(
          router.calls.last,
          anyOf('go $path', 'push $path'),
          reason: '$path opens as is',
        );
      }
    });
  });

  group('openDeepLink, page du site sans écran (MOB-59)', () {
    late List<Uri> opened;

    setUp(() {
      opened = <Uri>[];
      debugLinkOpener = (Uri url) async {
        opened.add(url);
        return true;
      };
    });
    tearDown(() => debugLinkOpener = null);

    test('part au navigateur, la pile et le lien en attente intacts', () async {
      final members = PathVariants.teamAdminMembers('velo-club')['fr']!;

      for (final signedIn in [true, false]) {
        opened.clear();
        openDeepLink(router, members, signedIn: signedIn, pending: pending);
        await Future<void>.delayed(Duration.zero);

        expect(router.calls, isEmpty, reason: 'signedIn: $signedIn');
        expect(pending.location, isNull, reason: 'signedIn: $signedIn');
        expect(opened.single.path, members);
      }
    });
  });

  group('resumeAfterSignIn', () {
    test('lands on the pending link, hierarchy rebuilt, then forgets it', () {
      final ride = PathVariants.ride('velo-club', 'dimanche')['fr']!;
      openDeepLink(router, ride, signedIn: false, pending: pending);
      router.calls.clear();

      resumeAfterSignIn(router, pending);

      expect(router.calls, [
        'go ${PathVariants.teams()['fr']}',
        'push ${PathVariants.team('velo-club')['fr']}',
        // Une sortie est rangée sous l'Agenda (ledger `MOB-60`).
        'push ${PathVariants.teamAgenda('velo-club')['fr']}',
        'push $ride',
      ]);
      expect(pending.location, isNull);

      router.calls.clear();
      resumeAfterSignIn(router, pending);
      expect(router.calls, [
        'go ${Paths.home()}',
      ], reason: 'the link is used once — a later sign-in goes home');
    });

    test('keeps the query string of a device link', () {
      final garmin = '${PathVariants.deviceVerifyGarmin()['en']!}?code=ABC123';
      openDeepLink(router, garmin, signedIn: false, pending: pending);
      router.calls.clear();

      resumeAfterSignIn(router, pending);

      expect(router.calls, ['go ${PathVariants.home()['en']}', 'push $garmin']);
    });

    test('without a pending link, goes home', () {
      resumeAfterSignIn(router, pending);

      expect(router.calls, ['go ${Paths.home()}']);
    });
  });

  test('logging out forgets a link still waiting', () async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(_FakeStorage()),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(authProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(pendingSignInLinkProvider).location = '/garmin?code=ABC123';
    await container.read(authProvider.notifier).logout();

    expect(container.read(pendingSignInLinkProvider).location, isNull);
  });
}

/// Records navigation instead of performing it: what matters here is the order
/// of `go` and `push`, which is what builds the back stack.
class _RecordingRouter extends Fake implements GoRouter {
  final List<String> calls = [];

  @override
  void go(String location, {Object? extra}) => calls.add('go $location');

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) {
    calls.add('push $location');
    return Future<T?>.value();
  }
}

class _FakeStorage extends Fake implements SecureTokenStorage {
  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> deleteRefreshToken() async {}
}

class _FakeAuthRepository extends Fake implements AuthRepository {
  @override
  Future<void> logout(String? refreshToken) async {}
}
