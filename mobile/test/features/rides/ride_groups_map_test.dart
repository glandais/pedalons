import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/domain/ride_route_layers.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_groups_map.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';

import 'ride_fixtures.dart';

/// S12-4 — ce que la carte de sortie doit demander, et ce qu'elle doit mesurer.
void main() {
  test('dix groupes sur trois parcours ne font que trois appels', () {
    final RideDto ride = fixtureRide(
      groups: <RideGroupDto>[
        for (int i = 0; i < 10; i++)
          fixtureGroup(
            id: 'g$i',
            sortOrder: i,
            // Trois parcours partagés, comme une sortie réelle : les groupes
            // se répartissent sur un court, un moyen et un long.
            routeSlug: 'parcours-${i % 3}',
          ),
      ],
    );

    expect(distinctRouteSlugs(ride), <String>[
      'parcours-0',
      'parcours-1',
      'parcours-2',
    ]);
  });

  test('un groupe sans parcours reprend celui de la sortie', () {
    final RideDto ride = fixtureRide(
      groups: <RideGroupDto>[fixtureGroup(id: 'g1')],
    ).copyWith(routeSlug: 'parcours-de-la-sortie');

    expect(distinctRouteSlugs(ride), <String>['parcours-de-la-sortie']);
  });

  test('une sortie sans aucun parcours ne demande rien', () {
    expect(distinctRouteSlugs(fixtureRide()), isEmpty);
  });

  test(
    'le parcours de la sortie est demandé même si aucun groupe ne le roule',
    () {
      final RideDto ride = fixtureRide(
        groups: <RideGroupDto>[fixtureGroup(id: 'g1', routeSlug: 'court')],
      ).copyWith(routeSlug: 'principal');

      // D'abord celui de la sortie, comme le web : l'ordre numérote les couleurs.
      expect(distinctRouteSlugs(ride), <String>['principal', 'court']);
    },
  );

  group('une couche par parcours', () {
    // Chill et G1 sans parcours propre roulent celui de la sortie ; Sportif a
    // le sien, que G3 partage.
    final RideDto ride = fixtureRide(
      groups: <RideGroupDto>[
        fixtureGroup(id: 'chill', name: 'Chill', sortOrder: 0),
        fixtureGroup(id: 'g1', name: 'G1', sortOrder: 1),
        fixtureGroup(
          id: 'sportif',
          name: 'Sportif',
          sortOrder: 2,
          routeSlug: 'long',
        ),
        fixtureGroup(id: 'g3', name: 'G3', sortOrder: 3, routeSlug: 'long'),
      ],
    ).copyWith(routeSlug: 'principal');

    test('les groupes qui partagent un parcours partagent une couche', () {
      final List<RideRouteLayer> layers = rideRouteLayers(ride);
      expect(layers.map((RideRouteLayer l) => l.routeSlug), <String>[
        'principal',
        'long',
      ]);
      expect(layers[0].label('Parcours principal'), 'Chill · G1');
      expect(layers[1].label('Parcours principal'), 'Sportif · G3');
      expect(layers.map((RideRouteLayer l) => l.colorIndex), <int>[0, 1]);
    });

    test('la couleur d’un groupe est celle de son parcours', () {
      final Map<String, int> colors = <String, int>{
        for (final RideGroupDto g in ride.groups)
          g.id: groupTrackColorIndex(ride, g),
      };
      expect(colors, <String, int>{'chill': 0, 'g1': 0, 'sportif': 1, 'g3': 1});
    });

    test('le parcours principal sans groupe garde son libellé', () {
      final RideDto other = fixtureRide(
        groups: <RideGroupDto>[fixtureGroup(id: 'a', routeSlug: 'court')],
      ).copyWith(routeSlug: 'principal');
      final List<RideRouteLayer> layers = rideRouteLayers(other);
      expect(layers.first.label('Parcours principal'), 'Parcours principal');
      expect(groupForRoute(other, 'principal'), isNull);
    });

    test(
      'toucher un parcours garde le groupe qui le roule, sinon le premier',
      () {
        expect(groupForRoute(ride, 'long', current: 'g3'), 'g3');
        expect(groupForRoute(ride, 'long', current: 'chill'), 'sportif');
        expect(groupForRoute(ride, 'principal', current: 'g3'), 'chill');
      },
    );
  });

  test('la hauteur de carte est bornée, jamais figée à 300', () {
    // iPhone SE — 300 px fixes mangeraient 40 % de l'écran.
    expect(rideMapHeight(667), 293.48);
    // Petit écran : le plancher tient.
    expect(rideMapHeight(500), 260);
    // Grande tablette : le plafond tient.
    expect(rideMapHeight(1366), 460);
  });
}
