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
import 'package:pedalons/features/rides/presentation/widgets/ride_groups_map.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/features/routes/domain/track_surfaces.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_color_mode_switch.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// La carte du détail d'une **sortie solo** en mode « Météo » (ledger
/// `MOB-94`) : `RideGroupsMap` sans `onlyGroup`, avec le leg du groupe
/// unique. Le vent colore le parcours de ce groupe, et lui seul ; les
/// pastilles n'apparaissent qu'en plein écran ; une sortie à plusieurs
/// groupes n'a pas de mode sur sa carte. Avec deux parcours (celui de la
/// sortie, celui du groupe), la carte garde la couleur de ses couches hors
/// Météo, comme au site (ledger `MOB-105`).
void main() {
  setUpAll(loadTestTranslations);
  setUp(() => RideGroupsMap.debugSkipNativeMap = true);
  tearDown(() => RideGroupsMap.debugSkipNativeMap = false);

  const RideKey key = RideKey(teamSlug: 'n-peloton', rideSlug: 'np-665');

  RouteDetailDto route(String slug) => RouteDetailDto(
    elevationState: 'HD',
    tags: const [],
    id: 'r-$slug',
    slug: slug,
    team: fixtureRide().team,
    name: slug,
    media: fixtureRide().media,
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

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required RideDto ride,
    WeatherLegDto? leg,
    RouteColorBy mode = RouteColorBy.wind,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
        rideRouteGeometryProvider.overrideWith(
          (Ref ref, RouteRef r) =>
              AsyncValue<RouteDetailDto>.data(route(r.routeSlug)),
        ),
        // Pas de lot à charger : l'emprise reste celle de la graine.
        rideRouteGeometriesProvider.overrideWith(
          (Ref ref, RideKey k) => RideRouteGeometriesController(ref, k),
        ),
        unitSystemProvider.overrideWithValue(UnitSystem.metric),
        rideMapColorModeProvider.overrideWith((Ref ref, RideKey k) => mode),
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
                RideGroupsMap(
                  rideKey: key,
                  ride: ride,
                  weatherLeg: leg,
                  weatherAttribution: const WeatherAttributionDto(
                    name: 'Open-Meteo.com',
                    url: 'https://open-meteo.com/',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  PdlMap map(WidgetTester tester) => tester
      .widget<RideGroupsMapProbe>(find.byType(RideGroupsMapProbe).last)
      .map;

  PdlMapTrack track(WidgetTester tester, String slug) =>
      map(tester).tracks.singleWhere((PdlMapTrack t) => t.id == slug);

  final RideDto solo = fixtureRide(
    groups: <RideGroupDto>[fixtureGroup(routeSlug: 'court')],
  );

  testWidgets('sortie solo, mode « Météo » : le parcours du groupe coloré, '
      'la légende et son crédit, aucune pastille encastrée', (
    WidgetTester tester,
  ) async {
    await pump(tester, ride: solo, leg: fixtureLeg());

    final List<Color> colors = track(tester, 'court').segmentColors!;
    expect(colors.sublist(0, 15), everyElement(RelativeWind.head.stroke));
    expect(colors.sublist(15), everyElement(RelativeWind.tail.stroke));
    expect(find.byKey(keys.rideGroup.windMapLegend), findsOneWidget);
    expect(find.byKey(keys.rideGroup.windMapCredit), findsOneWidget);
    expect(map(tester).markers, isEmpty);
  });

  testWidgets('sortie solo, plein écran : les pastilles et leur feuille', (
    WidgetTester tester,
  ) async {
    // Une zone loin de celle de n'importe quel poste de test : l'heure ne
    // peut venir que de `ride.timezone`.
    await pump(
      tester,
      ride: solo.copyWith(timezone: 'Asia/Tokyo'),
      leg: fixtureLeg(),
    );
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final PdlMap full = map(tester);
    expect(full.markers.map((PdlMapMarker m) => m.id), <String>[
      'weather.checkpoint.0',
      'weather.checkpoint.1',
    ]);
    full.onMarkerTapped!('weather.checkpoint.1');
    await tester.pumpAndSettle();
    expect(find.byKey(keys.rideGroup.weatherMapSheet), findsOneWidget);
    // L'heure se lit dans la zone de la sortie : 20:05 UTC à Tokyo, 05:05.
    expect(find.text('Passage vers 05:05'), findsOneWidget);
  });

  testWidgets('sortie solo, mode Pente : la pente comme un parcours, plein '
      'écran nu', (WidgetTester tester) async {
    await pump(tester, ride: solo, leg: fixtureLeg(), mode: RouteColorBy.grade);
    // Plus la couleur unie du groupe (ledger `MOB-105`) : sans montée, le
    // bleu neutre.
    expect(track(tester, 'court').segmentColors, everyElement(slopeNeutral));
    expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);

    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();
    expect(map(tester).markers, isEmpty);
  });

  testWidgets('le parcours principal que le groupe ne roule pas garde la '
      'couleur de sa couche', (WidgetTester tester) async {
    await pump(
      tester,
      ride: solo.copyWith(routeSlug: 'principal'),
      leg: fixtureLeg(),
    );

    expect(track(tester, 'principal').segmentColors, isNull);
    expect(track(tester, 'court').segmentColors, isNotNull);
    // Le parcours coloré garde le trait d'un tracé sélectionné, même quand
    // la sélection est sur le principal : délavé, il trahirait sa légende.
    expect(track(tester, 'court').emphasized, isTrue);
    expect(track(tester, 'principal').emphasized, isFalse);
  });

  for (final RouteColorBy mode in <RouteColorBy>[
    RouteColorBy.grade,
    RouteColorBy.surface,
  ]) {
    testWidgets('deux parcours, mode ${mode.name} : chaque couche à sa '
        'couleur, comme au site', (WidgetTester tester) async {
      await pump(
        tester,
        ride: solo.copyWith(routeSlug: 'principal'),
        leg: fixtureLeg(),
        mode: mode,
      );
      expect(track(tester, 'principal').segmentColors, isNull);
      expect(track(tester, 'court').segmentColors, isNull);
    });
  }

  testWidgets('deux parcours, plein écran : pas d\'interrupteur Pente | '
      'Revêtement | Météo, la bascule « Vent sur le tracé » de la feuille', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pump(
      tester,
      ride: solo.copyWith(routeSlug: 'principal'),
      leg: fixtureLeg(),
    );
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    expect(find.byKey(keys.routeDetail.fullscreenColorBy), findsNothing);
    await tester.tap(find.byIcon(PdlIcons.layers));
    await tester.pumpAndSettle();
    final Finder wind = find.byKey(
      const ValueKey<String>('pdlMapHeroSwitch_wind'),
    );
    expect(wind, findsOneWidget);
    await tester.tap(wind);
    await tester.pumpAndSettle();
    expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);
  });

  testWidgets('un seul parcours, plein écran : l\'interrupteur, sur l\'état '
      'de la carte encastrée', (WidgetTester tester) async {
    final ProviderContainer container = await pump(
      tester,
      ride: solo,
      leg: fixtureLeg(),
    );
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final Finder toggle = find.byKey(keys.routeDetail.fullscreenColorBy);
    expect(toggle, findsOneWidget);
    expect(
      tester.widget<RouteColorModeSwitch>(toggle).value,
      RouteColorBy.wind,
    );
    await tester.tap(
      find.descendant(
        of: toggle,
        matching: find.byKey(keys.routeDetail.colorByMode('grade')),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);
    expect(map(tester).markers, isEmpty);
  });

  testWidgets('le parcours du groupe masqué : ni légende ni crédit', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pump(
      tester,
      ride: solo.copyWith(routeSlug: 'principal'),
      leg: fixtureLeg(),
    );
    expect(find.byKey(keys.rideGroup.windMapLegend), findsOneWidget);

    container.read(hiddenRideRoutesProvider(key).notifier).state = <String>{
      'court',
    };
    await tester.pump();

    expect(map(tester).tracks.map((PdlMapTrack t) => t.id), <String>[
      'principal',
    ]);
    expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);
    expect(find.byKey(keys.rideGroup.windMapCredit), findsNothing);
  });

  testWidgets('plusieurs groupes : une couleur par groupe, pas de mode '
      '« Météo » sur la carte de la sortie', (WidgetTester tester) async {
    await pump(
      tester,
      ride: fixtureRide(
        groups: <RideGroupDto>[
          fixtureGroup(id: 'g1', routeSlug: 'court'),
          fixtureGroup(id: 'g2', routeSlug: 'long', sortOrder: 1),
        ],
      ),
      leg: fixtureLeg(),
    );

    for (final PdlMapTrack t in map(tester).tracks) {
      expect(t.segmentColors, isNull);
    }
    expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);
  });

  for (final String status in <String>['NOT_YET_AVAILABLE', 'OUT_OF_RANGE']) {
    testWidgets('sortie solo, $status : pas de Météo, la pente', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        ride: solo,
        leg: fixtureLeg(status: status),
      );

      expect(track(tester, 'court').segmentColors, everyElement(slopeNeutral));
      expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);
    });
  }
}
