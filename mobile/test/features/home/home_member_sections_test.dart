import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/provider_retry.dart';
import 'package:pedalons/features/home/presentation/widgets/my_teams_section.dart';
import 'package:pedalons/features/home/presentation/widgets/week_agenda_section.dart';
import 'package:pedalons/features/home/providers/next_ride_provider.dart';
import 'package:pedalons/features/home/providers/week_events_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import '../rides/ride_fixtures.dart';
import '../teams/team_fixtures.dart';

/// Les blocs membre de l'accueil : « Cette semaine » et « Mes équipes ».
CalendarEventDto _event(
  String slug, {
  String start = '2099-07-29T17:30:00Z',
  String type = 'RIDE',
  String teamSlug = 'vc-craponne',
  String teamName = 'VC Craponne',
  bool registered = false,
  bool finished = false,
  String status = 'PUBLISHED',
  String? tripSlug,
}) => CalendarEventDto(
  timezone: 'Europe/Paris',
  id: 'e-$slug',
  title: 'Titre $slug',
  start: start,
  allDay: false,
  type: type,
  teamSlug: teamSlug,
  teamName: teamName,
  entitySlug: slug,
  registered: registered,
  status: status,
  finished: finished,
  tripSlug: tripSlug,
);

ConfigDto _config({required bool singleTeam}) => ConfigDto(
  webAuthnRpId: 'localhost',
  appName: 'Pédalons',
  singleTeam: singleTeam,
  enableGpxPlanner: false,
  mapStyles: const <MapStyleDto>[],
  tileServerBaseUrl: '',
  defaultCenter: const MapCenterDto(lat: 45.7, lon: 4.8, zoom: 9),
  gpsAutoSyncEnabled: false,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<CalendarEventDto> events = const <CalendarEventDto>[],
  Object? eventsError,
  NextRide? next,
  List<TeamDetailDto> teams = const <TeamDetailDto>[],
  Object? teamsError,
  bool singleTeam = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // La politique de l'app : une erreur qui n'est pas passagère s'affiche
      // tout de suite, sans squelette de nouvel essai.
      retry: providerRetry,
      overrides: [
        weekEventsProvider.overrideWith((Ref ref) async {
          if (eventsError != null) throw eventsError;
          return events;
        }),
        nextRideProvider.overrideWith((Ref ref) async => next),
        myTeamsProvider.overrideWith((Ref ref) async {
          if (teamsError != null) throw teamsError;
          return teams;
        }),
        appConfigProvider.overrideWith(
          (Ref ref) async => _config(singleTeam: singleTeam),
        ),
      ],
      child: MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  setUpAll(loadTestTranslations);

  group('weekAgendaEvents', () {
    test('écarte ce qui est terminé et trie par instant', () {
      final List<CalendarEventDto> result = weekAgendaEvents(<CalendarEventDto>[
        _event('tard', start: '2099-07-30T08:00:00Z'),
        _event('fini', start: '2099-07-28T08:00:00Z', finished: true),
        // Même instant que 07:30Z, exprimé dans un autre décalage : il doit
        // se classer en instant, pas en chaîne.
        _event('tot', start: '2099-07-29T09:30:00+02:00'),
      ]);
      expect(result.map((CalendarEventDto e) => e.entitySlug), <String>[
        'tot',
        'tard',
      ]);
    });
  });

  group('Cette semaine', () {
    testWidgets('liste les événements, avec l\'équipe et le badge Inscrit', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const WeekAgendaSection(),
        events: <CalendarEventDto>[
          _event('mardi-soir', registered: true),
          _event(
            'etape-1',
            type: 'TRIP_STAGE',
            tripSlug: 'ardeche',
            teamName: 'Rouleurs du Pilat',
          ),
        ],
      );

      expect(find.text('Les 7 prochains jours'), findsOneWidget);
      expect(find.byKey(keys.home.weekEvent('mardi-soir')), findsOneWidget);
      expect(find.byKey(keys.home.weekEvent('etape-1')), findsOneWidget);
      expect(find.textContaining('VC Craponne'), findsOneWidget);
      expect(find.textContaining('Rouleurs du Pilat'), findsOneWidget);
      expect(find.text('INSCRIT'), findsOneWidget);
    });

    testWidgets('ne répète pas la sortie que « Ma prochaine sortie » montre', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await _pump(
        tester,
        const WeekAgendaSection(),
        next: NextRide(ride: ride, group: null),
        events: <CalendarEventDto>[
          _event(ride.slug, teamSlug: ride.team.slug, registered: true),
          _event('autre'),
        ],
      );

      expect(find.byKey(keys.home.weekEvent(ride.slug)), findsNothing);
      expect(find.byKey(keys.home.weekEvent('autre')), findsOneWidget);
    });

    testWidgets('la prochaine sortie seule : « rien d\'autre », pas « rien »', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await _pump(
        tester,
        const WeekAgendaSection(),
        next: NextRide(ride: ride, group: null),
        events: <CalendarEventDto>[
          _event(ride.slug, teamSlug: ride.team.slug, registered: true),
        ],
      );

      expect(find.byKey(keys.home.weekEmpty), findsOneWidget);
      expect(
        find.text(
          "Rien d'autre de prévu dans vos équipes ces sept prochains jours.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('au-delà de la limite, renvoie le reste au calendrier', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const WeekAgendaSection(),
        events: <CalendarEventDto>[
          for (int i = 0; i < kWeekAgendaLimit + 2; i++) _event('s$i'),
        ],
      );

      expect(find.byKey(keys.home.weekEvent('s0')), findsOneWidget);
      expect(
        find.byKey(keys.home.weekEvent('s$kWeekAgendaLimit')),
        findsNothing,
      );
      expect(find.text('2 autres événements au calendrier'), findsOneWidget);
    });

    testWidgets('une semaine vide se réduit à une carte compacte', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const WeekAgendaSection());

      expect(find.byKey(keys.home.weekEmpty), findsOneWidget);
      expect(
        find.text('Rien de prévu dans vos équipes ces sept prochains jours.'),
        findsOneWidget,
      );
    });

    testWidgets('un échec masque le bloc entier', (WidgetTester tester) async {
      await _pump(
        tester,
        const WeekAgendaSection(),
        eventsError: Exception('boom'),
      );

      expect(find.byKey(keys.home.weekSection), findsNothing);
      expect(find.text('Les 7 prochains jours'), findsNothing);
    });
  });

  group('Mes équipes', () {
    test('la ligne d\'activité omet les zéros', () {
      expect(
        teamActivityLine(
          fixtureTeam(
            upcomingRideCount: 2,
            upcomingTripCount: 0,
            recentPostCount: 1,
          ),
        ),
        '2 sorties à venir · 1 nouvelle publication',
      );
      expect(
        teamActivityLine(
          fixtureTeam(upcomingRideCount: 0, upcomingTripCount: 1),
        ),
        '1 voyage à venir',
      );
    });

    test('sans activité, la ligne retombe sur le nombre de membres', () {
      expect(
        teamActivityLine(fixtureTeam(upcomingRideCount: 0, memberCount: 12)),
        isNot(isEmpty),
      );
      expect(
        teamActivityLine(fixtureTeam(upcomingRideCount: 0, memberCount: 12)),
        contains('12'),
      );
      // Accordé : « 1 membre », jamais « 1 membres » (BRANDING §8.3).
      expect(
        teamActivityLine(fixtureTeam(upcomingRideCount: 0, memberCount: 1)),
        '1 membre',
      );
    });

    testWidgets('chaque équipe montre son rôle et son activité', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const MyTeamsSection(),
        teams: <TeamDetailDto>[
          fixtureTeam(
            slug: 'vc-craponne',
            name: 'VC Craponne',
            role: 'ORGANIZER',
            upcomingRideCount: 2,
            recentPostCount: 1,
          ),
          fixtureTeam(
            slug: 'pilat',
            name: 'Rouleurs du Pilat',
            role: 'MEMBER',
            upcomingRideCount: 0,
            upcomingTripCount: 1,
          ),
        ],
      );

      expect(find.text('Mes équipes'), findsOneWidget);
      expect(find.byKey(keys.home.teamRow('vc-craponne')), findsOneWidget);
      expect(find.byKey(keys.home.teamRow('pilat')), findsOneWidget);
      expect(find.text('ORGANISATEUR'), findsOneWidget);
      expect(find.text('MEMBRE'), findsOneWidget);
      expect(
        find.text('2 sorties à venir · 1 nouvelle publication'),
        findsOneWidget,
      );
      expect(find.text('1 voyage à venir'), findsOneWidget);
      // Rien à « Trouver » quand on a déjà des équipes.
      expect(find.byKey(keys.home.findTeamButton), findsNothing);
    });

    testWidgets('sans équipe, propose d\'en trouver une', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const MyTeamsSection());

      expect(
        find.text('Vous n\'êtes membre d\'aucune équipe.'),
        findsOneWidget,
      );
      expect(find.byKey(keys.home.findTeamButton), findsOneWidget);
    });

    testWidgets('un site mono-équipe ne propose pas d\'en parcourir', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const MyTeamsSection(), singleTeam: true);

      expect(
        find.text('Vous n\'êtes membre d\'aucune équipe.'),
        findsOneWidget,
      );
      expect(find.byKey(keys.home.findTeamButton), findsNothing);
    });

    testWidgets('un échec masque le bloc entier', (WidgetTester tester) async {
      await _pump(
        tester,
        const MyTeamsSection(),
        teamsError: Exception('boom'),
      );

      expect(find.byKey(keys.home.teamsSection), findsNothing);
    });
  });
}
