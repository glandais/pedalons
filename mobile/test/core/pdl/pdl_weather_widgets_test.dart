import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// `PdlWindArrow` et `PdlSegmentBar`, les deux briques génériques de la météo.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: PedalonsTheme.build(Brightness.light),
    home: Scaffold(
      body: Center(child: SizedBox(width: 300, child: child)),
    ),
  );

  testWidgets('la flèche est tournée de l\'angle reçu, sens horaire', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(const PdlWindArrow(angle: 90)));

    final Transform transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(PdlWindArrow),
        matching: find.byType(Transform),
      ),
    );
    // Une rotation de +90° envoie l'axe x sur l'axe y.
    final Matrix4 m = transform.transform;
    expect(m.entry(0, 0), closeTo(math.cos(math.pi / 2), 1e-9));
    expect(m.entry(1, 0), closeTo(1, 1e-9));
  });

  testWidgets('la flèche porte son libellé quand on le lui donne', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const PdlWindArrow(angle: 180, semanticLabel: 'Vent de face')),
    );
    expect(find.bySemanticsLabel('Vent de face'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('la barre découpe ses tronçons au prorata', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const PdlSegmentBar(
          entries: <PdlSegmentBarEntry>[
            PdlSegmentBarEntry(extent: 1, color: Color(0xFF000001)),
            PdlSegmentBarEntry(extent: 3, color: Color(0xFF000002)),
            // Un tronçon nul ne prend aucune place.
            PdlSegmentBarEntry(extent: 0, color: Color(0xFF000003)),
          ],
        ),
      ),
    );

    final List<double> widths = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(PdlSegmentBar),
            matching: find.byType(ColoredBox),
          ),
        )
        .map((ColoredBox box) => tester.getSize(find.byWidget(box)).width)
        .toList();
    expect(widths, hasLength(2));
    expect(widths[0], closeTo(75, 0.5));
    expect(widths[1], closeTo(225, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('la barre vide reste une piste, et se résume', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const PdlSegmentBar(
          entries: <PdlSegmentBarEntry>[],
          semanticLabel: 'Rien',
        ),
      ),
    );
    expect(find.byType(ColoredBox), findsWidgets);
    expect(find.bySemanticsLabel('Rien'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
