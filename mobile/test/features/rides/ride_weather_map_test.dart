import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/geo/polyline_index.dart';
import 'package:pedalons/core/theme/enum_colors.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';
import 'package:pedalons/features/rides/domain/ride_weather_map.dart';

import 'ride_fixtures.dart';

/// Le vent sur le tracé d'un groupe (ledger `MOB-91`) : les distances
/// chaînées **sans saut** entre les traces, la convention des distances
/// météo du serveur (`RouteSampleLookup.chain`), et une couleur par
/// intervalle de chaque ligne brute.
void main() {
  /// Une trace de [km] kilomètres plein nord, un sommet par kilomètre, sa
  /// 4ᵉ composante partant de [startM] — comme `northbound` du
  /// `RouteSampleLookupTest`.
  List<List<double>> northbound(
    int km, {
    double lon = 5,
    double lat = 45,
    double startM = 0,
  }) => <List<double>>[
    for (int i = 0; i <= km; i++)
      <double>[lon, lat + i * 0.009, 300, startM + i * 1000.0],
  ];

  WindSegmentDto segment(double from, double to, String wind) => WindSegmentDto(
    fromDistance: from,
    toDistance: to,
    relativeWind: wind,
    headwind: 0,
  );

  group('chainedMeasures', () {
    test('deux traces de 20 km, la seconde repartant de 0 : 40 km, saut nul', () {
      // La seconde trace commence à 50 km de la fin de la première : le saut
      // ne compte pas, quelle que soit la distance qui les sépare sur la carte.
      final List<List<List<double>>> lines = <List<List<double>>>[
        northbound(20),
        northbound(20, lon: 5.7),
      ];

      final List<List<double>> m = chainedMeasures(lines);

      expect(m[0].first, 0);
      expect(m[0].last, 20000);
      expect(m[1].first, 20000);
      expect(m[1][1], 21000);
      expect(m[1].last, 40000);
      // PolylineIndex, lui, compte le saut à vol d'oiseau : c'est pourquoi il
      // ne sert pas ici.
      expect(
        PolylineIndex.fromLineStrings(lines).totalDistance,
        greaterThan(80000),
      );
    });

    test('une trace dont la distance part de 7 km reste chaînée à 20 km', () {
      final List<double> m = chainedMeasures(<List<List<double>>>[
        northbound(20),
        northbound(20, startM: 7000),
      ])[1];
      expect(m.first, 20000);
      expect(m.last, 40000);
    });

    test('une ligne vide n’avance rien, une distance ne recule jamais', () {
      final List<List<double>> broken = northbound(3)
        ..[2] = <double>[5, 45.018, 300, 500];
      final List<List<double>> m = chainedMeasures(<List<List<double>>>[
        <List<double>>[],
        broken,
        northbound(1),
      ]);
      expect(m[0], isEmpty);
      expect(m[1], <double>[0, 1000, 1000, 3000]);
      expect(m[2], <double>[3000, 4000]);
    });

    test('sans 4ᵉ composante, la haversine dans la trace', () {
      final List<double> m = chainedMeasures(<List<List<double>>>[
        <List<double>>[
          <double>[5, 45],
          <double>[5, 45.009],
        ],
      ])[0];
      expect(m.first, 0);
      expect(m.last, closeTo(1000, 5));
    });
  });

  group('windSegmentColors', () {
    test(
      'deux traces : la couleur suit les distances chaînées, pas le saut',
      () {
        // Le fixture du serveur : deux traces de 20 km, prévisions tous les
        // 15 km — 0 → 15 face, 15 → 30 dos, 30 → 40 travers.
        final List<String?> colors = windSegmentColors<String?>(
          <List<List<double>>>[northbound(20), northbound(20, lon: 5.7)],
          <WindSegmentDto>[
            // Dans le désordre : la fonction trie elle-même.
            segment(30000, 40000, 'CROSS'),
            segment(0, 15000, 'HEAD'),
            segment(15000, 30000, 'TAIL'),
          ],
          (RelativeWind? w) => w?.name,
        );

        // Une couleur par intervalle de chaque ligne brute : 20 + 20.
        expect(colors.length, 40);
        expect(colors.sublist(0, 15), everyElement('head'));
        expect(colors.sublist(15, 20), everyElement('tail'));
        // La seconde trace commence à 20 km chaînés, pas au-delà du saut.
        expect(colors.sublist(20, 30), everyElement('tail'));
        expect(colors.sublist(30, 40), everyElement('cross'));
      },
    );

    test('hors des tronçons ou vent inconnu : null, jamais le travers', () {
      final List<String?> colors = windSegmentColors<String?>(
        <List<List<double>>>[northbound(4)],
        <WindSegmentDto>[
          segment(0, 2000, 'SOMETHING_NEW'),
          segment(2000, 3000, 'TAIL'),
        ],
        (RelativeWind? w) => w?.name,
      );
      expect(colors, <String?>[null, null, 'tail', null]);
    });

    test('une ligne d’un seul sommet ne compte aucun intervalle', () {
      final List<String?> colors = windSegmentColors<String?>(
        <List<List<double>>>[
          <List<double>>[
            <double>[5, 45, 0, 0],
          ],
          northbound(2),
        ],
        <WindSegmentDto>[segment(0, 2000, 'HEAD')],
        (RelativeWind? w) => w?.name,
      );
      expect(colors, <String?>['head', 'head']);
    });
  });

  group('showsWindOnMap', () {
    test('OK et STALE avec une météo : oui', () {
      expect(showsWindOnMap(fixtureLeg()), isTrue);
      expect(showsWindOnMap(fixtureLeg(status: 'STALE')), isTrue);
    });

    test('aucune prévision : non', () {
      expect(showsWindOnMap(null), isFalse);
      for (final String status in <String>[
        'NOT_YET_AVAILABLE',
        'NO_LOCATION',
        'OUT_OF_RANGE',
        'UNAVAILABLE',
        'SOMETHING_NEW',
      ]) {
        expect(showsWindOnMap(fixtureLeg(status: status)), isFalse);
      }
    });

    test('aucun point ne porte de météo, ou aucun tronçon : non', () {
      final WeatherLegDto leg = fixtureLeg();
      expect(
        showsWindOnMap(
          leg.copyWith(
            checkpoints: <WeatherCheckpointDto>[
              for (final WeatherCheckpointDto c in leg.checkpoints)
                c.copyWith(weather: null),
            ],
          ),
        ),
        isFalse,
      );
      expect(
        showsWindOnMap(leg.copyWith(segments: const <WindSegmentDto>[])),
        isFalse,
      );
    });
  });

  test('le trait du vent : nuance 6 du thème clair, dans les deux thèmes', () {
    expect(RelativeWind.tail.stroke, PdlColors.light.accentTeal);
    expect(RelativeWind.cross.stroke, PdlColors.light.neutral);
    expect(RelativeWind.head.stroke, PdlColors.light.accentOrange);
  });

  group('pointsAtDistances', () {
    test(
      'deux traces, la seconde repartant de 0 : chaque point sur son sommet',
      () {
        // Comme `chainedMeasures` : la seconde trace, décalée de 0,7° à l'est,
        // commence à 20 km chaînés, sans compter le saut.
        final List<List<List<double>>> lines = <List<List<double>>>[
          northbound(20),
          northbound(20, lon: 5.7),
        ];

        final List<LngLat?> points = pointsAtDistances(lines, <double>[
          0,
          15000,
          20000,
          25000,
          40000,
        ]);

        expect(points[0], const LngLat(5, 45));
        expect(points[1]!.lng, 5);
        expect(points[1]!.lat, closeTo(45 + 15 * 0.009, 1e-9));
        // 20 km : le dernier sommet de la première trace, premier à l'atteindre.
        expect(points[2]!.lng, 5);
        expect(points[2]!.lat, closeTo(45 + 20 * 0.009, 1e-9));
        // 25 km : 5 km dans la seconde trace — pas 5 km avant, comme le
        // donnerait le saut compté à vol d'oiseau.
        expect(points[3]!.lng, 5.7);
        expect(points[3]!.lat, closeTo(45 + 5 * 0.009, 1e-9));
        expect(points[4]!.lng, 5.7);
        expect(points[4]!.lat, closeTo(45 + 20 * 0.009, 1e-9));
      },
    );

    test('un arrondi du serveur sous le demi-mètre tombe sur le sommet', () {
      final List<LngLat?> points = pointsAtDistances(
        <List<List<double>>>[northbound(3)],
        <double>[1000.4, 1000.6],
      );
      expect(points[0]!.lat, closeTo(45.009, 1e-9));
      // Au-delà du demi-mètre : le sommet suivant.
      expect(points[1]!.lat, closeTo(45.018, 1e-9));
    });

    test('au-delà de la fin : le dernier sommet ; sans sommet : rien', () {
      expect(
        pointsAtDistances(
          <List<List<double>>>[northbound(2)],
          <double>[9000],
        ).single!.lat,
        closeTo(45.018, 1e-9),
      );
      expect(
        pointsAtDistances(<List<List<double>>>[<List<double>>[]], <double>[0]),
        <LngLat?>[null],
      );
    });
  });
}
