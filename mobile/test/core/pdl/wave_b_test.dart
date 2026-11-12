import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// Les trois points de la vague B qui se cassent sans qu'on le voie :
/// le premier jour de la semaine, la hauteur figée d'une rangée de chips, et
/// un compteur de pagination sans total.
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

  group('PdlMonthGrid.composeMonth', () {
    test('la semaine commence toujours un lundi et finit un dimanche', () {
      for (final (int year, int month) in const <(int, int)>[
        (2026, 7),
        (2026, 2),
        (2024, 2),
        (2026, 11),
      ]) {
        final List<PdlMonthCell> cells = PdlMonthGrid.composeMonth(year, month);
        expect(cells.length % 7, 0, reason: '$year-$month');
        expect(cells.first.date.weekday, DateTime.monday);
        expect(cells.last.date.weekday, DateTime.sunday);
      }
    });

    test('juillet 2026 tient en 35 cases, du 29 juin au 2 août', () {
      final List<PdlMonthCell> cells = PdlMonthGrid.composeMonth(2026, 7);
      expect(cells.length, 35);
      expect(cells.first.date, DateTime(2026, 6, 29));
      expect(cells.first.inMonth, isFalse);
      expect(cells.last.date, DateTime(2026, 8, 2));
      expect(cells.where((PdlMonthCell c) => c.inMonth).length, 31);
    });

    test('février bissextile rend bien ses 29 jours', () {
      final List<PdlMonthCell> cells = PdlMonthGrid.composeMonth(2024, 2);
      expect(cells.where((PdlMonthCell c) => c.inMonth).length, 29);
      // 2024-02-01 est un jeudi : la grille démarre le lundi 29 janvier.
      expect(cells.first.date, DateTime(2024, 1, 29));
    });
  });

  testWidgets('PdlChipRow mesure sa hauteur, elle n\'est pas figée', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      PdlChipRow(
        children: <Widget>[
          PdlChip(label: 'Tout', selected: true, onTap: () {}),
          PdlChip(label: 'Sorties', onTap: () {}),
        ],
      ),
    );
    final double normal = tester.getSize(find.byType(PdlChipRow)).height;
    expect(normal, greaterThanOrEqualTo(44));

    // La rangée prend la hauteur de ce qu'elle porte : un enfant plus haut la
    // fait grandir, là où un `SizedBox(height: 44)` l'aurait rognée. C'est
    // exactement le défaut F-DE-3.
    await pump(
      tester,
      const PdlChipRow(children: <Widget>[SizedBox(height: 80, width: 60)]),
    );
    expect(tester.getSize(find.byType(PdlChipRow)).height, 80);
  });

  testWidgets('PdlPagedListFooter affiche le compteur avec son total', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      const PdlPagedListFooter(
        isLoadingNext: true,
        hasMore: true,
        isEmpty: false,
        progressLabel: '8 participants sur 40',
        loadingLabel: 'chargement de la suite...',
        endLabel: 'Vous avez tout vu',
        errorLabel: 'Impossible de charger la suite.',
        retryLabel: 'Réessayer',
      ),
    );
    expect(
      find.text('8 participants sur 40 · chargement de la suite...'),
      findsOneWidget,
    );
  });

  testWidgets('en fin de liste, « Vous avez tout vu » ferme la lecture', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      const PdlPagedListFooter(
        isLoadingNext: false,
        hasMore: false,
        isEmpty: false,
        progressLabel: '40 participants sur 40',
        loadingLabel: 'chargement de la suite...',
        endLabel: 'Vous avez tout vu',
        errorLabel: 'Impossible de charger la suite.',
        retryLabel: 'Réessayer',
      ),
    );
    // Un seul pied, une seule ligne (règle RL12 des listes).
    expect(
      find.text('40 participants sur 40 · Vous avez tout vu'),
      findsOneWidget,
    );
  });

  testWidgets('PdlPersonRow ne rend rien quand organizerFlag est faux', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      const PdlPersonRow(name: 'Hélène Ebrard', organizerLabel: 'Organisateur'),
    );
    expect(find.text('Organisateur'), findsNothing);

    await pump(
      tester,
      const PdlPersonRow(
        name: 'Antoine Yvon',
        organizerFlag: true,
        organizerLabel: 'Organisateur',
      ),
    );
    expect(find.text('Organisateur'), findsOneWidget);
    expect(
      tester.getSize(find.byType(PdlPersonRow)).height,
      greaterThanOrEqualTo(PdlPersonRow.minHeight),
    );
  });

  testWidgets('PdlEmptyState rend ses quatre variantes', (
    WidgetTester tester,
  ) async {
    for (final PdlEmptyVariant variant in PdlEmptyVariant.values) {
      await pump(
        tester,
        PdlEmptyState(
          variant: variant,
          title: 'Titre ${variant.name}',
          message: 'Une phrase.',
        ),
      );
      await tester.pump();
      expect(find.text('Titre ${variant.name}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
