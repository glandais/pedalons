import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl_month_grid.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// Les marqueurs de la grille de mois — S22-1 et cas de test §5.3-5.
void main() {
  const List<String> weekdays = <String>[
    'Lun',
    'Mar',
    'Mer',
    'Jeu',
    'Ven',
    'Sam',
    'Dim',
  ];

  Future<PdlColors> pump(
    WidgetTester tester,
    PdlMonthGrid grid, {
    Brightness brightness = Brightness.light,
  }) async {
    late PdlColors colors;
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(brightness),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              colors = context.pdl;
              return grid;
            },
          ),
        ),
      ),
    );
    return colors;
  }

  /// La décoration du disque portant le numéro [day].
  ///
  /// `last` et non `first` : la grille de juillet 2026 affiche **deux** cases
  /// « 29 » — le 29 juin de débordement puis le 29 juillet — et c'est celle du
  /// mois affiché qui compte.
  BoxDecoration numberDecoration(WidgetTester tester, int day) {
    final Finder container = find
        .ancestor(of: find.text('$day').last, matching: find.byType(Container))
        .first;
    return tester.widget<Container>(container).decoration! as BoxDecoration;
  }

  testWidgets('« aujourd\'hui » et « inscrit » se cumulent sur la même case', (
    WidgetTester tester,
  ) async {
    final PdlColors c = await pump(
      tester,
      PdlMonthGrid(
        year: 2026,
        month: 7,
        weekdayLabels: weekdays,
        today: DateTime(2026, 7, 22),
        isRegistered: (DateTime d) => d.day == 22 || d.day == 29,
      ),
    );

    // Le 22 est les deux : aplat indigo **et** anneau, ce dernier en `onPrimary`
    // pour rester visible sur l'aplat. La maquette les rendait exclusifs.
    final BoxDecoration both = numberDecoration(tester, 22);
    expect(both.color, c.primary);
    expect(both.border, isNotNull);
    expect((both.border! as Border).top.color, c.onPrimary);

    // Le 29 n'est qu'inscrit : anneau `primary`, aucun aplat.
    final BoxDecoration registeredOnly = numberDecoration(tester, 29);
    expect(registeredOnly.color, isNull);
    expect((registeredOnly.border! as Border).top.color, c.primary);

    // Le 23 n'est ni l'un ni l'autre.
    final BoxDecoration plain = numberDecoration(tester, 23);
    expect(plain.color, isNull);
    expect(plain.border, isNull);
  });

  testWidgets('un jour hors mois ne porte jamais de point', (
    WidgetTester tester,
  ) async {
    final List<DateTime> asked = <DateTime>[];
    await pump(
      tester,
      PdlMonthGrid(
        year: 2026,
        month: 7,
        weekdayLabels: weekdays,
        // Juillet 2026 déborde sur le 29 juin et le 2 août : les deux tombent
        // un lundi / dimanche et portent le même numéro qu'un jour du mois.
        dotsOf: (DateTime d) {
          asked.add(d);
          return const <Color>[Color(0xFF228BE6)];
        },
      ),
    );

    expect(
      asked.every((DateTime d) => d.month == 7),
      isTrue,
      reason: 'la grille ne demande pas de points aux jours de débordement',
    );
  });

  testWidgets('le libellé d\'accessibilité remplace le numéro nu', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      PdlMonthGrid(
        year: 2026,
        month: 7,
        weekdayLabels: weekdays,
        onDayTap: (_) {},
        daySemanticLabel: (DateTime d) =>
            d.day == 22 ? 'mercredi 22 juillet, 2 événements' : '${d.day}',
      ),
    );

    expect(
      find.bySemanticsLabel('mercredi 22 juillet, 2 événements'),
      findsOneWidget,
    );
  });

  testWidgets('les week-ends sont teintés, les jours ouvrés non', (
    WidgetTester tester,
  ) async {
    final PdlColors c = await pump(
      tester,
      PdlMonthGrid(year: 2026, month: 7, weekdayLabels: weekdays),
    );

    // Deux `DecoratedBox` enveloppent le numéro : celui du disque, construit
    // par le `Container`, puis celui de la case. C'est le second qu'on mesure.
    BoxDecoration cellOf(int day) {
      final Finder box = find
          .ancestor(
            of: find.text('$day').last,
            matching: find.byType(DecoratedBox),
          )
          .at(1);
      return tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
    }

    // 4 juillet 2026 est un samedi, le 6 un lundi.
    expect(cellOf(4).color, c.surfaceAlt);
    expect(cellOf(6).color, isNull);
  });
}
