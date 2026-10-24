import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_weather_map_markers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// Les pastilles météo de la carte plein écran d'un groupe (ledger `MOB-92`,
/// palier 2) : leur position sur un parcours à deux traces, leur égalité de
/// valeur, et le contenu de la feuille.
void main() {
  setUpAll(loadTestTranslations);

  /// [km] kilomètres plein nord, un sommet par kilomètre, la 4ᵉ composante
  /// repartant de 0 — comme une trace servie par l'API.
  List<List<double>> northbound(int km, {double lon = 5}) => <List<double>>[
    for (int i = 0; i <= km; i++)
      <double>[lon, 45 + i * 0.009, 300, i * 1000.0],
  ];

  // Deux traces de 10 et 20 km, la seconde loin à l'est : le point de 15 km
  // tombe à 5 km dans la seconde.
  final List<List<List<double>>> twoTracks = <List<List<double>>>[
    northbound(10),
    northbound(20, lon: 5.7),
  ];

  // Les heures du fixture tombent en 2099, au-delà des règles d'heure d'été
  // de la base des fuseaux : le point en route passe ici en juillet 2026,
  // 20:05 Z, soit 22:05 à Paris — et 20:05 dans le fuseau de l'appareil de
  // test (UTC).
  const String passage = '2026-07-29T20:05:00Z';
  final WeatherLegDto base = fixtureLeg(
    rainAlert: const WeatherRainAlertDto(
      probability: 70,
      time: passage,
      condition: 'RAIN',
      distance: 15000,
    ),
  );
  final WeatherLegDto leg = base.copyWith(
    checkpoints: <WeatherCheckpointDto>[
      base.checkpoints[0],
      base.checkpoints[1].copyWith(time: passage),
      base.checkpoints[2],
    ],
  );

  List<PdlMapMarker> markers({
    WeatherLegDto? of,
    UnitSystem units = UnitSystem.metric,
  }) => rideWeatherMapMarkers(
    lines: twoTracks,
    leg: of ?? leg,
    units: units,
    timezone: 'Europe/Paris',
  );

  group('positions', () {
    test('une pastille par point qui porte une météo, la goutte à 15 km', () {
      final List<PdlMapMarker> m = markers();

      // L'arrivée (index 2) n'a pas de météo : pas de pastille.
      expect(m.map((PdlMapMarker x) => x.id), <String>[
        weatherCheckpointMarkerId(0),
        weatherCheckpointMarkerId(1),
        weatherRainMarkerId,
      ]);
      // Départ : le premier sommet de la première trace.
      expect(m[0].lon, 5);
      expect(m[0].lat, 45);
      // 15 km chaînés, saut nul : 5 km dans la seconde trace.
      expect(m[1].lon, 5.7);
      expect(m[1].lat, closeTo(45 + 5 * 0.009, 1e-9));
      expect(m[2].lon, m[1].lon);
      expect(m[2].lat, m[1].lat);
      // La pastille au-dessus de son point, la goutte en dessous.
      expect(m[1].alignment, Alignment.bottomCenter);
      expect(m[2].alignment, Alignment.topCenter);
    });

    test('sans alerte pluie, pas de goutte ; sans distance non plus', () {
      expect(
        markers(of: fixtureLeg()).map((PdlMapMarker x) => x.id),
        isNot(contains(weatherRainMarkerId)),
      );
      final WeatherLegDto noDistance = fixtureLeg(
        rainAlert: const WeatherRainAlertDto(
          probability: 70,
          time: '2099-07-29T20:05:00Z',
          condition: 'RAIN',
        ),
      );
      expect(
        markers(of: noDistance).map((PdlMapMarker x) => x.id),
        isNot(contains(weatherRainMarkerId)),
      );
    });

    test('l\'annonce porte l\'heure de passage dans la zone de la sortie', () {
      // 20:05 Z en juillet : 22:05 à Paris.
      expect(markers()[1].semanticLabel, contains('22:05'));
      expect(markers()[1].semanticLabel, contains('15,0 km'));
      expect(markers()[1].semanticLabel, contains('14 °C'));
    });
  });

  group('égalité', () {
    test('reconstruits pour les mêmes données : égaux', () {
      expect(listEquals(markers(), markers()), isTrue);
    });

    test('une autre unité change l\'annonce, donc le marqueur', () {
      expect(
        listEquals(markers(), markers(units: UnitSystem.imperial)),
        isFalse,
      );
    });
  });

  group('la flèche absolue sur une carte tournée', () {
    test('le cap de la carte se retranche, dans [0, 360)', () {
      // Vent du nord-ouest (315°) : il souffle vers le sud-est, 135°.
      expect(windArrowOnMap(315, 0), 135);
      // Carte tournée de 90° (l'est en haut) : le sud-est pointe à 45°.
      expect(windArrowOnMap(315, 90), 45);
      expect(windArrowOnMap(315, 180), 315);
      expect(windArrowOnMap(0, 270), 270);
    });

    double arrowAngle(WidgetTester tester) => tester
        .widget<PdlWindArrow>(
          find.descendant(
            of: find.byType(RideWeatherPastille),
            matching: find.byType(PdlWindArrow),
          ),
        )
        .angle;

    Future<void> pumpPastille(WidgetTester tester, {double? bearing}) {
      final Widget pastille = SizedBox(
        width: 96,
        height: 32,
        child: RideWeatherPastille(
          weather: leg.checkpoints[1].weather!,
          units: UnitSystem.metric,
        ),
      );
      return tester.pumpWidget(
        MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: Center(
              child: bearing == null
                  ? pastille
                  : PdlMapBearing(bearing: bearing, child: pastille),
            ),
          ),
        ),
      );
    }

    testWidgets('hors carte : nord en haut', (WidgetTester tester) async {
      await pumpPastille(tester);
      final double north = windArrowOnMap(
        leg.checkpoints[1].weather!.wind.direction,
        0,
      );
      expect(arrowAngle(tester), north);
    });

    testWidgets('carte tournée : la pastille droite, la flèche compense', (
      WidgetTester tester,
    ) async {
      await pumpPastille(tester, bearing: 90);
      final double direction = leg.checkpoints[1].weather!.wind.direction;
      expect(arrowAngle(tester), windArrowOnMap(direction, 90));
      expect(arrowAngle(tester), isNot(windArrowOnMap(direction, 0)));

      // La carte tourne encore : la flèche suit.
      await pumpPastille(tester, bearing: 200);
      expect(arrowAngle(tester), windArrowOnMap(direction, 200));
    });
  });

  group('la feuille du détail', () {
    Future<void> pumpDetails(
      WidgetTester tester,
      WeatherCheckpointDto checkpoint, {
      UnitSystem units = UnitSystem.metric,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RideWeatherCheckpointDetails(
                checkpoint: checkpoint,
                units: units,
                timezone: 'Europe/Paris',
              ),
            ),
          ),
        ),
      );
    }

    WeatherCheckpointDto enRoute({
      double? gusts = 32,
      double precipitation = 1.2,
      int? probability = 60,
    }) => WeatherCheckpointDto(
      indexField: 1,
      kind: 'EN_ROUTE',
      distance: 15000,
      time: passage,
      weather: fixtureConditions(
        condition: 'RAIN',
        gusts: gusts,
        precipitation: precipitation,
        precipitationProbability: probability,
      ),
    );

    testWidgets('heure dans la zone de la sortie, pluie, vent et rafales', (
      WidgetTester tester,
    ) async {
      await pumpDetails(tester, enRoute());

      expect(find.byKey(keys.rideGroup.weatherMapSheet), findsOneWidget);
      expect(find.text('En route'), findsOneWidget);
      expect(find.text('Passage vers 22:05'), findsOneWidget);
      expect(find.text('À 15,0 km du départ'), findsOneWidget);
      expect(find.text('Pluie 60 %'), findsOneWidget);
      expect(find.text('1,2 mm de précipitations'), findsOneWidget);
      expect(find.text('Vent NO 18 km/h'), findsOneWidget);
      expect(find.text('Rafales 32 km/h'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rafales absentes : rien, jamais « 0 »', (
      WidgetTester tester,
    ) async {
      await pumpDetails(
        tester,
        enRoute(gusts: null, precipitation: 0, probability: null),
      );

      expect(find.textContaining('Rafales'), findsNothing);
      expect(find.textContaining('rafales'), findsNothing);
      expect(find.textContaining('précipitations'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('Vent NO 18 km/h'), findsOneWidget);
    });

    testWidgets('en impérial : °F, mph, miles', (WidgetTester tester) async {
      await pumpDetails(tester, enRoute(), units: UnitSystem.imperial);

      expect(find.textContaining('58 °F'), findsOneWidget);
      expect(find.text('Vent NO 11 mph'), findsOneWidget);
      expect(find.text('Rafales 20 mph'), findsOneWidget);
      expect(find.text('À 9,3 mi du départ'), findsOneWidget);
      expect(find.textContaining('km'), findsNothing);
      expect(find.textContaining('°C'), findsNothing);
    });

    testWidgets('la goutte : la phrase de l\'alerte, heure de la sortie', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: RideWeatherRainDetails(
              alert: leg.rainAlert!,
              units: UnitSystem.metric,
              timezone: 'Europe/Paris',
            ),
          ),
        ),
      );

      expect(find.text('Pluie probable'), findsOneWidget);
      expect(
        find.text('Pluie probable (70 %) vers 22:05, à 15,0 km.'),
        findsOneWidget,
      );
    });
  });
}
