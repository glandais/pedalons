import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/enum_colors.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/comments/data/comment_repository.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/domain/track_surfaces.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_color_mode_switch.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_map.dart';
import 'package:pedalons/features/routes/providers/route_detail_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/trips/data/trip_repository.dart';
import 'package:pedalons/features/trips/domain/trip_weather_map.dart';
import 'package:pedalons/features/trips/presentation/pages/stage_detail_page.dart';
import 'package:pedalons/features/trips/providers/trip_detail_provider.dart';
import 'package:pedalons/features/trips/providers/trip_weather_provider.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import '../rides/ride_fixtures.dart';
import 'trip_fixtures.dart';

/// La carte du détail d'une étape en mode « Météo » (ledger `MOB-94`) : la
/// carte de son parcours (`EmbeddedRouteSheet` → `RouteMap`), comme
/// l'Aperçu d'un groupe — l'interrupteur Pente | Revêtement | Météo sous la
/// carte (ledger `MOB-105`), sur la pente par défaut, tracé
/// coloré, légende et crédit ; pastilles et feuille en plein écran
/// seulement, à l'heure de la zone de l'étape ; retombée quand la prévision
/// disparaît.
class _Trips implements TripRepository {
  _Trips(this.trip, this.weather);

  final TripDto trip;
  TripWeatherDto weather;
  int weatherReads = 0;

  @override
  Future<TripDto> getTrip(String teamSlug, String tripSlug) async => trip;

  @override
  Future<TripWeatherDto> getTripWeather(String t, String s) async {
    weatherReads++;
    return weather;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Teams implements TeamRepository {
  @override
  Future<List<TeamDetailDto>> getMyTeams() async => <TeamDetailDto>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Comments implements CommentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Routes implements RouteRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);
  setUp(() => RouteMap.debugSkipNativeMap = true);
  tearDown(() => RouteMap.debugSkipNativeMap = false);

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  // J1 à Tokyo, sur un parcours de 30 km plein nord, un sommet par km.
  TripDto trip({String status = 'PUBLISHED', String? endDate}) => fixtureTrip(
    status: status,
    endDate: endDate ?? '2099-08-18T07:00:00Z',
    stages: <TripStageDto>[
      fixtureStage(
        index: 1,
        timezone: 'Asia/Tokyo',
        route: fixtureStageRoute(),
      ),
      fixtureStage(
        index: 2,
        route: fixtureStageRoute(slug: 'gtmc-j2', name: 'GTMC J2'),
      ),
    ],
  );

  final RouteDetailDto route = RouteDetailDto(
    elevationState: 'HD',
    tags: const [],
    id: 'route-gtmc-j1',
    slug: 'gtmc-j1',
    team: kFixtureTeam,
    name: 'GTMC J1',
    media: kEmptyMedia,
    distance: 30000,
    elevationGain: 0,
    elevationLoss: 0,
    surfaceType: 'ROAD',
    visibility: 'PUBLIC',
    createdBy: const PublicUserDto(id: 'u9', displayName: 'Créatrice'),
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
    tracks: <TrackDto>[
      TrackDto(
        line: GeoJsonLineString(
          type: GeoJsonLineStringTypeType.lineString,
          coordinates: <List<double>>[
            for (int i = 0; i <= 30; i++)
              <double>[5, 45 + i * 0.009, 300, i * 1000.0],
          ],
        ),
        climbs: const <ClimbDto>[],
      ),
    ],
    waypoints: const <WaypointDto>[],
    deleted: false,
  );

  TripWeatherDto weather({String status = 'OK'}) => TripWeatherDto(
    status: 'OK',
    attribution: const WeatherAttributionDto(
      name: 'Open-Meteo.com',
      url: 'https://open-meteo.com/',
    ),
    stages: <TripStageWeatherDto>[
      TripStageWeatherDto(
        stageId: 's1',
        leg: fixtureLeg(groupId: null, status: status),
      ),
    ],
  );

  Future<(_Trips, ProviderContainer)> pump(
    WidgetTester tester, {
    TripDto? t,
    TripWeatherDto? dto,
  }) async {
    // Les chiffres de l'en-tête de la fiche parcours débordent avec la police
    // carrée des tests (« Ahem ») dans la colonne de 600 px de l'écran : ce
    // fichier regarde la carte, pas cet en-tête, que d'autres tests couvrent.
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    tester.view.physicalSize = const Size(402 * 3, 3000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final TripDto theTrip = t ?? trip();
    final _Trips trips = _Trips(theTrip, dto ?? weather());
    final ProviderContainer container = ProviderContainer(
      retry: (int _, Object _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        unitSystemProvider.overrideWithValue(UnitSystem.metric),
        tripRepositoryProvider.overrideWithValue(trips),
        teamRepositoryProvider.overrideWithValue(_Teams()),
        commentRepositoryProvider.overrideWithValue(_Comments()),
        routeRepositoryProvider.overrideWithValue(_Routes()),
        routeDetailProvider(
          const RouteKey(teamSlug: 'n-peloton', routeSlug: 'gtmc-j1'),
        ).overrideWith((Ref ref) async => route),
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
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: StageDetailPage(
            teamSlug: theTrip.team.slug,
            tripSlug: theTrip.slug,
            stageSlug: 'j1',
          ),
        ),
      ),
    );
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    return (trips, container);
  }

  const TripKey key = TripKey(teamSlug: 'n-peloton', tripSlug: 'gtmc-bromance');

  /// Le segment « Météo » de l'interrupteur unique.
  Finder windSegment() => find.byKey(keys.routeDetail.colorByMode('wind'));

  PdlMap map(WidgetTester tester) =>
      tester.widget<RouteMapProbe>(find.byType(RouteMapProbe).last).map;

  testWidgets('une prévision : l\'interrupteur, sur la pente par défaut ; en '
      'Météo, le tracé coloré, la légende et le crédit, sans pastille '
      'encastrée', (WidgetTester tester) async {
    final (_, ProviderContainer container) = await pump(tester);

    final Finder toggle = find.byKey(keys.trip.stageMapColorBy);
    expect(toggle, findsOneWidget);
    expect(tester.widget<RouteColorModeSwitch>(toggle).modes, <RouteColorBy>[
      RouteColorBy.grade,
      RouteColorBy.wind,
    ]);
    expect(
      tester.widget<RouteColorModeSwitch>(toggle).value,
      RouteColorBy.grade,
    );
    final Finder chip = windSegment();
    expect(map(tester).kmMarkers, isNotEmpty);
    expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);
    final List<Color>? slope = map(tester).tracks.single.segmentColors;

    // Pas de montée sur ce parcours plat : tout au bleu neutre.
    expect(slope, everyElement(slopeNeutral));

    await tester.tap(chip);
    await tester.pump();
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.wind);

    final List<Color> colors = map(tester).tracks.single.segmentColors!;
    expect(colors, isNot(slope));
    expect(colors.sublist(0, 15), everyElement(RelativeWind.head.stroke));
    expect(colors.sublist(15), everyElement(RelativeWind.tail.stroke));
    // Les bornes km s'effacent en mode « Météo ».
    expect(map(tester).kmMarkers, isEmpty);
    expect(find.byKey(keys.rideGroup.windMapLegend), findsOneWidget);
    expect(find.byKey(keys.rideGroup.windMapCredit), findsOneWidget);
    expect(map(tester).markers, isEmpty);
  });

  testWidgets('plein écran : les pastilles, à l\'heure de la zone de l\'étape, '
      'sans bascule dans la feuille', (WidgetTester tester) async {
    final (_, ProviderContainer container) = await pump(tester);
    container.read(tripMapColorModeProvider(key).notifier).state =
        RouteColorBy.wind;
    await tester.pump();

    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final PdlMap full = map(tester);
    expect(full.markers.map((PdlMapMarker m) => m.id), <String>[
      'weather.checkpoint.0',
      'weather.checkpoint.1',
    ]);
    expect(full.markers[1].lat, closeTo(45 + 15 * 0.009, 1e-9));

    // L'étape roule à Tokyo : 20:05 UTC se lit 05:05.
    full.onMarkerTapped!('weather.checkpoint.1');
    await tester.pumpAndSettle();
    expect(find.byKey(keys.rideGroup.weatherMapSheet), findsOneWidget);
    expect(find.text('Passage vers 05:05'), findsOneWidget);
    Navigator.of(tester.element(find.byKey(keys.rideGroup.weatherMapSheet)))
        .pop();
    await tester.pumpAndSettle();

    // Le mode se choisit par l'interrupteur posé sur la carte (ledger
    // `MOB-105`), pas dans la feuille des couches.
    expect(
      find.byKey(const ValueKey<String>('pdlMapHeroSwitch_wind')),
      findsNothing,
    );
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.wind);
  });

  testWidgets('plein écran : le même interrupteur, sur le même état, aller et '
      'retour', (WidgetTester tester) async {
    final (_, ProviderContainer container) = await pump(tester);
    container.read(tripMapColorModeProvider(key).notifier).state =
        RouteColorBy.wind;
    await tester.pump();

    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final Finder full = find.byKey(keys.routeDetail.fullscreenColorBy);
    expect(full, findsOneWidget);
    expect(tester.widget<RouteColorModeSwitch>(full).modes, <RouteColorBy>[
      RouteColorBy.grade,
      RouteColorBy.wind,
    ]);
    expect(tester.widget<RouteColorModeSwitch>(full).value, RouteColorBy.wind);
    expect(find.byKey(keys.rideGroup.windMapLegend), findsOneWidget);

    // Pente, choisie en plein écran : la carte du plein écran suit tout de
    // suite — plus de vent, plus de pastilles, plus de légende.
    await tester.tap(
      find.descendant(
        of: full,
        matching: find.byKey(keys.routeDetail.colorByMode('grade')),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.grade);
    expect(tester.widget<RouteColorModeSwitch>(full).value, RouteColorBy.grade);
    expect(map(tester).markers, isEmpty);
    expect(map(tester).tracks.single.segmentColors, everyElement(slopeNeutral));
    expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);

    // Retour : la carte encastrée et son interrupteur ont suivi.
    await tester.tap(find.byIcon(PdlIcons.fullscreenExit));
    await tester.pumpAndSettle();
    expect(find.byKey(keys.routeDetail.fullscreenColorBy), findsNothing);
    expect(
      tester
          .widget<RouteColorModeSwitch>(find.byKey(keys.trip.stageMapColorBy))
          .value,
      RouteColorBy.grade,
    );
    expect(map(tester).tracks.single.segmentColors, everyElement(slopeNeutral));
  });

  testWidgets('une prévision perdue au refetch ramène le mode sur la pente', (
    WidgetTester tester,
  ) async {
    final (_Trips trips, ProviderContainer container) = await pump(tester);
    container.read(tripMapColorModeProvider(key).notifier).state =
        RouteColorBy.wind;
    await tester.pump();

    trips.weather = weather(status: 'UNAVAILABLE');
    container.invalidate(tripWeatherProvider(key));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.grade);
    expect(windSegment(), findsNothing);
    expect(map(tester).tracks.single.segmentColors, isNot(isEmpty));
    expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);
  });

  testWidgets('une prévision perdue au refetch laisse un Revêtement choisi', (
    WidgetTester tester,
  ) async {
    final (_Trips trips, ProviderContainer container) = await pump(tester);
    container.read(tripMapColorModeProvider(key).notifier).state =
        RouteColorBy.surface;
    await tester.pump();

    trips.weather = weather(status: 'UNAVAILABLE');
    container.invalidate(tripWeatherProvider(key));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.surface);
  });

  testWidgets('éteindre « Météo » ne ramène sur la pente que depuis Météo', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? _) {
            widgetRef = ref;
            ref.watch(tripMapColorModeProvider(key));
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    container.read(tripMapColorModeProvider(key).notifier).state =
        RouteColorBy.surface;
    setTripMapWindMode(widgetRef, key, false);
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.surface);

    setTripMapWindMode(widgetRef, key, true);
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.wind);
    setTripMapWindMode(widgetRef, key, false);
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.grade);
  });

  testWidgets('une étape sans prévision qu\'on rafraîchit n\'éteint pas le '
      'mode des autres étapes du voyage', (WidgetTester tester) async {
    // J1 déjà partie (OUT_OF_RANGE), J2 prévue : le mode, allumé depuis la
    // carte d'ensemble, est partagé par tout le voyage.
    TripWeatherDto mixed() => TripWeatherDto(
      status: 'OK',
      attribution: weather().attribution,
      stages: <TripStageWeatherDto>[
        TripStageWeatherDto(
          stageId: 's1',
          leg: fixtureLeg(groupId: null, status: 'OUT_OF_RANGE'),
        ),
        TripStageWeatherDto(stageId: 's2', leg: fixtureLeg(groupId: null)),
      ],
    );
    final (_, ProviderContainer container) = await pump(tester, dto: mixed());
    container.read(tripMapColorModeProvider(key).notifier).state =
        RouteColorBy.wind;
    await tester.pump();
    expect(windSegment(), findsNothing);

    container.invalidate(tripWeatherProvider(key));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.wind);
  });

  for (final String status in <String>['OUT_OF_RANGE', 'NOT_YET_AVAILABLE']) {
    testWidgets('$status : pas de « Météo », même choisie', (
      WidgetTester tester,
    ) async {
      final (_, ProviderContainer container) = await pump(
        tester,
        dto: weather(status: status),
      );
      container.read(tripMapColorModeProvider(key).notifier).state =
          RouteColorBy.wind;
      await tester.pump();

      expect(windSegment(), findsNothing);
      expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);
      expect(map(tester).kmMarkers, isNotEmpty);
    });
  }

  testWidgets('voyage annulé : pas de « Météo », et la météo n\'est pas '
      'demandée', (WidgetTester tester) async {
    final (_Trips trips, _) = await pump(tester, t: trip(status: 'CANCELLED'));
    expect(windSegment(), findsNothing);
    expect(trips.weatherReads, 0);
  });
}
