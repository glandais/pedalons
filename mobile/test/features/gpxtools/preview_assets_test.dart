import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/gpxtools/domain/preview_assets.dart';
import 'package:pedalons/features/routes/domain/shown_route.dart';

/// docs/LEDGER_*.md MOB-178 : un aperçu GPX se montre et s'exporte comme un
/// parcours, sans équipe ni slug.

GpxPreviewDto preview({String name = 'Boucle : col / vallée'}) => GpxPreviewDto(
  id: 'p1',
  name: name,
  distance: 42000,
  elevationGain: 600,
  elevationLoss: 600,
  hilliness: 14,
  elevationState: 'HD',
  owned: true,
  createdAt: '2026-11-22T08:00:00Z',
  gpxUrl: '/api/gpx-previews/p1/gpx',
  fitUrl: '/api/gpx-previews/p1/fit',
  drawn: false,
  tracks: const <TrackDto>[],
  waypoints: const <WaypointDto>[],
);

void main() {
  test('les fichiers d’un aperçu : son URL, son extension, son type', () {
    final GpxPreviewDto p = preview();
    expect(p.gpxAsset.url, '/api/gpx-previews/p1/gpx');
    expect(p.gpxAsset.fileName, 'Boucle col vallée.gpx');
    expect(p.gpxAsset.contentType, 'application/gpx+xml');
    expect(p.fitAsset.url, '/api/gpx-previews/p1/fit');
    expect(p.fitAsset.fileName, 'Boucle col vallée.fit');
    expect(p.fitAsset.contentType, 'application/vnd.ant.fit');
  });

  test('un nom dont il ne reste rien devient « parcours »', () {
    expect(previewFileStem(' /:* '), 'parcours');
  });

  test('le tracé affiché est le même objet pour le même DTO : les mémoires '
      'du vent le comparent par identité', () {
    final GpxPreviewDto p = preview();
    expect(identical(p.shown, p.shown), isTrue);
    expect(p.shown.id, 'p1');
    expect(p.shown.start, isNull);
    // Un DTO égal mais distinct a le sien.
    expect(identical(p.copyWith().shown, p.shown), isFalse);
  });
}
