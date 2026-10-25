import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/models/ad_type.dart';
import 'package:pedalons/api/generated/models/climb_category.dart';
import 'package:pedalons/api/generated/models/publication_type.dart';
import 'package:pedalons/api/generated/models/status.dart';
import 'package:pedalons/api/generated/models/surface_type.dart';
import 'package:pedalons/api/generated/models/team_role.dart';
import 'package:pedalons/api/generated/models/visibility.dart';
import 'package:pedalons/core/theme/enum_colors.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pdl_typography.dart';

/// Compare une couleur à une teinte HSL exprimée comme dans le plan §1.1.5,
/// à un canal près (`HSLColor.toColor` arrondit).
void expectHsl(Color actual, double h, double s, double l) {
  final Color expected = HSLColor.fromAHSL(1, h, s, l).toColor();
  expect(
    actual.toARGB32(),
    expected.toARGB32(),
    reason: 'attendu hsl($h, $s, $l)',
  );
}

void main() {
  group('PdlColors', () {
    test(
      'la primaire est foncée d\'une nuance en clair, l\'indigo métier non',
      () {
        expect(PdlColors.light.primary.toARGB32(), 0xFF4263EB);
        expect(PdlColors.dark.primary.toARGB32(), 0xFF3B5BDB);
        expect(PdlColors.light.accentIndigo.toARGB32(), 0xFF4C6EF5);
        expect(PdlColors.dark.accentIndigo.toARGB32(), 0xFF3B5BDB);
      },
    );

    test('les 9 paires douces de badge sont exposées dans les deux modes', () {
      for (final PdlColors c in <PdlColors>[PdlColors.light, PdlColors.dark]) {
        expect(c.softPairs, hasLength(9));
        // Aucune paire n'est dégénérée : un fond doux et son texte ne peuvent
        // pas être la même couleur, sinon le badge est illisible.
        for (final PdlSoftPair p in c.softPairs) {
          expect(p.background, isNot(p.foreground));
        }
        // Les paires sont distinctes entre elles, à l'exception documentée de
        // « Vente » et « Publié » qui partagent la famille verte — elles ne
        // sont représentées qu'une fois dans la liste.
        expect(c.softPairs.toSet(), hasLength(9));
      }
    });

    test('les paires douces claires valent les littéraux de pedalons.css', () {
      const PdlColors c = PdlColors.light;
      expect(c.softBlue.background.toARGB32(), 0xFFD0EBFF);
      expect(c.softBlue.foreground.toARGB32(), 0xFF1864AB);
      expect(c.softGrape.background.toARGB32(), 0xFFF3D9FA);
      expect(c.softTeal.background.toARGB32(), 0xFFC3FAE8);
      expect(c.softOrange.background.toARGB32(), 0xFFFFE8CC);
      expect(c.softGreen.background.toARGB32(), 0xFFD3F9D8);
      expect(c.softGray.background.toARGB32(), 0xFFF1F3F5);
      expect(c.softDone.background.toARGB32(), 0xFFE9ECEF);
      expect(c.softRed.background.toARGB32(), 0xFFFFE3E3);
      expect(c.softIndigo.background.toARGB32(), 0xFFDBE4FF);
    });

    test('les paires douces sombres suivent la règle de dérivation §1.1.2', () {
      // soft(sombre) = nuance 9 × 0,5 ; on-soft(sombre) = nuance 0.
      const PdlColors c = PdlColors.dark;
      expect(
        c.softIndigo.background.toARGB32(),
        0xFF1B2864,
      ); // indigo-9 #364fc7 ÷2
      expect(c.softIndigo.foreground.toARGB32(), 0xFFEDF2FF); // indigo-0
      expect(
        c.softGreen.background.toARGB32(),
        0xFF16451F,
      ); // green-9 #2b8a3e ÷2
      expect(c.softRed.background.toARGB32(), 0xFF651515); // red-9 #c92a2a ÷2
      expect(c.softGray.background.toARGB32(), 0xFF111315); // gray-9 #212529 ÷2
      expect(c.warningSoft.toARGB32(), 0xFF733C00); // yellow-9 #e67700 ÷2
      expect(c.warningOnSoft.toARGB32(), 0xFFFFF9DB); // yellow-0
    });

    test(
      'le voile et la barrière de feuille sont identiques dans les deux modes',
      () {
        expect(PdlColors.light.scrim, PdlColors.dark.scrim);
        expect(PdlColors.light.sheetBarrier, PdlColors.dark.sheetBarrier);
      },
    );

    test('lerp interpole et copyWith préserve les champs non nommés', () {
      final PdlColors mid = PdlColors.light.lerp(PdlColors.dark, 1.0);
      expect(mid.primary, PdlColors.dark.primary);
      final PdlColors copy = PdlColors.light.copyWith(
        primary: PdlColors.dark.primary,
      );
      expect(copy.primary, PdlColors.dark.primary);
      expect(copy.surfaceAlt, PdlColors.light.surfaceAlt);
    });
  });

  group('PdlTypography', () {
    test('screenTitle est 22/700 avec letterSpacing −0.2', () {
      final PdlTypography t = PdlTypography.of(Brightness.light);
      expect(t.screenTitle.fontSize, 22);
      expect(t.screenTitle.fontWeight, FontWeight.w700);
      expect(t.screenTitle.letterSpacing, -0.2);
      expect(t.screenTitle.color, PdlColors.light.textBright);
    });

    test('badge est 10/700 CAPS avec letterSpacing 0.25', () {
      final PdlTypography t = PdlTypography.of(Brightness.light);
      expect(t.badge.fontSize, 10);
      expect(t.badge.fontWeight, FontWeight.w700);
      expect(t.badge.letterSpacing, 0.25);
      expect(t.badgeLg.fontSize, 11);
      expect(t.badgeLg.letterSpacing, 0.25);
    });

    test('la pile mono passe par fontFamilyFallback, pas par une police téléchargée', () {
      final PdlTypography t = PdlTypography.of(Brightness.light);
      expect(t.mono.fontFamilyFallback, PdlTypography.monoFallback);
      expect(t.monoAxis.fontFamilyFallback, PdlTypography.monoFallback);
      expect(t.monoAxis.color, PdlColors.light.textPlaceholder);
    });

    test('le mode sombre repeint les rôles sans changer les métriques', () {
      final PdlTypography l = PdlTypography.of(Brightness.light);
      final PdlTypography d = PdlTypography.of(Brightness.dark);
      expect(d.screenTitle.fontSize, l.screenTitle.fontSize);
      expect(d.screenTitle.color, PdlColors.dark.textBright);
      expect(d.body.color, PdlColors.dark.text);
    });
  });

  group('slopeColor', () {
    test('0 % est le vert de tête d\'échelle', () {
      expectHsl(slopeColor(0), 85, 0.86, 0.62);
    });

    test('18 % et au-delà saturent sur le violet', () {
      expectHsl(slopeColor(18), 255, 0.86, 0.62);
      expectHsl(slopeColor(40), 255, 0.86, 0.62);
    });

    test('une pente négative est bornée sur le vert', () {
      expectHsl(slopeColor(-12), 85, 0.86, 0.62);
    });

    test('la pente inconnue a sa propre teinte, hors de l\'échelle', () {
      expectHsl(slopeNeutral, 210, 0.86, 0.62);
      expect(slopeNeutral, isNot(slopeColor(0)));
    });
  });

  group('kMultiTrackPalette', () {
    test('compte 10 couleurs dans l\'ordre imposé', () {
      expect(kMultiTrackPalette, hasLength(10));
      expect(kMultiTrackPalette.first.toARGB32(), 0xFF566B13);
      expect(kMultiTrackPalette.last.toARGB32(), 0xFFE3A209);
    });

    test('multiTrackColor boucle modulo 10 et encaisse un index négatif', () {
      expect(multiTrackColor(0), kMultiTrackPalette[0]);
      expect(multiTrackColor(10), kMultiTrackPalette[0]);
      expect(multiTrackColor(13), kMultiTrackPalette[3]);
      expect(multiTrackColor(-3), kMultiTrackPalette[3]);
    });
  });

  group('PdlTone', () {
    test('seules les catégories de col se rendent en aplat', () {
      const PdlColors c = PdlColors.light;
      for (final ClimbCategory k in ClimbCategory.values) {
        expect(k.tone(c).filledStyle, isTrue, reason: '$k');
      }
      expect(Status.published.tone(c).filledStyle, isFalse);
      expect(TeamRole.admin.tone(c).filledStyle, isFalse);
      expect(AdType.sale.tone(c).filledStyle, isFalse);
      expect(PublicationType.trip.tone(c).filledStyle, isFalse);
      expect(SurfaceType.gravel.tone(c).filledStyle, isFalse);
    });

    test('CAT3 est la seule catégorie à texte foncé sur son aplat', () {
      const PdlColors c = PdlColors.light;
      expect(ClimbCategory.cat3.tone(c).onFill, c.neutralOnSoft);
      for (final ClimbCategory k in <ClimbCategory>[
        ClimbCategory.hc,
        ClimbCategory.cat1,
        ClimbCategory.cat2,
        ClimbCategory.cat4,
      ]) {
        expect(k.tone(c).onFill.toARGB32(), 0xFFFFFFFF, reason: '$k');
      }
    });

    // BRAND-2 : la route est gris doux partout, trait de rappel compris — le
    // near-black de la charte a quitté les jetons Flutter.
    test('le revêtement « route » est gris doux, aplat compris', () {
      const PdlColors c = PdlColors.light;
      final PdlTone road = SurfaceType.road.tone(c);
      expect(road.fill, c.neutral);
      expect(road.soft, c.softGray.background);
      expect(road.onSoft, c.softGray.foreground);
    });

    test('les 7 enums couvrent leur valeur inconnue sans planter', () {
      const PdlColors c = PdlColors.dark;
      expect(Status.$unknown.tone(c).soft, c.softGray.background);
      expect(TeamRole.$unknown.tone(c).soft, c.softGray.background);
      expect(SurfaceType.$unknown.tone(c).soft, c.softGray.background);
      expect(ClimbCategory.$unknown.tone(c).soft, c.softGray.background);
      expect(AdType.$unknown.tone(c).soft, c.softGray.background);
      expect(Visibility.$unknown.tone(c).soft, c.softGray.background);
      expect(PublicationType.$unknown.tone(c).soft, c.softGray.background);
    });
  });

  group('PdlShadows', () {
    test('en sombre l\'ombre ne porte pas, sauf pour les feuilles', () {
      expect(PdlShadows.md(Brightness.light), isNotEmpty);
      expect(PdlShadows.md(Brightness.dark), isEmpty);
      expect(PdlShadows.segThumb(Brightness.dark), isEmpty);
      expect(PdlShadows.sheet, isNotEmpty);
    });
  });
}
