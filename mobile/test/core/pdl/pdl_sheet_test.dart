import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// La feuille modale se referme d'un appui hors d'elle — sauf si l'appelant
/// l'interdit.
void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    bool isDismissible = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => PdlSheet.show<void>(
                  context: context,
                  isDismissible: isDismissible,
                  builder: (_) => const PdlSheet(
                    title: 'Feuille',
                    children: <Widget>[Text('Contenu')],
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Contenu'), findsOneWidget);
  }

  testWidgets('un appui au-dessus de la feuille la referme', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    await tester.tapAt(const Offset(400, 80));
    await tester.pumpAndSettle();

    expect(find.text('Contenu'), findsNothing);
  });

  testWidgets('un appui dans la feuille la garde ouverte', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Contenu'));
    await tester.pumpAndSettle();

    expect(find.text('Contenu'), findsOneWidget);
  });

  testWidgets('isDismissible: false garde la feuille ouverte', (
    WidgetTester tester,
  ) async {
    await openSheet(tester, isDismissible: false);

    await tester.tapAt(const Offset(400, 80));
    await tester.pumpAndSettle();

    expect(find.text('Contenu'), findsOneWidget);
  });
}
