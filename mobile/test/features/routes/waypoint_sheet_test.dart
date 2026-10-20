import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/routes/presentation/widgets/waypoint_sheet.dart';

import '../../support/localization.dart';
import 'route_fixtures.dart';

/// La fiche d'un point de parcours (ledger `MOB-84`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> pump(WidgetTester tester, Widget details) => tester.pumpWidget(
    MaterialApp(
      theme: PedalonsTheme.build(Brightness.light),
      home: Scaffold(body: details),
    ),
  );

  testWidgets('type, nom, description et distance', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      WaypointDetails(
        waypoint: fixtureWaypoint(
          description: 'Ouvert dès 8 h.',
          distance: 12300,
        ),
        units: UnitSystem.metric,
      ),
    );
    expect(find.text('Ravitaillement'), findsOneWidget);
    expect(find.text('Café du Port'), findsOneWidget);
    expect(find.text('Ouvert dès 8 h.'), findsOneWidget);
    expect(
      find.text('À ${AppFormatters.formatDistance(12300)} du départ'),
      findsOneWidget,
    );
  });

  testWidgets('hors tracé : « Hors tracé »', (WidgetTester tester) async {
    await pump(
      tester,
      WaypointDetails(
        waypoint: fixtureWaypoint(distance: null),
        units: UnitSystem.metric,
      ),
    );
    expect(find.text('Hors tracé'), findsOneWidget);
    expect(find.textContaining('du départ'), findsNothing);
  });

  testWidgets('un nom vide met le type en titre', (WidgetTester tester) async {
    await pump(
      tester,
      WaypointDetails(
        waypoint: fixtureWaypoint(name: '', type: 'DANGER'),
        units: UnitSystem.metric,
      ),
    );
    expect(find.text('Danger'), findsOneWidget);
  });
}
