import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/domain/member_filters.dart';
import 'package:pedalons/features/teams/domain/team_discovery_filters.dart';
import 'package:pedalons/features/teams/presentation/pages/teams_discover_page.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_discovery_card.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// S34-2 et S34-3 — la découverte d'équipes.
///
/// C'était l'un des deux cul-de-sacs de l'application : la loupe de « Mes
/// équipes » et le CTA de son état vide menaient à un écran « à venir ».
class _StubTeamRepository implements TeamRepository {
  _StubTeamRepository({this.teams = const <TeamDetailDto>[], this.joinError});

  final List<TeamDetailDto> teams;
  final Object? joinError;

  final List<TeamDiscoveryFilters> queries = <TeamDiscoveryFilters>[];

  /// Bloque l'adhésion jusqu'à ce que le test la libère, pour observer l'état
  /// pendant que la requête est en vol.
  Completer<void>? gate;

  @override
  Future<PageResult<TeamDetailDto>> fetchTeams({
    required TeamDiscoveryFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async {
    queries.add(filters);
    if (page > 0) {
      return PageResult<TeamDetailDto>(
        items: const <TeamDetailDto>[],
        total: teams.length,
      );
    }
    return PageResult<TeamDetailDto>(items: teams, total: teams.length);
  }

  @override
  Future<MemberDto> joinTeam(String slug) async {
    if (gate != null) await gate!.future;
    if (joinError != null) throw joinError!;
    return fixtureMember(index: 0);
  }

  @override
  Future<PageResult<MemberDto>> fetchMembers({
    required MemberFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async => const PageResult<MemberDto>(items: <MemberDto>[], total: 0);

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => const <TeamDetailDto>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DioException _forbidden() => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: 403,
    data: <String, dynamic>{'code': 'FORBIDDEN'},
  ),
);

DioException _memberLimitReached() => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: 409,
    data: <String, dynamic>{
      'code': 'TEAM_MEMBER_LIMIT_REACHED',
      'errorDetails': <String, dynamic>{
        'type': 'TEAM_MEMBER_LIMIT_REACHED',
        'limit': 25,
        'current': 25,
      },
    },
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> openDiscover(
    WidgetTester tester, {
    required _StubTeamRepository repository,
    Brightness brightness = Brightness.light,
  }) async {
    // Assez haut pour que toutes les cartes du jeu d'essai soient construites :
    // sous 600 px, la troisième reste hors du viewport.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [teamRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: PedalonsTheme.build(brightness),
          home: const TeamsDiscoverPage(),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('l\'écran liste les équipes et annonce le tri qu\'il demande', (
    WidgetTester tester,
  ) async {
    await openDiscover(
      tester,
      repository: _StubTeamRepository(teams: fixtureTeams(3)),
    );

    expect(find.byType(TeamDiscoveryCard), findsNWidgets(3));
    // API-13 : le dépôt demande `sortBy=MEMBER_COUNT` (`kTeamDiscoverySort`),
    // l'écran peut donc l'annoncer.
    expect(kTeamDiscoverySort, TeamSortBy.memberCount);
    expect(
      find.text('3 équipes · triées par nombre de membres'),
      findsOneWidget,
    );
  });

  // Ledger `MOB-139`, D3 : « 1 membre », jamais « 1 membres ».
  testWidgets('le compte de membres s\'accorde', (WidgetTester tester) async {
    await openDiscover(
      tester,
      repository: _StubTeamRepository(
        teams: <TeamDetailDto>[
          fixtureTeam(slug: 'solo', name: 'Solo', memberCount: 1),
          fixtureTeam(slug: 'club', name: 'Club', memberCount: 40),
        ],
      ),
    );

    expect(find.text('1\u00a0membre'), findsOneWidget);
    expect(find.text('40\u00a0membres'), findsOneWidget);
  });

  testWidgets('la chip « Ouvertes à l\'adhésion » part bien au serveur', (
    WidgetTester tester,
  ) async {
    final _StubTeamRepository repository = _StubTeamRepository(
      teams: fixtureTeams(2),
    );
    await openDiscover(tester, repository: repository);

    await tester.tap(find.text('Ouvertes à l\'adhésion'));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(repository.queries.last.scope, TeamDiscoveryScope.joinable);
  });

  testWidgets('les états de l\'action ; membre, le rôle réel et aucun bouton '
      '(règle R12)', (WidgetTester tester) async {
    await openDiscover(
      tester,
      repository: _StubTeamRepository(
        teams: <TeamDetailDto>[
          fixtureTeam(slug: 'a', name: 'A', joinable: true),
          fixtureTeam(slug: 'b', name: 'B', joinable: false),
          fixtureTeam(slug: 'c', name: 'C', joinable: true, role: 'ORGANIZER'),
        ],
      ),
    );

    expect(find.text('Rejoindre l\'équipe'), findsOneWidget);
    expect(find.text('Sur invitation'), findsOneWidget);
    // Plus de « Voir l'équipe » ni de « Membre » générique : le rôle réel, et
    // toucher la carte ouvre l'équipe.
    expect(find.text('Voir l\'équipe'), findsNothing);
    expect(find.text('MEMBRE'), findsNothing);
    expect(
      tester
          .widget<PdlBadge>(find.byKey(keys.teamsDiscover.cardRole('c')))
          .label,
      'Organisateur',
    );
    expect(
      find.descendant(
        of: find.byKey(keys.teamsDiscover.card('c')),
        matching: find.byType(PdlButton),
      ),
      findsNothing,
    );
    final PdlButton inviteOnly = tester.widget<PdlButton>(
      find.widgetWithText(PdlButton, 'Sur invitation'),
    );
    expect(inviteOnly.enabled, isFalse);
  });

  testWidgets('l\'adhésion est optimiste, et l\'appel en vol se voit', (
    WidgetTester tester,
  ) async {
    final _StubTeamRepository repository = _StubTeamRepository(
      teams: <TeamDetailDto>[fixtureTeam(slug: 'a', name: 'A')],
    )..gate = Completer<void>();
    await openDiscover(tester, repository: repository);

    await tester.tap(find.text('Rejoindre l\'équipe'));
    await tester.pump();
    expect(find.text('Adhésion…'), findsOneWidget);

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(keys.teamsDiscover.cardRole('a')), findsOneWidget);
    expect(find.text('Rejoindre l\'équipe'), findsNothing);
  });

  testWidgets('un échec rétablit la carte et nomme sa cause', (
    WidgetTester tester,
  ) async {
    await openDiscover(
      tester,
      repository: _StubTeamRepository(
        teams: <TeamDetailDto>[fixtureTeam(slug: 'a', name: 'A')],
        joinError: _forbidden(),
      ),
    );

    await tester.tap(find.text('Rejoindre l\'équipe'));
    await tester.pumpAndSettle();

    // Rétablissement complet : le bouton est revenu à ce qu'il était.
    expect(find.text('Rejoindre l\'équipe'), findsOneWidget);
    expect(find.text('Voir l\'équipe'), findsNothing);
    // Et l'échec est un état nommé, pas un snackbar.
    expect(find.byType(PdlBanner), findsOneWidget);
    expect(find.textContaining('Impossible de rejoindre A'), findsOneWidget);
  });

  testWidgets(
    'une équipe pleine : la carte revient, le bandeau dit la limite',
    (WidgetTester tester) async {
      await openDiscover(
        tester,
        repository: _StubTeamRepository(
          teams: <TeamDetailDto>[
            fixtureTeam(slug: 'a', name: 'A', memberCount: 25),
          ],
          joinError: _memberLimitReached(),
        ),
      );

      await tester.tap(find.text('Rejoindre l\'équipe'));
      await tester.pumpAndSettle();

      expect(find.text('Rejoindre l\'équipe'), findsOneWidget);
      expect(find.text('25\u00A0membres'), findsOneWidget);
      expect(find.textContaining('Impossible de rejoindre A'), findsOneWidget);
      expect(
        find.textContaining('a atteint 25 membres, la limite de l\'offre'),
        findsOneWidget,
      );
    },
  );

  testWidgets('le mode sombre rend le même écran', (WidgetTester tester) async {
    await openDiscover(
      tester,
      repository: _StubTeamRepository(teams: fixtureTeams(2)),
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(TeamDiscoveryCard), findsNWidgets(2));
  });
}
