import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/map/pdl_waypoint_mark.dart';

/// Les images des points de parcours (`MOB-84`), dessinées à 3× comme les
/// chevrons de sens.
const PdlWaypointMark _mark = PdlWaypointMark(
  glyph: IconData(0xe318, fontFamily: 'MaterialIcons'),
  disc: Color(0xFFFD7E14),
  onDisc: Color(0xFFFFFFFF),
);

/// Largeur et hauteur d'un PNG, lues dans son en-tête IHDR.
(int, int) _size(Uint8List png) {
  final ByteData d = ByteData.sublistView(png);
  return (d.getUint32(16), d.getUint32(20));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('le pictogramme fait 78 × 78 px', (WidgetTester tester) async {
    final Uint8List? png = await tester.runAsync<Uint8List?>(
      () => pdlWaypointIconPng(_mark, ring: const Color(0xFFFFFFFF)),
    );
    expect(png, isNotNull);
    expect(_size(png!), (78, 78));
  });

  testWidgets('l\'étiquette fait 66 px de haut et grandit avec le texte', (
    WidgetTester tester,
  ) async {
    final (Uint8List?, Uint8List?) pngs = (await tester
        .runAsync<(Uint8List?, Uint8List?)>(() async {
          Future<Uint8List?> label(String text) => pdlWaypointLabelPng(
            text,
            style: const TextStyle(fontSize: 12),
            background: const Color(0xFFFFFFFF),
            foreground: const Color(0xFF000000),
          );
          return (await label('Café'), await label('Café du Port de la Lune'));
        }))!;
    expect(pngs.$1, isNotNull);
    expect(pngs.$2, isNotNull);
    expect(_size(pngs.$1!).$2, 66);
    expect(_size(pngs.$2!).$1, greaterThan(_size(pngs.$1!).$1));
  });

  test('un nom de 40 caractères est tronqué à 28 et une ellipse', () {
    final String text = pdlWaypointLabelText('a' * 40);
    expect(text, '${'a' * 28}…');
    expect(pdlWaypointLabelText('Café'), 'Café');
  });

  test('le disque est comparé par valeur', () {
    expect(
      _mark,
      const PdlWaypointMark(
        glyph: IconData(0xe318, fontFamily: 'MaterialIcons'),
        disc: Color(0xFFFD7E14),
        onDisc: Color(0xFFFFFFFF),
      ),
    );
  });
}
