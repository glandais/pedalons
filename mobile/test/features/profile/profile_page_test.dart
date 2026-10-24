import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/passkey_management_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/profile/data/profile_repository.dart';
import 'package:pedalons/features/profile/presentation/widgets/data_and_account_section.dart';
import 'package:pedalons/features/profile/presentation/widgets/passkeys_section.dart';
import 'package:pedalons/features/profile/presentation/widgets/preferences_section.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';

/// S33-2 et S33-4 — les préférences et les clés d'accès.
///
/// Deux défauts s'y vérifient. Le premier est visible : l'exemple chiffré sous
/// le segmenté d'unités doit suivre le réglage, sans quoi le choix reste
/// abstrait. Le second ne l'était pas du tout — ajouter une clé d'accès
/// supprimait toutes les autres, en silence.
const UserDto _user = UserDto(
  id: 'u-me',
  email: 'moi@example.org',
  displayName: 'Moi',
  contactableByMembers: true,
  emailVerified: true,
);

/// `PATCH /api/users/me/preferences` : garde les corps envoyés et renvoie
/// l'utilisateur tel que le serveur l'aurait enregistré.
class _FakeUsersClient implements UsersClient {
  final List<UserPreferencesRequest> preferenceCalls =
      <UserPreferencesRequest>[];

  @override
  Future<UserDto> updateMyPreferences({
    required UserPreferencesRequest body,
  }) async {
    preferenceCalls.add(body);
    return _user.copyWith(timezone: body.timezone ?? _user.timezone);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePasskeys implements PasskeyManagementRepository {
  _FakePasskeys(this.passkeys);

  List<PasskeyDto> passkeys;
  final List<String> deleted = <String>[];

  @override
  Future<List<PasskeyDto>> listPasskeys() async => passkeys;

  @override
  Future<void> deletePasskey(String id) async {
    deleted.add(id);
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

const AccountDeletionImpactDto _noImpact = AccountDeletionImpactDto(
  blocked: false,
  blockingTeams: <TeamPublicationDto>[],
  deletedTeams: <TeamPublicationDto>[],
  migratedTeams: <TeamPublicationDto>[],
);

TeamPublicationDto _team(String name) =>
    TeamPublicationDto(id: name, name: name, slug: name, visibility: 'TEAM');

class _StubProfileRepository implements ProfileRepository {
  _StubProfileRepository([this.impact = _noImpact]);

  final AccountDeletionImpactDto impact;
  bool accountDeleted = false;

  @override
  Future<AccountDeletionImpactDto> deletionImpact() async => impact;

  @override
  Future<void> deleteAccount() async {
    accountDeleted = true;
  }

  @override
  Future<UserExportDto?> latestExport() async => null;

  @override
  Future<List<GpsServiceType>> availableGpsServices() async =>
      const <GpsServiceType>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_FakePasskeys> mount(
    WidgetTester tester,
    Widget child, {
    List<PasskeyDto> passkeys = const <PasskeyDto>[],
    Brightness brightness = Brightness.light,
    _StubProfileRepository? profile,
    _FakeUsersClient? users,
  }) async {
    final _FakeAuthRepository auth = _FakeAuthRepository();
    final _FakePasskeys keys = _FakePasskeys(passkeys);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          passkeyManagementRepositoryProvider.overrideWithValue(keys),
          profileRepositoryProvider.overrideWithValue(
            profile ?? _StubProfileRepository(),
          ),
          accessTokenHolderProvider.overrideWith((ref) => 'token'),
          if (users != null) usersClientProvider.overrideWithValue(users),
          authProvider.overrideWith((ref) => _StubAuthNotifier(ref, auth)),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(brightness),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    return keys;
  }

  group('préférences', () {
    testWidgets('les quatre réglages sont là, sans bouton d\'enregistrement', (
      WidgetTester tester,
    ) async {
      await mount(tester, const PreferencesSection());

      expect(find.text('Métrique'), findsOneWidget);
      expect(find.text('Impérial'), findsOneWidget);
      expect(find.text('Fuseau horaire'), findsOneWidget);
      // Jamais choisi : le fuseau de l'appareil.
      expect(find.text('Fuseau de l\'appareil'), findsOneWidget);
      expect(find.text('Système'), findsOneWidget);
      expect(find.text('Langue'), findsOneWidget);
      // La confidentialité a sa propre page.
      expect(find.text('Accepter les messages des membres'), findsNothing);
      // Ils s'appliquent immédiatement : aucun « Enregistrer » dans la carte.
      expect(find.text('Enregistrer'), findsNothing);
    });

    testWidgets(
      'le fuseau choisi dans la feuille part au serveur et s\'affiche sur la ligne',
      (WidgetTester tester) async {
        final _FakeUsersClient users = _FakeUsersClient();
        await mount(tester, const PreferencesSection(), users: users);

        await tester.tap(find.byKey(keys.profile.timezoneRow));
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.enterText(
          find.descendant(
            of: find.byKey(keys.profile.timezoneSearch),
            matching: find.byType(EditableText),
          ),
          'auckland',
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(
          find.byKey(keys.profile.timezoneOption('Pacific/Auckland')),
        );
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(
          users.preferenceCalls.map((UserPreferencesRequest r) => r.timezone),
          <String?>['Pacific/Auckland'],
        );
        expect(
          find.descendant(
            of: find.byKey(keys.profile.timezoneRow),
            matching: find.text('Pacific/Auckland'),
          ),
          findsOneWidget,
        );
        expect(find.text('Fuseau de l\'appareil'), findsNothing);
      },
    );

    testWidgets('l\'exemple chiffré est en métrique par défaut', (
      WidgetTester tester,
    ) async {
      await mount(tester, const PreferencesSection());

      // L'espace entre le nombre et l'unité est insécable : on ne le tape pas
      // dans l'attendu.
      expect(find.textContaining('66,5'), findsOneWidget);
      expect(find.textContaining('413'), findsOneWidget);
    });
  });

  group('clés d\'accès', () {
    const List<PasskeyDto> two = <PasskeyDto>[
      PasskeyDto(
        id: 'k1',
        deviceName: 'iPhone 15',
        lastUsedAt: '2026-07-24T10:00:00Z',
      ),
      PasskeyDto(id: 'k2', deviceName: 'MacBook Pro'),
    ];

    testWidgets('les deux clés sont listées, pas seulement la dernière', (
      WidgetTester tester,
    ) async {
      await mount(tester, const PasskeysSection(), passkeys: two);

      expect(find.text('iPhone 15'), findsOneWidget);
      expect(find.text('MacBook Pro'), findsOneWidget);
      expect(find.text('2 clés d\'accès'), findsOneWidget);
      // `lastUsedAt` nul veut dire « jamais employée », pas « inconnue ».
      expect(find.text('Jamais utilisée'), findsOneWidget);
      expect(find.textContaining('Dernière utilisation'), findsOneWidget);
    });

    testWidgets('supprimer demande confirmation et nomme la clé', (
      WidgetTester tester,
    ) async {
      final _FakePasskeys auth = await mount(
        tester,
        const PasskeysSection(),
        passkeys: two,
      );

      await tester.tap(find.byTooltip('Supprimer la clé iPhone 15'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.textContaining('Supprimer la clé « iPhone 15 »'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Vos autres clés restent valables'),
        findsOneWidget,
      );

      await tester.tap(find.text('Annuler'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(auth.deleted, isEmpty);
    });

    testWidgets('le mode sombre rend la même liste', (
      WidgetTester tester,
    ) async {
      await mount(
        tester,
        const PasskeysSection(),
        passkeys: two,
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('iPhone 15'), findsOneWidget);
    });
  });

  group('suppression du compte', () {
    Future<void> settle(WidgetTester tester) async {
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('bloquée, elle nomme les équipes sans ouvrir de confirmation', (
      WidgetTester tester,
    ) async {
      final _StubProfileRepository profile = _StubProfileRepository(
        AccountDeletionImpactDto(
          blocked: true,
          blockingTeams: <TeamPublicationDto>[_team('Les Rouleurs')],
          deletedTeams: <TeamPublicationDto>[_team('Mon équipe')],
          migratedTeams: const <TeamPublicationDto>[],
        ),
      );
      await mount(tester, const DeleteAccountSection(), profile: profile);

      await tester.tap(find.text('Supprimer le compte'));
      await settle(tester);

      expect(find.textContaining('Les Rouleurs'), findsOneWidget);
      expect(
        find.text('Voulez-vous vraiment supprimer votre compte ?'),
        findsNothing,
      );
      expect(profile.accountDeleted, isFalse);
    });

    testWidgets(
      'une équipe venue de biketeam bloque, nommée avec son adresse, sans confirmation',
      (WidgetTester tester) async {
        final _StubProfileRepository profile = _StubProfileRepository(
          AccountDeletionImpactDto(
            blocked: true,
            blockingTeams: const <TeamPublicationDto>[],
            deletedTeams: const <TeamPublicationDto>[],
            migratedTeams: <TeamPublicationDto>[_team('Club migré')],
          ),
        );
        await mount(tester, const DeleteAccountSection(), profile: profile);

        await tester.tap(find.text('Supprimer le compte'));
        await settle(tester);

        expect(find.textContaining('Club migré ('), findsOneWidget);
        expect(find.textContaining('venue de biketeam'), findsOneWidget);
        expect(find.textContaining('annuler sa bascule'), findsOneWidget);
        expect(
          find.textContaining('qui compte d\'autres membres'),
          findsNothing,
        );
        expect(
          find.text('Voulez-vous vraiment supprimer votre compte ?'),
          findsNothing,
        );
        expect(profile.accountDeleted, isFalse);
      },
    );

    testWidgets('la confirmation nomme les équipes supprimées avec le compte', (
      WidgetTester tester,
    ) async {
      final _StubProfileRepository profile = _StubProfileRepository(
        AccountDeletionImpactDto(
          blocked: false,
          blockingTeams: const <TeamPublicationDto>[],
          deletedTeams: <TeamPublicationDto>[_team('Mon équipe')],
          migratedTeams: const <TeamPublicationDto>[],
        ),
      );
      await mount(tester, const DeleteAccountSection(), profile: profile);

      await tester.tap(find.text('Supprimer le compte'));
      await settle(tester);

      expect(
        find.text('Voulez-vous vraiment supprimer votre compte ?'),
        findsOneWidget,
      );
      expect(
        find.textContaining('unique membre de l\'équipe Mon équipe'),
        findsOneWidget,
      );

      await tester.tap(find.text('Annuler'));
      await settle(tester);
      expect(profile.accountDeleted, isFalse);
    });
  });
}
