import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/config/router.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/link_launcher.dart';
import 'package:pedalons/features/calendar/presentation/pages/calendar_page.dart';
import 'package:pedalons/features/calendar/providers/calendar_month_provider.dart';
import 'package:pedalons/features/feed/presentation/widgets/publication_feed_view.dart';
import 'package:pedalons/features/feed/providers/publication_feed_provider.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/presentation/pages/team_agenda_page.dart';
import 'package:pedalons/features/teams/presentation/pages/team_home_page.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_sections.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// Ledger `MOB-60` — l'Agenda et les Publications d'une équipe, comme au site
/// (plan `2026-10-06-team-agenda.md` §6) : les adresses qui y mènent, celles
/// de l'ancien fil et des anciens onglets qui y sont redirigées, les filtres
/// de date envoyés à l'API, et le type qui ne fuit pas dans l'état partagé.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  late GoRouter router;

  setUpAll(() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    router = container.read(routerProvider);
  });

  /// La page qu'ouvre [location] : la feuille de la route, construite.
  Future<TeamHomePage> pageAt(WidgetTester tester, String location) async {
    final RouteMatchList matches = router.configuration.findMatch(
      Uri.parse(location),
    );
    expect(matches.isError, isFalse, reason: 'aucune route pour $location');

    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (BuildContext c) {
          context = c;
          return const SizedBox();
        },
      ),
    );

    final RouteMatch leaf = matches.last;
    final Page<dynamic> page = leaf.route.pageBuilder!(
      context,
      leaf.buildState(
        router.configuration,
        matches,
        metadata: const <String, dynamic>{},
      ),
    );
    return (page as NoTransitionPage<dynamic>).child as TeamHomePage;
  }

  group('adresses', () {
    // (adresse, section, type, période, vue)
    final Map<
      String,
      (
        Map<String, String>,
        TeamSectionKind,
        PublicationType?,
        AgendaScope,
        AgendaView,
      )
    >
    cases = {
      'teamAgenda': (
        PathVariants.teamAgenda('velo-club'),
        TeamSectionKind.agenda,
        null,
        AgendaScope.upcoming,
        AgendaView.list,
      ),
      'teamPosts': (
        PathVariants.teamPosts('velo-club'),
        TeamSectionKind.posts,
        null,
        AgendaScope.upcoming,
        AgendaView.list,
      ),
      // L'Agenda en vue Calendrier.
      'teamCalendar': (
        PathVariants.teamCalendar('velo-club'),
        TeamSectionKind.agenda,
        null,
        AgendaScope.upcoming,
        AgendaView.calendar,
      ),
      // Les anciens onglets « Sorties » et « Voyages » (ledger `WEB-64`),
      // redirigés comme au site : l'Agenda, sur les voyages pour le second.
      'teamRides': (
        PathVariants.teamRides('velo-club'),
        TeamSectionKind.agenda,
        null,
        AgendaScope.upcoming,
        AgendaView.list,
      ),
      'teamTrips': (
        PathVariants.teamTrips('velo-club'),
        TeamSectionKind.agenda,
        PublicationType.trip,
        AgendaScope.upcoming,
        AgendaView.list,
      ),
    };

    cases.forEach((String id, entry) {
      final (
        Map<String, String> variants,
        TeamSectionKind kind,
        PublicationType? type,
        AgendaScope scope,
        AgendaView view,
      ) = entry;
      for (final MapEntry<String, String> variant in variants.entries) {
        final String path = variant.value;

        test('$id [${variant.key}] $path reste dans l\'app', () {
          expect(internalLocationFor('https://www.pedalons.fr$path'), path);
          expect(ancestorsForDeepLink(path), <String>[
            PathVariants.teams()[variant.key]!,
            PathVariants.team('velo-club')[variant.key]!,
          ]);
        });

        testWidgets('$id [${variant.key}] $path ouvre la bonne section', (
          WidgetTester tester,
        ) async {
          final TeamHomePage home = await pageAt(tester, path);
          expect(home.teamSlug, 'velo-club');
          expect(home.section, kind);
          expect(home.agendaType, type);
          expect(home.agendaScope, scope);
          expect(home.agendaView, view);
        });
      }
    });

    testWidgets('« Voir tout » de « Mes prochaines » : l\'Agenda sur « Je '
        'participe »', (WidgetTester tester) async {
      final TeamHomePage home = await pageAt(
        tester,
        '${PathVariants.teamAgenda('velo-club')['fr']!}?w=me&type=ride',
      );
      expect(home.section, TeamSectionKind.agenda);
      expect(home.agendaScope, AgendaScope.participating);
      expect(home.agendaType, PublicationType.ride);
    });

    testWidgets('l\'adresse nue d\'une équipe : le tableau de bord', (
      WidgetTester tester,
    ) async {
      final TeamHomePage home = await pageAt(
        tester,
        PathVariants.team('velo-club')['fr']!,
      );
      expect(home.section, TeamSectionKind.dashboard);
    });
  });

  group('anciennes adresses du fil (resolveTeamRootSection)', () {
    TeamSectionTarget at(Map<String, String> query) =>
        resolveTeamRootSection(query);

    test('sans paramètre : le tableau de bord, pour tout le monde', () {
      expect(at(const <String, String>{}).kind, TeamSectionKind.dashboard);
    });

    test('?tab=publications seul : le tableau de bord', () {
      expect(
        at(const <String, String>{'tab': 'publications'}).kind,
        TeamSectionKind.dashboard,
      );
    });

    test('?tab=publications&type=post : les Publications', () {
      expect(
        at(const <String, String>{'tab': 'publications', 'type': 'post'}).kind,
        TeamSectionKind.posts,
      );
    });

    test('?tab=publications&type=ride|trip : l\'Agenda sur ce type', () {
      final TeamSectionTarget rides = at(const <String, String>{
        'tab': 'publications',
        'type': 'ride',
      });
      expect(rides.kind, TeamSectionKind.agenda);
      expect(rides.type, PublicationType.ride);
      final TeamSectionTarget trips = at(const <String, String>{
        'type': 'trip',
      });
      expect(trips.kind, TeamSectionKind.agenda);
      expect(trips.type, PublicationType.trip);
    });

    test('?w=me / ?w=upcoming / ?w=all : « Je participe » / « À venir »', () {
      final TeamSectionTarget me = at(const <String, String>{'w': 'me'});
      expect(me.kind, TeamSectionKind.agenda);
      expect(me.scope, AgendaScope.participating);
      for (final String w in <String>['upcoming', 'all']) {
        final TeamSectionTarget target = at(<String, String>{'w': w});
        expect(target.kind, TeamSectionKind.agenda);
        expect(target.scope, AgendaScope.upcoming);
        expect(target.type, isNull);
      }
    });
  });

  group('Agenda', () {
    late List<PublicationFeedKey> requested;

    setUp(() => requested = <PublicationFeedKey>[]);

    Future<ProviderContainer> pumpAgenda(
      WidgetTester tester, {
      String? role = 'MEMBER',
      PublicationType? initialType,
      AgendaScope initialScope = AgendaScope.upcoming,
      TeamDetailDto? team,
      bool emptyFeed = false,
      bool failingFeed = false,
    }) async {
      final TeamDetailDto shown =
          team ?? fixtureTeam(slug: 'velo-club', role: role);
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          // Aucun tag : pas d'appel réseau pour le vocabulaire du type.
          teamTagsProvider.overrideWith(
            (ref, key) async => const <TagWithUsageDto>[],
          ),
          publicationFeedProvider.overrideWith((ref, key) {
            requested.add(key);
            if (failingFeed) return _FailingFeedNotifier(key);
            return emptyFeed
                ? _EmptyFeedNotifier(key)
                : _StuckFeedNotifier(key);
          }),
          publicationFeedCountProvider.overrideWith((ref, key) async => 5),
          myTeamsProvider.overrideWith((ref) async => const <TeamDetailDto>[]),
          calendarMonthProvider.overrideWith(
            (ref, key) => Completer<CalendarMonth>().future,
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: PedalonsTheme.build(Brightness.light),
            home: TeamAgendaPage(
              team: shown,
              sections: buildTeamSections(shown),
              initialType: initialType,
              initialScope: initialScope,
              chrome: ({required Widget? header, required Widget body}) =>
                  Scaffold(body: body),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return container;
    }

    Future<void> tearDownFeed(WidgetTester tester) async {
      // Laisse s'éteindre les minuteries du fil (squelettes, autoDispose).
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('« À venir » par défaut : when=UPCOMING, sans participation, '
        'et le nombre de résultats', (WidgetTester tester) async {
      await pumpAgenda(tester);

      expect(requested, isNotEmpty);
      expect(requested.last.when, PublicationWhen.upcoming);
      expect(requested.last.participating, isFalse);
      expect(requested.last.type, isNull);
      expect(find.text('5 sorties et voyages à venir'), findsOneWidget);
      // Les chips de l'Agenda : Tout, Sorties, Voyages — pas de publications.
      expect(
        find.byKey(keys.feed.typeChip(PublicationType.post)),
        findsNothing,
      );
      expect(
        find.byKey(keys.feed.typeChip(PublicationType.trip)),
        findsOneWidget,
      );

      await tearDownFeed(tester);
    });

    testWidgets('« Je participe » puis « Passées »', (
      WidgetTester tester,
    ) async {
      await pumpAgenda(tester);

      await tester.tap(find.byKey(keys.teamAgenda.scope('participating')));
      await tester.pump();
      await tester.pump();
      expect(requested.last.when, PublicationWhen.upcoming);
      expect(requested.last.participating, isTrue);

      await tester.tap(find.byKey(keys.teamAgenda.scope('past')));
      await tester.pump();
      await tester.pump();
      expect(requested.last.when, PublicationWhen.past);
      expect(requested.last.participating, isFalse);
      expect(find.text('5 sorties et voyages passés'), findsOneWidget);

      await tearDownFeed(tester);
    });

    testWidgets('le type du lien sert la première page, sans être recopié '
        'dans l\'état partagé (leçon WEB-64)', (WidgetTester tester) async {
      final ProviderContainer container = await pumpAgenda(
        tester,
        initialType: PublicationType.trip,
      );

      expect(
        requested.map((PublicationFeedKey k) => k.type).toSet(),
        <PublicationType?>{PublicationType.trip},
        reason: 'aucune page « Tout » demandée puis jetée',
      );
      expect(find.text('5 voyages à venir'), findsOneWidget);

      // Point de départ, pas filtre imposé : les chips restent libres.
      await tester.tap(find.byKey(keys.feed.typeChip(PublicationType.ride)));
      await tester.pump();
      await tester.pump();
      expect(requested.last.type, PublicationType.ride);

      for (final String? scope in <String?>[
        'velo-club',
        'agenda/velo-club',
        null,
      ]) {
        expect(
          container.read(publicationFeedTypeProvider(scope)),
          isNull,
          reason: 'le type de l\'Agenda reste à l\'Agenda',
        );
      }

      await tearDownFeed(tester);
    });

    testWidgets('un membre bascule en calendrier, filtré sur « Je participe » '
        'et le type, gardés d\'une vue à l\'autre', (
      WidgetTester tester,
    ) async {
      await pumpAgenda(
        tester,
        initialType: PublicationType.ride,
        initialScope: AgendaScope.participating,
      );

      await tester.tap(find.byKey(keys.teamAgenda.view('calendar')));
      await tester.pump();

      final CalendarPage calendar = tester.widget<CalendarPage>(
        find.byType(CalendarPage),
      );
      expect(calendar.teamSlug, 'velo-club');
      expect(calendar.registeredOnly, isTrue);
      expect(calendar.typeFilter, CalendarTypeFilter.rides);
      // En calendrier, la période se réduit à « Tout / Je participe ».
      expect(find.byKey(keys.teamAgenda.scope('past')), findsNothing);
      expect(find.text('Tout'), findsWidgets);

      await tester.tap(find.byKey(keys.teamAgenda.view('list')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CalendarPage), findsNothing);
      expect(requested.last.type, PublicationType.ride);
      expect(requested.last.participating, isTrue);

      await tearDownFeed(tester);
    });

    group('DL7 — un type n\'est offert que si l\'équipe a le module', () {
      final TeamDetailDto noTrips = fixtureTeam(
        slug: 'velo-club',
        role: 'MEMBER',
      ).copyWith(enableTrips: false);

      testWidgets('en liste : pas de chip « Voyages » sans le module', (
        WidgetTester tester,
      ) async {
        await pumpAgenda(tester, team: noTrips);

        expect(find.byKey(keys.feed.typeChip(null)), findsOneWidget);
        expect(
          find.byKey(keys.feed.typeChip(PublicationType.ride)),
          findsOneWidget,
        );
        expect(
          find.byKey(keys.feed.typeChip(PublicationType.trip)),
          findsNothing,
        );

        await tearDownFeed(tester);
      });

      testWidgets('en calendrier non plus', (WidgetTester tester) async {
        await pumpAgenda(tester, team: noTrips);

        await tester.tap(find.byKey(keys.teamAgenda.view('calendar')));
        await tester.pump();

        final CalendarPage calendar = tester.widget<CalendarPage>(
          find.byType(CalendarPage),
        );
        expect(calendar.typeOptions, <CalendarTypeFilter>[
          CalendarTypeFilter.all,
          CalendarTypeFilter.rides,
        ]);
        expect(find.text('Sorties'), findsOneWidget);
        expect(find.text('Voyages'), findsNothing);

        await tearDownFeed(tester);
      });

      testWidgets('un lien `?type=trip` sur une équipe sans voyages s\'ouvre '
          'sur « Tout »', (WidgetTester tester) async {
        await pumpAgenda(
          tester,
          team: noTrips,
          initialType: PublicationType.trip,
        );

        expect(requested.last.type, isNull);

        await tearDownFeed(tester);
      });
    });

    // Règle RL11 : le fil prend la forme d'erreur des autres listes, plus le
    // bandeau « Fil indisponible. » à lui.
    testWidgets('RL11 — une panne du fil : « Chargement impossible », '
        '« Réessayer », « Signaler un problème »', (WidgetTester tester) async {
      await pumpAgenda(tester, failingFeed: true);
      await tester.pump();

      expect(find.text('Chargement impossible'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Signaler un problème'), findsOneWidget);
      expect(find.text('Fil indisponible.'), findsNothing);
      expect(find.byType(PdlBanner), findsNothing);

      await tearDownFeed(tester);
    });

    group('DL2 — le type et « Je participe » comptent comme filtre', () {
      testWidgets('sans filtre, le vide absolu de l\'Agenda', (
        WidgetTester tester,
      ) async {
        await pumpAgenda(tester, emptyFeed: true);

        expect(find.byKey(keys.feed.emptyState), findsOneWidget);
        expect(find.text("Rien à l'agenda pour le moment"), findsOneWidget);

        await tearDownFeed(tester);
      });

      testWidgets('« Sorties » sans résultat : le vide filtré, qui efface le '
          'type', (WidgetTester tester) async {
        await pumpAgenda(
          tester,
          emptyFeed: true,
          initialType: PublicationType.ride,
        );

        expect(find.byKey(keys.feed.filteredEmptyState), findsOneWidget);
        expect(find.text("Rien à l'agenda pour le moment"), findsNothing);
        // RL10 : le titre nomme l'objet, le message nomme le filtre.
        expect(find.text('Aucune sortie pour ces filtres'), findsOneWidget);
        expect(find.text('Rien ne correspond à : Sorties.'), findsOneWidget);

        await tester.tap(find.byKey(keys.feed.clearFiltersButton));
        await tester.pump();
        await tester.pump();
        expect(requested.last.type, isNull);
        expect(find.byKey(keys.feed.emptyState), findsOneWidget);

        await tearDownFeed(tester);
      });

      testWidgets(
        '« Je participe » sans résultat : le vide filtré, qui revient '
        'à « À venir »',
        (WidgetTester tester) async {
          await pumpAgenda(
            tester,
            emptyFeed: true,
            initialScope: AgendaScope.participating,
          );

          expect(find.byKey(keys.feed.filteredEmptyState), findsOneWidget);
          expect(
            find.text('Aucune sortie ni aucun voyage pour ces filtres'),
            findsOneWidget,
          );
          expect(
            find.text('Rien ne correspond à : Je participe.'),
            findsOneWidget,
          );

          await tester.tap(find.byKey(keys.feed.clearFiltersButton));
          await tester.pump();
          await tester.pump();
          expect(requested.last.participating, isFalse);
          expect(requested.last.when, PublicationWhen.upcoming);
          expect(find.byKey(keys.feed.emptyState), findsOneWidget);

          await tearDownFeed(tester);
        },
      );

      // RL10 (KIT §10) : « Passées » est un filtre — l'app cessait d'annoncer
      // « pour le moment » un passé vide. Ce test codait l'ancien vide absolu.
      testWidgets('« Passées » sans résultat : le vide filtré, qui revient à '
          '« À venir »', (WidgetTester tester) async {
        await pumpAgenda(
          tester,
          emptyFeed: true,
          initialScope: AgendaScope.past,
        );

        expect(find.byKey(keys.feed.filteredEmptyState), findsOneWidget);
        expect(find.byKey(keys.feed.emptyState), findsNothing);
        expect(
          find.text('Aucune sortie ni aucun voyage pour ces filtres'),
          findsOneWidget,
        );
        expect(find.text('Rien ne correspond à : Passées.'), findsOneWidget);

        await tester.tap(find.byKey(keys.feed.clearFiltersButton));
        await tester.pump();
        await tester.pump();
        expect(requested.last.when, PublicationWhen.upcoming);
        expect(find.byKey(keys.feed.emptyState), findsOneWidget);

        await tearDownFeed(tester);
      });
    });

    testWidgets('un visiteur n\'a pas de calendrier', (
      WidgetTester tester,
    ) async {
      await pumpAgenda(tester, role: null);

      expect(find.byKey(keys.teamAgenda.view('calendar')), findsNothing);
      expect(find.byType(PublicationFeedView), findsOneWidget);

      await tearDownFeed(tester);
    });
  });
}

/// Ne répond jamais : aucun appel HTTP, le fil reste sur ses squelettes.
class _StuckFeedNotifier extends PublicationFeedNotifier {
  _StuckFeedNotifier(PublicationFeedKey key)
    : super(PublicationsClient(Dio()), key);

  @override
  Future<PageResult<PublicationDto>> fetchPage(int page) =>
      Completer<PageResult<PublicationDto>>().future;
}

/// Rend une liste vide : les états vides du fil.
class _EmptyFeedNotifier extends PublicationFeedNotifier {
  _EmptyFeedNotifier(PublicationFeedKey key)
    : super(PublicationsClient(Dio()), key);

  @override
  Future<PageResult<PublicationDto>> fetchPage(int page) async =>
      const PageResult<PublicationDto>(items: <PublicationDto>[], total: 0);
}

/// Échoue sur une panne du serveur : l'état d'erreur du fil.
class _FailingFeedNotifier extends PublicationFeedNotifier {
  _FailingFeedNotifier(PublicationFeedKey key)
    : super(PublicationsClient(Dio()), key);

  @override
  Future<PageResult<PublicationDto>> fetchPage(int page) async {
    final RequestOptions request = RequestOptions(path: '/api/publications');
    throw DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(requestOptions: request, statusCode: 500),
    );
  }
}
