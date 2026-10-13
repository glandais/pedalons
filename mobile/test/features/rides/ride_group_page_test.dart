import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/data/ride_repository.dart';
import 'package:pedalons/features/rides/domain/ride_group_tab.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_group_page.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// La page d'un groupe de sortie (ledger `MOB-67`) : l'onglet Météo — ce que
/// montrait l'écran « Météo du parcours », pour ce groupe —, l'Aperçu et son
/// meneur, la barre d'inscription, les pastilles qui partagent la sélection
/// avec le détail, et le groupe disparu.
class _Repository implements RideRepository {
  _Repository(this.ride, this.weather);

  final RideDto ride;
  final RideWeatherDto weather;
  final List<String> joined = <String>[];
  final List<String> left = <String>[];

  @override
  Future<RideDto> getRide(String teamSlug, String rideSlug) async => ride;

  @override
  Future<RideWeatherDto> getRideWeather(String t, String r) async => weather;

  @override
  Future<RideParticipationDto> joinGroup(String t, String r, String g) async {
    joined.add(g);
    return const RideParticipationDto(id: 'p', userId: 'u');
  }

  @override
  Future<void> leaveGroup(String t, String r, String g) async => left.add(g);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Teams implements TeamRepository {
  _Teams({required this.member});

  final bool member;

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => member
      ? <TeamDetailDto>[
          const TeamDetailDto(
            timezone: 'Europe/Paris',
            id: 't1',
            slug: 'n-peloton',
            name: 'N-Peloton',
            about: MediaDto(
              markdown: '',
              assets: AssetsDto(
                images: <AssetDto>[],
                attachments: <AssetDto>[],
              ),
            ),
            visibility: 'PUBLIC',
            enableTrips: true,
            enableAds: true,
            enablePosts: true,
            enableRides: true,
            enableRoutes: true,
            visibilityEditable: true,
            joinable: true,
            addMemberAllowed: true,
            enableMemberDirectory: false,
            postsAsTeamByDefault: true,
            enableRoutePlanner: false,
            memberCount: 40,
            upcomingRideCount: 3,
            routeCount: 12,
            upcomingTripCount: 0,
            recentPostCount: 0,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ]
      : <TeamDetailDto>[];

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

  final RideDto twoGroups = fixtureRide(
    groups: <RideGroupDto>[
      fixtureGroup(id: 'g1', name: 'Rapide'),
      fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
    ],
  );
  const RideKey key = RideKey(teamSlug: 'n-peloton', rideSlug: 'np-665');

  RideWeatherDto weather({String status = 'OK', List<WeatherLegDto>? legs}) =>
      fixtureWeather(
        status: status,
        departure: fixtureConditions(),
        fetchedAt: '2099-07-29T17:00:00Z',
        legs:
            legs ??
            <WeatherLegDto>[
              fixtureLeg(
                groupId: 'g1',
                rainAlert: const WeatherRainAlertDto(
                  probability: 70,
                  time: '2099-07-29T20:05:00Z',
                  condition: 'RAIN',
                  distance: 15000,
                ),
              ),
              fixtureLeg(
                groupId: 'g2',
                speedIsDefault: true,
                relativeWind: 'CROSS',
              ),
            ],
      );

  late ProviderContainer container;
  late _Repository repository;

  Future<void> open(
    WidgetTester tester,
    RideWeatherDto dto, {
    RideDto? ride,
    String groupId = 'g1',
    RideGroupTab tab = RideGroupTab.weather,
    UnitSystem units = UnitSystem.metric,
    bool member = true,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    repository = _Repository(ride ?? twoGroups, dto);
    container = ProviderContainer(
      retry: (int _, Object _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        unitSystemProvider.overrideWithValue(units),
        rideRepositoryProvider.overrideWithValue(repository),
        teamRepositoryProvider.overrideWithValue(_Teams(member: member)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: RideGroupPage(
            teamSlug: key.teamSlug,
            rideSlug: key.rideSlug,
            groupId: groupId,
            initialTab: tab,
          ),
        ),
      ),
    );
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  test('?tab= ouvre l\'onglet demandé, l\'Aperçu par défaut', () {
    expect(RideGroupTab.fromQuery('weather'), RideGroupTab.weather);
    expect(RideGroupTab.fromQuery('participants'), RideGroupTab.participants);
    expect(RideGroupTab.fromQuery('overview'), RideGroupTab.overview);
    expect(RideGroupTab.fromQuery(null), RideGroupTab.overview);
    expect(RideGroupTab.fromQuery('nope'), RideGroupTab.overview);
  });

  // ─────────────────────────────────────────────────────────── onglet Météo

  group('onglet Météo', () {
    testWidgets('le départ, l\'en-tête du leg, l\'alerte, l\'exposition et la '
        'frise', (WidgetTester tester) async {
      await open(tester, weather());

      expect(find.text('Groupe Rapide'), findsOneWidget);
      expect(find.text('Météo au départ'), findsOneWidget);
      expect(find.text('14 °C'), findsWidgets);
      expect(find.textContaining('Pluie probable (70 %)'), findsOneWidget);
      expect(find.text('Exposition au vent'), findsOneWidget);
      expect(find.byType(PdlSegmentBar), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(1)), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(2)), findsOneWidget);
      expect(find.text('Prévision pas encore disponible ici'), findsOneWidget);
      expect(find.text('FACE'), findsOneWidget);
      expect(find.text('DOS'), findsOneWidget);
      expect(find.text('Prévisions : Open-Meteo.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('une pastille change de groupe, et le partage avec le détail', (
      WidgetTester tester,
    ) async {
      await open(tester, weather());

      // La page pose son groupe dans la sélection partagée.
      expect(container.read(selectedRideGroupProvider(key)), 'g1');
      expect(find.byKey(keys.rideGroup.groupChip('g1')), findsOneWidget);
      expect(find.byKey(keys.rideGroup.groupChip('g2')), findsOneWidget);
      expect(find.textContaining('Pluie probable'), findsOneWidget);
      expect(find.textContaining('vitesse par défaut'), findsNothing);

      await tester.tap(find.byKey(keys.rideGroup.groupChip('g2')));
      await tester.pump();
      await tester.pump();

      expect(container.read(selectedRideGroupProvider(key)), 'g2');
      expect(find.text('Groupe Cool'), findsOneWidget);
      expect(find.textContaining('Pluie probable'), findsNothing);
      expect(find.textContaining('vitesse par défaut'), findsOneWidget);
      expect(find.text('TRAVERS'), findsOneWidget);
    });

    testWidgets('STALE se signale par un bandeau', (WidgetTester tester) async {
      await open(tester, weather(status: 'STALE'));

      expect(
        find.textContaining('Prévision ancienne', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('un groupe sans parcours dit qu\'il n\'y a que le départ', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(
          legs: <WeatherLegDto>[
            WeatherLegDto(
              status: 'NO_LOCATION',
              groupId: 'g1',
              startTime: '2099-07-29T19:30:00Z',
              averageSpeed: 25,
              speedIsDefault: true,
              distance: 0,
              arrivalTime: '2099-07-29T19:30:00Z',
              checkpoints: const <WeatherCheckpointDto>[],
              segments: const <WindSegmentDto>[],
              windExposure: const WindExposureDto(head: 0, cross: 0, tail: 0),
            ),
          ],
        ),
      );

      expect(
        find.textContaining('n\'a pas de parcours', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(PdlSegmentBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final String legStatus in <String>[
      'UNAVAILABLE',
      'NOT_YET_AVAILABLE',
      'SOMETHING_NEW',
    ]) {
      testWidgets('un leg $legStatus : un bandeau, pas de frise', (
        WidgetTester tester,
      ) async {
        await open(
          tester,
          weather(legs: <WeatherLegDto>[fixtureLeg(status: legStatus)]),
        );

        expect(find.byKey(keys.ride.weatherLegUnavailable), findsOneWidget);
        expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);
        expect(find.byType(PdlSegmentBar), findsNothing);
        expect(find.text('Météo au départ'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('le leg d\'un autre groupe n\'est jamais prêté à celui-ci', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(legs: <WeatherLegDto>[fixtureLeg(groupId: 'g2')]),
      );

      expect(find.text('Météo au départ'), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en impérial, des °F et des mph', (WidgetTester tester) async {
      await open(tester, weather(), units: UnitSystem.imperial);

      expect(find.text('58 °F'), findsWidgets);
      expect(find.textContaining('mph'), findsWidgets);
      expect(find.textContaining('°C'), findsNothing);
    });

    testWidgets('UNAVAILABLE : un état d\'erreur et « Réessayer »', (
      WidgetTester tester,
    ) async {
      await open(tester, fixtureWeather(status: 'UNAVAILABLE'));

      expect(find.byKey(keys.ride.weatherUnavailable), findsOneWidget);
      expect(find.byKey(keys.ride.weatherRetryButton), findsOneWidget);
    });

    // `NO_LOCATION` ici pour un membre qui n'organise pas.
    for (final String status in <String>[
      'OUT_OF_RANGE',
      'NO_LOCATION',
      'SOMETHING_NEW',
    ]) {
      testWidgets('$status : un état neutre, pas un onglet blanc', (
        WidgetTester tester,
      ) async {
        await open(tester, fixtureWeather(status: status));

        expect(find.byKey(keys.rideGroup.weatherEmpty), findsOneWidget);
        expect(find.byKey(keys.ride.weatherNoLocation), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('NOT_YET_AVAILABLE donne la date d\'ouverture', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        fixtureWeather(
          status: 'NOT_YET_AVAILABLE',
          availableFrom: '2099-07-22T19:30:00Z',
        ),
      );

      expect(find.byKey(keys.ride.weatherNotYetAvailable), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────── Aperçu

  group('Aperçu', () {
    testWidgets('meneur nul : rien, et jamais le créateur de la sortie', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(), tab: RideGroupTab.overview);

      expect(find.byKey(keys.rideGroup.leader), findsNothing);
      expect(find.text('MENEUR'), findsNothing);
      expect(find.text('Départ'), findsOneWidget);
      expect(find.text('Allure moyenne'), findsOneWidget);
      expect(find.text('Dénivelé positif'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un meneur désigné : son nom et le badge « Meneur »', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        tab: RideGroupTab.overview,
        ride: fixtureRide(
          groups: <RideGroupDto>[
            fixtureGroup(
              id: 'g1',
              leader: const PublicUserDto(id: 'l1', displayName: 'Léa'),
            ),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.leader), findsOneWidget);
      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('MENEUR'), findsOneWidget);
    });

    testWidgets('le résumé météo du groupe ouvre l\'onglet Météo', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(), tab: RideGroupTab.overview);

      expect(find.byKey(keys.rideGroup.weatherSummaryCard), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);

      await tester.ensureVisible(find.byKey(keys.rideGroup.weatherSummaryCard));
      await tester.tap(find.byKey(keys.rideGroup.weatherSummaryCard));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsOneWidget);
    });

    testWidgets('départ avec la sortie, arrivée estimée du leg', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        tab: RideGroupTab.overview,
        ride: fixtureRide(
          dateTime: '2099-07-29T19:30:00Z',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', startAt: '2099-07-29T19:30:00Z'),
          ],
        ),
      );

      expect(find.text('avec la sortie'), findsOneWidget);
      expect(find.textContaining('Arrivée estimée'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────── barre d'inscription

  group('barre d\'inscription', () {
    testWidgets('un membre rejoint le groupe', (WidgetTester tester) async {
      await open(tester, weather(), tab: RideGroupTab.overview);

      expect(find.byKey(keys.rideGroup.participantsCount), findsOneWidget);
      expect(find.text('3/16 participants'), findsOneWidget);
      expect(find.text('13 places restantes'), findsOneWidget);
      expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);

      await tester.tap(find.byKey(keys.rideGroup.joinButton));
      await tester.pump();
      await tester.pump();

      expect(repository.joined, <String>['g1']);
    });

    testWidgets('inscrit dans ce groupe : « Quitter »', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        tab: RideGroupTab.overview,
        ride: fixtureRide(
          registered: true,
          registeredGroupId: 'g1',
          groups: <RideGroupDto>[fixtureGroup(id: 'g1', registered: true)],
        ),
      );

      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      await tester.tap(find.byKey(keys.rideGroup.leaveButton));
      await tester.pump();
      await tester.pump();

      expect(repository.left, <String>['g1']);
    });

    testWidgets('un groupe complet : le badge, aucun bouton', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        tab: RideGroupTab.overview,
        ride: fixtureRide(
          groups: <RideGroupDto>[
            fixtureGroup(
              id: 'g1',
              full: true,
              countParticipants: 16,
              maxParticipants: 16,
            ),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.fullBadge), findsOneWidget);
      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);
      expect(find.text('16/16 participants'), findsOneWidget);
    });

    testWidgets(
      'inscrit dans un autre groupe : la mention, pas « Rejoindre »',
      (WidgetTester tester) async {
        await open(
          tester,
          weather(),
          tab: RideGroupTab.overview,
          ride: fixtureRide(
            registered: true,
            registeredGroupId: 'g2',
            groups: <RideGroupDto>[
              fixtureGroup(id: 'g1', name: 'Rapide'),
              fixtureGroup(
                id: 'g2',
                name: 'Cool',
                sortOrder: 1,
                registered: true,
              ),
            ],
          ),
        );

        expect(find.byKey(keys.rideGroup.registeredElsewhere), findsOneWidget);
        expect(
          find.text('Vous êtes inscrit dans le groupe Cool.'),
          findsOneWidget,
        );
        expect(find.byKey(keys.rideGroup.joinButton), findsNothing);

        await tester.tap(find.byKey(keys.rideGroup.viewMyGroup));
        await tester.pump();
        await tester.pump();

        expect(find.text('Groupe Cool'), findsOneWidget);
        expect(find.byKey(keys.rideGroup.leaveButton), findsOneWidget);
        expect(container.read(selectedRideGroupProvider(key)), 'g2');
      },
    );

    testWidgets('un non-membre ne voit aucun bouton', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(), tab: RideGroupTab.overview, member: false);

      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      expect(find.byKey(keys.rideGroup.participantsCount), findsOneWidget);
    });
  });

  testWidgets('un groupe disparu : un état vide et le retour à la sortie', (
    WidgetTester tester,
  ) async {
    await open(tester, weather(), groupId: 'gone');

    expect(find.byKey(keys.rideGroup.notFound), findsOneWidget);
    expect(find.text('Ce groupe n\'existe plus'), findsOneWidget);
    expect(find.byKey(keys.rideGroup.backToRide), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
