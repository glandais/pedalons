import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/units/unit_system.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/rides/domain/ride_group_action.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_group_card.dart';

import '../support/localization.dart';
import 'rides/ride_fixtures.dart';

/// S11-8 — la passe transverse du lot 2 : accessibilité, unités, jeux de clés.
///
/// Trois choses y sont vérifiées mécaniquement, parce qu'elles se cassent
/// silencieusement :
///
/// * **aucune cible sous 44 px** — un `size: sm` qu'on croit devoir compacter
///   jusqu'à la cible est l'erreur la plus facile à commettre ;
/// * **rien ne déborde à `textScaleFactor = 2,0`** — le brief l'exige, et
///   c'est là que les rangées de statistiques cèdent ;
/// * **`fr.json` et `en.json` portent le même jeu de clés** — une clé ajoutée
///   d'un seul côté ne se voit qu'en anglais, longtemps après.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  group('jeux de clés', () {
    Set<String> keysOf(Map<String, dynamic> map, [String prefix = '']) {
      final Set<String> keys = <String>{};
      map.forEach((String k, dynamic v) {
        keys.add('$prefix$k');
        if (v is Map<String, dynamic>) keys.addAll(keysOf(v, '$prefix$k.'));
      });
      return keys;
    }

    test('fr et en déclarent exactement les mêmes clés', () {
      final Map<String, dynamic> fr =
          json.decode(File('assets/l10n/fr.json').readAsStringSync())
              as Map<String, dynamic>;
      final Map<String, dynamic> en =
          json.decode(File('assets/l10n/en.json').readAsStringSync())
              as Map<String, dynamic>;

      expect(
        keysOf(fr).difference(keysOf(en)),
        isEmpty,
        reason: 'clés présentes en français seulement',
      );
      expect(
        keysOf(en).difference(keysOf(fr)),
        isEmpty,
        reason: 'clés présentes en anglais seulement',
      );
    });
  });

  group('unités', () {
    test('la même distance se lit dans les deux systèmes', () {
      // Le champ existe au contrat ; coder « km » en dur imposerait de rouvrir
      // tous les écrans plus tard (§1.0.4).
      expect(
        AppFormatters.formatDistance(66500, UnitSystem.metric),
        contains('66,5'),
      );
      // Le séparateur suit la **langue**, pas le système d'unités : un
      // francophone en impérial lit « 41,3 mi ».
      expect(
        AppFormatters.formatDistance(66500, UnitSystem.imperial),
        contains('41,3'),
      );
      expect(
        AppFormatters.formatDistance(66500, UnitSystem.imperial),
        contains('mi'),
      );
      expect(
        AppFormatters.formatElevation(413, UnitSystem.imperial),
        contains('ft'),
      );
    });
  });

  group('cibles tactiles et débordement', () {
    /// La carte de groupe est le composant le plus dense du lot : quatre
    /// statistiques, des avatars, un bouton et jusqu'à quatre actions texte.
    /// Si quelque chose déborde à ×2,0, c'est ici.
    Future<void> pumpGroupCard(
      WidgetTester tester, {
      required double scale,
      required Brightness brightness,
      required UnitSystem units,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MaterialApp(
            theme: PedalonsTheme.build(brightness),
            home: Scaffold(
              body: SingleChildScrollView(
                child: RideGroupCard(
                  group: fixtureGroup(
                    leader: const PublicUserDto(
                      id: 'u9',
                      displayName: 'Antoine Yvon',
                    ),
                  ),
                  rideDateTime: '2026-10-11T06:00:00Z',
                  timezone: 'Europe/Paris',
                  action: RideGroupAction.join,
                  trackColor: multiTrackColor(0),
                  units: units,
                  selected: true,
                  onJoin: () {},
                  onShowParticipants: () {},
                  onExportGpx: () {},
                  onExportFit: () {},
                  onSendToDevice: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final Brightness brightness in Brightness.values) {
      for (final UnitSystem units in <UnitSystem>[
        UnitSystem.metric,
        UnitSystem.imperial,
      ]) {
        final String mode = brightness == Brightness.light ? 'clair' : 'sombre';
        final String system = units.isImperial ? 'impérial' : 'métrique';

        testWidgets('rien ne déborde à ×1,0 et ×2,0 — $mode, $system', (
          WidgetTester tester,
        ) async {
          for (final double scale in <double>[1.0, 1.3, 2.0]) {
            await pumpGroupCard(
              tester,
              scale: scale,
              brightness: brightness,
              units: units,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: 'débordement à ×$scale en $mode / $system',
            );
          }
        });
      }
    }

    testWidgets('aucun bouton ne descend sous 44 px, même compacté', (
      WidgetTester tester,
    ) async {
      await pumpGroupCard(
        tester,
        scale: 1,
        brightness: Brightness.light,
        units: UnitSystem.metric,
      );

      for (final Element element in find.byType(PdlButton).evaluate()) {
        final Size size = tester.getSize(find.byWidget(element.widget));
        expect(
          size.height,
          greaterThanOrEqualTo(PdlMetrics.tapTarget),
          reason:
              'un ${(element.widget as PdlButton).label} de ${size.height} px',
        );
      }
    });
  });
}
