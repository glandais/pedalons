import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/elevation/elevation_samples.dart';
import 'package:pedalons/core/theme/enum_colors.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';
import 'package:pedalons/features/routes/domain/route_elevation_builder.dart';
import 'package:pedalons/features/routes/domain/track_surfaces.dart';
import 'package:pedalons/features/routes/domain/track_slope_colors.dart';

/// Le revêtement le long d'un parcours (ledger `MOB-81`) : la logique du site
/// (`trackSurface.ts`), mêmes bornes.
SurfaceSpanDto span(double from, double to, TrackSurface surface) =>
    SurfaceSpanDto(from: from, to: to, surface: surface);

/// Une piste G3DM : un sommet tous les [step] mètres, `M` repartant de zéro.
TrackDto track({
  required int vertices,
  double step = 100,
  double lat = 45,
  String? state = 'READY',
  List<SurfaceSpanDto>? spans,
}) => TrackDto(
  line: GeoJsonLineString(
    type: GeoJsonLineStringTypeType.lineString,
    coordinates: <List<double>>[
      for (int i = 0; i < vertices; i++)
        <double>[5, lat + i * step / 111195, 100, i * step],
    ],
  ),
  climbs: const <ClimbDto>[],
  surfaceState: state,
  surfaces: spans,
);

void main() {
  final List<SurfaceSpanDto> spans = <SurfaceSpanDto>[
    span(0, 100, TrackSurface.paved),
    span(100, 300, TrackSurface.gravel),
  ];

  group('surfaceAtDistance', () {
    test('une borne appartient à la plage qui y commence', () {
      expect(surfaceAtDistance(spans, 0), TrackSurface.paved);
      expect(surfaceAtDistance(spans, 99.9), TrackSurface.paved);
      expect(surfaceAtDistance(spans, 100), TrackSurface.gravel);
      expect(surfaceAtDistance(spans, 300), TrackSurface.gravel);
    });

    test('hors plages, sans plages ou liste vide : inconnu', () {
      expect(surfaceAtDistance(spans, -1), TrackSurface.unknown);
      expect(surfaceAtDistance(spans, 300.1), TrackSurface.unknown);
      expect(surfaceAtDistance(null, 10), TrackSurface.unknown);
      expect(
        surfaceAtDistance(const <SurfaceSpanDto>[], 10),
        TrackSurface.unknown,
      );
    });
  });

  group('hasTrackSurfaces / trackSurfacesPending', () {
    test('prêt avec des plages', () {
      expect(
        hasTrackSurfaces(<TrackDto>[track(vertices: 4, spans: spans)]),
        isTrue,
      );
      expect(
        trackSurfacesPending(<TrackDto>[track(vertices: 4, spans: spans)]),
        isFalse,
      );
    });

    test('prêt sans plage, absent ou indisponible : rien', () {
      for (final TrackDto t in <TrackDto>[
        track(vertices: 4, spans: const <SurfaceSpanDto>[]),
        track(vertices: 4, state: null),
        track(vertices: 4, state: 'UNAVAILABLE'),
      ]) {
        expect(hasTrackSurfaces(<TrackDto>[t]), isFalse);
        expect(trackSurfacesPending(<TrackDto>[t]), isFalse);
      }
    });

    test('en cours seulement quand aucune piste n\'est prête', () {
      final TrackDto pending = track(vertices: 4, state: 'PENDING');
      expect(trackSurfacesPending(<TrackDto>[pending]), isTrue);
      expect(
        trackSurfacesPending(<TrackDto>[
          pending,
          track(vertices: 4, spans: spans),
        ]),
        isFalse,
      );
    });
  });

  group('segmentSurfaces', () {
    test('une classe par segment, lue au milieu', () {
      final List<TrackSurface>? s = segmentSurfaces(<TrackDto>[
        track(vertices: 4, spans: spans),
      ]);
      expect(s, <TrackSurface>[
        TrackSurface.paved,
        TrackSurface.gravel,
        TrackSurface.gravel,
      ]);
    });

    test('autant que segmentCount, une piste non prête est inconnue', () {
      final List<TrackDto> tracks = <TrackDto>[
        track(vertices: 4, spans: spans),
        track(vertices: 3, state: 'PENDING'),
      ];
      final List<TrackSurface>? s = segmentSurfaces(tracks);
      expect(s, hasLength(segmentCount(tracks.map((t) => t.line.coordinates))));
      expect(s!.sublist(3), <TrackSurface>[
        TrackSurface.unknown,
        TrackSurface.unknown,
      ]);
    });

    test('null sans aucune piste prête', () {
      expect(
        segmentSurfaces(<TrackDto>[track(vertices: 4, state: 'PENDING')]),
        isNull,
      );
      expect(segmentSurfaces(const <TrackDto>[]), isNull);
    });

    test('un sommet sans mesure M : inconnu', () {
      const TrackDto t = TrackDto(
        line: GeoJsonLineString(
          type: GeoJsonLineStringTypeType.lineString,
          coordinates: <List<double>>[
            <double>[5, 45, 100],
            <double>[5, 45.001, 100],
          ],
        ),
        climbs: <ClimbDto>[],
        surfaceState: 'READY',
        surfaces: <SurfaceSpanDto>[
          SurfaceSpanDto(from: 0, to: 100, surface: TrackSurface.paved),
        ],
      );
      expect(segmentSurfaces(const <TrackDto>[t]), <TrackSurface>[
        TrackSurface.unknown,
      ]);
    });
  });

  test(
    'surfaceShares : ordre de la légende, parts, classes vides retirées',
    () {
      final List<TrackSurfaceShare> shares = surfaceShares(<TrackDto>[
        track(
          vertices: 5,
          spans: <SurfaceSpanDto>[
            span(0, 100, TrackSurface.offNetwork),
            span(100, 300, TrackSurface.gravel),
            span(300, 400, TrackSurface.paved),
          ],
        ),
        track(vertices: 3, state: 'PENDING'),
      ]);

      expect(shares.map((s) => s.surface), <TrackSurface>[
        TrackSurface.paved,
        TrackSurface.gravel,
        TrackSurface.offNetwork,
      ]);
      expect(shares.map((s) => s.length), <double>[100, 200, 100]);
      expect(shares.map((s) => s.share), <double>[0.25, 0.5, 0.25]);
      expect(surfaceShares(const <TrackDto>[]), isEmpty);
    },
  );

  group('barSurfaces', () {
    ElevationSamples samples(List<TrackDto> tracks, int bars) =>
        elevationSamplesFromLines(
          tracks.map((t) => t.line.coordinates),
          targetBars: bars,
        )!;

    test('une barre par segment', () {
      final List<TrackDto> tracks = <TrackDto>[
        track(vertices: 4, spans: spans),
      ];
      expect(barSurfaces(samples(tracks, 3), tracks), <TrackSurface?>[
        TrackSurface.paved,
        TrackSurface.gravel,
        TrackSurface.gravel,
      ]);
    });

    test('la classe dominante d\'une barre qui couvre plusieurs segments', () {
      final List<TrackDto> tracks = <TrackDto>[
        track(vertices: 4, spans: spans),
      ];
      // [0, 150] : 100 m d'asphalte contre 50 m de gravier.
      expect(barSurfaces(samples(tracks, 2), tracks), <TrackSurface?>[
        TrackSurface.paved,
        TrackSurface.gravel,
      ]);
    });

    test('le pont entre deux pistes ne compte pas', () {
      final List<TrackDto> tracks = <TrackDto>[
        track(
          vertices: 2,
          spans: <SurfaceSpanDto>[span(0, 100, TrackSurface.paved)],
        ),
        track(
          vertices: 2,
          lat: 45.0018,
          spans: <SurfaceSpanDto>[span(0, 100, TrackSurface.gravel)],
        ),
      ];
      final List<TrackSurface?> bars = barSurfaces(samples(tracks, 3), tracks);
      expect(bars, <TrackSurface?>[
        TrackSurface.paved,
        null,
        TrackSurface.gravel,
      ]);
    });

    test('une piste non prête est inconnue', () {
      final List<TrackDto> tracks = <TrackDto>[
        track(
          vertices: 3,
          spans: <SurfaceSpanDto>[span(0, 200, TrackSurface.dirt)],
        ),
        track(vertices: 3, lat: 45.0030, state: 'PENDING'),
      ];
      final List<TrackSurface?> bars = barSurfaces(samples(tracks, 5), tracks);
      expect(bars.first, TrackSurface.dirt);
      expect(bars.last, TrackSurface.unknown);
    });
  });

  test('surfaceSegmentColors rend le trait de chaque classe', () {
    final PdlColors c = PdlColors.light;
    final List<Color>? colors = surfaceSegmentColors(<TrackDto>[
      track(vertices: 4, spans: spans),
    ], c);
    expect(colors, <Color>[
      TrackSurface.paved.stroke(c),
      TrackSurface.gravel.stroke(c),
      TrackSurface.gravel.stroke(c),
    ]);
    expect(colors![1], TrackSurface.gravel.family.soft(c).fill);
  });
}
