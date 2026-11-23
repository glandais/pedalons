import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/map/pdl_mass_layer.dart';

const String _template =
    'https://example.test/api/routes/tiles/{z}/{x}/{y}.mvt';

void main() {
  group('PdlMassTiles', () {
    test(
      'la source règle maxZoom — sans quoi la carte est vide au-delà de 2',
      () {
        final VectorSource source = PdlMassTiles.source(
          id: 'mass',
          tileUrlTemplate: _template,
        );

        expect(source.maxZoom, 14);
        expect(source.minZoom, 0);
        expect((source as VectorSourceTiles).tiles, hasLength(1));
      },
    );

    /// MapLibre substitue les gabarits lui-même : les encoder produirait des
    /// 404 silencieux.
    test('le gabarit de tuile passe verbatim', () {
      final VectorSource source = PdlMassTiles.source(
        id: 'mass',
        tileUrlTemplate: _template,
      );

      expect((source as VectorSourceTiles).tiles.first, _template);
    });

    test('sourceLayer se précise sur la couche, pas sur la source', () {
      final LineStyleLayer layer = PdlMassTiles.layer(
        id: 'mass-line',
        sourceId: 'mass',
        color: const Color(0xFF228BE6),
      );

      expect(layer.sourceLayerId, PdlMassTiles.sourceLayerId);
      expect(layer.sourceId, 'mass');
      expect(layer.color, const Expression.literal(Color(0xFF228BE6)));
    });

    /// Le nom de la couche est celui que `ST_AsMVT` donne côté backend : le
    /// changer d'un côté sans l'autre produit une carte vide, sans erreur.
    test('la couche de tuile s\'appelle routes', () {
      expect(PdlMassTiles.sourceLayerId, 'routes');
    });
  });
}
