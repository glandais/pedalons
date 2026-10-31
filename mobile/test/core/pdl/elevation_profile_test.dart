import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/elevation/elevation_area_painter.dart';
import 'package:pedalons/core/pdl/elevation/elevation_cursor_painter.dart';
import 'package:pedalons/core/pdl/elevation/elevation_markers_painter.dart';
import 'package:pedalons/core/pdl/map/pdl_waypoint_mark.dart';
import 'package:pedalons/core/pdl/elevation/elevation_samples.dart';
import 'package:pedalons/core/pdl/elevation/pdl_elevation_profile.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// 300 points synthétiques — la taille maximale que le serveur renvoie.
///
/// La première moitié est plate (pente 0), la seconde grimpe à 20 % : les deux
/// extrémités de l'échelle de pente sont donc représentées, et les deux barres
/// extrêmes en sont les témoins.
ElevationSamples _synthetic({int count = 300}) {
  final List<ElevationPoint> points = <ElevationPoint>[];
  double elevation = 100;
  for (int i = 0; i < count; i++) {
    final double distance = i * 100.0;
    final bool climbing = i > count ~/ 2;
    if (climbing) elevation += 20;
    points.add(
      ElevationPoint(
        distance: distance,
        elevation: elevation,
        grade: i == 0 ? 0 : (climbing ? 20 : 0),
      ),
    );
  }
  return ElevationSamples.fromPoints(points);
}

/// Canvas d'essai : on ne veut que la liste des formes demandées.
///
/// `noSuchMethod` absorbe tout le reste de l'interface — y compris le
/// `drawParagraph` de l'info-bulle, dont le contenu ne nous intéresse pas.
class _RecordingCanvas implements ui.Canvas {
  final List<(ui.RRect, Color)> rrects = <(ui.RRect, Color)>[];
  final List<(ui.Rect, Color)> rects = <(ui.Rect, Color)>[];

  /// Un segment de la ligne de crête : ses deux extrémités et sa couleur.
  final List<(Offset, Offset, Color)> lines = <(Offset, Offset, Color)>[];

  /// Les aplats sous la ligne : seule leur couleur nous intéresse, la
  /// silhouette se vérifie sur les segments.
  final List<Color> fills = <Color>[];

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) =>
      rrects.add((rrect, paint.color));

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) => rects.add((rect, paint.color));

  @override
  void drawLine(Offset p1, Offset p2, ui.Paint paint) =>
      lines.add((p1, p2, paint.color));

  @override
  void drawPath(ui.Path path, ui.Paint paint) => fills.add(paint.color);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const PdlWaypointMark _mark = PdlWaypointMark(
  glyph: IconData(0xe318, fontFamily: 'MaterialIcons'),
  disc: Color(0xFFFD7E14),
  onDisc: Color(0xFFFFFFFF),
);

PdlProfileMarker _marker(String key, double distance, {int priority = 1}) =>
    PdlProfileMarker(
      key: key,
      distance: distance,
      mark: _mark,
      priority: priority,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ElevationAreaPainter', () {
    test('colorise chaque tranche par sa propre pente', () {
      final ElevationSamples samples = _synthetic();
      final _RecordingCanvas canvas = _RecordingCanvas();

      ElevationAreaPainter(
        samples: samples,
        neutralColor: slopeNeutral,
        slopeColorOf: slopeColor,
      ).paint(canvas, const Size(380, 110));

      // Une ligne de crête et un aplat par tranche.
      expect(canvas.lines, hasLength(samples.bars.length));
      expect(canvas.fills, hasLength(samples.bars.length));
      expect(samples.bars.length, kElevationBarTarget);

      // Pente nulle → le neutre (teinte 210), pente ≥ 18 % → teinte −105
      // enroulée en 255 (l'échelle du site, ledger `MOB-105`).
      expect(samples.bars.first.grade, closeTo(0, 1e-9));
      expect(samples.bars.last.grade, closeTo(20, 1e-9));
      expect(HSLColor.fromColor(canvas.lines.first.$3).hue, closeTo(210, 1.5));
      expect(HSLColor.fromColor(canvas.lines.last.$3).hue, closeTo(255, 1.5));

      // L'aplat est la même teinte, en translucide : c'est la ligne qui porte
      // la lecture.
      expect(
        HSLColor.fromColor(canvas.fills.first).hue,
        closeTo(HSLColor.fromColor(canvas.lines.first.$3).hue, 1e-6),
      );
      expect(canvas.fills.first.a, lessThan(canvas.lines.first.$3.a));
    });

    test(
      'barColors remplace l\'échelle de pente, une entrée nulle est neutre',
      () {
        final ElevationSamples samples = _synthetic(count: 5);
        final List<Color?> colors = <Color?>[
          const Color(0xFF112233),
          null,
          const Color(0xFF445566),
          const Color(0xFF778899),
        ];
        final _RecordingCanvas canvas = _RecordingCanvas();

        ElevationAreaPainter(
          samples: samples,
          neutralColor: slopeNeutral,
          slopeColorOf: slopeColor,
          barColors: colors,
        ).paint(canvas, const Size(380, 110));

        expect(canvas.lines.map((l) => l.$3.toARGB32()).toList(), <int>[
          0xFF112233,
          slopeNeutral.toARGB32(),
          0xFF445566,
          0xFF778899,
        ]);
      },
    );

    test('shouldRepaint suit l\'identité de barColors', () {
      final ElevationSamples samples = _synthetic(count: 5);
      final List<Color?> a = <Color?>[const Color(0xFF112233)];
      ElevationAreaPainter painter(List<Color?>? colors) =>
          ElevationAreaPainter(
            samples: samples,
            neutralColor: slopeNeutral,
            slopeColorOf: slopeColor,
            barColors: colors,
          );

      expect(painter(a).shouldRepaint(painter(a)), isFalse);
      expect(painter(a).shouldRepaint(painter(<Color?>[...a])), isTrue);
      expect(painter(a).shouldRepaint(painter(null)), isTrue);
    });

    test('une pente inconnue tombe sur slopeNeutral', () {
      final ElevationSamples samples = ElevationSamples.fromPoints(
        const <ElevationPoint>[
          ElevationPoint(distance: 0, elevation: 10),
          ElevationPoint(distance: 100, elevation: 20),
        ],
        targetBars: 1,
      );
      final _RecordingCanvas canvas = _RecordingCanvas();

      ElevationAreaPainter(
        samples: samples,
        neutralColor: slopeNeutral,
        slopeColorOf: slopeColor,
      ).paint(canvas, const Size(380, 110));

      // Comparaison sur l'entier ARGB : `Paint.color` fait un aller-retour en
      // flottants, deux couleurs identiques à l'œil n'y sont pas `==`.
      expect(canvas.lines.single.$3.toARGB32(), slopeNeutral.toARGB32());
    });

    test('la silhouette est continue et couvre toute la largeur', () {
      final ElevationSamples samples = _synthetic(count: 5);
      final _RecordingCanvas canvas = _RecordingCanvas();
      const Size size = Size(101, 110);

      ElevationAreaPainter(
        samples: samples,
        neutralColor: slopeNeutral,
        slopeColorOf: slopeColor,
      ).paint(canvas, size);

      expect(canvas.lines.first.$1.dx, closeTo(0, 1e-9));
      expect(canvas.lines.last.$2.dx, closeTo(size.width, 1e-9));

      // Chaque segment repart exactement d'où le précédent s'arrête : c'est ce
      // qui distingue une aire d'un histogramme, et ce qu'une altitude prise au
      // centre des tranches casserait.
      for (int i = 1; i < canvas.lines.length; i++) {
        expect(canvas.lines[i].$1.dx, closeTo(canvas.lines[i - 1].$2.dx, 1e-9));
        expect(canvas.lines[i].$1.dy, closeTo(canvas.lines[i - 1].$2.dy, 1e-9));
      }

      // Et rien ne sort de la boîte.
      for (final (Offset a, Offset b, Color _) in canvas.lines) {
        expect(a.dy, inInclusiveRange(0, size.height));
        expect(b.dy, inInclusiveRange(0, size.height));
      }
    });
  });

  group('ElevationCursorPainter', () {
    ElevationCursorPainter painterAt(ValueNotifier<double?> cursor) =>
        ElevationCursorPainter(
          samples: _synthetic(),
          distance: cursor,
          repaint: cursor,
          lineColor: const Color(0xB3000000),
          tipBackground: const Color(0xFFFFFFFF),
          tipBorder: const Color(0xFFDEE2E6),
          tipTextStyle: const TextStyle(fontSize: 10),
          textScaler: TextScaler.noScaling,
          label: (ElevationReading r) => '28,7 km · 74 m · 4,1 %',
        );

    test('l\'info-bulle est bornée au bord gauche (curseur à 0 %)', () {
      final ValueNotifier<double?> cursor = ValueNotifier<double?>(0);
      addTearDown(cursor.dispose);
      final _RecordingCanvas canvas = _RecordingCanvas();

      painterAt(cursor).paint(canvas, const Size(380, 140));

      final ui.RRect tip = canvas.rrects.first.$1;
      expect(tip.left, greaterThanOrEqualTo(0));
      expect(tip.top, ElevationCursorPainter.tipTop);
      // Sans bornage, une bulle centrée sur x = 0 commencerait à −largeur / 2.
      expect(tip.left, closeTo(ElevationCursorPainter.tipEdgeInset, 1e-9));
    });

    test('l\'info-bulle est bornée au bord droit (curseur à 100 %)', () {
      final ElevationSamples samples = _synthetic();
      final ValueNotifier<double?> cursor = ValueNotifier<double?>(
        samples.totalDistance,
      );
      addTearDown(cursor.dispose);
      final _RecordingCanvas canvas = _RecordingCanvas();
      const Size size = Size(380, 140);

      painterAt(cursor).paint(canvas, size);

      final ui.RRect tip = canvas.rrects.first.$1;
      expect(tip.right, lessThanOrEqualTo(size.width));
      expect(
        tip.right,
        closeTo(size.width - ElevationCursorPainter.tipEdgeInset, 1e-9),
      );
    });

    test('le réticule est un trait de 1 px sur toute la hauteur', () {
      final ValueNotifier<double?> cursor = ValueNotifier<double?>(
        _synthetic().totalDistance / 2,
      );
      addTearDown(cursor.dispose);
      final _RecordingCanvas canvas = _RecordingCanvas();

      painterAt(cursor).paint(canvas, const Size(380, 140));

      final (ui.Rect line, Color _) = canvas.rects.single;
      expect(line.width, 1);
      expect(line.top, 0);
      expect(line.bottom, 140);
      expect(line.center.dx, closeTo(190, 0.5));
    });

    test('sans distance, rien n\'est peint', () {
      final ValueNotifier<double?> cursor = ValueNotifier<double?>(null);
      addTearDown(cursor.dispose);
      final _RecordingCanvas canvas = _RecordingCanvas();

      painterAt(cursor).paint(canvas, const Size(380, 140));

      expect(canvas.rects, isEmpty);
      expect(canvas.rrects, isEmpty);
    });
  });

  group('ElevationMarkersPainter (MOB-84)', () {
    test('markerAt ne répond que dans la bande haute, à 22 px près', () {
      final List<PdlProfileMarker> markers = <PdlProfileMarker>[
        _marker('a', 1000),
      ];
      // 10 000 m sur 400 px : 1 000 m tombent à x = 40.
      expect(
        ElevationMarkersPainter.markerAt(
          markers,
          10000,
          400,
          const Offset(40, 20),
        ),
        'a',
      );
      expect(
        ElevationMarkersPainter.markerAt(
          markers,
          10000,
          400,
          const Offset(60, 44),
        ),
        'a',
      );
      // Sous la bande : le réticule garde le toucher.
      expect(
        ElevationMarkersPainter.markerAt(
          markers,
          10000,
          400,
          const Offset(40, 60),
        ),
        isNull,
      );
      // Trop loin (23 px).
      expect(
        ElevationMarkersPainter.markerAt(
          markers,
          10000,
          400,
          const Offset(63, 20),
        ),
        isNull,
      );
    });

    test('à égalité de distance, le type le plus important gagne', () {
      final List<PdlProfileMarker> markers = <PdlProfileMarker>[
        _marker('info', 1000, priority: 0),
        _marker('danger', 1000, priority: 11),
      ];
      expect(
        ElevationMarkersPainter.markerAt(
          markers,
          10000,
          400,
          const Offset(40, 10),
        ),
        'danger',
      );
    });

    test('shouldRepaint réagit à la sélection et aux repères', () {
      final ElevationSamples samples = _synthetic();
      ElevationMarkersPainter painter({String? selected, double d = 1000}) =>
          ElevationMarkersPainter(
            samples: samples,
            markers: <PdlProfileMarker>[_marker('a', d)],
            ring: const Color(0xFFFFFFFF),
            selectedKey: selected,
          );
      expect(painter().shouldRepaint(painter()), isFalse);
      expect(painter().shouldRepaint(painter(selected: 'a')), isTrue);
      expect(painter().shouldRepaint(painter(d: 2000)), isTrue);
    });

    test('une distance hors du profil n\'est pas peinte', () {
      final ElevationSamples samples = _synthetic();
      final _RecordingCanvas canvas = _RecordingCanvas();
      ElevationMarkersPainter(
        samples: samples,
        markers: <PdlProfileMarker>[
          _marker('loin', samples.totalDistance + 1000),
          _marker('neg', -5),
        ],
        ring: const Color(0xFFFFFFFF),
      ).paint(canvas, const Size(380, 110));
      expect(canvas.lines, isEmpty);
    });
  });

  group('PdlElevationProfile', () {
    Widget host(Widget child) => MaterialApp(
      theme: PedalonsTheme.build(Brightness.light),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );

    testWidgets('le glissement ne repeint pas les barres', (
      WidgetTester tester,
    ) async {
      final ElevationSamples samples = _synthetic();
      final ValueNotifier<double?> cursor = ValueNotifier<double?>(null);
      addTearDown(cursor.dispose);

      await tester.pumpWidget(
        host(
          PdlElevationProfile(
            samples: samples,
            cursorDistance: cursor,
            height: PdlMetrics.elevationLarge,
            axisLabel: (double m, {required bool isLast}) =>
                isLast ? '${m ~/ 1000} km' : '${m ~/ 1000}',
            tipLabel: (ElevationReading r) => '${r.distance ~/ 1000} km',
          ),
        ),
      );
      await tester.pump();

      final int before = ElevationAreaPainter.debugPaintCount;
      expect(before, greaterThan(0));

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(PdlElevationProfile)),
      );
      for (int i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();

      // Le réticule a bien bougé…
      expect(cursor.value, isNotNull);
      // …et **persiste après le relâchement**.
      final double held = cursor.value!;
      await tester.pump(const Duration(milliseconds: 200));
      expect(cursor.value, held);

      // …sans que l'aire ait été repeinte une seule fois.
      expect(ElevationAreaPainter.debugPaintCount, before);
    });

    testWidgets('un toucher sur un repère l\'ouvre sans bouger le réticule', (
      WidgetTester tester,
    ) async {
      final ElevationSamples samples = _synthetic();
      final ValueNotifier<double?> cursor = ValueNotifier<double?>(null);
      addTearDown(cursor.dispose);
      final List<String> tapped = <String>[];

      await tester.pumpWidget(
        host(
          PdlElevationProfile(
            samples: samples,
            cursorDistance: cursor,
            height: PdlMetrics.elevationLarge,
            axisLabel: (double m, {required bool isLast}) => '',
            tipLabel: (ElevationReading r) => '',
            markers: <PdlProfileMarker>[
              _marker('mid', samples.totalDistance / 2),
            ],
            onMarkerTapped: tapped.add,
          ),
        ),
      );
      await tester.pump();

      final Rect box = tester.getRect(find.byType(PdlElevationProfile));
      // La bande haute, au milieu du graphique.
      await tester.tapAt(Offset(box.center.dx, box.top + 12));
      await tester.pump();
      expect(tapped, <String>['mid']);
      expect(cursor.value, isNull);

      // Ailleurs dans le graphique : le réticule bouge, aucun repère.
      await tester.tapAt(Offset(box.left + 20, box.top + 80));
      await tester.pump();
      expect(tapped, hasLength(1));
      expect(cursor.value, isNotNull);
    });

    testWidgets('le glissement ne repeint pas les repères', (
      WidgetTester tester,
    ) async {
      final ElevationSamples samples = _synthetic();
      final ValueNotifier<double?> cursor = ValueNotifier<double?>(null);
      addTearDown(cursor.dispose);

      await tester.pumpWidget(
        host(
          PdlElevationProfile(
            samples: samples,
            cursorDistance: cursor,
            height: PdlMetrics.elevationLarge,
            axisLabel: (double m, {required bool isLast}) => '',
            tipLabel: (ElevationReading r) => '',
            markers: <PdlProfileMarker>[_marker('a', 5000)],
            onMarkerTapped: (String _) {},
          ),
        ),
      );
      await tester.pump();
      final int before = ElevationMarkersPainter.debugPaintCount;
      expect(before, greaterThan(0));

      final Rect box = tester.getRect(find.byType(PdlElevationProfile));
      final TestGesture gesture = await tester.startGesture(
        Offset(box.left + 10, box.top + 90),
      );
      for (int i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(12, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();

      expect(cursor.value, isNotNull);
      expect(ElevationMarkersPainter.debugPaintCount, before);
    });

    testWidgets('un tap sous la boîte efface le réticule', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double?> cursor = ValueNotifier<double?>(1234);
      addTearDown(cursor.dispose);

      await tester.pumpWidget(
        host(
          PdlElevationProfile(
            samples: _synthetic(),
            cursorDistance: cursor,
            height: PdlMetrics.elevationCompact,
            axisLabel: (double m, {required bool isLast}) => '${m ~/ 1000}',
            tipLabel: (ElevationReading r) => '${r.distance ~/ 1000}',
          ),
        ),
      );
      await tester.pump();

      // L'axe est sous la boîte : y taper sort du profil.
      final Offset topLeft = tester.getTopLeft(
        find.byType(PdlElevationProfile),
      );
      await tester.tapAt(
        topLeft + const Offset(40, PdlMetrics.elevationCompact + 6),
      );
      await tester.pump();

      expect(cursor.value, isNull);
    });

    testWidgets('l\'axe porte 5 graduations, la dernière avec l\'unité', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          PdlElevationProfile(
            samples: _synthetic(),
            axisLabel: (double m, {required bool isLast}) =>
                isLast ? '${(m / 1000).round()} km' : '${(m / 1000).round()}',
            tipLabel: (ElevationReading r) => '',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('0'), findsOneWidget);
      expect(find.textContaining('km'), findsOneWidget);
    });

    testWidgets(
      'les états de chargement et d\'échec ne peignent aucune barre',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          host(
            const PdlElevationProfile.loading(
              label: 'Chargement du profil altimétrique...',
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text('Chargement du profil altimétrique...'),
          findsOneWidget,
        );

        bool retried = false;
        await tester.pumpWidget(
          host(
            PdlElevationProfile.failed(
              label: 'Profil indisponible',
              actionLabel: 'Réessayer',
              onRetry: () => retried = true,
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Profil indisponible'), findsOneWidget);
        await tester.tap(find.text('Réessayer'));
        expect(retried, isTrue);
      },
    );
  });
}
