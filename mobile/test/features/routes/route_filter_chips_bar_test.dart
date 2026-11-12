import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/features/routes/domain/route_filters.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_filter_chips_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F-DE-3 — la rangée de chips coupée.
///
/// Deux défauts distincts, et un seul test ne les attrape pas tous les deux :
///
/// * la 4ᵉ chip se faisait couper net par le bord droit, **sans signal** — une
///   chip tronquée se lit comme une chip abîmée, pas comme « il y en a
///   d'autres » ;
/// * la barre figeait sa hauteur à 40 px, ce qui rognait les chips dès que
///   l'agrandissement typographique passait la barre des 130 %.
///
/// Les deux se reproduisent silencieusement à la première réécriture de la
/// barre, d'où ce garde-fou.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Widget host({required double textScale}) => ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          // Étroit à dessein : c'est la largeur qui produit le débordement.
          body: SizedBox(
            width: 300,
            child: RouteFilterChipsBar(
              filters: const RouteFilters(),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('le débordement horizontal est annoncé par un fondu', (
    tester,
  ) async {
    await tester.pumpWidget(host(textScale: 1));

    final row = find.byType(PdlChipRow);
    expect(row, findsOneWidget);

    // Plus de chips que de largeur : le contenu défile.
    expect(tester.widget<PdlChipRow>(row).children.length, greaterThan(3));
    expect(
      tester.widget<PdlChipRow>(row).fadeWidth,
      greaterThan(0),
      reason:
          'sans fondu, la chip du bord droit est coupée net et rien ne dit '
          "qu'il en reste",
    );
    expect(
      find.descendant(of: row, matching: find.byType(ShaderMask)),
      findsOneWidget,
    );
  });

  testWidgets('aucune chip n\'est rognée à textScaleFactor 1,3', (
    tester,
  ) async {
    for (final double scale in <double>[1, 1.3]) {
      await tester.pumpWidget(host(textScale: scale));
      await tester.pump();

      final double rowHeight = tester.getSize(find.byType(PdlChipRow)).height;

      expect(
        rowHeight,
        isNot(40),
        reason:
            'la barre imposait 40 px en dur ; sa hauteur doit venir de son '
            'contenu, pas d\'une constante (scale $scale)',
      );

      for (final Element chip in find.byType(PdlChip).evaluate()) {
        expect(
          tester.getSize(find.byElementPredicate((e) => e == chip)).height,
          lessThanOrEqualTo(rowHeight),
          reason:
              'une chip plus haute que sa rangée est une chip rognée '
              '(scale $scale)',
        );
      }

      // La garantie la plus directe : aucun débordement de mise en page.
      expect(tester.takeException(), isNull, reason: 'scale $scale');
    }
  });
}
