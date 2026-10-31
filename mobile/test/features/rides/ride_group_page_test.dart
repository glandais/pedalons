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
import 'package:pedalons/core/theme/enum_colors.dart';
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
import 'package:pedalons/features/routes/domain/track_surfaces.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_color_mode_switch.dart';
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

    testWidgets('une prévision perdue ramène le mode « Météo » sur la pente', (
      WidgetTester tester,
    ) async {
      await open(tester, weather());
      container.read(rideMapColorModeProvider(key).notifier).state =
          RouteColorBy.wind;

      repository.weather = fixtureWeather(status: 'UNAVAILABLE');
      container.invalidate(rideWeatherProvider(key));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);

      // Revenue, la prévision ne rallume pas le mode toute seule.
      repository.weather = weather();
      container.invalidate(rideWeatherProvider(key));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);
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

    testWidgets('sans prévision chargée (leg nul) : pas de Météo', (
      WidgetTester tester,
    ) async {
      await openOverview(tester, fixtureWeather());

      expect(find.byType(RideGroupsMap), findsOneWidget);
      expect(find.byKey(keys.routeDetail.colorByMode('wind')), findsNothing);
    });

    testWidgets('NOT_YET_AVAILABLE : pas de Météo', (
      WidgetTester tester,
    ) async {
      await openOverview(
        tester,
        weather(
          status: 'NOT_YET_AVAILABLE',
          legs: <WeatherLegDto>[fixtureLeg(status: 'NOT_YET_AVAILABLE')],
        ),
      );

      expect(find.byType(RideGroupsMap), findsOneWidget);
      expect(find.byKey(keys.routeDetail.colorByMode('wind')), findsNothing);
    });

    for (final String status in <String>['OK', 'STALE']) {
      testWidgets(
        '$status : l\'interrupteur, sur la pente par défaut ; Météo au toucher',
        (WidgetTester tester) async {
          await openOverview(
            tester,
            weather(
              status: status,
              legs: <WeatherLegDto>[fixtureLeg(status: status)],
            ),
          );

          final Finder toggle = find.byKey(keys.rideGroup.mapColorBy);
          expect(toggle, findsOneWidget);
          // Aucun override du mode : son défaut, la pente.
          expect(
            tester.widget<RouteColorModeSwitch>(toggle).value,
            RouteColorBy.grade,
          );
          expect(
            container.read(rideMapColorModeProvider(key)),
            RouteColorBy.grade,
          );

          final Finder wind = find.byKey(keys.routeDetail.colorByMode('wind'));
          await tester.ensureVisible(wind);
          await tester.tap(wind);
          await tester.pump();

          expect(
            container.read(rideMapColorModeProvider(key)),
            RouteColorBy.wind,
          );
          expect(
            tester.widget<RouteColorModeSwitch>(toggle).value,
            RouteColorBy.wind,
          );
        },
      );
    }
  });

  // ────────────────────────────────────── la carte de l'onglet Météo

  /// La carte encastrée en tête de l'onglet Météo (ledger `MOB-93`) : en mode
  /// « Météo » d'office, sans toucher au choix de l'Aperçu, et le réticule
  /// d'un point de la frise.
  group('carte de l\'onglet Météo', () {
    setUp(() => RideGroupsMap.debugSkipNativeMap = true);
    tearDown(() => RideGroupsMap.debugSkipNativeMap = false);

    final RideDto routed = fixtureRide(
      groups: <RideGroupDto>[
        fixtureGroup(id: 'g1', name: 'Rapide', routeSlug: 'court'),
        fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
      ],
    );
    TrackDto trackOf(List<List<double>> coordinates) => TrackDto(
      line: GeoJsonLineString(
        type: GeoJsonLineStringTypeType.lineString,
        coordinates: coordinates,
      ),
      climbs: const <ClimbDto>[],
    );
    // Deux traces : 10 km plein nord, un saut de ~8 km vers l'est, puis 20 km
    // dont la distance repart de 0 — 30 km chaînés, saut nul.
    final RouteDetailDto route = RouteDetailDto(
      elevationState: 'HD',
      tags: const [],
      id: 'r-court',
      slug: 'court',
      team: routed.team,
      name: 'Court',
      media: routed.media,
      distance: 30000,
      elevationGain: 0,
      elevationLoss: 0,
      surfaceType: 'ROAD',
      visibility: 'PUBLIC',
      createdBy: const PublicUserDto(id: 'u9', displayName: 'Créatrice'),
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
      tracks: <TrackDto>[
        trackOf(<List<double>>[
          for (int i = 0; i <= 10; i++)
            <double>[5, 45 + i * 0.009, 300, i * 1000.0],
        ]),
        trackOf(<List<double>>[
          for (int j = 0; j <= 20; j++)
            <double>[5.1, 45 + (10 + j) * 0.009, 300, j * 1000.0],
        ]),
      ],
      waypoints: const <WaypointDto>[],
      deleted: false,
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
        (Ref ref, RouteRef r) => AsyncValue<RouteDetailDto>.data(route),
      ),
    ];

    Future<void> openWeather(
      WidgetTester tester,
      RideWeatherDto dto, {
      RideGroupTab tab = RideGroupTab.weather,
    }) => open(tester, dto, ride: routed, tab: tab, overrides: mapOverrides);

    Finder tabMap() => find.byKey(keys.rideGroup.weatherTabMap);

    PdlMap probe(WidgetTester tester) =>
        tester.widget<RideGroupsMapProbe>(find.byType(RideGroupsMapProbe)).map;

    /// Le tracé porte-t-il le vent ? Hors Météo il se colore par la pente
    /// (ledger `MOB-105`), jamais plus `null`.
    bool windy(WidgetTester tester) =>
        probe(tester).tracks.single.segmentColors!
            .contains(RelativeWind.tail.stroke);

    for (final String status in <String>['OK', 'STALE']) {
      testWidgets('$status : la carte en tête, tracé coloré d\'office, sans '
          'interrupteur ni pastille', (WidgetTester tester) async {
        await openWeather(
          tester,
          weather(
            status: status,
            legs: <WeatherLegDto>[fixtureLeg(status: status)],
          ),
        );

        expect(tabMap(), findsOneWidget);
        // Une seule carte sur la page : l'Aperçu n'est pas monté.
        expect(find.byType(RideGroupsMap), findsOneWidget);
        expect(tester.widget<RideGroupsMap>(tabMap()).forceWeatherMode, isTrue);
        expect(probe(tester).tracks.single.segmentColors, isNotNull);
        expect(probe(tester).markers, isEmpty);
        expect(find.byKey(keys.rideGroup.windMapLegend), findsOneWidget);
        expect(find.byKey(keys.rideGroup.windMapCredit), findsOneWidget);
        expect(find.byKey(keys.rideGroup.mapColorBy), findsNothing);
        // Le choix de l'Aperçu n'a pas bougé.
        expect(
          container.read(rideMapColorModeProvider(key)),
          RouteColorBy.grade,
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final String legStatus in <String>[
      'NOT_YET_AVAILABLE',
      'UNAVAILABLE',
      'NO_LOCATION',
    ]) {
      testWidgets('un leg $legStatus : pas de carte', (
        WidgetTester tester,
      ) async {
        await openWeather(
          tester,
          weather(legs: <WeatherLegDto>[fixtureLeg(status: legStatus)]),
        );

        expect(tabMap(), findsNothing);
        expect(find.byType(RideGroupsMap), findsNothing);
      });
    }

    testWidgets('sans leg pour ce groupe : pas de carte', (
      WidgetTester tester,
    ) async {
      await openWeather(
        tester,
        weather(legs: <WeatherLegDto>[fixtureLeg(groupId: 'g2')]),
      );

      expect(tabMap(), findsNothing);
    });

    testWidgets('NOT_YET_AVAILABLE pour toute la sortie : pas de carte', (
      WidgetTester tester,
    ) async {
      await openWeather(
        tester,
        fixtureWeather(
          status: 'NOT_YET_AVAILABLE',
          availableFrom: '2099-07-22T19:30:00Z',
        ),
      );

      expect(tabMap(), findsNothing);
    });

    testWidgets('un groupe sans parcours : pas de carte', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(), ride: twoGroups, overrides: mapOverrides);

      expect(tabMap(), findsNothing);
      expect(find.byKey(keys.ride.weatherCheckpoint(1)), findsOneWidget);
    });

    testWidgets('toucher un point de la frise pose le réticule à sa distance '
        'chaînée ; le retoucher l\'ôte', (WidgetTester tester) async {
      await openWeather(tester, weather());
      expect(probe(tester).cursor, isNull);

      // 15 km chaînés : le 5ᵉ kilomètre de la seconde trace, saut ignoré.
      final Finder enRoute = find.byKey(keys.ride.weatherCheckpoint(1));
      await tester.ensureVisible(enRoute);
      await tester.tap(enRoute);
      await tester.pump();
      expect(probe(tester).cursor!.lon, 5.1);
      expect(probe(tester).cursor!.lat, closeTo(45 + 15 * 0.009, 1e-9));
      expect(
        tester.getSemantics(enRoute),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );

      // L'arrivée, au bout de la seconde trace.
      final Finder finish = find.byKey(keys.ride.weatherCheckpoint(2));
      await tester.ensureVisible(finish);
      await tester.tap(finish);
      await tester.pump();
      expect(probe(tester).cursor!.lon, 5.1);
      expect(probe(tester).cursor!.lat, closeTo(45 + 30 * 0.009, 1e-9));

      await tester.tap(finish);
      await tester.pump();
      expect(probe(tester).cursor, isNull);
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);
    });

    testWidgets('un toucher sur la carte ouvre le plein écran en mode Météo, '
        'réticule compris', (WidgetTester tester) async {
      await openWeather(tester, weather());
      final Finder start = find.byKey(keys.ride.weatherCheckpoint(0));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pump();

      await tester.ensureVisible(tabMap());
      await tester.tap(find.byKey(PdlMapHero.tapTargetKey));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final RideGroupsMap full = tester.widget<RideGroupsMap>(
        find.byWidgetPredicate(
          (Widget w) => w is RideGroupsMap && w.fullscreen,
        ),
      );
      expect(full.forceWeatherMode, isTrue);
      expect(full.cursorDistance, 0);
      final PdlMap fullMap = tester
          .widget<RideGroupsMapProbe>(find.byType(RideGroupsMapProbe).last)
          .map;
      expect(fullMap.markers, isNotEmpty);
      expect(fullMap.cursor!.lat, closeTo(45, 1e-9));
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);
    });

    testWidgets('l\'Aperçu reste tel quel : la pente, l\'interrupteur, pas de '
        'toucher plein écran', (WidgetTester tester) async {
      await openWeather(tester, weather(), tab: RideGroupTab.overview);

      expect(tabMap(), findsNothing);
      final RideGroupsMap overview = tester.widget<RideGroupsMap>(
        find.byType(RideGroupsMap),
      );
      expect(overview.forceWeatherMode, isFalse);
      expect(overview.cursorDistance, isNull);
      expect(windy(tester), isFalse);
      expect(find.byKey(keys.rideGroup.mapColorBy), findsOneWidget);
      expect(find.byKey(PdlMapHero.tapTargetKey), findsNothing);

      // La personne choisit « Météo » dans l'Aperçu…
      final Finder chip = find.byKey(keys.routeDetail.colorByMode('wind'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.wind);
      expect(windy(tester), isTrue);

      // … aller sur l'onglet Météo, où l'Aperçu est démonté et la carte
      // impose le mode sans lire ce choix, puis revenir ne le perd pas.
      await tester.tap(find.byKey(keys.rideGroup.tabWeather));
      await tester.pump();
      expect(tabMap(), findsOneWidget);
      expect(find.byType(RideGroupsMap), findsOneWidget);
      await tester.tap(find.byKey(keys.rideGroup.tabOverview));
      await tester.pump();
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.wind);
      expect(
        tester
            .widget<RouteColorModeSwitch>(find.byKey(keys.rideGroup.mapColorBy))
            .value,
        RouteColorBy.wind,
      );
      expect(windy(tester), isTrue);
      // Le profil remonté avec l'Aperçu finit ses cadres.
      await settle(tester);
    });
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

    testWidgets('un non-membre ne reçoit que le nombre : ni onglet, ni liste, '
        'ni « Voir tout »', (WidgetTester tester) async {
      // Le serveur lui envoie `participants: []` et un meneur nul ; l'onglet
      // demandé par lien (`?tab=participants`) retombe sur l'Aperçu.
      final RideDto stripped = fixtureRide(
        groups: <RideGroupDto>[
          for (final RideGroupDto g in twoGroups.groups)
            g.copyWith(participants: const <PublicUserDto>[], leader: null),
        ],
      );
      await open(
        tester,
        weather(),
        ride: stripped,
        tab: RideGroupTab.participants,
        member: false,
      );

      expect(find.byKey(keys.rideGroup.tabParticipants), findsNothing);
      expect(find.byKey(keys.rideGroup.tabOverview), findsOneWidget);
      expect(find.byKey(keys.rideGroup.viewAllParticipants), findsNothing);
      expect(find.text('Hélène Ebrard'), findsNothing);
      expect(participants.calls, 0);
      expect(find.byKey(keys.rideGroup.leader), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un membre garde l\'onglet Participants et « Voir tout »', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(), tab: RideGroupTab.overview);

      expect(find.byKey(keys.rideGroup.tabParticipants), findsOneWidget);
      expect(find.byKey(keys.rideGroup.viewAllParticipants), findsOneWidget);
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

    testWidgets(
      'poussée au-dessus du détail : elle s\'efface, le détail reste',
      (WidgetTester tester) async {
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
      },
    );

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
