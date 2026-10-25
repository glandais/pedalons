import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/elevation/elevation_samples.dart';

/// L'agrégation est du calcul pur : elle se teste sans binding et sans thème.
void main() {
  group('ElevationSamples.fromPoints', () {
    test('la pente d\'une barre est la moyenne pondérée par la distance', () {
      // Deux segments dans la même barre : 10 m à 10 % et 90 m à 0 %.
      // Une moyenne arithmétique donnerait 5 %, la bonne réponse est 1 %.
      final ElevationSamples s = ElevationSamples.fromPoints(
        const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 100, grade: 0),
          ElevationPoint(distance: 10, elevation: 101, grade: 10),
          ElevationPoint(distance: 100, elevation: 101, grade: 0),
        ],
        targetBars: 1,
      );

      expect(s.bars, hasLength(1));
      expect(s.bars.single.grade, closeTo(1, 1e-9));
    });

    test('un segment à cheval sur deux barres est réparti au prorata', () {
      // Points à 0, 60 et 100 m, deux barres de 50 m : le segment 0→60 à 10 %
      // déborde de 10 m sur la seconde barre, qui voit donc 10 m à 10 % et
      // 40 m à 0 % → 2 %.
      final ElevationSamples s = ElevationSamples.fromPoints(
        const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 0, grade: 0),
          ElevationPoint(distance: 60, elevation: 6, grade: 10),
          ElevationPoint(distance: 100, elevation: 6, grade: 0),
        ],
        targetBars: 2,
      );

      expect(s.bars, hasLength(2));
      expect(s.bars.first.grade, closeTo(10, 1e-9));
      expect(s.bars.last.grade, closeTo(2, 1e-9));
    });

    test('des segments inégaux pondèrent bien par la longueur réelle', () {
      // 1 m à 20 % puis 99 m à 0 % → 0,2 %, pas 10 %.
      final ElevationSamples s = ElevationSamples.fromPoints(
        const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 0, grade: 0),
          ElevationPoint(distance: 1, elevation: 0.2, grade: 20),
          ElevationPoint(distance: 100, elevation: 0.2, grade: 0),
        ],
        targetBars: 1,
      );

      expect(s.bars.single.grade, closeTo(0.2, 1e-9));
    });

    test('moins de points que de barres voulues : on n\'invente pas', () {
      // Le serveur borne `samples` au nombre de points **réellement stockés** :
      // demander 76 barres sur un profil de 4 points doit en rendre 3, pas 76
      // copies.
      final ElevationSamples s = ElevationSamples.fromPoints(
        const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 0, grade: 0),
          ElevationPoint(distance: 10, elevation: 5, grade: 50),
          ElevationPoint(distance: 20, elevation: 5, grade: 0),
          ElevationPoint(distance: 30, elevation: 0, grade: -50),
        ],
      );

      expect(s.bars, hasLength(3));
      expect(s.bars.first.grade, closeTo(50, 1e-9));
      expect(s.bars.last.grade, closeTo(-50, 1e-9));
    });

    test('un profil de moins de deux points ne produit aucune barre', () {
      expect(
        ElevationSamples.fromPoints(const <ElevationPoint>[]).isEmpty,
        isTrue,
      );
      expect(
        ElevationSamples.fromPoints(const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 12),
        ]).isEmpty,
        isTrue,
      );
    });

    test('une barre sans pente connue reste nulle', () {
      final ElevationSamples s = ElevationSamples.fromPoints(
        const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 0),
          ElevationPoint(distance: 10, elevation: 1),
        ],
        targetBars: 1,
      );

      expect(s.bars.single.grade, isNull);
    });

    test('les bornes du serveur priment sur celles des points', () {
      final ElevationSamples s = ElevationSamples.fromPoints(
        const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 100, grade: 0),
          ElevationPoint(distance: 1000, elevation: 200, grade: 10),
        ],
        totalDistance: 1200,
        minElevation: 50,
        maxElevation: 400,
      );

      expect(s.totalDistance, 1200);
      expect(s.minElevation, 50);
      expect(s.maxElevation, 400);
    });

    test('la hauteur relative reste dans [0.10, 0.94]', () {
      final ElevationSamples s = ElevationSamples.fromPoints(
        const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 0, grade: 0),
          ElevationPoint(distance: 100, elevation: 100, grade: 10),
        ],
        targetBars: 2,
      );

      for (final ElevationBar bar in s.bars) {
        expect(s.normalizedHeight(bar), inInclusiveRange(0.10, 0.94));
      }
      // Profil plat : pas de division par zéro, tout au plancher.
      final ElevationSamples flat = ElevationSamples.fromPoints(
        const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 42, grade: 0),
          ElevationPoint(distance: 100, elevation: 42, grade: 0),
        ],
        targetBars: 1,
      );
      expect(flat.normalizedHeight(flat.bars.single), closeTo(0.10, 1e-9));
    });
  });

  group('readingAt', () {
    test('interpole l\'altitude entre les deux points encadrants', () {
      final ElevationSamples s = ElevationSamples.fromPoints(
        const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 0, grade: 0),
          ElevationPoint(distance: 100, elevation: 100, grade: 100),
        ],
        targetBars: 1,
      );

      final ElevationReading r = s.readingAt(25)!;
      expect(r.distance, 25);
      expect(r.elevation, closeTo(25, 1e-9));
      expect(r.grade, closeTo(100, 1e-9));
    });

    test('borne aux extrémités plutôt que d\'extrapoler', () {
      final ElevationSamples s = ElevationSamples.fromPoints(
        const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 10, grade: 0),
          ElevationPoint(distance: 100, elevation: 20, grade: 10),
        ],
        targetBars: 1,
      );

      expect(s.readingAt(-50)!.elevation, 10);
      expect(s.readingAt(500)!.elevation, 20);
    });
  });
}
