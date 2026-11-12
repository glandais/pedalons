import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// Ledger `MOB-39` — les tags d'un contenu : tronqués en carte, complets en
/// fiche, et rien du tout quand il n'y en a pas.
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

  List<PdlTagEntry> entries(int count) => <PdlTagEntry>[
    for (int i = 0; i < count; i++)
      PdlTagEntry(label: 'Tag $i', color: const Color(0xFF2F9E44)),
  ];

  testWidgets('en carte : les premiers tags, puis « +n »', (
    WidgetTester tester,
  ) async {
    await pump(tester, PdlTagRow(tags: entries(5), maxVisible: 3));

    expect(find.byType(PdlTag), findsNWidgets(3));
    expect(find.text('Tag 0'), findsOneWidget);
    expect(find.text('Tag 2'), findsOneWidget);
    expect(find.text('Tag 3'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('pas de « +1 » : un seul tag de trop est montré', (
    WidgetTester tester,
  ) async {
    await pump(tester, PdlTagRow(tags: entries(4), maxVisible: 3));

    expect(find.byType(PdlTag), findsNWidgets(4));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('pas de « +0 » quand tout tient', (WidgetTester tester) async {
    await pump(tester, PdlTagRow(tags: entries(3), maxVisible: 3));

    expect(find.byType(PdlTag), findsNWidgets(3));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('en fiche : tous les tags', (WidgetTester tester) async {
    await pump(tester, PdlTagRow(tags: entries(7)));

    expect(find.byType(PdlTag), findsNWidgets(7));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('sans tag, rien n\'est rendu', (WidgetTester tester) async {
    await pump(tester, const PdlTagRow(tags: <PdlTagEntry>[]));

    expect(find.byType(Wrap), findsNothing);
    expect(tester.getSize(find.byType(PdlTagRow)), Size.zero);
  });

  testWidgets('le libellé garde sa casse : un tag n\'est pas un badge', (
    WidgetTester tester,
  ) async {
    // Le badge met son libellé en capitales ; le tag non (plan des tags,
    // D10) — c'est une partie de ce qui l'en distingue.
    await pump(
      tester,
      const PdlTag(label: 'Sortie café', color: Color(0xFF2F9E44)),
    );

    expect(find.text('Sortie café'), findsOneWidget);
    expect(find.text('SORTIE CAFÉ'), findsNothing);
  });
}
