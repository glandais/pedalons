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
import 'package:pedalons/features/rides/presentation/widgets/ride_weather_map_markers.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/features/routes/domain/track_surfaces.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_color_mode_switch.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// Le vent sur la carte d'un groupe (ledger `MOB-91`) : la légende selon le
/// statut du leg et le mode, les couleurs posées sur le tracé, et le leg
/// transmis au plein écran. Hors Météo, le tracé se colore comme un parcours
/// — pente des montées, revêtement (ledger `MOB-105`).
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
    RouteColorBy mode = RouteColorBy.wind,
    WeatherAttributionDto? attribution,
    double? cursorDistance,
    RouteDetailDto? geometry,
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
              selectedId: 's',
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
              AsyncValue<RouteDetailDto>.data(geometry ?? route),
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
                  onlyGroup: group,
                  weatherLeg: leg,
                  weatherAttribution: attribution,
                  cursorDistance: cursorDistance,
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

  testWidgets('mode Pente : la pente des montées, pas de légende', (
    WidgetTester tester,
  ) async {
    await pump(tester, leg: fixtureLeg(), mode: RouteColorBy.grade);

    expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);
    // Aucune montée sur ce tracé plat : tout est au bleu neutre, plus jamais
    // la couleur unie du groupe.
    final List<Color> colors = track(tester).segmentColors!;
    expect(colors, hasLength(30));
    expect(colors, everyElement(slopeNeutral));
  });

  testWidgets('mode Pente : une montée prend la teinte de sa pente, le reste '
      'le bleu neutre', (WidgetTester tester) async {
    final RouteDetailDto climbing = route.copyWith(
      tracks: <TrackDto>[
        route.tracks.single.copyWith(
          climbs: const <ClimbDto>[
            ClimbDto(
              startDistance: 5000,
              endDistance: 10000,
              elevationGain: 300,
              averageGradient: 6,
              maxGradient: 9,
              parts: <ClimbPartDto>[],
            ),
          ],
        ),
      ],
    );
    await pump(
      tester,
      leg: fixtureLeg(),
      mode: RouteColorBy.grade,
      geometry: climbing,
    );

    final List<Color> colors = track(tester).segmentColors!;
    expect(colors.sublist(0, 5), everyElement(slopeNeutral));
    // Un segment se lit sur son sommet de départ, bornes incluses.
    expect(colors.sublist(5, 11), everyElement(slopeColor(6)));
    expect(colors.sublist(11), everyElement(slopeNeutral));
  });

  testWidgets('mode Revêtement sans revêtement connu : la pente', (
    WidgetTester tester,
  ) async {
    await pump(tester, leg: fixtureLeg(), mode: RouteColorBy.surface);

    expect(track(tester).segmentColors, everyElement(slopeNeutral));
  });

  testWidgets('un tronçon sans vent connu prend le bleu neutre', (
    WidgetTester tester,
  ) async {
    final WeatherLegDto leg = fixtureLeg();
    await pump(
      tester,
      leg: leg.copyWith(segments: <WindSegmentDto>[leg.segments.first]),
    );

    final List<Color> colors = track(tester).segmentColors!;
    expect(colors.sublist(0, 15), everyElement(RelativeWind.head.stroke));
    expect(colors.sublist(15), everyElement(slopeNeutral));
  });

  for (final String status in <String>[
    'NOT_YET_AVAILABLE',
    'NO_LOCATION',
    'OUT_OF_RANGE',
    'UNAVAILABLE',
  ]) {
    testWidgets('$status : pas de Météo, même choisie — la pente', (
      WidgetTester tester,
    ) async {
      await pump(tester, leg: fixtureLeg(status: status));

      expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);
      expect(track(tester).segmentColors, everyElement(slopeNeutral));
    });
  }

  testWidgets('le plein écran reçoit le leg et l\'interrupteur, sur le même '
      'état, aller et retour', (WidgetTester tester) async {
    final WeatherLegDto leg = fixtureLeg();
    final ProviderContainer container = await pump(tester, leg: leg);
    // Encastrée, la carte n'a pas d'interrupteur sur elle : il est sous elle,
    // dans l'onglet.
    expect(find.byKey(keys.routeDetail.fullscreenColorBy), findsNothing);

    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final RideGroupsMap full = tester.widget<RideGroupsMap>(
      find.byWidgetPredicate((Widget w) => w is RideGroupsMap && w.fullscreen),
    );
    expect(identical(full.weatherLeg, leg), isTrue);
    // La légende suit dans la page plein écran.
    expect(find.byKey(keys.rideGroup.windMapLegend), findsWidgets);

    // L'interrupteur du plein écran (ledger `MOB-105`), pas une bascule de la
    // feuille des couches — ici, sans fonds ni ombrage, pas de feuille.
    expect(find.byIcon(PdlIcons.layers), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('pdlMapHeroSwitch_wind')),
      findsNothing,
    );
    final Finder toggle = find.byKey(keys.routeDetail.fullscreenColorBy);
    expect(toggle, findsOneWidget);
    expect(
      find.descendant(of: find.byWidget(full), matching: toggle),
      findsOneWidget,
    );
    expect(tester.widget<RouteColorModeSwitch>(toggle).modes, <RouteColorBy>[
      RouteColorBy.grade,
      RouteColorBy.wind,
    ]);
    expect(
      tester.widget<RouteColorModeSwitch>(toggle).value,
      RouteColorBy.wind,
    );

    // Pente, choisie en plein écran : l'état partagé change, la carte du
    // plein écran suit.
    await tester.tap(
      find.descendant(
        of: toggle,
        matching: find.byKey(keys.routeDetail.colorByMode('grade')),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);
    expect(map(tester).markers, isEmpty);
    expect(map(tester).tracks.single.segmentColors, everyElement(slopeNeutral));

    // Retour : la carte encastrée aussi.
    await tester.tap(find.byIcon(PdlIcons.close));
    await tester.pumpAndSettle();
    expect(find.byKey(keys.routeDetail.fullscreenColorBy), findsNothing);
    expect(track(tester).segmentColors, everyElement(slopeNeutral));
    expect(find.byKey(keys.rideGroup.windMapLegend), findsNothing);
  });

  testWidgets('plein écran sans prévision ni revêtement : rien à choisir, pas '
      'd\'interrupteur', (WidgetTester tester) async {
    await pump(tester, leg: null, mode: RouteColorBy.grade);
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    expect(find.byKey(keys.routeDetail.fullscreenColorBy), findsNothing);
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

  testWidgets('encastrée en mode « Météo » : les pastilles, et un toucher '
      'ouvre le plein écran, pas leur feuille (ledger `MOB-107`)', (
    WidgetTester tester,
  ) async {
    await pump(tester, leg: fixtureLeg());

    final PdlMap embedded = map(tester);
    expect(embedded.markers.map((PdlMapMarker m) => m.id), <String>[
      'weather.checkpoint.0',
      'weather.checkpoint.1',
    ]);
    expect(embedded.onMarkerTapped, isNotNull);

    embedded.onMarkerTapped!('weather.checkpoint.1');
    await tester.pumpAndSettle();
    expect(find.byKey(keys.rideGroup.weatherMapSheet), findsNothing);
    expect(find.byType(PdlSheet), findsNothing);
    expect(
      find.byWidgetPredicate((Widget w) => w is RideGroupsMap && w.fullscreen),
      findsOneWidget,
    );
    // Le plein écran, lui, n'a pas changé : la pastille ouvre sa feuille.
    map(tester).onMarkerTapped!('weather.checkpoint.1');
    await tester.pumpAndSettle();
    expect(find.byKey(keys.rideGroup.weatherMapSheet), findsOneWidget);
  });

  testWidgets(
    'hors mode « Météo », les bornes kilométriques du groupe (MOB-120)',
    (WidgetTester tester) async {
      await pump(tester, leg: fixtureLeg(), mode: RouteColorBy.grade);
      expect(map(tester).kmMarkers, isNotEmpty);
    },
  );

  testWidgets('en mode « Météo », pas de bornes kilométriques (MOB-120)', (
    WidgetTester tester,
  ) async {
    await pump(tester, leg: fixtureLeg());
    expect(map(tester).kmMarkers, isEmpty);
  });

  RideGroupDto g(String id, String? slug) =>
      fixtureGroup(id: id, routeSlug: slug);

  test('bornes (MOB-121), plusieurs groupes sur le même parcours : oui', () {
    expect(
      rideMapShowsKmMarkers(
        fixtureRide(groups: <RideGroupDto>[g('a', 'court'), g('b', 'court')]),
        null,
      ),
      isTrue,
    );
  });

  test('bornes (MOB-121), des parcours différents : non', () {
    expect(
      rideMapShowsKmMarkers(
        fixtureRide(groups: <RideGroupDto>[g('a', 'court'), g('b', 'long')]),
        null,
      ),
      isFalse,
    );
  });

  test('bornes (MOB-121), la page d\'un groupe : toujours', () {
    final RideGroupDto only = g('a', 'court');
    expect(
      rideMapShowsKmMarkers(
        fixtureRide(groups: <RideGroupDto>[only, g('b', 'long')]),
        only,
      ),
      isTrue,
    );
  });

  testWidgets('encastrée hors mode « Météo » : aucune pastille', (
    WidgetTester tester,
  ) async {
    await pump(tester, leg: fixtureLeg(), mode: RouteColorBy.grade);

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
    await pump(tester, leg: fixtureLeg(), mode: RouteColorBy.grade);
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    expect(map(tester).markers, isEmpty);
  });

  // ── Le réticule de la frise (ledger `MOB-93`) ───────────────────────────

  testWidgets('sans point de frise touché : pas de toucher plein écran, '
      'pas de réticule', (WidgetTester tester) async {
    await pump(tester, leg: fixtureLeg());

    expect(find.byKey(PdlMapHero.tapTargetKey), findsNothing);
    expect(map(tester).cursor, isNull);
  });

  testWidgets('le réticule tombe à la distance chaînée, sur deux traces', (
    WidgetTester tester,
  ) async {
    // Deux traces : 10 km plein nord, puis un saut de ~8 km vers l'est, et
    // 20 km dont la distance repart de 0. 15 km chaînés (saut nul) tombent au
    // 5ᵉ kilomètre de la seconde ; `PolylineIndex`, qui compte le saut,
    // tomberait ailleurs.
    final RouteDetailDto twoTracks = route.copyWith(
      tracks: <TrackDto>[
        TrackDto(
          line: GeoJsonLineString(
            type: GeoJsonLineStringTypeType.lineString,
            coordinates: <List<double>>[
              for (int i = 0; i <= 10; i++)
                <double>[5, 45 + i * 0.009, 300, i * 1000.0],
            ],
          ),
          climbs: const <ClimbDto>[],
        ),
        TrackDto(
          line: GeoJsonLineString(
            type: GeoJsonLineStringTypeType.lineString,
            coordinates: <List<double>>[
              for (int j = 0; j <= 20; j++)
                <double>[5.1, 45 + (10 + j) * 0.009, 300, j * 1000.0],
            ],
          ),
          climbs: const <ClimbDto>[],
        ),
      ],
    );
    await pump(
      tester,
      leg: fixtureLeg(),
      cursorDistance: 15000,
      geometry: twoTracks,
    );

    final PdlMapPoint cursor = map(tester).cursor!;
    expect(cursor.lon, 5.1);
    expect(cursor.lat, closeTo(45 + 15 * 0.009, 1e-9));
  });

  // ── La carte du bas (ledger `MOB-129`) ─────────────────────────────────
  /// La carte de surface qui porte [of].
  Finder cardOf(Finder of) =>
      find.ancestor(of: of, matching: find.byType(PdlMapFloatingCard));

  /// La place publiée par le hero à la carte qu'il encadre.
  double insetOf(WidgetTester tester) => PdlMapBottomInset.of(
    tester.element(find.byType(RideGroupsMapProbe).last),
  );

  testWidgets('plein écran : l\'interrupteur et la légende dans une seule '
      'carte, que le hero mesure', (WidgetTester tester) async {
    await pump(tester, leg: fixtureLeg(), attribution: openMeteo);
    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    final Finder full = find.byWidgetPredicate(
      (Widget w) => w is RideGroupsMap && w.fullscreen,
    );
    final Finder toggle = find.byKey(keys.routeDetail.fullscreenColorBy);
    final Finder legend = find.descendant(
      of: full,
      matching: find.byKey(keys.rideGroup.windMapLegend),
    );
    expect(cardOf(toggle), findsOneWidget);
    expect(cardOf(legend), findsOneWidget);
    // Une seule surface : la même carte, et la légende n'en a pas à elle.
    expect(
      identical(tester.widget(cardOf(toggle)), tester.widget(cardOf(legend))),
      isTrue,
    );
    expect(
      find.descendant(of: legend, matching: find.byType(PdlBlurSurface)),
      findsNothing,
    );
    // Le crédit Open-Meteo reste en clair, dans la carte.
    expect(
      find.descendant(
        of: cardOf(toggle),
        matching: find.byKey(keys.rideGroup.windMapCredit),
      ),
      findsOneWidget,
    );

    // L'interrupteur prend toute la largeur de la carte, marges comprises.
    final Rect card = tester.getRect(cardOf(toggle));
    expect(tester.getSize(toggle).width, card.width - 2 * PdlSpacing.chipGap);
    // L'inset publié est la hauteur de la carte, plus la marge du hero : la
    // ligne du bas (échelle, crédit ⓘ) se pose au-dessus.
    expect(insetOf(tester), card.height + PdlSpacing.sectionTightV);
  });

  testWidgets('vignette : la légende seule, à sa largeur, sous « Agrandir »', (
    WidgetTester tester,
  ) async {
    await pump(tester, leg: fixtureLeg());
    // La mesure est remontée après l'image : une de plus pour la publier.
    await tester.pump();

    final Finder legend = find.byKey(keys.rideGroup.windMapLegend);
    final Rect card = tester.getRect(cardOf(legend));
    final Rect hero = tester.getRect(find.byType(PdlMapHero));
    expect(find.byKey(keys.routeDetail.fullscreenColorBy), findsNothing);
    // À gauche, à la largeur de son contenu : elle laisse voir la carte.
    expect(card.left, hero.left + PdlSpacing.sectionTightV);
    expect(card.width, lessThan(hero.width - 2 * PdlSpacing.sectionTightV));
    expect(insetOf(tester), card.height + PdlSpacing.sectionTightV);
    // « Agrandir » au-dessus d'elle, plus jamais dessous.
    expect(
      tester.getRect(find.byIcon(PdlIcons.fullscreen)).bottom,
      lessThan(card.top),
    );
  });
}
