import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/features/routes/data/gpx_file_source.dart';
import 'package:pedalons/features/routes/domain/gpx_check.dart';
import 'package:pedalons/features/routes/domain/route_form.dart';

/// Le contrôle local d'un GPX avant envoi (ledger `MOB-79`) : l'extension, le
/// début du contenu, et le nom que le fichier se donne. Le serveur reste seul
/// juge ; ceci évite d'envoyer 10 Mio pour s'entendre dire que c'est une page
/// HTML.
void main() {
  GpxFile file(String name, {int size = 1200}) =>
      GpxFile(path: '/tmp/$name', name: name, size: size);

  const String gpx =
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">'
      '<trk><name>Boucle</name><trkseg></trkseg></trk></gpx>';

  group('checkGpx', () {
    test('accepte un .gpx dont le contenu ouvre un élément gpx', () {
      final GpxCheck check = checkGpx(file('col.gpx'), gpx);
      expect(check, isA<GpxAccepted>());
      expect((check as GpxAccepted).trackName, 'Boucle');
    });

    test("l'extension est insensible à la casse", () {
      expect(checkGpx(file('COL.GPX'), gpx), isA<GpxAccepted>());
      expect(checkGpx(file('col.Gpx'), gpx), isA<GpxAccepted>());
    });

    test('refuse un .txt, même au contenu de GPX', () {
      final GpxCheck check = checkGpx(file('notes.txt'), gpx);
      expect(check, isA<GpxRefused>());
      expect((check as GpxRefused).refusal, GpxRefusal.notGpx);
      // Le message cite le nom tel que choisi.
      expect(check.fileName, 'notes.txt');
    });

    test('refuse un .gpx qui contient du HTML', () {
      final GpxCheck check = checkGpx(
        file('page.gpx'),
        '<!doctype html><html><body>Connexion</body></html>',
      );
      expect((check as GpxRefused).refusal, GpxRefusal.notGpx);
    });

    test('refuse un contenu vide', () {
      expect(checkGpx(file('vide.gpx', size: 0), ''), isA<GpxRefused>());
    });

    test('accepte une déclaration XML, une marque BOM, un préfixe', () {
      expect(
        checkGpx(file('a.gpx'), '﻿<?xml version="1.0"?><gpx>'),
        isA<GpxAccepted>(),
      );
      expect(
        checkGpx(
          file('b.gpx'),
          '<?xml version="1.0"?>\n<ns:gpx version="1.1">',
        ),
        isA<GpxAccepted>(),
      );
      expect(
        checkGpx(file('c.gpx'), '<gpx/>'),
        isA<GpxAccepted>(),
        reason: 'un élément gpx vide reste un élément gpx',
      );
    });

    test('ne prend pas <gpxx:TrackExtension> pour la racine', () {
      expect(
        checkGpx(file('d.gpx'), '<root><gpxx:TrackExtension/></root>'),
        isA<GpxRefused>(),
      );
    });

    test('un fichier de plus de 10 Mio est refusé comme trop gros', () {
      final GpxCheck check = checkGpx(
        file('gros.gpx', size: kGpxMaxBytes + 1),
        gpx,
      );
      expect((check as GpxRefused).refusal, GpxRefusal.tooLarge);
      // Pile à la limite : accepté.
      expect(
        checkGpx(file('limite.gpx', size: kGpxMaxBytes), gpx),
        isA<GpxAccepted>(),
      );
    });
  });

  group('gpxTrackName', () {
    test('le nom de <metadata> passe avant celui de la trace', () {
      expect(
        gpxTrackName(
          '<gpx><metadata><name>Titre du fichier</name></metadata>'
          '<trk><name>Trace</name><trkseg/></trk></gpx>',
        ),
        'Titre du fichier',
      );
    });

    test("ignore l'auteur et le lien de <metadata>", () {
      expect(
        gpxTrackName(
          '<gpx><metadata><author><name>Léa</name></author>'
          '<link href="x"><text>site</text></link></metadata>'
          '<trk><name>Ma trace</name><trkseg/></trk></gpx>',
        ),
        'Ma trace',
      );
    });

    test(
      "prend la première <trk>, jamais le nom d'un <wpt> ou d'une <rte>",
      () {
        expect(
          gpxTrackName(
            '<gpx><wpt lat="1" lon="2"><name>Café</name></wpt>'
            '<rte><name>Itinéraire</name></rte>'
            '<trk><name>Col de la Croix</name><trkseg/></trk>'
            '<trk><name>Autre</name><trkseg/></trk></gpx>',
          ),
          'Col de la Croix',
        );
      },
    );

    test("ne descend pas dans le segment d'une trace sans nom", () {
      expect(
        gpxTrackName(
          '<gpx><trk><trkseg><trkpt lat="1" lon="2"><name>Point</name>'
          '</trkpt></trkseg></trk></gpx>',
        ),
        isNull,
      );
    });

    test('déroule CDATA, entités et espaces', () {
      expect(
        gpxTrackName(
          '<gpx><trk><name><![CDATA[Tour <A&B>]]></name></trk></gpx>',
        ),
        'Tour <A&B>',
      );
      expect(
        gpxTrackName(
          '<gpx><trk><name>  Mont &amp; Vaux &lt;2&gt; &quot;x&quot; '
          '&apos;y&apos; &#233;t&#xE9;\n  fin </name></trk></gpx>',
        ),
        'Mont & Vaux <2> "x" \'y\' été fin',
      );
    });

    test('tolère un préfixe et des attributs', () {
      expect(
        gpxTrackName(
          '<g:gpx><g:trk><g:name id="n">Préfixé</g:name></g:trk></g:gpx>',
        ),
        'Préfixé',
      );
    });

    test('un nom vide ou absent vaut null', () {
      expect(gpxTrackName('<gpx><trk><name>  </name></trk></gpx>'), isNull);
      expect(gpxTrackName('<gpx><trk><trkseg/></trk></gpx>'), isNull);
      expect(gpxTrackName('<gpx/>'), isNull);
    });
  });

  group('suggestedRouteName', () {
    GpxAccepted accepted(String name, String? trackName) =>
        GpxAccepted(file(name), trackName: trackName);

    test('le nom du GPX quand il fait au moins 3 caractères', () {
      expect(suggestedRouteName(accepted('x.gpx', 'Vercors')), 'Vercors');
    });

    test(
      'le nom du fichier sans .gpx sinon, casse de l\'extension comprise',
      () {
        expect(suggestedRouteName(accepted('col-test.gpx', null)), 'col-test');
        expect(suggestedRouteName(accepted('Col Test.GPX', null)), 'Col Test');
      },
    );

    test('un nom de moins de 3 caractères cède au nom du fichier', () {
      expect(
        suggestedRouteName(accepted('boucle-nord.gpx', 'ab')),
        'boucle-nord',
      );
    });

    test('tronque à 200 caractères', () {
      final String long = 'a' * 300;
      expect(
        suggestedRouteName(accepted('x.gpx', long)).length,
        kRouteNameMaxLength,
      );
      expect(
        suggestedRouteName(accepted('${'b' * 250}.gpx', null)).length,
        kRouteNameMaxLength,
      );
    });
  });

  group('gpxRefusalOfApiCode', () {
    test('traduit les codes du serveur', () {
      for (final String code in <String>[
        'GPX_FAILURE',
        'FILE_TYPE_REJECTED',
        'FILE_DETECTION_FAILED',
      ]) {
        expect(gpxRefusalOfApiCode(code), GpxRefusal.notGpx, reason: code);
      }
      expect(gpxRefusalOfApiCode('GPX_EMPTY'), GpxRefusal.empty);
      expect(gpxRefusalOfApiCode('GPX_TOO_LONG'), GpxRefusal.tooLong);
      expect(gpxRefusalOfApiCode('FILE_TOO_LARGE'), GpxRefusal.tooLarge);
    });

    test("un autre échec n'est pas la faute du fichier", () {
      expect(gpxRefusalOfApiCode('FORBIDDEN'), isNull);
      expect(gpxRefusalOfApiCode(null), isNull);
    });
  });

  group('inspectGpxFile', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('gpx_inspect_'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<GpxFile> write(String name, List<int> bytes) async {
      final File f = File('${dir.path}/$name');
      await f.writeAsBytes(bytes);
      return GpxFile(path: f.path, name: name, size: bytes.length);
    }

    test('lit un GPX en UTF-8', () async {
      final GpxFile f = await write('utf8.gpx', utf8.encode(gpx));
      final GpxCheck check = await inspectGpxFile(f);
      expect((check as GpxAccepted).trackName, 'Boucle');
    });

    test(
      'lit un GPX en UTF-16 avec marque BOM, petit et grand boutiste',
      () async {
        final List<int> units = gpx.codeUnits;
        final Uint8List le = Uint8List.fromList(<int>[
          0xFF,
          0xFE,
          for (final int u in units) ...<int>[u & 0xFF, u >> 8],
        ]);
        final Uint8List be = Uint8List.fromList(<int>[
          0xFE,
          0xFF,
          for (final int u in units) ...<int>[u >> 8, u & 0xFF],
        ]);
        for (final Uint8List bytes in <Uint8List>[le, be]) {
          final GpxFile f = await write('utf16.gpx', bytes);
          final GpxCheck check = await inspectGpxFile(f);
          expect(check, isA<GpxAccepted>());
          expect((check as GpxAccepted).trackName, 'Boucle');
        }
      },
    );

    test('un octet invalide ne fait pas lever', () async {
      final GpxFile f = await write('latin1.gpx', <int>[
        ...utf8.encode('<gpx><trk><name>Caf'),
        0xE9,
        ...utf8.encode('</name></trk></gpx>'),
      ]);
      expect(await inspectGpxFile(f), isA<GpxAccepted>());
    });

    test('un fichier absent est refusé comme « pas un GPX »', () async {
      final GpxCheck check = await inspectGpxFile(
        GpxFile(path: '${dir.path}/absent.gpx', name: 'absent.gpx', size: 10),
      );
      expect(check, isA<GpxRefused>());
      expect((check as GpxRefused).refusal, GpxRefusal.notGpx);
    });

    test('un .txt est refusé', () async {
      final GpxFile f = await write('notes.txt', utf8.encode('pas un gpx'));
      expect(
        (await inspectGpxFile(f) as GpxRefused).refusal,
        GpxRefusal.notGpx,
      );
    });
  });
}
