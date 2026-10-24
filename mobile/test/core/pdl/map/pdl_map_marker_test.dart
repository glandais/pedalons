import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// Le marqueur générique de `PdlMap` (ledger `MOB-92`) : égalité de valeur
/// sans le widget, cible de 44 px, bouton pour le lecteur d'écran.
void main() {
  PdlMapMarker marker({
    String id = 'a',
    double lon = 5,
    double lat = 45,
    String label = 'Départ, 21:30',
    Widget child = const SizedBox(),
    Alignment alignment = Alignment.bottomCenter,
    Size size = const Size(96, 32),
  }) => PdlMapMarker(
    id: id,
    lon: lon,
    lat: lat,
    size: size,
    alignment: alignment,
    semanticLabel: label,
    child: child,
  );

  test('égalité de valeur : le widget n\'y entre pas', () {
    // Deux widgets distincts (pas `const`) : leur égalité est leur identité.
    expect(marker(child: Container()), marker(child: Container()));
    expect(
      marker(child: Container()).hashCode,
      marker(child: Container()).hashCode,
    );
    expect(marker(), isNot(marker(id: 'b')));
    expect(marker(), isNot(marker(lon: 5.1)));
    expect(marker(), isNot(marker(lat: 45.1)));
    expect(marker(), isNot(marker(label: 'Départ, 21:45')));
    expect(marker(), isNot(marker(alignment: Alignment.center)));
    expect(marker(), isNot(marker(size: const Size(32, 32))));
  });

  test('la cible ne descend pas sous 44 px', () {
    expect(marker().targetSize, const Size(96, PdlMetrics.tapTarget));
    expect(
      marker(size: const Size(20, 20)).targetSize,
      const Size(PdlMetrics.tapTarget, PdlMetrics.tapTarget),
    );
  });

  testWidgets('le toucher, la cible de 44 px, le visuel accroché en bas', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: Center(
            child: PdlMapMarkerTarget(
              marker: marker(
                child: const ColoredBox(color: Colors.transparent),
              ),
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    final Rect box = tester.getRect(find.byType(PdlMapMarkerTarget));
    expect(box.height, PdlMetrics.tapTarget);
    // Au-dessus du visuel (32 px accrochés en bas des 44), dans la cible.
    await tester.tapAt(Offset(box.center.dx, box.top + 3));
    expect(taps, 1);
    final Rect visual = tester.getRect(find.byType(ColoredBox).last);
    expect(visual.bottom, box.bottom);
    expect(visual.height, 32);

    final SemanticsNode node = tester.getSemantics(
      find.byType(PdlMapMarkerTarget),
    );
    expect(node.label, 'Départ, 21:30');
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('PdlMapBearing : le cap de la carte, 0 hors d\'une carte', (
    WidgetTester tester,
  ) async {
    final List<double> seen = <double>[];
    Widget probe() => Builder(
      builder: (BuildContext context) {
        seen.add(PdlMapBearing.of(context));
        return const SizedBox();
      },
    );

    await tester.pumpWidget(probe());
    await tester.pumpWidget(PdlMapBearing(bearing: 42, child: probe()));
    await tester.pumpWidget(PdlMapBearing(bearing: 90, child: probe()));
    expect(seen, <double>[0, 42, 90]);
  });
}
