import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';

void main() {
  group('parseMapView', () {
    test('reads zoom/lat/lon, the format the site writes', () {
      expect(
        parseMapView('12.5/45.1885/5.7245'),
        const PdlMapCamera(lon: 5.7245, lat: 45.1885, zoom: 12.5),
      );
    });

    for (final String? value in <String?>[
      null,
      '',
      '12/45',
      '12/45/5/1',
      'a/45/5',
      '23/45/5',
      '-1/45/5',
      '12/86/5',
      '12/45/181',
      '12/NaN/5',
    ]) {
      test('rejects ${value ?? 'null'}', () {
        expect(parseMapView(value), isNull);
      });
    }
  });

  test('mapViewFromQuery reads the map parameter only', () {
    expect(
      mapViewFromQuery(const <String, String>{
        'distance': '50',
        kMapViewParam: '10/45.189/5.725',
      }),
      const PdlMapCamera(lon: 5.725, lat: 45.189, zoom: 10),
    );
    expect(mapViewFromQuery(const <String, String>{'distance': '50'}), isNull);
  });
}
