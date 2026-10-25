import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/features/routes/domain/route_waypoints.dart';
import 'package:pedalons/features/routes/presentation/widgets/waypoint_selection.dart';

import 'route_fixtures.dart';

/// Les points de parcours d'auteur côté mobile (ledger `MOB-84`).
void main() {
  group('waypointTypeOf', () {
    test('un type inconnu se rend comme une information', () {
      expect(waypointTypeOf('CAMPSITE'), WaypointType.info);
      expect(waypointTypeOf(''), WaypointType.info);
      expect(waypointTypeOf(r'$unknown'), WaypointType.info);
      expect(waypointTypeOf('DANGER'), WaypointType.danger);
    });

    test('la table de priorité couvre tous les types du contrat', () {
      expect(
        kWaypointPriority.keys.toSet(),
        WaypointType.$valuesDefined.toSet(),
      );
      expect(kWaypointPriority.values.toSet(), hasLength(12));
      expect(kWaypointPriority[WaypointType.danger], 11);
      expect(kWaypointPriority[WaypointType.info], 0);
    });

    test(
      'les 12 glyphes sont distincts, et le type inconnu prend celui de INFO',
      () {
        final Set<int> codes = <int>{
          for (final WaypointType t in WaypointType.$valuesDefined)
            t.glyph.codePoint,
        };
        expect(codes, hasLength(12));
        expect(WaypointType.$unknown.glyph, WaypointType.info.glyph);
      },
    );
  });

  group('tri et clés', () {
    test('le long du parcours, hors tracé à la fin, stable', () {
      final List<WaypointDto> list = <WaypointDto>[
        fixtureWaypoint(id: 'a', distance: null, name: 'hors'),
        fixtureWaypoint(id: 'b', distance: 500, name: 'b'),
        fixtureWaypoint(id: 'c', distance: 100, name: 'c'),
        fixtureWaypoint(id: 'd', distance: 500, name: 'd'),
        fixtureWaypoint(id: 'e', distance: null, name: 'hors2'),
      ];
      expect(
        sortWaypoints(list).map((WaypointDto w) => w.id).toList(),
        <String>['c', 'b', 'd', 'a', 'e'],
      );
    });

    test('la clé de repli est le rang dans la liste d\'origine', () {
      final WaypointDto w = fixtureWaypoint(id: null);
      expect(waypointKey(w, 3), 'i3');
      expect(waypointKey(fixtureWaypoint(id: 'x'), 3), 'x');
    });
  });

  group('carte et profil', () {
    test('jamais de filtre sur la valeur des coordonnées (WEB-108)', () {
      final List<WaypointDto> list = <WaypointDto>[
        fixtureWaypoint(id: 'a', lon: 0, lat: 45),
        fixtureWaypoint(id: 'b', lon: 3, lat: 0),
      ];
      expect(waypointHasPosition(list[0]), isTrue);
      final List<PdlMapWaypoint> onMap = mapWaypointsOf(list);
      expect(onMap, hasLength(2));
      expect(onMap[0].lon, 0);
      expect(onMap[1].lat, 0);
    });

    test('hors tracé sur la carte, jamais sur le profil', () {
      final List<WaypointDto> list = <WaypointDto>[
        fixtureWaypoint(id: 'a', distance: 1000),
        fixtureWaypoint(id: 'b', distance: null),
      ];
      expect(mapWaypointsOf(list).map((PdlMapWaypoint w) => w.key), <String>[
        'a',
        'b',
      ]);
      expect(
        profileMarkersOf(list).map((PdlProfileMarker m) => m.key),
        <String>['a'],
      );
    });

    test(
      'un nom vide ne donne pas d\'étiquette, un type inconnu devient INFO',
      () {
        final PdlMapWaypoint w = mapWaypointsOf(<WaypointDto>[
          fixtureWaypoint(type: 'CAMPSITE', name: ''),
        ]).single;
        expect(w.label, isNull);
        expect(w.iconId, 'INFO');
        expect(w.priority, 0);
      },
    );
  });

  group('traductions', () {
    for (final String lang in <String>['fr', 'en']) {
      test('chaque type a son libellé en $lang', () {
        final Map<String, dynamic> data = json.decode(
          File('assets/l10n/$lang.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        final Map<String, dynamic> types =
            ((data['routes'] as Map<String, dynamic>)['waypoints']
                    as Map<String, dynamic>)['type']
                as Map<String, dynamic>;
        for (final WaypointType t in WaypointType.$valuesDefined) {
          expect(t.labelKey, 'routes.waypoints.type.${t.json}');
          expect(
            types.containsKey(t.json),
            isTrue,
            reason: '${t.json} / $lang',
          );
        }
      });
    }
  });

  group('WaypointSelectionController', () {
    test('choisir deux fois le même point change le numéro de série', () {
      final WaypointSelectionController c = WaypointSelectionController();
      c.select('a', move: PdlWaypointMove.center);
      final int first = c.value!.serial;
      c.select('a', move: PdlWaypointMove.center);
      expect(c.value!.serial, greaterThan(first));
      c.clearIf(first);
      expect(c.value, isNotNull, reason: 'un choix plus récent survit');
      c.clearIf(c.value!.serial);
      expect(c.value, isNull);
      c.dispose();
      c.clearIf(1); // sans effet, sans exception
    });
  });
}
