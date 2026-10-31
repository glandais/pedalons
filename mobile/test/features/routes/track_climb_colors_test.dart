import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/elevation/elevation_samples.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/features/routes/domain/route_color_mode.dart';
import 'package:pedalons/features/routes/domain/route_elevation_builder.dart';
import 'package:pedalons/features/routes/domain/track_slope_colors.dart';
import 'package:pedalons/features/routes/domain/track_surfaces.dart';

/// La pente d'un parcours comme au site (ledger `MOB-105`) : seules les
/// montées se colorent, partie par partie, le reste au bleu neutre — sur la
/// carte comme sur le profil.

/// Une piste G3DM plein nord : un sommet tous les [step] mètres, `M`
/// repartant de zéro, l'altitude plate (la géométrie ne compte plus).
TrackDto track({
  required int vertices,
  double step = 1000,
  double lat = 45,
  List<ClimbDto> climbs = const <ClimbDto>[],
}) => TrackDto(
  line: GeoJsonLineString(
    type: GeoJsonLineStringTypeType.lineString,
    coordinates: <List<double>>[
      for (int i = 0; i < vertices; i++)
        <double>[5, lat + i * step / 111195, 100, i * step],
    ],
  ),
  climbs: climbs,
);

ClimbDto climb(
  int start,
  int end,
  num average, {
  List<ClimbPartDto> parts = const <ClimbPartDto>[],
}) => ClimbDto(
  startDistance: start,
  endDistance: end,
  elevationGain: 100,
  averageGradient: average,
  maxGradient: average,
  parts: parts,
);

ClimbPartDto part(int start, int end, num grade) => ClimbPartDto(
  startDistance: start,
  endDistance: end,
  elevationGain: 10,
  grade: grade,
);

void main() {
  group('climbGradeAt', () {
    final List<ClimbDto> climbs = <ClimbDto>[
      climb(
        1000,
        3000,
        5,
        parts: <ClimbPartDto>[part(1000, 2000, 3), part(2000, 3000, 8)],
      ),
      climb(5000, 6000, 7),
    ];

    test('hors montée : 0', () {
      expect(climbGradeAt(climbs, 0), 0);
      expect(climbGradeAt(climbs, 4000), 0);
      expect(climbGradeAt(climbs, 6001), 0);
    });

    test('dans une montée à parties : la pente de la partie, bornes '
        'incluses (la première partie gagne à la jointure)', () {
      expect(climbGradeAt(climbs, 1000), 3);
      expect(climbGradeAt(climbs, 2000), 3);
      expect(climbGradeAt(climbs, 2500), 8);
      expect(climbGradeAt(climbs, 3000), 8);
    });

    test('sans parties : la pente moyenne', () {
      expect(climbGradeAt(climbs, 5500), 7);
    });
  });

  group('climbSegmentColors', () {
    test('une couleur par segment, lue au sommet de départ ; hors montée le '
        'bleu neutre', () {
      final List<TrackDto> tracks = <TrackDto>[
        track(vertices: 6, climbs: <ClimbDto>[climb(1000, 3000, 6)]),
      ];
      final List<Color> colors = climbSegmentColors(tracks);
      expect(colors, <Color>[
        slopeNeutral,
        slopeColor(6),
        slopeColor(6),
        slopeColor(6), // le sommet 3000 m est la borne haute, incluse
        slopeNeutral,
      ]);
    });

    test('chaque piste avec ses montées, `M` repartant de zéro', () {
      final List<TrackDto> tracks = <TrackDto>[
        track(vertices: 3, climbs: <ClimbDto>[climb(0, 1000, 4)]),
        track(vertices: 3, lat: 46, climbs: <ClimbDto>[climb(1000, 2000, 9)]),
      ];
      expect(climbSegmentColors(tracks), <Color>[
        slopeColor(4),
        slopeColor(4),
        slopeNeutral,
        slopeColor(9),
      ]);
    });

    test('un sommet sans `M` est hors montée', () {
      final TrackDto noMeasure = TrackDto(
        line: const GeoJsonLineString(
          type: GeoJsonLineStringTypeType.lineString,
          coordinates: <List<double>>[
            <double>[5, 45, 100],
            <double>[5, 45.01, 200],
          ],
        ),
        climbs: <ClimbDto>[climb(0, 5000, 10)],
      );
      expect(climbSegmentColors(<TrackDto>[noMeasure]), <Color>[slopeNeutral]);
    });

    test('mémorisées par liste de pistes', () {
      final List<TrackDto> tracks = <TrackDto>[track(vertices: 4)];
      expect(
        identical(climbSegmentColors(tracks), climbSegmentColors(tracks)),
        isTrue,
      );
    });

    test('autant de couleurs que de segments', () {
      final List<TrackDto> tracks = <TrackDto>[
        track(vertices: 8),
        track(vertices: 4, lat: 46),
      ];
      expect(
        climbSegmentColors(tracks),
        hasLength(segmentCount(tracks.map((TrackDto t) => t.line.coordinates))),
      );
    });
  });

  group('climbBars', () {
    test('chaque barre prend la pente de la montée qui la couvre le plus, '
        'neutre ailleurs', () {
      // 10 km, 10 barres d'un kilomètre : une montée de 2 à 5 km.
      final List<TrackDto> tracks = <TrackDto>[
        track(vertices: 11, climbs: <ClimbDto>[climb(2000, 5000, 6)]),
      ];
      final ElevationSamples samples = elevationSamplesFromLines(
        tracks.map((TrackDto t) => t.line.coordinates),
        targetBars: 10,
      )!;
      final ClimbBars bars = climbBars(samples, tracks);

      expect(bars.grades, hasLength(10));
      expect(bars.grades.sublist(0, 2), everyElement(0));
      // Le segment qui part du sommet de 5 km est encore en montée (borne
      // haute incluse), comme sur la carte.
      expect(bars.grades.sublist(2, 6), everyElement(6));
      expect(bars.grades.sublist(6), everyElement(0));
      expect(bars.colors[0], slopeNeutral);
      expect(bars.colors[3], slopeColor(6));
    });

    test('l\'infobulle ne dit la pente qu\'en montée', () {
      final List<TrackDto> tracks = <TrackDto>[
        track(vertices: 11, climbs: <ClimbDto>[climb(2000, 5000, 6)]),
      ];
      final ElevationSamples samples = elevationSamplesFromLines(
        tracks.map((TrackDto t) => t.line.coordinates),
        targetBars: 10,
      )!;
      final ClimbBars bars = climbBars(samples, tracks);
      expect(climbGradeTip(samples, bars, 3500), 6);
      expect(climbGradeTip(samples, bars, 500), isNull);
    });
  });

  group('les modes de l\'interrupteur', () {
    test('la pente toujours, le revêtement et Météo s\'ils sont là', () {
      expect(routeColorModes(surfaces: false, wind: false), <RouteColorBy>[
        RouteColorBy.grade,
      ]);
      expect(routeColorModes(surfaces: true, wind: true), <RouteColorBy>[
        RouteColorBy.grade,
        RouteColorBy.surface,
        RouteColorBy.wind,
      ]);
    });

    test('un mode indisponible retombe sur la pente', () {
      final List<RouteColorBy> modes = routeColorModes(
        surfaces: true,
        wind: false,
      );
      expect(resolveRouteColorBy(RouteColorBy.wind, modes), RouteColorBy.grade);
      expect(
        resolveRouteColorBy(RouteColorBy.surface, modes),
        RouteColorBy.surface,
      );
    });

    test('le profil suit Pente | Revêtement, et reste en pente en Météo', () {
      expect(profileColorBy(RouteColorBy.wind), RouteColorBy.grade);
      expect(profileColorBy(RouteColorBy.surface), RouteColorBy.surface);
      expect(profileColorBy(RouteColorBy.grade), RouteColorBy.grade);
    });
  });
}
