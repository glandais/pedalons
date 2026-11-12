import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_climbs_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';

/// S13/S25 — une montée porte le nom du waypoint posé à son sommet
/// (`ClimbDto.name`, docs/LEDGER_*.md API-10) ; sans lui, « Montée N ».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  ClimbDto climb({String? name}) => ClimbDto(
    startDistance: 1000,
    endDistance: 3000,
    elevationGain: 150,
    averageGradient: 7.5,
    maxGradient: 10.2,
    category: 'CAT4',
    parts: const <ClimbPartDto>[],
    name: name,
  );

  Future<void> pumpSection(WidgetTester tester, List<ClimbDto> climbs) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RouteClimbsSection(climbs: climbs),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('une montée nommée rend son nom, les autres leur numéro', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, <ClimbDto>[
      climb(name: 'Col du Glandon'),
      climb(),
    ]);

    expect(find.text('Col du Glandon'), findsOneWidget);
    expect(find.text('Montée 1'), findsNothing);
    expect(find.text('Montée 2'), findsOneWidget);
  });

  // docs/LEDGER_*.md MOB-45 — « Cols et montées (1) » pour une seule montée.
  testWidgets('le titre est au singulier pour une seule montée', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, <ClimbDto>[climb()]);
    expect(find.textContaining('Col ou montée (1)'), findsOneWidget);
    expect(find.textContaining('Cols et montées'), findsNothing);
  });

  testWidgets('le titre est au pluriel à partir de deux montées', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, <ClimbDto>[climb(), climb()]);
    expect(find.textContaining('Cols et montées (2)'), findsOneWidget);
  });
}
