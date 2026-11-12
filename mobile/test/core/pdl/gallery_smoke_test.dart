import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/dev/pdl_gallery_page.dart';

/// La galerie rend les 20 primitives dans leurs variantes. La pomper de bout en
/// bout est le moyen le moins cher de savoir qu'aucune primitive ne déborde ni
/// ne lève à la construction — dans les deux modes, puisque c'est là qu'un
/// jeton oublié se voit.
void main() {
  Future<void> pumpGallery(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(brightness),
        home: const PdlGalleryPage(),
      ),
    );
    await tester.pump();
  }

  for (final Brightness brightness in Brightness.values) {
    testWidgets('la galerie se construit en ${brightness.name}', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(402 * 3, 874 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await pumpGallery(tester, brightness);
      expect(tester.takeException(), isNull);

      // Et elle défile jusqu'au bout sans lever : les blocs du bas — voile,
      // surface floutée — sont les plus exposés.
      final Finder list = find.byType(ListView);
      await tester.drag(list, const Offset(0, -4000));
      await tester.pump();
      await tester.drag(list, const Offset(0, -4000));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('la bascule clair / sombre de la galerie repeint la page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpGallery(tester, Brightness.light);
    await tester.tap(find.text('Sombre'));
    // `pump` et non `pumpAndSettle` : les squelettes scintillent en boucle,
    // la page ne se stabilise jamais.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
