import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/presentation/pages/teams_page.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_discovery_card.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// « Mes équipes » : ses pages, sa recherche, son appel — rendus par le
/// serveur, comme Découvrir.
class _StubTeamRepository implements TeamRepository {
  _StubTeamRepository(this.teams, {this.error});

  final List<TeamDetailDto> teams;
  final Object? error;
  final List<({String? search, int page, int size})> calls =
      <({String? search, int page, int size})>[];

  @override
  Future<PageResult<TeamDetailDto>> fetchMyTeams({
    String? search,
    int page = 0,
    int size = kDefaultPageSize,
  }) async {
    calls.add((search: search, page: page, size: size));
    if (error != null) throw error!;
    final List<TeamDetailDto> matching = search == null
        ? teams
        : teams.where((TeamDetailDto t) => t.name.contains(search)).toList();
    final int offset = page * size;
    return PageResult<TeamDetailDto>(
      items: matching.skip(offset).take(size).toList(),
      total: matching.length,
    );
  }

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => teams.take(20).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ledger `MOB-139` — la carte de l'onglet Équipes : D3 (« 1 membre », jamais
/// « 1 membres »), D4 (« Administrateur »), D9 (logo lu dans `team.logoUrl`)
/// et règle R12 (la carte de la découverte, seule carte d'équipe de l'app).
///
/// Audit des listes, DL5 et DL10 : la liste est paginée et cherchée côté
/// serveur, et son erreur porte le titre d'erreur des listes.
void main() {
  setUpAll(loadTestTranslations);

  Future<ProviderContainer> openWith(
    WidgetTester tester,
    _StubTeamRepository repository, {
    bool settle = true,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        teamRepositoryProvider.overrideWithValue(repository),
        myInvitationsProvider.overrideWith(
          (Ref ref) async => const <MyInvitationDto>[],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const TeamsPage(),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
    }
    return container;
  }

  Future<void> open(WidgetTester tester, List<TeamDetailDto> teams) =>
      openWith(tester, _StubTeamRepository(teams));

  testWidgets('le compte de membres s\'accorde, le rôle garde son nom', (
    WidgetTester tester,
  ) async {
    await open(tester, <TeamDetailDto>[
      fixtureTeam(slug: 'solo', name: 'Solo', memberCount: 1, role: 'ADMIN'),
      fixtureTeam(slug: 'club', name: 'Club', memberCount: 40),
    ]);

    expect(find.text('1\u00a0membre'), findsOneWidget);
    expect(find.text('40\u00a0membres'), findsOneWidget);
    expect(find.textContaining('1\u00a0membres'), findsNothing);
    final PdlBadge role = tester.widget<PdlBadge>(
      find.byKey(keys.teams.teamCardRole('solo')),
    );
    expect(role.label, 'Administrateur');
  });

  testWidgets('règle R12 : la carte de la découverte, avec le logo de '
      '`team.logoUrl`, l’extrait sur deux lignes et aucun bouton', (
    WidgetTester tester,
  ) async {
    await open(tester, <TeamDetailDto>[
      fixtureTeam(
        slug: 'club',
        name: 'Club',
        logoUrl: 'https://x/logo.png',
        role: 'MEMBER',
      ).copyWith(excerpt: 'Sorties route et gravel au départ de Huelgoat.'),
    ]);

    final Finder card = find.byKey(keys.teams.teamCard('club'));
    expect(tester.widget(card), isA<TeamDiscoveryCard>());
    expect(
      find.descendant(of: card, matching: find.byType(PdlCardMedia)),
      findsOneWidget,
    );
    final Text excerpt = tester.widget<Text>(
      find.text('Sorties route et gravel au départ de Huelgoat.'),
    );
    expect(excerpt.maxLines, 2);
    expect(
      tester
          .widget<PdlBadge>(find.byKey(keys.teams.teamCardRole('club')))
          .label,
      'Membre',
    );
    expect(
      find.descendant(of: card, matching: find.byType(PdlButton)),
      findsNothing,
    );
    final PdlAvatar avatar = tester.widget<PdlAvatar>(
      find.descendant(of: card, matching: find.byType(PdlAvatar)),
    );
    expect(avatar.imageUrl, 'https://x/logo.png');
  });

  testWidgets('DL5 — la liste est paginée : page et size partent, le pied '
      'dit combien il en reste', (WidgetTester tester) async {
    // Assez haut pour que les vingt cartes et le pied soient construits : la
    // dernières cartes appellent la page suivante.
    tester.view.physicalSize = const Size(1200, 12000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _StubTeamRepository repository = _StubTeamRepository(
      fixtureTeams(25),
    );
    await openWith(tester, repository);

    expect(repository.calls.first, (search: null, page: 0, size: 20));
    expect(repository.calls.map((c) => c.page), <int>[0, 1]);
    expect(find.byKey(keys.teams.teamCard('equipe-24')), findsOneWidget);
    final PdlPagedListFooter footer = tester.widget<PdlPagedListFooter>(
      find.byType(PdlPagedListFooter),
    );
    expect(footer.progressLabel, '25 équipes sur 25');
    expect(find.text('25 équipes sur 25'), findsOneWidget);
  });

  testWidgets('DL5 — la recherche part au serveur', (
    WidgetTester tester,
  ) async {
    final _StubTeamRepository repository = _StubTeamRepository(fixtureTeams(3));
    await openWith(tester, repository);

    await tester.tap(find.byTooltip('Rechercher une équipe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Équipe 2');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(repository.calls.last.search, 'Équipe 2');
    expect(find.byKey(keys.teams.teamCard('equipe-2')), findsOneWidget);
    expect(find.byKey(keys.teams.teamCard('equipe-1')), findsNothing);
  });

  testWidgets('DL5 — rejoindre ou quitter une équipe recharge la liste', (
    WidgetTester tester,
  ) async {
    final _StubTeamRepository repository = _StubTeamRepository(fixtureTeams(2));
    final ProviderContainer container = await openWith(tester, repository);
    final int before = repository.calls.length;

    // Ce que font l'adhésion, le départ et l'acceptation d'une invitation.
    container.invalidate(myTeamsProvider);
    await tester.pumpAndSettle();

    expect(repository.calls.length, before + 1);
  });

  testWidgets('DL10 — une panne porte le titre d\'erreur des listes', (
    WidgetTester tester,
  ) async {
    final RequestOptions request = RequestOptions(path: '/api/teams');
    await openWith(
      tester,
      _StubTeamRepository(
        const <TeamDetailDto>[],
        error: DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response<Object?>(requestOptions: request, statusCode: 500),
        ),
      ),
      settle: false,
    );

    expect(find.byKey(keys.teams.loadError), findsOneWidget);
    expect(find.text('Erreur de chargement'), findsOneWidget);
    expect(find.text('Équipe indisponible'), findsNothing);
  });
}
