import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/profile/data/profile_repository.dart';
import 'package:pedalons/features/profile/presentation/pages/profile_privacy_page.dart';
import 'package:pedalons/features/profile/presentation/widgets/timezone_sheet.dart';
import 'package:pedalons/features/profile/providers/profile_summary_provider.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';

/// Les sous-pages du profil : ce que « Confidentialité » rassemble, et le
/// sélecteur de fuseau horaire des préférences.
const UserDto _user = UserDto(
  id: 'u-me',
  email: 'moi@example.org',
  displayName: 'Moi',
  contactableByMembers: true,
  emailVerified: true,
);

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(Ref ref, AuthRepository repository)
    : super(repository, _FakeSecureStorage(), ref) {
    state = const AuthState(user: _user, accessToken: 'token');
  }
}

class _StubProfileRepository implements ProfileRepository {
  @override
  Future<UserExportDto?> latestExport() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const ProfileSummaryDto _summary = ProfileSummaryDto(
  participations: ProfileParticipationSummaryDto(
    upcomingCount: 0,
    pastCount: 0,
    next: <PublicationDto>[],
  ),
  teams: <ProfileTeamDto>[],
  passkeyCount: 0,
  pairedDevices: <PairedDeviceDto>[],
  blockedUserCount: 2,
  notifications: ProfileNotificationSummaryDto(
    channels: <NotificationChannel>[],
    enabledChannels: <NotificationChannel>[],
    emailDigest: false,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'Confidentialité : contact, utilisateurs bloqués, rapports d\'erreur, mes données',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final _FakeAuthRepository auth = _FakeAuthRepository();
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(auth),
            accessTokenHolderProvider.overrideWith((ref) => 'token'),
            authProvider.overrideWith((ref) => _StubAuthNotifier(ref, auth)),
            profileRepositoryProvider.overrideWithValue(
              _StubProfileRepository(),
            ),
            profileSummaryProvider.overrideWith((ref) async => _summary),
          ],
          child: MaterialApp(
            theme: PedalonsTheme.build(Brightness.light),
            home: const ProfilePrivacyPage(),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Confidentialité'), findsOneWidget);
      // Le retour dit où il mène.
      expect(
        tester.widget<PdlAppBar>(find.byType(PdlAppBar)).backSemanticLabel,
        'Retour au profil',
      );
      expect(find.text('Accepter les messages des membres'), findsOneWidget);
      expect(
        tester
            .widget<PdlSwitch>(find.byKey(keys.profile.contactableSwitch))
            .value,
        isTrue,
      );
      expect(
        find.textContaining('votre adresse ne leur est jamais montrée'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(keys.moderation.blockedUsersRow),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.text('Rapports d\'erreur'), findsOneWidget);
      expect(find.text('Mes données'), findsOneWidget);
      expect(find.text('Demander mes données'), findsOneWidget);
    },
  );

  group('fuseau horaire', () {
    Future<String?> Function() open(WidgetTester tester, {String? current}) {
      String? picked;
      bool closed = false;
      return () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: PedalonsTheme.build(Brightness.light),
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      picked = await showTimezoneSheet(
                        context,
                        current: current,
                      );
                      closed = true;
                    },
                    child: const Text('ouvrir'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('ouvrir'));
        await settle(tester);
        return closed ? picked : null;
      };
    }

    testWidgets('la recherche ignore la casse et les soulignés', (
      WidgetTester tester,
    ) async {
      await open(tester)();

      await tester.enterText(
        find.descendant(
          of: find.byKey(keys.profile.timezoneSearch),
          matching: find.byType(EditableText),
        ),
        'new york',
      );
      await settle(tester);

      expect(
        find.byKey(keys.profile.timezoneOption('America/New_York')),
        findsOneWidget,
      );
      expect(
        find.byKey(keys.profile.timezoneOption('Europe/Paris')),
        findsNothing,
      );
    });

    testWidgets('le fuseau courant porte une coche, et toucher le rend', (
      WidgetTester tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    picked = await showTimezoneSheet(
                      context,
                      current: 'Europe/Paris',
                    );
                  },
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await settle(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(keys.profile.timezoneSearch),
          matching: find.byType(EditableText),
        ),
        'paris',
      );
      await settle(tester);
      expect(
        find.descendant(
          of: find.byKey(keys.profile.timezoneOption('Europe/Paris')),
          matching: find.byType(Icon),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(keys.profile.timezoneOption('Europe/Paris')));
      await settle(tester);
      expect(picked, 'Europe/Paris');
    });
  });
}
