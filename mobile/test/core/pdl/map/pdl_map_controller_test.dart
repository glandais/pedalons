import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';
import 'package:pedalons/core/pdl/map/pdl_map_controller.dart';
import 'package:pedalons/core/pdl/map/pdl_route_arrow.dart';
import 'package:pedalons/core/pdl/map/pdl_waypoint_mark.dart';

/// Un style qui applique les deux règles de MapLibre iOS qui comptent ici :
/// `addSource` lève sur un identifiant déjà pris, et `removeSource` ne fait
/// rien tant qu'une couche emploie la source. Chaque appel rend la main,
/// comme le vrai, ce qui laisse deux poses s'entrelacer.
class _StrictStyle extends Fake implements StyleController {
  final Set<String> sources = <String>{};
  final Map<String, String?> layers = <String, String?>{};
  final Map<String, Uint8List> images = <String, Uint8List>{};
  final Map<String, StyleLayer> layerObjects = <String, StyleLayer>{};
  final Map<String, String> geoJson = <String, String>{};
  int imageCalls = 0;

  @override
  Future<void> addImage(String id, Uint8List bytes) async {
    await Future<void>.delayed(Duration.zero);
    imageCalls++;
    images[id] = bytes;
  }

  @override
  Future<void> addSource(Source source) async {
    await Future<void>.delayed(Duration.zero);
    if (!sources.add(source.id)) {
      throw Exception('A Source with the id "${source.id}" already exists');
    }
    if (source is GeoJsonSource) geoJson[source.id] = source.data;
  }

  @override
  Future<void> removeSource(String id) async {
    await Future<void>.delayed(Duration.zero);
    if (layers.values.contains(id)) return;
    sources.remove(id);
  }

  @override
  Future<void> addLayer(
    StyleLayer layer, {
    String? belowLayerId,
    String? aboveLayerId,
    int? atIndex,
  }) async {
    await Future<void>.delayed(Duration.zero);
    if (layers.containsKey(layer.id)) {
      throw Exception('A Layer with the id "${layer.id}" already exists');
    }
    layers[layer.id] = layer is StyleLayerWithSource ? layer.sourceId : null;
    layerObjects[layer.id] = layer;
  }

  @override
  Future<void> removeLayer(String id) async {
    await Future<void>.delayed(Duration.zero);
    layers.remove(id);
    layerObjects.remove(id);
  }

  @override
  Future<void> updateGeoJsonSource({
    required String id,
    required String data,
  }) async {
    await Future<void>.delayed(Duration.zero);
    if (!sources.contains(id)) throw StateError('no source $id');
    geoJson[id] = data;
  }
}

PdlMapTrack _track(String id) => PdlMapTrack(
  id: id,
  color: const Color(0xFF000000),
  lines: const <List<List<double>>>[
    <List<double>>[
      <double>[2.0, 48.0],
      <double>[2.1, 48.1],
    ],
  ],
);

const PdlWaypointMark _mark = PdlWaypointMark(
  glyph: IconData(0xe318, fontFamily: 'MaterialIcons'),
  disc: Color(0xFFFD7E14),
  onDisc: Color(0xFFFFFFFF),
);

PdlMapWaypoint _waypoint(
  String key, {
  String icon = 'SUPPLY',
  String? label = 'Café du Port',
  double lon = 2.05,
  double lat = 48.05,
}) => PdlMapWaypoint(
  key: key,
  lon: lon,
  lat: lat,
  iconId: icon,
  mark: _mark,
  label: label,
  priority: 6,
);

void main() {
  group('PdlMapBox.ofTracks', () {
    test('englobe tous les tracés', () {
      final PdlMapBox? box = PdlMapBox.ofTracks(<PdlMapTrack>[
        PdlMapTrack(
          id: 'a',
          color: const Color(0xFF000000),
          lines: <List<List<double>>>[
            <List<double>>[
              <double>[2.0, 45.0],
              <double>[3.0, 46.0],
            ],
          ],
        ),
        PdlMapTrack(
          id: 'b',
          color: const Color(0xFF000000),
          lines: <List<List<double>>>[
            <List<double>>[
              <double>[1.0, 47.0],
            ],
          ],
        ),
      ]);

      expect(box, isNotNull);
      expect(box!.minLon, 1.0);
      expect(box.maxLon, 3.0);
      expect(box.minLat, 45.0);
      expect(box.maxLat, 47.0);
    });

    test('rend null quand il n\'y a aucune coordonnée', () {
      expect(PdlMapBox.ofTracks(const <PdlMapTrack>[]), isNull);
      expect(
        PdlMapBox.ofTracks(<PdlMapTrack>[
          PdlMapTrack(
            id: 'vide',
            color: const Color(0xFF000000),
            lines: const <List<List<double>>>[<List<double>>[]],
          ),
        ]),
        isNull,
      );
    });

    test('l\'aller-retour par LngLatBounds conserve les quatre bords', () {
      const PdlMapBox box = PdlMapBox(
        minLon: 1.5,
        minLat: 44.5,
        maxLon: 3.5,
        maxLat: 46.5,
      );
      expect(PdlMapBox.fromLngLatBounds(box.toLngLatBounds()), box);
    });
  });

  group('bornes kilométriques', () {
    test('le pas suit la longueur du parcours', () {
      expect(pdlKmMarkerIntervalKm(5), 1);
      expect(pdlKmMarkerIntervalKm(15), 2);
      expect(pdlKmMarkerIntervalKm(30), 5);
      expect(pdlKmMarkerIntervalKm(120), 10);
    });

    /// Une ligne est-ouest sur l'équateur : un degré de longitude y vaut
    /// ~111,19 km, ce qui donne des distances vérifiables à la main.
    List<List<double>> equatorLine(int points, double stepDeg) =>
        <List<double>>[
          for (int i = 0; i < points; i++) <double>[i * stepDeg, 0.0],
        ];

    test('une borne tous les kilomètres sur un parcours de 5 km', () {
      // 0,001° ≈ 111,19 m ; 50 pas ≈ 5,56 km.
      final List<PdlKmMarker> markers = computePdlKmMarkers(
        <List<List<double>>>[equatorLine(51, 0.001)],
      );
      expect(markers.length, 5);
      expect(markers.first.label, '1');
      expect(markers.last.label, '5');
      // La première borne tombe à ~1 km, soit ~0,00899°.
      expect(markers.first.lon, closeTo(0.00899, 0.0002));
      expect(markers.first.lat, closeTo(0, 1e-9));
    });

    test('la distance servie l\'emporte sur la distance calculée', () {
      // 5,56 km de géométrie, mais `RouteDetailDto.distance` annonce 30 km :
      // le pas passe donc de 1 km à 5 km. Les bornes qui tombent au-delà de la
      // géométrie sont ramenées sur son dernier point par `PolylineIndex` —
      // c'est le comportement voulu, un tracé plus court que sa distance
      // déclarée n'est pas un cas normal.
      final List<PdlKmMarker> markers = computePdlKmMarkers(
        <List<List<double>>>[equatorLine(51, 0.001)],
        totalMeters: 30000,
      );
      expect(markers.map((PdlKmMarker m) => m.label), <String>[
        '5',
        '10',
        '15',
        '20',
        '25',
      ]);
    });

    test('la 4ᵉ composante G3DM sert de cumul quand elle est utilisable', () {
      final List<PdlKmMarker> markers = computePdlKmMarkers(
        <List<List<double>>>[
          <List<double>>[
            <double>[0, 0, 100, 0],
            <double>[0.01, 0, 100, 2000],
            <double>[0.02, 0, 100, 4000],
          ],
        ],
      );
      // 4 km de cumul, pas de 1 km → 3 bornes.
      expect(markers.map((PdlKmMarker m) => m.label), <String>['1', '2', '3']);
    });

    test('un tracé vide ne produit aucune borne', () {
      expect(computePdlKmMarkers(const <List<List<double>>>[]), isEmpty);
    });

    test('le formatage du libellé est délégué à l\'appelant', () {
      final List<PdlKmMarker> markers = computePdlKmMarkers(
        <List<List<double>>>[equatorLine(51, 0.001)],
        formatKm: (int km) => '$km km',
      );
      expect(markers.first.label, '1 km');
    });
  });

  group('PdlMapController', () {
    test('un tracé seul est implicitement sélectionné', () async {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);

      await controller.setContent(
        tracks: <PdlMapTrack>[
          PdlMapTrack(
            id: 'solo',
            color: const Color(0xFF228BE6),
            lines: const <List<List<double>>>[],
          ),
        ],
      );
      expect(controller.selectedTrackId, 'solo');
    });

    test('plusieurs tracés n\'en sélectionnent aucun d\'office', () async {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);

      await controller.setContent(
        tracks: <PdlMapTrack>[
          PdlMapTrack(
            id: 'a',
            color: const Color(0xFF000000),
            lines: const <List<List<double>>>[],
          ),
          PdlMapTrack(
            id: 'b',
            color: const Color(0xFF000000),
            lines: const <List<List<double>>>[],
          ),
        ],
      );
      expect(controller.selectedTrackId, isNull);
    });

    test('une sélection qui disparaît du jeu de tracés est oubliée', () async {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);

      final List<PdlMapTrack> two = <PdlMapTrack>[
        PdlMapTrack(
          id: 'a',
          color: const Color(0xFF000000),
          lines: const <List<List<double>>>[],
        ),
        PdlMapTrack(
          id: 'b',
          color: const Color(0xFF000000),
          lines: const <List<List<double>>>[],
        ),
      ];
      await controller.setContent(tracks: two);
      await controller.select('b');
      expect(controller.selectedTrackId, 'b');

      await controller.setContent(tracks: <PdlMapTrack>[two.first]);
      // 'b' a disparu ; 'a' reste seul, donc implicitement sélectionné.
      expect(controller.selectedTrackId, 'a');
    });

    test('changer de sélection notifie une fois', () async {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);
      int notifications = 0;
      controller.addListener(() => notifications++);

      await controller.select('x');
      expect(notifications, 1);
      // Re-sélectionner la même chose ne notifie pas.
      await controller.select('x');
      expect(notifications, 1);
    });

    test('sans carte attachée, trackIdAt ne lève pas', () {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);
      expect(controller.trackIdAt(const Offset(10, 10)), isNull);
      expect(controller.visibleBox, isNull);
    });

    test('sans carte attachée, massFeatureAt ne lève pas', () {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);
      expect(controller.massFeatureAt(const Offset(10, 10)), isNull);
    });

    test('la couche de masse est nommée sous le préfixe de l\'écran', () {
      final PdlMapController controller = PdlMapController(
        layerPrefix: 'ride-track',
      );
      addTearDown(controller.dispose);
      expect(controller.massLayerId, 'ride-track-mass');
    });

    /// **Garde-fou de performance, pas de correction.** L'URL de tuile porte le
    /// jeton, donc elle *est* la clé de cache de MapLibre : reposer la source
    /// pour une URL inchangée viderait le cache à chaque `build` de l'écran,
    /// plusieurs fois par seconde pendant une animation.
    test('reposer la même URL de masse ne change rien', () async {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);
      const String url = 'https://example.test/tiles/{z}/{x}/{y}.mvt?t=abc';

      await controller.setMassTileUrl(url);
      expect(controller.massTileUrl, url);

      // Sans style attaché il n'y a rien à observer côté MapLibre ; ce qu'on
      // vérifie est que l'appel est idempotent et ne lève pas.
      await controller.setMassTileUrl(url);
      expect(controller.massTileUrl, url);

      await controller.setMassTileUrl(null);
      expect(controller.massTileUrl, isNull);
    });
  });

  group('PdlMapController — pose des couches (MOB-35)', () {
    test('reposer des tracés sur un style chargé ne lève pas', () async {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);
      final _StrictStyle style = _StrictStyle();

      await controller.setContent(tracks: <PdlMapTrack>[_track('a')]);
      await controller.attachStyle(style);
      await controller.setContent(
        tracks: <PdlMapTrack>[_track('a'), _track('b')],
      );

      expect(
        style.layers.keys,
        containsAll(<String>['pdl-track-a', 'pdl-track-b']),
      );
    });

    test('des mises à jour non attendues ne s\'entrelacent pas', () async {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);
      final _StrictStyle style = _StrictStyle();
      await controller.attachStyle(style);

      // Ce que fait `PdlMap._pushContent` : un `setContent` par mise à jour
      // du widget, sans attendre le précédent.
      final List<Future<void>> pending = <Future<void>>[
        controller.setContent(tracks: <PdlMapTrack>[_track('a')]),
        controller.setContent(tracks: <PdlMapTrack>[_track('a'), _track('b')]),
        controller.select('b'),
        controller.setContent(tracks: <PdlMapTrack>[_track('a'), _track('b')]),
      ];
      await Future.wait(pending);

      expect(
        style.layers.keys.where(
          (String id) => id == 'pdl-track-a' || id == 'pdl-track-b',
        ),
        unorderedEquals(<String>['pdl-track-a', 'pdl-track-b']),
      );
      expect(controller.selectedTrackId, 'b');
    });
  });

  group('PdlMapController — tracé mis en avant (MOB-94)', () {
    test('un tracé mis en avant prend le trait du sélectionné, sans '
        'changer la sélection', () async {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);
      final _StrictStyle style = _StrictStyle();
      final PdlMapTrack emphasized = PdlMapTrack(
        id: 'b',
        color: const Color(0xFF000000),
        lines: _track('b').lines,
        segmentColors: const <Color>[Color(0xFF111111)],
        emphasized: true,
      );

      await controller.setContent(
        tracks: <PdlMapTrack>[_track('a'), emphasized],
      );
      await controller.attachStyle(style);

      final List<dynamic> features =
          (jsonDecode(style.geoJson['pdl-track-src']!)
                  as Map<String, dynamic>)['features']
              as List<dynamic>;
      int selOf(String id) =>
          ((features.firstWhere(
                        (dynamic f) =>
                            (f
                                as Map<
                                  String,
                                  dynamic
                                >)['properties']['trackId'] ==
                            id,
                      )
                      as Map<String, dynamic>)['properties']
                  as Map<String, dynamic>)['sel']
              as int;
      expect(selOf('a'), 0);
      expect(selOf('b'), 1);
      expect(controller.selectedTrackId, isNull);
      expect(emphasized, isNot(_track('b')));
    });
  });

  group('PdlMapController — sens des tracés', () {
    test('les chevrons passent au-dessus de tous les tracés', () async {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);
      final _StrictStyle style = _StrictStyle();

      await controller.setContent(
        tracks: <PdlMapTrack>[_track('a'), _track('b')],
      );
      await controller.attachStyle(style);

      expect(style.images.keys, contains(pdlRouteArrowImageId));
      expect(style.images[pdlRouteArrowImageId], isNotEmpty);
      expect(style.layers['pdl-track-arrows-layer'], 'pdl-track-arrows');
      final List<String> order = style.layers.keys.toList();
      expect(
        order.indexOf('pdl-track-arrows-layer'),
        greaterThan(order.indexOf('pdl-track-b')),
      );

      // Le tracé sélectionné repasse au premier plan : ses chevrons aussi.
      await controller.select('a');
      final List<String> raised = style.layers.keys.toList();
      expect(
        raised.indexOf('pdl-track-arrows-layer'),
        greaterThan(raised.indexOf('pdl-track-a')),
      );
    });

    test('sans tracé, ni source ni couche de chevrons', () async {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);
      final _StrictStyle style = _StrictStyle();

      await controller.attachStyle(style);

      expect(style.sources, isNot(contains('pdl-track-arrows')));
      expect(style.layers.keys, isNot(contains('pdl-track-arrows-layer')));
    });
  });

  group('PdlMapController — points de parcours (MOB-84)', () {
    Future<(PdlMapController, _StrictStyle)> attached(
      List<PdlMapWaypoint> waypoints,
    ) async {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);
      final _StrictStyle style = _StrictStyle();
      await controller.setContent(
        tracks: <PdlMapTrack>[_track('a')],
        waypoints: waypoints,
      );
      await controller.attachStyle(style);
      return (controller, style);
    }

    test(
      'une image par type distinct, une étiquette par point nommé',
      () async {
        final (
          PdlMapController _,
          _StrictStyle style,
        ) = await attached(<PdlMapWaypoint>[
          _waypoint('1'),
          _waypoint('2', label: 'Autre'),
          _waypoint('3', icon: 'WATER', label: null),
        ]);

        expect(
          style.images.keys.where((String k) => k.startsWith('pdl-waypoint:')),
          unorderedEquals(<String>[
            'pdl-waypoint:SUPPLY',
            'pdl-waypoint:WATER',
          ]),
        );
        expect(
          style.images.keys.where(
            (String k) => k.startsWith('pdl-waypoint-label:'),
          ),
          unorderedEquals(<String>[
            'pdl-waypoint-label:Café du Port',
            'pdl-waypoint-label:Autre',
          ]),
        );
      },
    );

    test(
      'la pile : chevrons, départ, halo, icônes, étiquettes, réticule',
      () async {
        final PdlMapController controller = PdlMapController();
        addTearDown(controller.dispose);
        final _StrictStyle style = _StrictStyle();
        await controller.setContent(
          tracks: <PdlMapTrack>[_track('a')],
          waypoints: <PdlMapWaypoint>[_waypoint('1')],
          start: const PdlMapPoint(lon: 2, lat: 48),
        );
        await controller.attachStyle(style);

        final List<String> order = style.layers.keys.toList();
        final List<String> expected = <String>[
          'pdl-track-arrows-layer',
          'pdl-track-points',
          'pdl-track-waypoints-halo',
          'pdl-track-waypoints-icon',
          'pdl-track-waypoints-label',
          'pdl-track-cursor-dot',
        ];
        for (final String id in expected) {
          expect(order, contains(id), reason: id);
        }
        for (int i = 1; i < expected.length; i++) {
          expect(
            order.indexOf(expected[i]),
            greaterThan(order.indexOf(expected[i - 1])),
            reason: '${expected[i - 1]} < ${expected[i]}',
          );
        }
      },
    );

    test('les étiquettes n\'apparaissent qu\'à partir du zoom 12', () async {
      final (PdlMapController _, _StrictStyle style) = await attached(
        <PdlMapWaypoint>[_waypoint('1')],
      );
      final StyleLayer label = style.layerObjects['pdl-track-waypoints-label']!;
      expect(label.minZoom, kPdlWaypointLabelMinZoom);
      expect(label.minZoom, 12);
    });

    test('un changement de fond repose images, sources et couches', () async {
      final (PdlMapController controller, _StrictStyle style) = await attached(
        <PdlMapWaypoint>[_waypoint('1')],
      );
      final int before = style.imageCalls;

      // Ce que fait `PdlMap` quand le style change : tout est effacé, puis
      // `MapEventStyleLoaded` rattache.
      style
        ..images.clear()
        ..sources.clear()
        ..layers.clear()
        ..layerObjects.clear();
      controller.detachStyle();
      await controller.attachStyle(style);

      expect(style.imageCalls, greaterThan(before));
      expect(style.images.keys, contains('pdl-waypoint:SUPPLY'));
      expect(style.layers.keys, contains('pdl-track-waypoints-icon'));
      expect(style.sources, contains('pdl-track-waypoints'));
    });

    test('sans point, ni source ni couche', () async {
      final (PdlMapController _, _StrictStyle style) = await attached(
        const <PdlMapWaypoint>[],
      );
      expect(style.sources, isNot(contains('pdl-track-waypoints')));
      expect(
        style.layers.keys.where((String id) => id.contains('waypoints')),
        isEmpty,
      );
    });

    test('le GeoJSON garde un point à [0, 45] (WEB-108)', () async {
      final (PdlMapController _, _StrictStyle style) = await attached(
        <PdlMapWaypoint>[_waypoint('1', lon: 0, lat: 45)],
      );
      final Map<String, Object?> data =
          jsonDecode(style.geoJson['pdl-track-waypoints']!)
              as Map<String, Object?>;
      final List<Object?> features = data['features']! as List<Object?>;
      expect(features, hasLength(1));
      final Map<String, Object?> feature =
          features.single! as Map<String, Object?>;
      expect(
        (feature['geometry']! as Map<String, Object?>)['coordinates'],
        <double>[0.0, 45.0],
      );
      final Map<String, Object?> props =
          feature['properties']! as Map<String, Object?>;
      expect(props['key'], '1');
      expect(props['icon'], 'pdl-waypoint:SUPPLY');
    });

    test(
      'setWaypointFocus pousse la source du halo, même pendant une pose',
      () async {
        final PdlMapController controller = PdlMapController();
        addTearDown(controller.dispose);
        final _StrictStyle style = _StrictStyle();
        await controller.setContent(
          tracks: <PdlMapTrack>[_track('a')],
          waypoints: <PdlMapWaypoint>[_waypoint('1')],
        );
        final Future<void> attaching = controller.attachStyle(style);
        final Future<void> focus = controller.setWaypointFocus('1');
        await Future.wait(<Future<void>>[attaching, focus]);

        final Map<String, Object?> data =
            jsonDecode(style.geoJson['pdl-track-waypoint-focus']!)
                as Map<String, Object?>;
        expect(data['features']! as List<Object?>, hasLength(1));

        await controller.setWaypointFocus(null);
        final Map<String, Object?> cleared =
            jsonDecode(style.geoJson['pdl-track-waypoint-focus']!)
                as Map<String, Object?>;
        expect(cleared['features']! as List<Object?>, isEmpty);
      },
    );

    test('sans carte attachée, waypointKeyAt rend null', () {
      final PdlMapController controller = PdlMapController();
      addTearDown(controller.dispose);
      expect(controller.waypointKeyAt(const Offset(10, 10)), isNull);
    });
  });
}
