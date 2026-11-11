import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_usages_section.dart';
import 'package:pedalons/features/routes/providers/route_detail_provider.dart';

import '../../support/localization.dart';

/// S13 — « Utilisé dans » : un voyage rend sa plage de dates (`endDate`,
/// docs/LEDGER_*.md API-9), une sortie sa date et son heure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  const RouteKey key = RouteKey(teamSlug: 'n-peloton', routeSlug: 'boucle');

  Future<void> pump(WidgetTester tester, List<RouteUsageDto> usages) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routeUsagesProvider.overrideWith(
            (Ref ref, RouteKey k) async => usages,
          ),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RouteUsagesSection(routeKey: key),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  // Midi UTC : le même jour quel que soit le fuseau de la machine de test.
  RouteUsageDto usage({
    required String type,
    required String slug,
    String? endDate,
    List<String> via = const <String>[],
  }) => RouteUsageDto(
    timezone: 'Europe/Paris',
    type: type,
    slug: slug,
    name: slug,
    // Le vendredi 1er août 2036 (la base des fuseaux s'arrête en 2037).
    dateTime: '2036-08-01T12:00:00Z',
    endDate: endDate,
    teamSlug: 'n-peloton',
    referencedDirectly: true,
    viaChildNames: via,
  );

  testWidgets('un voyage rend sa plage de dates, au format unique (BRAND-8)', (
    WidgetTester tester,
  ) async {
    await pump(tester, <RouteUsageDto>[
      usage(type: 'TRIP', slug: 'alpes', endDate: '2036-08-04T12:00:00Z'),
    ]);

    // Jour de semaine abrégé, le mois une fois, l'année hors de l'année en
    // cours — comme le web (`RouteUsages`).
    expect(find.text('ven. 1 → lun. 4 août 2036'), findsOneWidget);
    expect(find.text('1 août → 4 août'), findsNothing);
  });

  testWidgets('une sortie, ou un voyage sans étape, garde sa date seule', (
    WidgetTester tester,
  ) async {
    await pump(tester, <RouteUsageDto>[
      usage(type: 'RIDE', slug: 'dimanche'),
      usage(type: 'TRIP', slug: 'nu'),
    ]);

    expect(find.textContaining('→'), findsNothing);
    expect(find.textContaining('1 août'), findsNWidgets(2));
  });

  // Ledger `MOB-139`, D25 : le pluriel suit le nombre d'étapes ; le titre
  // s'accorde à « parcours » (libelles 4.7).
  testWidgets('« via l’étape » pour une, « via les étapes : » pour plusieurs', (
    WidgetTester tester,
  ) async {
    await pump(tester, <RouteUsageDto>[
      usage(type: 'TRIP', slug: 'alpes', via: const <String>['J1']),
      usage(type: 'TRIP', slug: 'pyrenees', via: const <String>['J1', 'J3']),
    ]);

    expect(find.text('Utilisé dans'), findsOneWidget);
    expect(find.text('via l\'étape J1'), findsOneWidget);
    expect(find.text('via les étapes : J1, J3'), findsOneWidget);
  });
}
