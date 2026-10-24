import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.generated.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/domain/member_filters.dart';
import 'package:pedalons/features/teams/domain/team_discovery_filters.dart';
import 'package:pedalons/features/teams/presentation/pages/team_home_page.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_header.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_sections.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// S23-1 à S23-3 — la page d'équipe.
///
/// Trois choses s'y vérifient : l'en-tête tient sous son plafond de 120 px,
/// se rétracte à 56 et son nom mène au tableau de bord, et l'adhésion est
/// résolue avant le premier paint puis bascule en optimiste.
class _StubTeamRepository implements TeamRepository {
  _StubTeamRepository(this.team, {this.joinError});

  TeamDetailDto team;
  final Object? joinError;

  int joins = 0;
  int leaves = 0;

  /// Bloque l'appel jusqu'à ce que le test le libère.
  Completer<void>? gate;

  /// Retient la lecture de l'équipe **sous son slug actuel** : ouverte par un
  /// ancien slug, la page la relit sous le nouveau.
  Completer<void>? currentSlugGate;

  final List<String> reads = <String>[];

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    reads.add(slug);
    if (slug == team.slug && currentSlugGate != null) {
      await currentSlugGate!.future;
    }
    return team;
  }

  @override
  Future<List<TeamDetailDto>> getMyTeams() async =>
      team.role == null ? const <TeamDetailDto>[] : <TeamDetailDto>[team];

  @override
  Future<MemberDto> joinTeam(String slug) async {
    joins++;
    if (gate != null) await gate!.future;
    if (joinError != null) throw joinError!;
    return fixtureMember(index: 0);
  }

  @override
  Future<void> leaveTeam(String slug) async {
    leaves++;
    if (gate != null) await gate!.future;
    if (joinError != null) throw joinError!;
  }

  @override
  Future<PageResult<MemberDto>> fetchMembers({
    required MemberFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async => const PageResult<MemberDto>(items: <MemberDto>[], total: 0);

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

DioException _forbidden() => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: 403,
    data: <String, dynamic>{'code': 'FORBIDDEN'},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  /// Un « settle » borné : l'état vide de la section À propos anime en boucle
  /// (`AnimatedEmptyState`), donc `pumpAndSettle` ne rendrait jamais la main.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openTeam(
    WidgetTester tester, {
    required _StubTeamRepository repository,
    TeamSectionKind section = TeamSectionKind.about,
    Brightness brightness = Brightness.light,
    String? slug,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          teamRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(brightness),
          home: TeamHomePage(
            teamSlug: slug ?? repository.team.slug,
            section: section,
          ),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  group('en-tête', () {
    testWidgets('déployé, il tient sous 120 px et montre l\'identité', (
      WidgetTester tester,
    ) async {
      await openTeam(tester, repository: _StubTeamRepository(fixtureTeam()));

      final Size size = tester.getSize(find.byType(TeamHeader).first);
      expect(size.height, lessThanOrEqualTo(120));
      expect(find.text('N-Peloton'), findsWidgets);
    });

    testWidgets('rétracté, il mesure la barre — et l\'action y reste', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            teamRepositoryProvider.overrideWithValue(
              _StubTeamRepository(fixtureTeam(role: 'MEMBER')),
            ),
          ],
          child: MaterialApp(
            theme: PedalonsTheme.build(Brightness.light),
            home: Scaffold(
              body: TeamHeader(
                team: fixtureTeam(role: 'MEMBER'),
                section: TeamSectionKind.dashboard,
                t: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 10));

      expect(tester.getSize(find.byType(TeamHeader)).height, 56);
      // L'action vit dans la rangée de barre : elle survit à la rétraction.
      expect(find.text('Quitter'), findsOneWidget);
    });

    for (final double t in <double>[0, 1]) {
      testWidgets('t = $t : le nom de l\'équipe mène au tableau de bord', (
        WidgetTester tester,
      ) async {
        setCurrentLocale('fr');
        final TeamDetailDto team = fixtureTeam(role: 'MEMBER');
        final GoRouter router = GoRouter(
          initialLocation: '/ailleurs',
          routes: <RouteBase>[
            GoRoute(
              path: '/ailleurs',
              builder: (_, _) => Scaffold(
                body: TeamHeader(
                  team: team,
                  section: TeamSectionKind.dashboard,
                  t: t,
                ),
              ),
            ),
            GoRoute(
              path: Paths.team(team.slug),
              builder: (_, _) => const Text('tableau de bord'),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              teamRepositoryProvider.overrideWithValue(
                _StubTeamRepository(team),
              ),
            ],
            child: MaterialApp.router(
              theme: PedalonsTheme.build(Brightness.light),
              routerConfig: router,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));

        await tester.tap(find.byKey(keys.team.headerIdentity).hitTestable());
        await tester.pump(const Duration(milliseconds: 10));

        expect(find.text('tableau de bord'), findsOneWidget);
      });
    }
  });

  /// Ledger `MOB-87` — « Mes équipes », depuis le nom de l'en-tête.
  group('Mes équipes', () {
    final TeamDetailDto alpes = fixtureTeam(
      slug: 'alpes',
      name: 'Alpes Vélo',
      role: 'MEMBER',
    ).copyWith(enableRides: false, enableTrips: false);
    final TeamDetailDto vercors = fixtureTeam(
      slug: 'vercors',
      name: 'Vercors',
      role: 'ADMIN',
    );

    /// L'en-tête de [team] sur la section [section], « Mes équipes » valant
    /// [myTeams] — dans l'ordre du serveur, que la feuille ne retouche pas.
    Future<void> openHeader(
      WidgetTester tester, {
      required TeamDetailDto team,
      required List<TeamDetailDto> myTeams,
      TeamSectionKind section = TeamSectionKind.dashboard,
    }) async {
      setCurrentLocale('fr');
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final GoRouter router = GoRouter(
        initialLocation: '/ailleurs',
        routes: <RouteBase>[
          GoRoute(
            path: '/ailleurs',
            builder: (_, _) => Scaffold(
              body: TeamHeader(team: team, section: section, t: 0),
            ),
          ),
          for (final TeamDetailDto x in <TeamDetailDto>[team, ...myTeams]) ...[
            GoRoute(
              path: Paths.team(x.slug),
              builder: (_, _) => Text('tableau de bord ${x.slug}'),
            ),
            GoRoute(
              path: Paths.teamAgenda(x.slug),
              builder: (_, _) => Text('agenda ${x.slug}'),
            ),
          ],
          GoRoute(
            path: Paths.teams(),
            builder: (_, _) => const Text('toutes les équipes'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            teamRepositoryProvider.overrideWithValue(_StubTeamRepository(team)),
            myTeamsProvider.overrideWith((_) async => myTeams),
          ],
          child: MaterialApp.router(
            theme: PedalonsTheme.build(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(keys.team.headerIdentity).hitTestable());
      await tester.pumpAndSettle();
    }

    Finder checkIn(String slug) => find.descendant(
      of: find.byKey(keys.team.switcherRow(slug)),
      matching: find.byIcon(PdlIcons.check),
    );

    testWidgets('membre de plusieurs : ▾, puis la feuille dans l\'ordre du '
        'serveur, l\'équipe courante cochée', (WidgetTester tester) async {
      final TeamDetailDto team = fixtureTeam(role: 'MEMBER');
      await openHeader(
        tester,
        team: team,
        myTeams: <TeamDetailDto>[alpes, team, vercors],
      );
      expect(find.byIcon(PdlIcons.chevronDown), findsWidgets);

      await openSheet(tester);
      expect(find.byKey(keys.team.switcherSheet), findsOneWidget);
      expect(find.text('Mes équipes'), findsOneWidget);
      final List<double> tops = <String>['alpes', 'n-peloton', 'vercors']
          .map(
            (String slug) =>
                tester.getTopLeft(find.byKey(keys.team.switcherRow(slug))).dy,
          )
          .toList();
      expect(tops[0], lessThan(tops[1]));
      expect(tops[1], lessThan(tops[2]));
      expect(checkIn('n-peloton'), findsOneWidget);
      expect(checkIn('alpes'), findsNothing);
      expect(checkIn('vercors'), findsNothing);
      // La coche n'est pas qu'un dessin : un lecteur d'écran l'entend aussi.
      expect(
        tester.getSemantics(find.byKey(keys.team.switcherRow('n-peloton'))),
        isSemantics(isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.byKey(keys.team.switcherRow('alpes'))),
        isSemantics(isSelected: false, isButton: true),
      );
      // « Toutes les équipes » ferme la liste.
      expect(
        tester.getTopLeft(find.byKey(keys.team.switcherAllTeams)).dy,
        greaterThan(tops[2]),
      );
      expect(find.text('Toutes les équipes'), findsOneWidget);
    });

    testWidgets('depuis l\'Agenda, une équipe qui en a un ouvre le sien', (
      WidgetTester tester,
    ) async {
      final TeamDetailDto team = fixtureTeam(role: 'MEMBER');
      await openHeader(
        tester,
        team: team,
        myTeams: <TeamDetailDto>[alpes, team, vercors],
        section: TeamSectionKind.agenda,
      );
      await openSheet(tester);
      await tester.tap(find.byKey(keys.team.switcherRow('vercors')));
      await tester.pumpAndSettle();

      expect(find.text('agenda vercors'), findsOneWidget);
    });

    testWidgets('depuis l\'Agenda, une équipe sans Agenda ouvre son tableau '
        'de bord', (WidgetTester tester) async {
      final TeamDetailDto team = fixtureTeam(role: 'MEMBER');
      await openHeader(
        tester,
        team: team,
        myTeams: <TeamDetailDto>[alpes, team, vercors],
        section: TeamSectionKind.agenda,
      );
      await openSheet(tester);
      await tester.tap(find.byKey(keys.team.switcherRow('alpes')));
      await tester.pumpAndSettle();

      expect(find.text('tableau de bord alpes'), findsOneWidget);
    });

    testWidgets('l\'équipe courante referme la feuille sans naviguer', (
      WidgetTester tester,
    ) async {
      final TeamDetailDto team = fixtureTeam(role: 'MEMBER');
      await openHeader(
        tester,
        team: team,
        myTeams: <TeamDetailDto>[alpes, team],
      );
      await openSheet(tester);
      await tester.tap(find.byKey(keys.team.switcherRow('n-peloton')));
      await tester.pumpAndSettle();

      expect(find.byKey(keys.team.switcherSheet), findsNothing);
      expect(find.byType(TeamHeader), findsOneWidget);
    });

    testWidgets('« Toutes les équipes » mène à la liste des équipes', (
      WidgetTester tester,
    ) async {
      final TeamDetailDto team = fixtureTeam(role: 'MEMBER');
      await openHeader(
        tester,
        team: team,
        myTeams: <TeamDetailDto>[alpes, team],
      );
      await openSheet(tester);
      await tester.tap(find.byKey(keys.team.switcherAllTeams));
      await tester.pumpAndSettle();

      expect(find.text('toutes les équipes'), findsOneWidget);
    });

    testWidgets('membre de cette seule équipe : pas de ▾, le nom mène au '
        'tableau de bord', (WidgetTester tester) async {
      final TeamDetailDto team = fixtureTeam(role: 'MEMBER');
      await openHeader(tester, team: team, myTeams: <TeamDetailDto>[team]);
      expect(find.byIcon(PdlIcons.chevronDown), findsNothing);

      await openSheet(tester);
      expect(find.byKey(keys.team.switcherSheet), findsNothing);
      expect(find.text('tableau de bord n-peloton'), findsOneWidget);
    });

    testWidgets('visiteur avec une équipe : la feuille, sans coche', (
      WidgetTester tester,
    ) async {
      await openHeader(
        tester,
        team: fixtureTeam(),
        myTeams: <TeamDetailDto>[alpes],
      );
      expect(find.byIcon(PdlIcons.chevronDown), findsWidgets);

      await openSheet(tester);
      expect(find.byKey(keys.team.switcherRow('alpes')), findsOneWidget);
      expect(find.byKey(keys.team.switcherRow('n-peloton')), findsNothing);
      expect(find.byIcon(PdlIcons.check), findsNothing);
    });

    testWidgets('visiteur sans équipe : pas de ▾, le nom mène au tableau de '
        'bord', (WidgetTester tester) async {
      await openHeader(
        tester,
        team: fixtureTeam(),
        myTeams: const <TeamDetailDto>[],
      );
      expect(find.byIcon(PdlIcons.chevronDown), findsNothing);

      await openSheet(tester);
      expect(find.byKey(keys.team.switcherSheet), findsNothing);
      expect(find.text('tableau de bord n-peloton'), findsOneWidget);
    });
  });

  group('À propos', () {
    testWidgets('l\'année de création, et plus de cellules chiffrées', (
      WidgetTester tester,
    ) async {
      await openTeam(
        tester,
        repository: _StubTeamRepository(fixtureTeam(role: 'MEMBER')),
      );

      expect(find.text('Équipe créée en 2024'), findsOneWidget);
      expect(find.byType(PdlStatCellRow), findsNothing);
    });
  });

  group('adhésion', () {
    testWidgets('membre : « Quitter », non-membre joignable : « Rejoindre »', (
      WidgetTester tester,
    ) async {
      await openTeam(
        tester,
        repository: _StubTeamRepository(fixtureTeam(role: 'MEMBER')),
      );
      expect(find.text('Quitter'), findsOneWidget);
      expect(find.text('Rejoindre'), findsNothing);
    });

    testWidgets('non joignable : « Sur invitation », désactivé', (
      WidgetTester tester,
    ) async {
      await openTeam(
        tester,
        repository: _StubTeamRepository(fixtureTeam(joinable: false)),
      );
      final PdlButton button = tester.widget<PdlButton>(
        find.widgetWithText(PdlButton, 'Sur invitation'),
      );
      expect(button.enabled, isFalse);
    });

    testWidgets('l\'adhésion est optimiste et l\'appel en vol se voit', (
      WidgetTester tester,
    ) async {
      final _StubTeamRepository repository = _StubTeamRepository(fixtureTeam())
        ..gate = Completer<void>();
      await openTeam(tester, repository: repository);

      await tester.tap(find.text('Rejoindre'));
      await tester.pump();
      expect(find.text('Adhésion…'), findsOneWidget);

      repository.team = fixtureTeam(role: 'MEMBER');
      repository.gate!.complete();
      await settle(tester);
      expect(find.text('Quitter'), findsOneWidget);
    });

    testWidgets('un échec rétablit le bouton et nomme sa cause', (
      WidgetTester tester,
    ) async {
      await openTeam(
        tester,
        repository: _StubTeamRepository(fixtureTeam(), joinError: _forbidden()),
      );

      await tester.tap(find.text('Rejoindre'));
      await settle(tester);

      expect(find.text('Rejoindre'), findsOneWidget);
      expect(find.byType(PdlBanner), findsOneWidget);
      expect(find.textContaining('Action impossible'), findsOneWidget);
    });

    testWidgets('quitter demande confirmation par une question fermée', (
      WidgetTester tester,
    ) async {
      final _StubTeamRepository repository = _StubTeamRepository(
        fixtureTeam(role: 'MEMBER'),
      );
      await openTeam(tester, repository: repository);

      await tester.tap(find.text('Quitter'));
      await settle(tester);
      expect(find.text('Quitter cette équipe ?'), findsOneWidget);
      expect(find.textContaining('réservés aux membres'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await settle(tester);
      expect(repository.leaves, 0);
    });

    testWidgets(
      'ouverte par un ancien slug, la page ne propose rien à un membre avant '
      'de connaître son adhésion, puis « Quitter »',
      (WidgetTester tester) async {
        final _StubTeamRepository repository = _StubTeamRepository(
          fixtureTeam(role: 'MEMBER', joinable: false),
        )..currentSlugGate = Completer<void>();
        await openTeam(tester, repository: repository, slug: 'ancien-slug');

        // Le slug actuel est encore en lecture : ni « Sur invitation » ni
        // « Rejoindre » à un membre.
        expect(repository.reads, <String>['ancien-slug', 'n-peloton']);
        expect(find.text('Sur invitation'), findsNothing);
        expect(find.text('Rejoindre'), findsNothing);

        repository.currentSlugGate!.complete();
        await settle(tester);
        expect(find.text('Quitter'), findsOneWidget);
        expect(find.text('Sur invitation'), findsNothing);
      },
    );
  });

  testWidgets('le mode sombre rend le même écran', (WidgetTester tester) async {
    await openTeam(
      tester,
      repository: _StubTeamRepository(fixtureTeam(role: 'MEMBER')),
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(TeamHeader), findsOneWidget);
  });
}
