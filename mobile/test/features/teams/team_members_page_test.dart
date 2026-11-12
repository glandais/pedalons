import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/domain/member_filters.dart';
import 'package:pedalons/features/teams/domain/team_discovery_filters.dart';
import 'package:pedalons/features/teams/presentation/pages/team_members_page.dart';
import 'package:pedalons/features/teams/providers/team_members_provider.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// S34-1 — le trombinoscope paginé.
///
/// Le défaut corrigé est le plus simple et le plus grave du lot :
/// `getTeamMembers` existait, **aucun écran ne l'appelait**, et l'appel
/// n'aurait de toute façon transmis ni `page` ni `size` — vingt membres sur
/// mille neuf cent quatre-vingt-dix-neuf, sans un mot.
class _StubTeamRepository implements TeamRepository {
  _StubTeamRepository({this.total = 1999});

  final int total;
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  @override
  Future<PageResult<MemberDto>> fetchMembers({
    required MemberFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async {
    calls.add(<String, Object?>{
      'teamSlug': filters.teamSlug,
      'role': filters.role,
      'search': filters.search,
      'page': page,
      'size': size,
    });
    final int offset = page * size;
    final int remaining = (total - offset).clamp(0, size);
    return PageResult<MemberDto>(
      items: fixtureMembers(remaining, from: offset),
      total: total,
    );
  }

  @override
  Future<PageResult<TeamDetailDto>> fetchTeams({
    required TeamDiscoveryFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async =>
      const PageResult<TeamDetailDto>(items: <TeamDetailDto>[], total: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> openMembers(
    WidgetTester tester, {
    required _StubTeamRepository repository,
    MemberFilters? filters,
    Brightness brightness = Brightness.light,
    bool rolesShown = true,
    bool signedInAsU1 = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamRepositoryProvider.overrideWithValue(repository),
          if (signedInAsU1) authProvider.overrideWith((Ref ref) => _Me(ref)),
          if (filters != null)
            memberFiltersProvider('n-peloton').overrideWith((ref) => filters),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(brightness),
          home: Scaffold(
            body: TeamMembersPage(
              teamSlug: 'n-peloton',
              rolesShown: rolesShown,
            ),
          ),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('la page transmet page et size, et annonce le total', (
    WidgetTester tester,
  ) async {
    final _StubTeamRepository repository = _StubTeamRepository();
    await openMembers(tester, repository: repository);

    expect(repository.calls.single['page'], 0);
    expect(repository.calls.single['size'], kDefaultPageSize);
    // 20 lignes chargées, 1 999 annoncées : la troncature n'est plus muette.
    expect(find.text('1999\u00a0membres'), findsOneWidget);
  });

  testWidgets(
    'une ligne dit le rôle et l\'ancienneté, et ouvre Signaler / Bloquer',
    (WidgetTester tester) async {
      await openMembers(tester, repository: _StubTeamRepository(total: 3));

      expect(find.text('Membre 0'), findsOneWidget);
      expect(find.textContaining('Membre depuis mars 2019'), findsWidgets);
      // Pas d'écran de profil public : une ligne ouvre le menu de
      // modération, rien d'autre (directive App Store 1.2).
      for (final PdlPersonRow row in tester.widgetList<PdlPersonRow>(
        find.byType(PdlPersonRow),
      )) {
        expect(row.onTap, isNotNull);
      }

      await tester.tap(find.text('Membre 0'));
      await tester.pumpAndSettle();

      expect(find.text('Signaler ce membre'), findsOneWidget);
      expect(find.text('Bloquer Membre 0'), findsOneWidget);
    },
  );

  testWidgets('règle R13 : un `⋯` en bout de ligne ouvre Signaler / Bloquer, '
      'jamais sur sa propre ligne', (WidgetTester tester) async {
    await openMembers(
      tester,
      repository: _StubTeamRepository(total: 3),
      signedInAsU1: true,
    );

    expect(find.byKey(keys.team.memberMore('u0')), findsOneWidget);
    expect(find.byKey(keys.team.memberMore('u2')), findsOneWidget);
    expect(find.byKey(keys.team.memberMore('u1')), findsNothing);

    await tester.tap(find.byKey(keys.team.memberMore('u0')));
    await tester.pumpAndSettle();
    expect(find.text('Signaler ce membre'), findsOneWidget);
    expect(find.text('Bloquer Membre 0'), findsOneWidget);
  });

  testWidgets('les chips de rôle sont exclusives et partent au serveur', (
    WidgetTester tester,
  ) async {
    final _StubTeamRepository repository = _StubTeamRepository(total: 3);
    await openMembers(tester, repository: repository);

    await tester.tap(find.text('Administrateur'));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(repository.calls.last['role'], TeamRole.admin);
  });

  // SEC-18 : sans les rôles, pas de filtre de rôle — le serveur le refuse.
  testWidgets('sans les rôles, aucune chip de rôle', (
    WidgetTester tester,
  ) async {
    await openMembers(
      tester,
      repository: _StubTeamRepository(total: 3),
      rolesShown: false,
    );

    expect(find.text('Administrateur'), findsNothing);
    expect(find.text('Membre 0'), findsOneWidget);
  });

  testWidgets('un vide filtré propose de tout réinitialiser', (
    WidgetTester tester,
  ) async {
    await openMembers(
      tester,
      repository: _StubTeamRepository(total: 0),
      filters: const MemberFilters(teamSlug: 'n-peloton', search: 'zzz'),
    );

    expect(find.text('Tout réinitialiser'), findsOneWidget);
  });

  testWidgets('le mode sombre rend la même liste', (WidgetTester tester) async {
    await openMembers(
      tester,
      repository: _StubTeamRepository(total: 3),
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('3\u00a0membres'), findsOneWidget);
  });
}

class _NoAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Connecté en « Membre 1 » (`u1`).
class _Me extends AuthNotifier {
  _Me(Ref ref) : super(_NoAuth(), _NoStorage(), ref) {
    state = const AuthState(
      isInitialized: true,
      accessToken: 'token',
      user: UserDto(
        plannerQuota: PlannerQuotaDto(used: 0, resetsOn: '2026-12-01'),
        id: 'u1',
        email: 'moi@example.org',
        displayName: 'Membre 1',
        contactableByMembers: true,
        emailVerified: true,
      ),
    );
  }
}
