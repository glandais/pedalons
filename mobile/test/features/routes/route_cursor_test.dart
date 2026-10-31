import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/map/pdl_map_controller.dart';
import 'package:pedalons/features/routes/domain/track_slope_colors.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_cursor_controller.dart';

/// S13-3 — le réticule bidirectionnel. La colorisation par pente, celle des
/// montées, est dans `track_climb_colors_test.dart` (ledger `MOB-105`).
///
/// Le cas de test 2 du §5.3 : « la distance affichée coïncide avec
/// `ElevationProfileDto.distance` à ±0,5 % ». Ici c'est la géométrie qui fait
/// foi des deux côtés — le lien est **toujours** une distance cumulée, jamais
/// un index de point, parce que le profil est échantillonné à ~300 points et la
/// géométrie en compte jusqu'à 3 000.
void main() {
  /// Une ligne droite est-ouest à latitude ~0, avec altitude et cumul :
  /// `[lon, lat, alt, m]`. Chaque segment fait 1 000 m.
  List<List<double>> straight({int segments = 10, double risePerSegment = 0}) {
    const double metersPerDegree = 111320.0;
    return <List<double>>[
      for (int i = 0; i <= segments; i++)
        <double>[
          i * 1000.0 / metersPerDegree,
          0,
          100 + i * risePerSegment,
          i * 1000.0,
        ],
    ];
  }

  test('segmentCount compte les segments de toutes les lignes', () {
    final List<List<List<double>>> lines = <List<List<double>>>[
      straight(segments: 7),
      straight(segments: 3),
    ];
    expect(segmentCount(lines), 10);
  });

  group('réticule', () {
    late RouteCursorController cursor;

    setUp(() {
      cursor = RouteCursorController(
        lines: <List<List<double>>>[straight(risePerSegment: 20)],
      );
    });

    tearDown(() => cursor.dispose());

    test('la distance totale colle à la géométrie à ±0,5 %', () {
      expect(cursor.totalDistance, closeTo(10000, 10000 * 0.005));
    });

    test('profil → carte : une distance devient une position', () {
      final PdlMapPoint? start = cursor.positionFor(0);
      final PdlMapPoint? end = cursor.positionFor(cursor.totalDistance);
      expect(start, isNotNull);
      expect(end, isNotNull);
      expect(start!.lon, closeTo(0, 1e-9));
      expect(end!.lon, greaterThan(start.lon));
    });

    test('carte → profil : un tap près du tracé rend la bonne distance', () {
      // Le point à mi-parcours, décalé de quelques mètres sur le côté.
      final PdlMapPoint mid = cursor.positionFor(5000)!;
      final double? d = cursor.distanceNear(mid.lon, mid.lat + 0.00005);
      expect(d, isNotNull);
      expect(d!, closeTo(5000, 5000 * 0.005));
    });

    test('un tap loin du tracé n\'accroche rien', () {
      expect(cursor.distanceNear(10, 45), isNull);
    });

    test('le réticule s\'efface, et l\'effacement se propage', () {
      int notifications = 0;
      cursor.distance.addListener(() => notifications++);

      cursor.moveTo(1234);
      expect(cursor.distance.value, 1234);
      cursor.clear();
      expect(cursor.distance.value, isNull);
      expect(notifications, 2);
    });
  });
}
