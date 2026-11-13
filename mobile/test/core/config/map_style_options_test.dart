import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pedalons/api/generated/models/map_style_dto.dart';
import 'package:pedalons/api/generated/models/unit_system.dart';
import 'package:pedalons/core/config/map_style_options.dart';
import 'package:pedalons/core/pdl/pdl.dart';

void main() {
  group('mapStyleGroupLabel', () {
    test('un groupe inconnu est rendu tel quel', () {
      // `group` est libre dans le contrat : le serveur peut en servir un que
      // cette version du client ne connaît pas. Le traduire afficherait sa clé
      // (`map.styleGroup.hillshade`), l'ignorer rangerait le fond sous la
      // section précédente — les deux mentent sur ce que le serveur a classé.
      expect(mapStyleGroupLabel('hillshade'), 'hillshade');
    });
  });

  group('mapStyleOptions', () {
    test('une ligne par fond servi, variante sombre ou non', () {
      const List<MapStyleDto> styles = <MapStyleDto>[
        MapStyleDto(
          id: 'cycling-road',
          label: 'Route',
          group: 'ign',
          url: 'https://tiles.example/road.json',
          darkVariant: 'https://tiles.example/road-dark.json',
        ),
        MapStyleDto(
          id: 'scan',
          label: 'Scan',
          group: 'ign',
          url: 'https://tiles.example/scan.json',
        ),
      ];
      expect(
        mapStyleOptions(styles).map((PdlMapStyleOption o) => o.id),
        <String>['cycling-road', 'scan'],
      );
    });
  });

  group('lightMapSwitch', () {
    List<PdlMapHeroSwitch> switches(Brightness brightness, bool hasDark) =>
        lightMapSwitch(
          brightness: brightness,
          hasDarkVariant: hasDark,
          value: true,
          onChanged: (_) {},
        );

    test('offert en thème sombre, sur un fond qui a une variante sombre', () {
      final PdlMapHeroSwitch option = switches(Brightness.dark, true).single;
      expect(option.id, 'lightMap');
      expect(option.value, isTrue);
    });

    test('absent là où il ne changerait rien', () {
      expect(switches(Brightness.light, true), isEmpty);
      expect(switches(Brightness.dark, false), isEmpty);
    });
  });

  group('mapScaleFor', () {
    String? label(UnitSystem units, double metersPerPixel) => Intl.withLocale(
      'fr',
      () => mapScaleFor(units).pick(metersPerPixel, 100)?.label,
    );

    test('métrique : mètres puis kilomètres', () {
      expect(label(UnitSystem.metric, 1), '100\u00a0m');
      expect(label(UnitSystem.metric, 10), '1\u00a0km');
      expect(label(UnitSystem.metric, 30), '2\u00a0km');
    });

    test('impérial : pieds puis milles, jamais de kilomètre', () {
      // 100 px à 1 m/px : 328 ft, donc le palier de 200 ft
      expect(label(UnitSystem.imperial, 1), '200\u00a0ft');
      // 100 px à 20 m/px : 2 000 m, soit 1,24 mi
      expect(label(UnitSystem.imperial, 20), '1\u00a0mi');
    });

    test('la barre ne dépasse jamais la largeur demandée', () {
      for (final UnitSystem units in <UnitSystem>[
        UnitSystem.metric,
        UnitSystem.imperial,
      ]) {
        for (final double mpp in <double>[0.5, 3, 47, 800, 12000]) {
          final PdlMapScaleStep step = mapScaleFor(units).pick(mpp, 100)!;
          expect(step.meters / mpp, lessThanOrEqualTo(100));
        }
      }
    });

    test('sans résolution exploitable, pas de barre', () {
      expect(mapScaleFor(UnitSystem.metric).pick(0, 100), isNull);
      expect(mapScaleFor(UnitSystem.metric).pick(double.nan, 100), isNull);
    });
  });
}
