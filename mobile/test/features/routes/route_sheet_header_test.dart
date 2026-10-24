import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_sheet_header.dart';

import '../../support/localization.dart';
import 'route_fixtures.dart';

/// L'équipe d'un parcours sur sa fiche (ledger `MOB-90`) : la ligne d'équipe
/// cliquable des autres détails, aux crans hauts seulement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> pump(WidgetTester tester, {required double extent}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unitSystemProvider.overrideWithValue(UnitSystem.metric)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: RouteSheetHeader(route: fixtureRouteDetail(), extent: extent),
          ),
        ),
      ),
    );
  }

  testWidgets('le cran déployé porte la ligne d\'équipe, cliquable', (
    WidgetTester tester,
  ) async {
    await pump(tester, extent: 0.5);

    final PdlTeamLine line = tester.widget<PdlTeamLine>(
      find.byType(PdlTeamLine),
    );
    expect(line.label, 'N-Peloton');
    expect(line.onTap, isNotNull);
  });

  testWidgets('la bande du cran bas ne la porte pas', (
    WidgetTester tester,
  ) async {
    await pump(tester, extent: 0.18);

    expect(find.byType(PdlTeamLine), findsNothing);
  });
}
