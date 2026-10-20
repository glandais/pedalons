import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/profile/presentation/pages/profile_help_page.dart';
import 'package:pedalons/features/profile/presentation/pages/profile_page.dart';
import 'package:pedalons/features/profile/providers/profile_summary_provider.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';

/// La vue d'ensemble du profil : une ligne d'état par sujet, sans flèche de
/// retour (l'onglet est une racine), et « Se déconnecter » une seule fois.
const UserDto _user = UserDto(
  id: 'u-me',
  email: 'camille@example.org',
  displayName: 'Camille Durand',
  contactableByMembers: true,
  emailVerified: true,
  unitSystem: 'METRIC',
  theme: 'SYSTEM',
  language: 'fr',
  timezone: 'Europe/Paris',
  connectedServices: <GpsServiceConnectionDto>[
    GpsServiceConnectionDto(
      serviceType: 'GARMIN',
      displayName: 'Garmin Connect',
      connectedAt: '2026-09-01T10:00:00Z',
      autoSync: false,
      autoSyncState: 'OFF',
      autoSyncRouteCount: 0,
    ),
  ],
);

const ProfileSummaryDto _summary = ProfileSummaryDto(
  participations: ProfileParticipationSummaryDto(
    upcomingCount: 3,
    pastCount: 12,
    next: <PublicationDto>[],
  ),
  teams: <ProfileTeamDto>[
    ProfileTeamDto(slug: 'a', name: 'Les Rouleurs', role: 'ADMIN'),
    ProfileTeamDto(slug: 'b', name: 'Gaby Cyclo', role: 'MEMBER'),
  ],
  passkeyCount: 2,
  pairedDevices: <PairedDeviceDto>[
    PairedDeviceDto(id: 'd1', type: 'KAROO', pairedAt: '2026-09-01T10:00:00Z'),
  ],
  blockedUserCount: 1,
  notifications: ProfileNotificationSummaryDto(
    channels: <NotificationChannel>[
      NotificationChannel.email,
      NotificationChannel.push,
    ],
    enabledChannels: <NotificationChannel>[
      NotificationChannel.email,
      NotificationChannel.push,
    ],
    emailDigest: true,
  ),
);

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `GET /api/users/me` : l'utilisateur tel qu'un autre appareil l'a laissé.
class _FakeUsersClient implements UsersClient {
  _FakeUsersClient(this.me);

  final UserDto me;
  int getMeCalls = 0;

  @override
  Future<UserDto> getMe() async {
    getMeCalls++;
    return me;
  }

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> mount(
    WidgetTester tester, {
    ProfileSummaryDto summary = _summary,
    UsersClient? users,
    void Function()? onSummaryLoad,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final _FakeAuthRepository auth = _FakeAuthRepository();
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          accessTokenHolderProvider.overrideWith((ref) => 'token'),
          authProvider.overrideWith((ref) => _StubAuthNotifier(ref, auth)),
          profileSummaryProvider.overrideWith((ref) async {
            onSummaryLoad?.call();
            return summary;
          }),
          if (users != null) usersClientProvider.overrideWithValue(users),
          packageInfoProvider.overrideWith(
            (ref) async => PackageInfo(
              appName: 'Pédalons',
              packageName: 'fr.pedalons',
              version: '1.4.0',
              buildNumber: '57',
            ),
          ),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const ProfilePage(),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('l\'onglet Profil est une racine : pas de flèche de retour', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    expect(tester.widget<PdlAppBar>(find.byType(PdlAppBar)).onBack, isNull);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('la carte d\'identité mène à « Mon compte »', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    expect(find.byKey(keys.profile.identityCard), findsOneWidget);
    expect(find.text('Camille Durand'), findsOneWidget);
    expect(find.text('camille@example.org'), findsOneWidget);
    expect(find.text('Photo, nom et compte'), findsOneWidget);
  });

  testWidgets('chaque raccourci porte sa ligne d\'état', (
    WidgetTester tester,
  ) async {
    await mount(tester);

    // Plus de « Mon activité » : l'accueil et l'Agenda listent les sorties.
    expect(find.text('Mon activité'), findsNothing);
    expect(find.text('Mes sorties'), findsNothing);
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Sécurité et confidentialité'), findsOneWidget);
    expect(find.text('Compte'), findsOneWidget);

    expect(
      find.text('Métrique · Europe/Paris · Système · Français'),
      findsOneWidget,
    );
    expect(find.text('E-mail et push · résumé quotidien'), findsOneWidget);
    expect(find.text('Garmin Connect · 1 Karoo'), findsOneWidget);
    expect(find.text('2 clés d\'accès'), findsOneWidget);
    expect(find.text('1 personne bloquée · mes données'), findsOneWidget);
    expect(find.text('Version 1.4.0 (57)'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(keys.profile.accountRow),
        matching: find.text('Mon compte'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Photo, nom affiché, suppression du compte'),
      findsOneWidget,
    );
  });

  testWidgets(
    'tirer pour rafraîchir relit le résumé et /me (préférences, services)',
    (WidgetTester tester) async {
      int summaryLoads = 0;
      final _FakeUsersClient users = _FakeUsersClient(
        _user.copyWith(
          timezone: 'America/New_York',
          connectedServices: const <GpsServiceConnectionDto>[],
        ),
      );
      await mount(tester, users: users, onSummaryLoad: () => summaryLoads++);
      expect(summaryLoads, 1);

      // Le rafraîchissement de la page, sans la secousse de `PdlRefresh` ;
      // sans `await` : la relecture n'aboutit qu'au fil des images.
      unawaited(
        tester
            .widget<PdlScreenScaffold>(find.byType(PdlScreenScaffold))
            .onRefresh!(),
      );
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(summaryLoads, 2);
      expect(users.getMeCalls, 1);
      expect(
        find.text('Métrique · America/New_York · Système · Français'),
        findsOneWidget,
      );
      expect(find.text('1 Karoo'), findsOneWidget);
    },
  );

  testWidgets('sans canal déclaré, les notifications restent dans l\'app', (
    WidgetTester tester,
  ) async {
    await mount(
      tester,
      summary: _summary.copyWith(
        notifications: const ProfileNotificationSummaryDto(
          channels: <NotificationChannel>[],
          enabledChannels: <NotificationChannel>[],
          emailDigest: false,
        ),
        pairedDevices: const <PairedDeviceDto>[],
      ),
    );
    expect(find.text('Dans l\'application seulement'), findsOneWidget);
    // Garmin Connect reste connecté, sans appareil appairé.
    expect(find.text('Garmin Connect'), findsOneWidget);
  });

  testWidgets(
    'push seul : ni e-mail ni résumé quotidien dans la ligne d\'état',
    (WidgetTester tester) async {
      // Un serveur sans envoi d'e-mails ne déclare pas EMAIL : le résumé
      // renvoie emailDigest à false, la ligne ne parle que du push.
      await mount(
        tester,
        summary: _summary.copyWith(
          notifications: const ProfileNotificationSummaryDto(
            channels: <NotificationChannel>[NotificationChannel.push],
            enabledChannels: <NotificationChannel>[NotificationChannel.push],
            emailDigest: false,
          ),
        ),
      );
      expect(find.text('Push'), findsOneWidget);
      expect(find.textContaining('E-mail'), findsNothing);
      expect(find.textContaining('résumé quotidien'), findsNothing);
    },
  );

  testWidgets('« Se déconnecter » une seule fois, en bas de la liste', (
    WidgetTester tester,
  ) async {
    await mount(tester);
    expect(find.text('Se déconnecter'), findsOneWidget);
    expect(find.byKey(keys.profile.logoutButton), findsOneWidget);
    // Les actions rares descendent d'un niveau.
    expect(find.text('Supprimer le compte'), findsNothing);
    expect(find.text('Déconnecter tous les appareils'), findsNothing);
  });
}
