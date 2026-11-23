import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/pdl/pdl.dart';

void main() {
  const PdlHillshade shading = PdlHillshade(
    url: 'https://tiles.example/tilejson.json',
    encoding: PdlDemEncoding.terrarium,
    shadowColor: Color(0xFF727C83),
    highlightColor: Color(0xFFFFFFE4),
  );

  group('PdlHillshade', () {
    test('deux instances identiques sont égales', () {
      // `PdlMap.didUpdateWidget` compare **par valeur** : les écrans en
      // reconstruisent une à chaque `build`, et comparer par identité reposerait
      // toutes les couches à chaque image — la carte scintillerait et la caméra
      // serait bousculée.
      expect(
        shading,
        const PdlHillshade(
          url: 'https://tiles.example/tilejson.json',
          encoding: PdlDemEncoding.terrarium,
          shadowColor: Color(0xFF727C83),
          highlightColor: Color(0xFFFFFFE4),
        ),
      );
    });

    test('changer de source, d\'encodage ou de teinte casse l\'égalité', () {
      expect(
        shading ==
            const PdlHillshade(
              url: 'https://autre.example/tilejson.json',
              encoding: PdlDemEncoding.terrarium,
              shadowColor: Color(0xFF727C83),
              highlightColor: Color(0xFFFFFFE4),
            ),
        isFalse,
      );
      expect(
        shading ==
            const PdlHillshade(
              url: 'https://tiles.example/tilejson.json',
              encoding: PdlDemEncoding.mapbox,
              shadowColor: Color(0xFF727C83),
              highlightColor: Color(0xFFFFFFE4),
            ),
        isFalse,
      );
      expect(
        shading ==
            const PdlHillshade(
              url: 'https://tiles.example/tilejson.json',
              encoding: PdlDemEncoding.terrarium,
              shadowColor: Color(0xFF000000),
              highlightColor: Color(0xFFFFFFE4),
            ),
        isFalse,
      );
    });
  });

  /// `maplibre` 0.4 écrit toujours un encodage dans la source : il doit être
  /// celui du TileJSON, sinon le relief est faux (ledger `MOB-181`).
  group('demEncodingOfTileJson', () {
    test('Terrarium quand le document le déclare (Mapterhorn)', () {
      expect(
        demEncodingOfTileJson(<String, Object?>{
          'tilejson': '3.0.0',
          'encoding': 'terrarium',
        }),
        PdlDemEncoding.terrarium,
      );
    });

    test('Mapbox sinon, la valeur par défaut de la spécification', () {
      expect(
        demEncodingOfTileJson(<String, Object?>{'encoding': 'mapbox'}),
        PdlDemEncoding.mapbox,
      );
      expect(
        demEncodingOfTileJson(<String, Object?>{'tilejson': '3.0.0'}),
        PdlDemEncoding.mapbox,
      );
      expect(demEncodingOfTileJson('pas du JSON'), PdlDemEncoding.mapbox);
    });
  });
}
