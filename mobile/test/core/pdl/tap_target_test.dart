import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// La règle du brief §5 : **aucune action ne descend sous 44 px**.
///
/// Elle est facile à violer sans s'en rendre compte — une pastille de 34 px
/// qu'on oublie de centrer dans sa boîte, un `size: sm` qu'on croit devoir
/// compacter jusqu'à la cible. Ce test mesure les quatre composants où la
/// tentation est la plus forte.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
  }

  void expectTallEnough(WidgetTester tester, Finder finder, String what) {
    final Size size = tester.getSize(finder);
    expect(
      size.height,
      greaterThanOrEqualTo(PdlMetrics.tapTarget),
      reason: '$what mesure ${size.height} px de haut, la cible est 44',
    );
  }

  testWidgets('PdlChip garde une cible de 44 px sous sa pastille de 34', (
    WidgetTester tester,
  ) async {
    await pump(tester, PdlChip(label: 'Gravel', onTap: () {}));
    expectTallEnough(tester, find.byType(PdlChip), 'PdlChip');

    // Et la pastille visible, elle, reste bien à 34 : le jeton n'a pas glissé.
    final Finder pill = find.descendant(
      of: find.byType(PdlChip),
      matching: find.byType(Container),
    );
    expect(tester.getSize(pill.first).height, PdlMetrics.chipVisual);
  });

  testWidgets('PdlChip répond aussi dans les 5 px autour de sa pastille', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pump(tester, PdlChip(label: 'Push', onTap: () => taps++));

    final Rect box = tester.getRect(find.byType(PdlChip));
    // Hors de la pastille (34 px centrés dans 44), mais dans la cible.
    await tester.tapAt(Offset(box.center.dx, box.top + 2));
    await tester.tapAt(Offset(box.center.dx, box.bottom - 2));
    // Et sur la pastille : un seul appel, pas deux.
    await tester.tapAt(box.center);

    expect(taps, 3);
  });

  testWidgets('PdlButton(size: sm) compacte la typo, jamais la cible', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      PdlButton(label: 'Rejoindre', size: PdlButtonSize.sm, onPressed: () {}),
    );
    expectTallEnough(tester, find.byType(PdlButton), 'PdlButton(size: sm)');
  });

  testWidgets('PdlButton(variant: text) reste à 44 px malgré ses 13/500', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      PdlButton(
        label: 'Voir tout',
        variant: PdlButtonVariant.text,
        size: PdlButtonSize.sm,
        onPressed: () {},
      ),
    );
    expectTallEnough(tester, find.byType(PdlButton), 'PdlButton(text)');
  });

  testWidgets('PdlSettingRow tient ses 52 px minimum', (
    WidgetTester tester,
  ) async {
    await pump(tester, PdlSettingRow(title: 'Langue', onTap: () {}));
    expectTallEnough(tester, find.byType(PdlSettingRow), 'PdlSettingRow');
    expect(
      tester.getSize(find.byType(PdlSettingRow)).height,
      greaterThanOrEqualTo(PdlSettingRow.minHeight),
    );
  });

  testWidgets('chaque segment de PdlSegmented mesure au moins 44 px', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      SizedBox(
        width: 300,
        child: PdlSegmented<String>(
          segments: const <PdlSegment<String>>[
            PdlSegment<String>(value: 'a', label: 'Mois'),
            PdlSegment<String>(value: 'b', label: 'Agenda'),
          ],
          value: 'a',
          onChanged: (_) {},
        ),
      ),
    );

    for (final Element element
        in find.byType(GestureDetector).evaluate().toList()) {
      final Size size = element.size!;
      expect(
        size.height,
        greaterThanOrEqualTo(PdlMetrics.tapTarget),
        reason: 'un segment mesure ${size.height} px de haut',
      );
    }
  });

  testWidgets('PdlSwitch occupe 44 px de haut même si son rail fait 28', (
    WidgetTester tester,
  ) async {
    await pump(tester, PdlSwitch(value: true, onChanged: (_) {}));
    expectTallEnough(tester, find.byType(PdlSwitch), 'PdlSwitch');
  });

  testWidgets('PdlFilterButton est un carré de 44', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      PdlFilterButton(onPressed: () {}, semanticLabel: 'Filtres'),
    );
    final Size size = tester.getSize(find.byType(PdlFilterButton));
    expect(size.height, greaterThanOrEqualTo(PdlMetrics.tapTarget));
    expect(size.width, greaterThanOrEqualTo(PdlMetrics.tapTarget));
  });

  testWidgets('PdlDisclosure : l’en-tête entier, 44 px au moins', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      const SizedBox(
        width: 360,
        child: PdlDisclosure(title: 'Points du parcours', child: SizedBox()),
      ),
    );
    expectTallEnough(tester, find.byType(InkWell), 'PdlDisclosure');
  });

  testWidgets('PdlPlaceRow.link garde 44 px sous un texte de 14', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      PdlPlaceRow.link(
        kind: PdlPlaceKind.start,
        name: 'Place de la Mairie',
        onTap: () {},
      ),
    );
    expectTallEnough(tester, find.byType(InkWell), 'PdlPlaceRow.link');
  });
}
