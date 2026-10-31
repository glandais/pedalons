import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/elevation/elevation_band_painter.dart';
import 'package:pedalons/core/pdl/elevation/elevation_samples.dart';
import 'package:pedalons/core/pdl/elevation/pdl_elevation_profile.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// La bande sous le profil (ledger `MOB-106`) : une couleur par barre, sur
/// l'axe de l'aire, que le réticule traverse.

/// 10 km, un point tous les 100 m, en pente douce.
ElevationSamples _samples({int bars = 4}) =>
    ElevationSamples.fromPoints(<ElevationPoint>[
      for (int i = 0; i <= 100; i++)
        ElevationPoint(
          distance: i * 100.0,
          elevation: 100.0 + i,
          grade: i == 0 ? null : 1,
        ),
    ], targetBars: bars);

class _RecordingCanvas implements ui.Canvas {
  final List<(ui.Rect, Color)> rects = <(ui.Rect, Color)>[];

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) => rects.add((rect, paint.color));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const Color _a = Color(0xFF00AA00);
const Color _b = Color(0xFFAA0000);
const Color _c = Color(0xFF0000AA);

void main() {
  group('ElevationBandPainter', () {
    test('une couleur par barre, sous la barre, les voisines fusionnées', () {
      final _RecordingCanvas canvas = _RecordingCanvas();
      ElevationBandPainter(
        samples: _samples(),
        colors: const <Color>[_a, _a, _b, _c],
      ).paint(canvas, const Size(400, 6));

      // `Paint.color` se relit en flottants : on compare les valeurs ARGB.
      expect(canvas.rects.map(((ui.Rect, Color) r) => r.$2.toARGB32()), <int>[
        _a.toARGB32(),
        _b.toARGB32(),
        _c.toARGB32(),
      ]);
      // Les deux premières barres (0 → 5 km) en un rectangle, la troisième de
      // 5 à 7,5 km : les abscisses de l'aire, un demi-pixel de recouvrement.
      expect(canvas.rects[0].$1.left, -0.5);
      expect(canvas.rects[0].$1.right, 200.5);
      expect(canvas.rects[1].$1.left, 199.5);
      expect(canvas.rects[1].$1.right, 300.5);
      expect(canvas.rects[2].$1.right, 400.5);
      expect(canvas.rects.first.$1.height, 6);
    });

    test('ne repeint que si les données changent', () {
      final ElevationSamples samples = _samples();
      const List<Color> colors = <Color>[_a, _a, _b, _c];
      final ElevationBandPainter painter = ElevationBandPainter(
        samples: samples,
        colors: colors,
      );
      expect(
        painter.shouldRepaint(
          ElevationBandPainter(samples: samples, colors: colors),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          ElevationBandPainter(
            samples: samples,
            colors: const <Color>[_a, _b, _b, _c],
          ),
        ),
        isTrue,
      );
    });

    test('le réticule à la même abscisse que sur le profil', () {
      final _RecordingCanvas canvas = _RecordingCanvas();
      ElevationBandCursorPainter(
        samples: _samples(),
        distance: ValueNotifier<double?>(2500),
        lineColor: _a,
      ).paint(canvas, const Size(400, 6));
      expect(canvas.rects.single.$1.center.dx, 100);
    });
  });

  group('PdlElevationProfile', () {
    Widget host(Widget child) => MaterialApp(
      theme: PedalonsTheme.build(Brightness.light),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );

    PdlElevationProfile profile(
      ElevationSamples samples,
      ValueNotifier<double?> cursor, {
      List<Color>? band,
    }) => PdlElevationProfile(
      samples: samples,
      cursorDistance: cursor,
      bandColors: band,
      axisLabel: (double m, {required bool isLast}) => '',
      tipLabel: (ElevationReading r) => '',
    );

    Finder bandPainter() => find.byWidgetPredicate(
      (Widget w) => w is CustomPaint && w.painter is ElevationBandPainter,
    );

    testWidgets('sans couleurs, pas de bande', (WidgetTester tester) async {
      final ValueNotifier<double?> cursor = ValueNotifier<double?>(null);
      addTearDown(cursor.dispose);
      await tester.pumpWidget(host(profile(_samples(), cursor)));
      expect(bandPainter(), findsNothing);

      await tester.pumpWidget(
        host(profile(_samples(), cursor, band: const <Color>[])),
      );
      expect(bandPainter(), findsNothing);
    });

    testWidgets('la bande sous le graphique, sur toute sa largeur ; un toucher '
        'sur elle déplace le réticule', (WidgetTester tester) async {
      final ElevationSamples samples = _samples();
      final ValueNotifier<double?> cursor = ValueNotifier<double?>(null);
      addTearDown(cursor.dispose);
      await tester.pumpWidget(
        host(profile(samples, cursor, band: const <Color>[_a, _a, _b, _c])),
      );

      expect(bandPainter(), findsOneWidget);
      final Rect band = tester.getRect(bandPainter());
      final Rect chart = tester.getRect(
        find.byWidgetPredicate(
          (Widget w) => w is SizedBox && w.height == PdlMetrics.elevationMedium,
        ),
      );
      expect(band.height, PdlMetrics.elevationBand);
      expect(band.top, chart.bottom + PdlMetrics.elevationBandGap);
      expect(band.left, chart.left);
      expect(band.width, chart.width);

      final int before = ElevationBandPainter.debugPaintCount;
      await tester.tapAt(Offset(band.left + band.width / 4, band.center.dy));
      await tester.pump();
      expect(cursor.value, closeTo(samples.totalDistance / 4, 1));
      // Le réticule se peint à part : la bande ne se repeint pas.
      expect(ElevationBandPainter.debugPaintCount, before);
    });
  });
}
