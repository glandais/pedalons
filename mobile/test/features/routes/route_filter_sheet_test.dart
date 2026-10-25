import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/features/routes/domain/route_filters.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_filter_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F-DE-5 — « Trier par » écrasé à 1 pt.
///
/// La feuille était un `Column` dans un `SingleChildScrollView` dans un
/// `Flexible`, sous un parent `MainAxisSize.min`, avec le bouton de validation
/// **hors** du défilement. Quand le contenu dépassait, la dernière ligne ne
/// disparaissait pas : elle s'écrasait. Elle existait toujours, elle était
/// même tapable, mais elle n'était plus ni lisible ni atteignable — un défaut
/// qu'aucune assertion de présence n'attrape.
///
/// D'où un test qui **mesure**. Il ne demande pas « la ligne est-elle là ? »
/// mais « fait-elle sa hauteur ? », dans le cas exact qui produisait
/// l'effondrement : tous les filtres actifs et un agrandissement
/// typographique de 130 %.
///
/// Le test n'installe pas easy_localization : sans lui `.tr()` rend la clé,
/// ce qui suffit à repérer une ligne et évite de faire dépendre une mesure de
/// mise en page d'un chargement d'assets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String windRow = 'routes.filters.windDirection';
  const String sortRow = 'routes.filters.sort';

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  /// Tous les filtres contraints à la fois : c'est le contenu le plus haut que
  /// la feuille puisse avoir, donc celui qui la faisait s'effondrer.
  const RouteFilters everythingSet = RouteFilters(
    search: 'galibier',
    minDistance: 30000,
    maxDistance: 90000,
    minElevationGain: 500,
    maxElevationGain: 2500,
    hilliness: Hilliness.hilly,
    surfaceType: SurfaceType.gravel,
    windDirection: WindDirection.north,
  );

  Future<void> openSheet(
    WidgetTester tester, {
    required double textScale,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showRouteFilterSheet(context, filters: everythingSet),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  /// La hauteur rendue d'une ligne de navigation, repérée par son libellé.
  double rowHeight(WidgetTester tester, String label) {
    final Finder tile = find.ancestor(
      of: find.text(label),
      matching: find.byType(ListTile),
    );
    expect(tile, findsOneWidget, reason: '« $label » n\'est pas rendue');
    return tester.getSize(tile).height;
  }

  Future<void> expectRowsKeepTheirHeight(
    WidgetTester tester,
    double textScale,
  ) async {
    await openSheet(tester, textScale: textScale);
    for (final String label in <String>[windRow, sortRow]) {
      // Il faut d'abord les amener à l'écran : elles sont en bas d'un corps
      // qui défile — ce qui est précisément le comportement attendu, au lieu
      // de s'écraser pour tenir sans défilement.
      await tester.scrollUntilVisible(find.text(label), 200);
      await tester.pumpAndSettle();
      expect(
        rowHeight(tester, label),
        greaterThanOrEqualTo(kFilterNavigationRowHeight),
        reason: '« $label » est écrasée à un facteur $textScale',
      );
    }
  }

  testWidgets(
    'les lignes de navigation gardent leurs 52 px avec tous les filtres actifs',
    (WidgetTester tester) => expectRowsKeepTheirHeight(tester, 1.0),
  );

  testWidgets(
    'elles y résistent à un agrandissement de 130 %',
    (WidgetTester tester) => expectRowsKeepTheirHeight(tester, 1.3),
  );

  testWidgets('le bouton de validation reste hors du défilement', (
    WidgetTester tester,
  ) async {
    // L'autre moitié de la correction : le corps défile, le pied ne bouge
    // pas. Si le pied défilait avec le corps, il faudrait atteindre le bas
    // d'une liste de filtres pour pouvoir valider.
    await openSheet(tester, textScale: 1.3);
    final Finder apply = find.textContaining('routes.filters.apply');
    expect(apply, findsOneWidget);
    expect(
      find.ancestor(of: apply, matching: find.byType(Scrollable)),
      findsNothing,
      reason: 'le bouton de validation ne doit pas vivre dans le défileur',
    );
    // Le champ de recherche de la feuille porte un debounce de 350 ms : sans
    // ce délai, le binding se plaint d'un timer encore en vol au démontage.
    await tester.pump(const Duration(seconds: 1));
  });
}
