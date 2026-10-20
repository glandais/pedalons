import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/theme/enum_colors.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';

/// Le trait d'une classe de revêtement (ledger `MOB-81`).
void main() {
  const List<TrackSurface> classes = <TrackSurface>[
    TrackSurface.paved,
    TrackSurface.pavedRough,
    TrackSurface.gravel,
    TrackSurface.dirt,
    TrackSurface.path,
    TrackSurface.unknown,
    TrackSurface.offNetwork,
  ];

  // Rapport de contraste WCAG entre deux couleurs opaques.
  double contrast(Color a, Color b) {
    final double la = a.computeLuminance();
    final double lb = b.computeLuminance();
    final double hi = la > lb ? la : lb;
    final double lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  test('en sombre, chaque trait tient 3:1 sur la surface du profil', () {
    const PdlColors c = PdlColors.dark;
    for (final TrackSurface s in classes) {
      expect(
        contrast(s.stroke(c), c.surface),
        greaterThanOrEqualTo(3),
        reason: '$s',
      );
    }
  });

  for (final (String name, PdlColors c) in <(String, PdlColors)>[
    ('clair', PdlColors.light),
    ('sombre', PdlColors.dark),
  ]) {
    group('thème $name', () {
      test('chaque classe a un trait opaque', () {
        for (final TrackSurface s in classes) {
          expect(s.stroke(c).a, 1, reason: '$s');
        }
        expect(TrackSurface.$unknown.stroke(c), TrackSurface.unknown.stroke(c));
      });

      test('les trois gris sont distincts deux à deux', () {
        final Set<int> grays = <int>{
          TrackSurface.paved.stroke(c).toARGB32(),
          TrackSurface.unknown.stroke(c).toARGB32(),
          TrackSurface.offNetwork.stroke(c).toARGB32(),
        };
        expect(grays, hasLength(3));
      });

      test(
        'une famille non grise rend l\'aplat clair du YAML, comme le site',
        () {
          for (final TrackSurface s in classes) {
            if (s.family == PdlFamily.gray) continue;
            expect(
              s.stroke(c),
              s.family.soft(PdlColors.light).fill,
              reason: '$s',
            );
          }
        },
      );
    });
  }
}
