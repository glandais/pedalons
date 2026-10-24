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
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_groups_map.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_weather_map_markers.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// Le vent sur la carte d'un groupe (ledger `MOB-91`) : la légende selon le
/// statut du leg et le mode, les couleurs posées sur le tracé, et le leg
/// transmis au plein écran.
void main() {
  setUpAll(loadTestTranslations);
  setUp(() => RideGroupsMap.debugSkipNativeMap = true);
  tearDown(() => RideGroupsMap.debugSkipNativeMap = false);

  const RideKey key = RideKey(teamSlug: 'n-peloton', rideSlug: 'np-665');
  final RideGroupDto group = fixtureGroup(routeSlug: 'court');
  final RideDto ride = fixtureRide(groups: <RideGroupDto>[group]);

  // 30 km plein nord, un sommet par kilomètre : les deux tronçons du leg
  // (0 → 15 face, 15 → 30 dos) se partagent les 30 intervalles.
  final RouteDetailDto route = RouteDetailDto(
    elevationState: 'HD',
    tags: const [],
    id: 'r-court',
    slug: 'court',
    team: ride.team,
    name: 'Court',
    media: ride.media,
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
    required WeatherLegDto? leg,
    bool windMode = true,
    WeatherAttributionDto? attribution,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ProviderContainer container = ProviderContainer(
      overrides: [
        // La configuration ne revient jamais : ni fonds à choisir, ni ombrage,
        // ni centre par défaut — rien de ce que ce test regarde.
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
        unitSystemProvider.overrideWithValue(UnitSystem.metric),
        rideMapWindModeProvider.overrideWith((Ref ref, RideKey k) => windMode),
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
                  onlyGroup: group,
                  weatherLeg: leg,
                  weatherAttribution: attribution,
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

  PdlMapTrack track(WidgetTester tester) => tester
      .widget<RideGroupsMapProbe>(find.byType(RideGroupsMapProbe).first)
      .map
      .tracks
      .single;

  testWidgets('prévision et mode « Météo » : légende en mots, tracé coloré', (
    WidgetTester tester,
  ) async {
    await pump(tester, leg: fixtureLeg());

    expect(find.byKey(keys.rideGroup.windMapLegend), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Dos 15')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Face 15')), findsOneWidget);
    // Une part nulle est omise.
    expect(find.textContaining('Travers'), findsNothing);
    expect(find.text('Prévision ancienne'), findsNothing);

    final List<Color> colors = track(tester).segmentColors!;
    expect(colors.length, 30);
    expect(colors.sublist(0, 15), everyElement(RelativeWind.head.stroke));
    expect(colors.sublist(15), everyElement(RelativeWind.tail.stroke));
  });

  testWidgets('STALE et vitesse par défaut : la légende le dit', (
    WidgetTester tester,
  ) async {
    await pump(tester, leg: fixtureLeg(status: 'STALE', speedIsDefault: true));

    expect(find.text('Prévision ancienne'), findsOneWidget);
    expect(find.text('Heures estimées à 25\u00a0km/h'), findsOneWidget);
  });

  testWidgets('mode éteint : trait habituel, pas de légende', (
    WidgetTester tester,
  ) async {
    await pump(tester, leg: fixtureLeg(), windMode: false);

    expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);
    expect(track(tester).segmentColors, isNull);
  });

  for (final String status in <String>[
    'NOT_YET_AVAILABLE',
    'NO_LOCATION',
    'OUT_OF_RANGE',
    'UNAVAILABLE',
  ]) {
    testWidgets('$status : rien, même le mode allumé', (
      WidgetTester tester,
    ) async {
      await pump(tester, leg: fixtureLeg(status: status));

      expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);
      expect(track(tester).segmentColors, isNull);
    });
  }

  testWidgets('le plein écran reçoit le leg et propose la bascule', (
    WidgetTester tester,
  ) async {
    final WeatherLegDto leg = fixtureLeg();
    final ProviderContainer container = await pump(tester, leg: leg);

    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final RideGroupsMap full = tester.widget<RideGroupsMap>(
      find.byWidgetPredicate((Widget w) => w is RideGroupsMap && w.fullscreen),
    );
    expect(identical(full.weatherLeg, leg), isTrue);
    // La légende suit dans la page plein écran.
    expect(find.byKey(keys.rideGroup.windMapLegend), findsWidgets);

    // La bascule vit dans la feuille des couches, comme l'ombrage.
    await tester.tap(find.byIcon(PdlIcons.layers).last);
    await tester.pumpAndSettle();
    final Finder row = find.byKey(
      const ValueKey<String>('pdlMapHeroSwitch_wind'),
    );
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(container.read(rideMapWindModeProvider(key)), isFalse);
  });

  // ── Palier 2 (ledger `MOB-92`) ─────────────────────────────────────────
  const WeatherAttributionDto openMeteo = WeatherAttributionDto(
    name: 'Open-Meteo.com',
    url: 'https://open-meteo.com/',
  );

  testWidgets('le crédit des prévisions est dans la légende, encastrée et '
      'plein écran', (WidgetTester tester) async {
    await pump(tester, leg: fixtureLeg(), attribution: openMeteo);

    expect(find.byKey(keys.rideGroup.windMapCredit), findsOneWidget);
    expect(find.text('Prévisions : Open-Meteo.com'), findsOneWidget);

    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final RideGroupsMap full = tester.widget<RideGroupsMap>(
      find.byWidgetPredicate((Widget w) => w is RideGroupsMap && w.fullscreen),
    );
    expect(full.weatherAttribution, openMeteo);
    expect(
      find.descendant(
        of: find.byWidget(full),
        matching: find.byKey(keys.rideGroup.windMapCredit),
      ),
      findsOneWidget,
    );
  });

  testWidgets('encastrée : aucune pastille, même en mode « Météo »', (
    WidgetTester tester,
  ) async {
    await pump(tester, leg: fixtureLeg());

    expect(map(tester).markers, isEmpty);
    expect(map(tester).onMarkerTapped, isNull);
  });

  testWidgets('plein écran en mode « Météo » : les pastilles, et le détail au '
      'toucher', (WidgetTester tester) async {
    await pump(tester, leg: fixtureLeg());
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final PdlMap full = map(tester);
    // Départ et point en route : l'arrivée du fixture n'a pas de météo.
    expect(full.markers.map((PdlMapMarker m) => m.id), <String>[
      'weather.checkpoint.0',
      'weather.checkpoint.1',
    ]);
    // 15 km chaînés : le 15ᵉ sommet du tracé.
    expect(full.markers[1].lat, closeTo(45 + 15 * 0.009, 1e-9));

    full.onMarkerTapped!('weather.checkpoint.1');
    await tester.pumpAndSettle();
    expect(find.byKey(keys.rideGroup.weatherMapSheet), findsOneWidget);
    expect(find.text('Rafales 32\u00a0km/h'), findsOneWidget);
  });

  testWidgets('plein écran : la goutte ouvre l\'alerte pluie', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      leg: fixtureLeg(
        rainAlert: const WeatherRainAlertDto(
          probability: 70,
          time: '2026-07-29T20:05:00Z',
          condition: 'RAIN',
          distance: 15000,
        ),
      ),
    );
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final PdlMap full = map(tester);
    expect(
      full.markers.map((PdlMapMarker m) => m.id),
      contains(weatherRainMarkerId),
    );

    full.onMarkerTapped!(weatherRainMarkerId);
    await tester.pumpAndSettle();
    expect(find.byKey(keys.rideGroup.weatherMapSheet), findsOneWidget);
    expect(find.text('Pluie probable'), findsOneWidget);
  });

  testWidgets('les libellés des pastilles suivent la langue : seules les '
      'positions sont mémorisées', (WidgetTester tester) async {
    addTearDown(loadTestTranslations);
    await pump(tester, leg: fixtureLeg());
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();
    expect(map(tester).markers.first.semanticLabel, startsWith('Départ'));

    // Même parcours, même leg : la mémoire des positions sert, mais la
    // langue a changé entre-temps.
    await tester.runAsync(() => loadTestTranslations(languageCode: 'en'));
    for (final Element e in find.byType(RideGroupsMap).evaluate()) {
      e.markNeedsBuild();
    }
    await tester.pumpAndSettle();
    expect(map(tester).markers.first.semanticLabel, startsWith('Start'));
  });

  testWidgets('plein écran, mode éteint : aucune pastille', (
    WidgetTester tester,
  ) async {
    await pump(tester, leg: fixtureLeg(), windMode: false);
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    expect(map(tester).markers, isEmpty);
  });
}
