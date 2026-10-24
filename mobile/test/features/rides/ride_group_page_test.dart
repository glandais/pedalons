import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/participants/data/participant_repository.dart';
import 'package:pedalons/features/participants/domain/participant_query.dart';
import 'package:pedalons/features/rides/data/ride_repository.dart';
import 'package:pedalons/features/rides/domain/ride_group_tab.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_detail_page.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_group_page.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_groups_map.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/features/rides/providers/ride_weather_provider.dart';
import 'package:pedalons/features/rides/providers/ride_scroll_target_provider.dart';
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
  RideWeatherDto weather;
  final List<String> joined = <String>[];
  final List<String> left = <String>[];
  int weatherCalls = 0;

  @override
  Future<RideDto> getRide(String teamSlug, String rideSlug) async => ride;

  @override
  Future<RideWeatherDto> getRideWeather(String t, String r) async {
    weatherCalls++;
    return weather;
  }

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

/// Le serveur des participants : la liste que la barre d'inscription change.
class _Participants implements ParticipantRepository {
  final List<PublicUserDto> people = <PublicUserDto>[
    const PublicUserDto(id: 'u2', displayName: 'Hélène Ebrard'),
  ];
  int calls = 0;

  @override
  Future<PageResult<PublicUserDto>> fetchPage(
    ParticipantQuery query, {
    required int page,
    required int size,
  }) async {
    calls++;
    return PageResult<PublicUserDto>(
      items: List<PublicUserDto>.of(people),
      total: people.length,
    );
  }
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

/// Les paliers asynchrones d'une navigation : traductions, détail,
/// appartenance, puis le départ planifié après le cadre.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
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
  late _Participants participants;

  Future<void> open(
    WidgetTester tester,
    RideWeatherDto dto, {
    RideDto? ride,
    String groupId = 'g1',
    RideGroupTab tab = RideGroupTab.weather,
    UnitSystem units = UnitSystem.metric,
    bool member = true,
    List overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    repository = _Repository(ride ?? twoGroups, dto);
    participants = _Participants();
    container = ProviderContainer(
      retry: (int _, Object _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        unitSystemProvider.overrideWithValue(units),
        rideRepositoryProvider.overrideWithValue(repository),
        participantRepositoryProvider.overrideWithValue(participants),
        teamRepositoryProvider.overrideWithValue(_Teams(member: member)),
        ...overrides,
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

    testWidgets('une prévision perdue éteint le mode « Météo » de la carte', (
      WidgetTester tester,
    ) async {
      await open(tester, weather());
      container.read(rideMapWindModeProvider(key).notifier).state = true;

      repository.weather = fixtureWeather(status: 'UNAVAILABLE');
      container.invalidate(rideWeatherProvider(key));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(container.read(rideMapWindModeProvider(key)), isFalse);

      // Revenue, la prévision ne rallume pas le mode toute seule.
      repository.weather = weather();
      container.invalidate(rideWeatherProvider(key));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(container.read(rideMapWindModeProvider(key)), isFalse);
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

    testWidgets('une sortie terminée ne demande pas sa météo', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          dateTime: '2020-07-29T17:30:00Z',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', name: 'Rapide'),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.weatherEmpty), findsOneWidget);
      expect(repository.weatherCalls, 0);
    });

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
      expect(find.text('CAPITAINE'), findsNothing);
      expect(find.text('Départ'), findsOneWidget);
      expect(find.text('Allure moyenne'), findsOneWidget);
      expect(find.text('Dénivelé positif'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un meneur désigné : son nom et le badge « Capitaine »', (
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
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.leader), findsOneWidget);
      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('CAPITAINE'), findsOneWidget);
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
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(find.text('avec la sortie'), findsOneWidget);
      expect(find.textContaining('Arrivée estimée'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────── la puce « Météo » de la carte

  /// La puce sous la carte encastrée de l'Aperçu (ledger `MOB-91`, test resté
  /// ouvert au ledger `MOB-92`). La carte native est remplacée par sa sonde, la
  /// géométrie reste en vol : la puce n'en dépend pas.
  group('puce « Météo » de la carte', () {
    setUp(() => RideGroupsMap.debugSkipNativeMap = true);
    tearDown(() => RideGroupsMap.debugSkipNativeMap = false);

    final RideDto routed = fixtureRide(
      groups: <RideGroupDto>[
        fixtureGroup(id: 'g1', routeSlug: 'court'),
        fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
      ],
    );
    final List mapOverrides = [
      appConfigProvider.overrideWith(
        (Ref ref) => Completer<ConfigDto>().future,
      ),
      mapStyleProvider.overrideWith(
        (Ref ref, Brightness b) => const AsyncValue<ResolvedMapStyle?>.data(
          ResolvedMapStyle(
            style: MapStyleDto(
              id: 'plan',
              label: 'Plan',
              group: 'vector',
              url: 'https://tiles.example/plan.json',
            ),
            url: 'https://tiles.example/plan.json',
          ),
        ),
      ),
      rideRouteGeometryProvider.overrideWith(
        (Ref ref, RouteRef r) => const AsyncValue<RouteDetailDto>.loading(),
      ),
    ];

    Future<void> openOverview(WidgetTester tester, RideWeatherDto dto) => open(
      tester,
      dto,
      ride: routed,
      tab: RideGroupTab.overview,
      overrides: mapOverrides,
    );

    testWidgets('sans prévision chargée (leg nul) : pas de puce', (
      WidgetTester tester,
    ) async {
      await openOverview(tester, fixtureWeather());

      expect(find.byType(RideGroupsMap), findsOneWidget);
      expect(find.byKey(keys.rideGroup.windMapChip), findsNothing);
    });

    testWidgets('NOT_YET_AVAILABLE : pas de puce', (WidgetTester tester) async {
      await openOverview(
        tester,
        weather(
          status: 'NOT_YET_AVAILABLE',
          legs: <WeatherLegDto>[fixtureLeg(status: 'NOT_YET_AVAILABLE')],
        ),
      );

      expect(find.byType(RideGroupsMap), findsOneWidget);
      expect(find.byKey(keys.rideGroup.windMapChip), findsNothing);
    });

    for (final String status in <String>['OK', 'STALE']) {
      testWidgets(
        '$status : la puce, éteinte par défaut ; un appui l\'allume',
        (WidgetTester tester) async {
          await openOverview(
            tester,
            weather(
              status: status,
              legs: <WeatherLegDto>[fixtureLeg(status: status)],
            ),
          );

          final Finder chip = find.byKey(keys.rideGroup.windMapChip);
          expect(chip, findsOneWidget);
          // Aucun override du mode : son défaut, éteint.
          expect(tester.widget<PdlChip>(chip).selected, isFalse);
          expect(container.read(rideMapWindModeProvider(key)), isFalse);

          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pump();

          expect(container.read(rideMapWindModeProvider(key)), isTrue);
          expect(tester.widget<PdlChip>(chip).selected, isTrue);
        },
      );
    }
  });

  // ──────────────────────────────────────────────────── barre d'inscription

  group('barre d\'inscription', () {
    testWidgets('un membre rejoint le groupe', (WidgetTester tester) async {
      await open(tester, weather(), tab: RideGroupTab.overview);

      expect(find.byKey(keys.rideGroup.participantsCount), findsOneWidget);
      expect(find.text('3/16 personnes'), findsOneWidget);
      expect(find.text('13 places restantes'), findsOneWidget);
      expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);

      await tester.tap(find.byKey(keys.rideGroup.joinButton));
      await tester.pump();
      await tester.pump();

      expect(repository.joined, <String>['g1']);
    });

    testWidgets('rejoindre depuis l\'onglet Participants recharge la liste', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(), tab: RideGroupTab.participants);

      expect(find.text('Hélène Ebrard'), findsOneWidget);
      expect(find.text('Gaby Landais'), findsNothing);
      final int before = participants.calls;

      participants.people.add(
        const PublicUserDto(id: 'u3', displayName: 'Gaby Landais'),
      );
      await tester.tap(find.byKey(keys.rideGroup.joinButton));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(repository.joined, <String>['g1']);
      expect(participants.calls, greaterThan(before));
      expect(find.text('Gaby Landais'), findsOneWidget);
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
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', registered: true),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
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
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.fullBadge), findsOneWidget);
      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);
      expect(find.text('16/16 personnes'), findsOneWidget);
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
          find.text('Votre inscription est dans le groupe Cool.'),
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

  // ─────────────────────────────── sortie solo ou sans groupe (ledger MOB-69)

  group('une sortie à un groupe quitte la page pour son détail', () {
    final RideDto solo = fixtureRide(
      groups: <RideGroupDto>[fixtureGroup(id: 'g1', name: 'Rapide')],
    );
    const Key home = Key('home');

    late GoRouter router;

    Future<void> mount(
      WidgetTester tester,
      RideDto ride, {
      String initialLocation = '/',
      bool nested = false,
    }) async {
      repository = _Repository(ride, weather());
      participants = _Participants();
      container = ProviderContainer(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          rideRepositoryProvider.overrideWithValue(repository),
          participantRepositoryProvider.overrideWithValue(participants),
          teamRepositoryProvider.overrideWithValue(_Teams(member: true)),
        ],
      );
      addTearDown(container.dispose);
      GoRoute groupRoute(String path) => GoRoute(
        path: path,
        builder: (BuildContext _, GoRouterState state) => RideGroupPage(
          teamSlug: state.pathParameters['teamSlug']!,
          rideSlug: state.pathParameters['rideSlug']!,
          groupId: state.pathParameters['groupId']!,
          initialTab: RideGroupTab.fromQuery(state.uri.queryParameters['tab']),
        ),
      );
      router = GoRouter(
        initialLocation: initialLocation,
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext _, GoRouterState _) =>
                const Scaffold(body: Text('Accueil', key: home)),
          ),
          for (final MapEntry<String, String> ridePath in PathVariants.ride(
            ':teamSlug',
            ':rideSlug',
          ).entries)
            GoRoute(
              path: ridePath.value,
              builder: (BuildContext _, GoRouterState state) => RideDetailPage(
                teamSlug: state.pathParameters['teamSlug']!,
                rideSlug: state.pathParameters['rideSlug']!,
              ),
              // Comme `router.dart` : la page d'un groupe est une route fille
              // du détail, qu'un lien profond reconstruit dessous.
              routes: <RouteBase>[
                if (nested)
                  groupRoute(
                    PathVariants.rideGroup(
                      ':teamSlug',
                      ':rideSlug',
                      ':groupId',
                    )[ridePath.key]!.substring(ridePath.value.length + 1),
                  ),
              ],
            ),
          if (!nested)
            for (final String path in PathVariants.rideGroup(
              ':teamSlug',
              ':rideSlug',
              ':groupId',
            ).values)
              groupRoute(path),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: PedalonsTheme.build(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
    }

    final String ridePath = Paths.ride(key.teamSlug, key.rideSlug);
    String groupPath(String id) =>
        Paths.rideGroup(key.teamSlug, key.rideSlug, id);

    testWidgets('poussée au-dessus du détail : elle s\'efface, le détail reste', (
      WidgetTester tester,
    ) async {
      await mount(tester, solo);
      unawaited(router.push(ridePath));
      await settle(tester);
      expect(find.byType(RideDetailPage), findsOneWidget);

      unawaited(router.push('${groupPath('g1')}?tab=weather'));
      await settle(tester);

      expect(find.byType(RideGroupPage), findsNothing);
      expect(find.byType(RideDetailPage), findsOneWidget);
      // L'onglet Météo devient un défilement du détail, consommé par lui.
      expect(container.read(rideScrollToWeatherProvider(key)), isFalse);

      // Un seul retour mène à l'écran d'avant le détail : pas d'entrée laissée.
      router.pop();
      await settle(tester);
      expect(find.byKey(home), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'poussée au-dessus d\'un autre écran : remplacée par le détail',
      (WidgetTester tester) async {
        await mount(tester, solo);
        unawaited(router.push(groupPath('g1')));
        await settle(tester);

        expect(find.byType(RideGroupPage), findsNothing);
        expect(find.byType(RideDetailPage), findsOneWidget);

        router.pop();
        await settle(tester);
        expect(find.byKey(home), findsOneWidget);
        expect(find.byType(RideDetailPage), findsNothing);
      },
    );

    testWidgets('ouverte à froid : le détail', (WidgetTester tester) async {
      await mount(tester, solo, initialLocation: groupPath('g1'));

      expect(find.byType(RideGroupPage), findsNothing);
      expect(find.byType(RideDetailPage), findsOneWidget);
      expect(router.canPop(), isFalse);
    });

    testWidgets(
      'lien profond dans la hiérarchie de l\'app : retour au détail reconstruit dessous',
      (WidgetTester tester) async {
        await mount(
          tester,
          solo,
          initialLocation: '${groupPath('g1')}?tab=weather',
          nested: true,
        );

        expect(find.byType(RideGroupPage), findsNothing);
        expect(find.byType(RideDetailPage), findsOneWidget);
        expect(router.routerDelegate.currentConfiguration.uri.path, ridePath);
        expect(container.read(rideScrollToWeatherProvider(key)), isFalse);
        expect(router.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('un groupe disparu d\'une sortie solo : le détail aussi', (
      WidgetTester tester,
    ) async {
      await mount(tester, solo, initialLocation: groupPath('gone'));

      expect(find.byKey(keys.rideGroup.notFound), findsNothing);
      expect(find.byType(RideDetailPage), findsOneWidget);
    });

    testWidgets('une sortie sans groupe : le détail', (
      WidgetTester tester,
    ) async {
      await mount(
        tester,
        fixtureRide(groups: const <RideGroupDto>[]),
        initialLocation: groupPath('g1'),
      );

      expect(find.byType(RideGroupPage), findsNothing);
      expect(find.byType(RideDetailPage), findsOneWidget);
    });

    testWidgets('deux groupes et un id inconnu : l\'état vide, inchangé', (
      WidgetTester tester,
    ) async {
      await mount(tester, twoGroups, initialLocation: groupPath('gone'));

      expect(find.byType(RideGroupPage), findsOneWidget);
      expect(find.byKey(keys.rideGroup.notFound), findsOneWidget);
    });
  });
}
