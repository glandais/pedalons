import 'dart:async';

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
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/domain/track_surfaces.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_color_mode_switch.dart';
import 'package:pedalons/features/trips/domain/trip_weather_map.dart';
import 'package:pedalons/features/trips/presentation/widgets/trip_map.dart';
import 'package:pedalons/features/trips/providers/trip_detail_provider.dart';
import 'package:pedalons/features/trips/providers/trip_weather_provider.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import '../rides/ride_fixtures.dart';
import 'trip_fixtures.dart';

/// La carte d'ensemble d'un voyage en mode « Météo » (ledger `MOB-94`) :
/// chaque étape colorée par **son** vent, les pastilles de **toutes** les
/// étapes en plein écran (à l'heure de la zone de chacune), une légende qui
/// additionne les parts et dit lesquelles, et des distances chaînées **par
/// étape**, saut nul entre les traces d'un même parcours.
class _Routes implements RouteRepository {
  _Routes(this.routes);

  final Map<String, RouteDetailDto> routes;

  @override
  Future<RoutesBulkResponse> getRoutesBulk(
    String teamSlug,
    List<String> slugs, {
    bool geometry = true,
  }) async => RoutesBulkResponse(
    routes: <RouteDetailDto>[
      for (final String s in slugs)
        if (routes[s] != null) routes[s]!,
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Un tracé plein nord depuis [lat0], un sommet par kilomètre, la distance
/// repartant de 0 (4ᵉ composante).
TrackDto _track(double lat0, int km) => TrackDto(
  line: GeoJsonLineString(
    type: GeoJsonLineStringTypeType.lineString,
    coordinates: <List<double>>[
      for (int i = 0; i <= km; i++)
        <double>[5, lat0 + i * 0.009, 300, i * 1000],
    ],
  ),
  climbs: const <ClimbDto>[],
);

RouteDetailDto _route(String slug, List<TrackDto> tracks) => RouteDetailDto(
  elevationState: 'HD',
  tags: const [],
  id: 'r-$slug',
  slug: slug,
  team: kFixtureTeam,
  name: slug,
  media: kEmptyMedia,
  distance: 30000,
  elevationGain: 0,
  elevationLoss: 0,
  surfaceType: 'ROAD',
  visibility: 'PUBLIC',
  createdBy: const PublicUserDto(id: 'u9', displayName: 'Créatrice'),
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: '2026-01-01T00:00:00Z',
  tracks: tracks,
  waypoints: const <WaypointDto>[],
  deleted: false,
);

/// Le leg de J2 : 0 → 10 km dos, 10 → 20 km face, un point de passage à
/// 15 km — sur la **seconde** trace de son parcours.
WeatherLegDto _legJ2({String status = 'OK'}) => WeatherLegDto(
  status: status,
  startTime: '2099-08-13T07:00:00Z',
  averageSpeed: 25,
  speedIsDefault: false,
  distance: 20000,
  arrivalTime: '2099-08-13T08:00:00Z',
  checkpoints: <WeatherCheckpointDto>[
    WeatherCheckpointDto(
      indexField: 0,
      kind: 'START',
      distance: 0,
      time: '2099-08-13T07:00:00Z',
      weather: fixtureConditions(),
      relativeWind: 'TAIL',
      headwind: -8,
      relativeWindAngle: 10,
    ),
    WeatherCheckpointDto(
      indexField: 1,
      kind: 'EN_ROUTE',
      distance: 15000,
      time: '2099-08-13T07:36:00Z',
      weather: fixtureConditions(),
      relativeWind: 'HEAD',
      headwind: 9,
      relativeWindAngle: 170,
    ),
  ],
  segments: const <WindSegmentDto>[
    WindSegmentDto(
      fromDistance: 0,
      toDistance: 10000,
      relativeWind: 'TAIL',
      headwind: -8,
    ),
    WindSegmentDto(
      fromDistance: 10000,
      toDistance: 20000,
      relativeWind: 'HEAD',
      headwind: 9,
    ),
  ],
  windExposure: const WindExposureDto(head: 10000, cross: 0, tail: 10000),
  prevailingWind: const WindDto(speed: 17, direction: 300, compass: 'NW'),
);

void main() {
  setUpAll(loadTestTranslations);
  setUp(() => TripMap.debugSkipNativeMap = true);
  tearDown(() => TripMap.debugSkipNativeMap = false);

  const TripKey key = TripKey(teamSlug: 'n-peloton', tripSlug: 'gtmc-bromance');

  // J1 : 30 km sur une trace. J2 : deux traces de 10 km, la seconde loin au
  // nord de la première — un saut que les distances météo ne comptent pas.
  final Map<String, RouteDetailDto> routes = <String, RouteDetailDto>{
    'gtmc-j1': _route('gtmc-j1', <TrackDto>[_track(45, 30)]),
    'gtmc-j2': _route('gtmc-j2', <TrackDto>[_track(46, 10), _track(47, 10)]),
  };

  TripDto trip({String status = 'PUBLISHED', String? endDate}) => fixtureTrip(
    status: status,
    endDate: endDate ?? '2099-08-18T07:00:00Z',
    stages: <TripStageDto>[
      fixtureStage(index: 1, route: fixtureStageRoute()),
      fixtureStage(
        index: 2,
        dateTime: '2099-08-13T07:00:00Z',
        timezone: 'Asia/Tokyo',
        route: fixtureStageRoute(slug: 'gtmc-j2', name: 'GTMC J2'),
      ),
      // Sans parcours : pas de tracé, pas de part.
      fixtureStage(index: 3),
    ],
  );

  const WeatherAttributionDto openMeteo = WeatherAttributionDto(
    name: 'Open-Meteo.com',
    url: 'https://open-meteo.com/',
  );

  TripWeatherDto weather({String j2Status = 'OK'}) => TripWeatherDto(
    status: 'OK',
    attribution: openMeteo,
    stages: <TripStageWeatherDto>[
      TripStageWeatherDto(stageId: 's1', leg: fixtureLeg(groupId: null)),
      TripStageWeatherDto(
        stageId: 's2',
        leg: _legJ2(status: j2Status),
      ),
    ],
  );

  Future<(ProviderContainer, List<int>)> pump(
    WidgetTester tester, {
    required TripDto trip,
    TripWeatherDto? dto,
    bool? windMode,
    RouteColorBy? colorBy,
    Map<String, RouteDetailDto>? served,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final List<int> weatherCalls = <int>[0];
    final ProviderContainer container = ProviderContainer(
      overrides: [
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
        routeRepositoryProvider.overrideWithValue(_Routes(served ?? routes)),
        tripDetailProvider.overrideWith((Ref ref, TripKey k) async => trip),
        tripWeatherProvider.overrideWith((Ref ref, TripKey k) async {
          weatherCalls[0]++;
          return dto ?? weather();
        }),
        unitSystemProvider.overrideWithValue(UnitSystem.metric),
        if (windMode != null || colorBy != null)
          tripMapColorModeProvider.overrideWith(
            (Ref ref, TripKey k) =>
                colorBy ?? (windMode! ? RouteColorBy.wind : RouteColorBy.grade),
          ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                TripMap(
                  tripKey: key,
                  trip: trip,
                  selectedStageId: null,
                  onSelect: (String _) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    return (container, weatherCalls);
  }

  PdlMap map(WidgetTester tester) =>
      tester.widget<TripMapProbe>(find.byType(TripMapProbe).last).map;

  PdlMapTrack track(WidgetTester tester, String stageId) =>
      map(tester).tracks.singleWhere((PdlMapTrack t) => t.id == stageId);

  TripMapColorBy shown(WidgetTester tester, Key switchKey) => tester
      .widget<MapColorModeSwitch<TripMapColorBy>>(find.byKey(switchKey))
      .value;

  Finder segment(Key switchKey, TripMapColorBy mode) => find.descendant(
    of: find.byKey(switchKey),
    matching: find.byKey(keys.trip.mapColorByMode(mode.name)),
  );

  testWidgets('l\'interrupteur Étapes | Météo est là, sur « Étapes » par '
      'défaut : le trait habituel', (WidgetTester tester) async {
    final (ProviderContainer container, _) = await pump(tester, trip: trip());

    expect(shown(tester, keys.trip.mapColorBy), TripMapColorBy.stages);
    expect(
      find.descendant(
        of: find.byKey(keys.trip.mapColorBy),
        matching: find.text('Étapes'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(keys.trip.mapColorBy),
        matching: find.text('Météo'),
      ),
      findsOneWidget,
    );
    expect(track(tester, 's1').segmentColors, isNull);
    expect(track(tester, 's2').segmentColors, isNull);
    expect(find.byKey(keys.trip.windMapLegend), findsNothing);
    expect(track(tester, 's1').emphasized, isFalse);

    await tester.tap(segment(keys.trip.mapColorBy, TripMapColorBy.wind));
    await tester.pump();
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.wind);
    expect(shown(tester, keys.trip.mapColorBy), TripMapColorBy.wind);
    expect(track(tester, 's1').segmentColors, isNotNull);
    expect(find.byKey(keys.trip.windMapLegend), findsOneWidget);

    // « Étapes » éteint la Météo : retour sur la pente pour la page d'une
    // étape, qui partage le choix.
    await tester.tap(segment(keys.trip.mapColorBy, TripMapColorBy.stages));
    await tester.pump();
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.grade);
    expect(track(tester, 's1').segmentColors, isNull);
    expect(find.byKey(keys.trip.windMapLegend), findsNothing);
  });

  testWidgets('un Revêtement choisi sur une étape se lit « Étapes » ici, et '
      'reste tant qu\'on ne passe pas par la Météo', (
    WidgetTester tester,
  ) async {
    final (ProviderContainer container, _) = await pump(
      tester,
      trip: trip(),
      colorBy: RouteColorBy.surface,
    );

    expect(shown(tester, keys.trip.mapColorBy), TripMapColorBy.stages);
    expect(track(tester, 's1').segmentColors, isNull);
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.surface);
  });

  testWidgets('mode « Météo » : chaque étape colorée par son propre vent, '
      'distances chaînées par étape', (WidgetTester tester) async {
    await pump(tester, trip: trip(), windMode: true);

    // J1 : 0 → 15 km face, 15 → 30 km dos (le leg du fixture).
    final List<Color> j1 = track(tester, 's1').segmentColors!;
    expect(j1.length, 30);
    expect(j1.sublist(0, 15), everyElement(RelativeWind.head.stroke));
    expect(j1.sublist(15), everyElement(RelativeWind.tail.stroke));

    // J2 : deux traces de 10 intervalles. La seconde repart de 0 et commence
    // loin de la première : chaînée **sans saut**, elle couvre 10 → 20 km,
    // face. Compter le saut l'aurait poussée au-delà des tronçons.
    final List<Color> j2 = track(tester, 's2').segmentColors!;
    expect(j2.length, 20);
    expect(j2.sublist(0, 10), everyElement(RelativeWind.tail.stroke));
    expect(j2.sublist(10), everyElement(RelativeWind.head.stroke));

    // La légende additionne les parts des deux étapes tracées, et le dit.
    expect(find.byKey(keys.trip.windMapLegend), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Dos 25')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Face 25')), findsOneWidget);
    expect(find.text('Parts additionnées des 2 étapes'), findsOneWidget);
    expect(find.text('Prévisions : Open-Meteo.com'), findsOneWidget);
    // Encastrée : aucune pastille. Le toucher y choisit l'étape — `MOB-107`
    // ne vaut que pour le groupe, la sortie solo et l'étape.
    expect(map(tester).markers, isEmpty);
  });

  testWidgets('plein écran : les pastilles de toutes les étapes, chacune à '
      'l\'heure de sa zone', (WidgetTester tester) async {
    await pump(tester, trip: trip(), windMode: true);
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final PdlMap full = map(tester);
    expect(full.markers.map((PdlMapMarker m) => m.id), <String>[
      'stage.s1/weather.checkpoint.0',
      'stage.s1/weather.checkpoint.1',
      'stage.s2/weather.checkpoint.0',
      'stage.s2/weather.checkpoint.1',
    ]);
    // J2 à 15 km chaînés : le 5ᵉ sommet de sa **seconde** trace.
    expect(full.markers[3].lat, closeTo(47 + 5 * 0.009, 1e-9));
    // J1 à 15 km : le 15ᵉ sommet de sa trace unique.
    expect(full.markers[1].lat, closeTo(45 + 15 * 0.009, 1e-9));

    // J2 roule à Tokyo : 07:36 UTC se lit 16:36.
    full.onMarkerTapped!('stage.s2/weather.checkpoint.1');
    await tester.pumpAndSettle();
    expect(find.byKey(keys.rideGroup.weatherMapSheet), findsOneWidget);
    expect(find.text('Passage vers 16:36'), findsOneWidget);
  });

  testWidgets('plein écran : le même interrupteur en bas de la carte, sur le '
      'même état, et rien dans la feuille des couches', (
    WidgetTester tester,
  ) async {
    final (ProviderContainer container, _) = await pump(
      tester,
      trip: trip(),
      windMode: true,
    );
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final Key full = keys.trip.fullscreenMapColorBy;
    expect(find.byKey(full), findsOneWidget);
    expect(shown(tester, full), TripMapColorBy.wind);
    expect(
      tester
          .widget<MapColorModeSwitch<TripMapColorBy>>(find.byKey(full))
          .overMap,
      isTrue,
    );
    expect(
      tester.widget<PdlMapHero>(find.byType(PdlMapHero).last).switches,
      isEmpty,
    );
    expect(
      find.byKey(const ValueKey<String>('pdlMapHeroSwitch_wind')),
      findsNothing,
    );

    // « Étapes », en plein écran : plus de vent, plus de pastilles.
    await tester.tap(segment(full, TripMapColorBy.stages));
    await tester.pumpAndSettle();
    expect(container.read(tripMapColorModeProvider(key)), RouteColorBy.grade);
    expect(map(tester).markers, isEmpty);
    expect(track(tester, 's1').segmentColors, isNull);
  });

  testWidgets('une étape sans prévision prend le bleu neutre, et la légende '
      'dit la seule étape comptée', (WidgetTester tester) async {
    await pump(
      tester,
      trip: trip(),
      dto: weather(j2Status: 'OUT_OF_RANGE'),
      windMode: true,
    );

    expect(track(tester, 's1').segmentColors, isNotNull);
    expect(track(tester, 's2').segmentColors, isNull);
    // Sa couleur d'étape se lirait comme un vent (ledger `MOB-105`).
    expect(track(tester, 's2').color, slopeNeutral);
    // Aucune étape n'est sélectionnée : le vent garde pourtant l'opacité et
    // la largeur d'un tracé sélectionné, l'étape sans prévision non.
    expect(track(tester, 's1').emphasized, isTrue);
    expect(track(tester, 's2').emphasized, isFalse);
    expect(
      find.text('Parts de la seule étape avec prévision : J1'),
      findsOneWidget,
    );
    expect(find.textContaining(RegExp(r'^Dos 15')), findsOneWidget);
  });

  testWidgets('aucune étape colorée encore dessinée : pas de légende vide', (
    WidgetTester tester,
  ) async {
    // Seule J1 a une prévision, et sa géométrie n'est pas servie : J2 est
    // tracée, sans couleur ni part.
    await pump(
      tester,
      trip: trip(),
      dto: weather(j2Status: 'OUT_OF_RANGE'),
      windMode: true,
      served: <String, RouteDetailDto>{'gtmc-j2': routes['gtmc-j2']!},
    );

    expect(map(tester).tracks.map((PdlMapTrack t) => t.id), <String>['s2']);
    expect(find.byKey(keys.trip.mapColorBy), findsOneWidget);
    expect(find.byKey(keys.trip.windMapLegend), findsNothing);
  });

  testWidgets('aucune étape avec prévision : ni interrupteur ni couleur', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      trip: trip(),
      dto: TripWeatherDto(
        status: 'NOT_YET_AVAILABLE',
        attribution: openMeteo,
        stages: <TripStageWeatherDto>[
          TripStageWeatherDto(
            stageId: 's1',
            leg: fixtureLeg(groupId: null, status: 'NOT_YET_AVAILABLE'),
          ),
        ],
      ),
      windMode: true,
    );

    expect(find.byKey(keys.trip.mapColorBy), findsNothing);
    expect(track(tester, 's1').segmentColors, isNull);
  });

  for (final (String label, TripDto t) in <(String, TripDto)>[
    ('annulé', trip(status: 'CANCELLED')),
    ('terminé', trip(endDate: '2020-08-18T07:00:00Z')),
  ]) {
    testWidgets('voyage $label : pas de mode, sans même demander la météo', (
      WidgetTester tester,
    ) async {
      final (_, List<int> calls) = await pump(tester, trip: t, windMode: true);

      expect(find.byKey(keys.trip.mapColorBy), findsNothing);
      expect(track(tester, 's1').segmentColors, isNull);
      expect(calls.single, 0);
    });
  }

  test('tripMapWindLegs : seulement les étapes qui montrent le vent', () {
    final Map<String, WeatherLegDto> legs = tripMapWindLegs(
      trip(),
      weather(j2Status: 'STALE'),
    );
    expect(legs.keys, <String>['s1', 's2']);
    expect(
      tripMapWindLegs(trip(), weather(j2Status: 'UNAVAILABLE')).keys,
      <String>['s1'],
    );
    expect(tripMapWindLegs(trip(), null), isEmpty);
  });
}
