import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/ads/presentation/widgets/ad_card.dart';

import '../../support/localization.dart';
import 'ad_fixtures.dart';

/// Ledger `MOB-139`, D11 (KIT §9) : la position d'une annonce est floutée à
/// ~1 km — la carte dit « Secteur {lieu} », sans icône d'épingle.
void main() {
  setUpAll(loadTestTranslations);

  testWidgets('le lieu se lit « Secteur … », sans épingle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdCard(
              ad: fixtureAd(locationDescription: 'Caluire-et-Cuire'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Secteur Caluire-et-Cuire'), findsOneWidget);
    expect(
      tester
          .widgetList<PdlStat>(find.byType(PdlStat))
          .where((PdlStat s) => s.icon == PdlIcons.place),
      isEmpty,
    );
    expect(find.byIcon(PdlIcons.place), findsNothing);
  });
}
