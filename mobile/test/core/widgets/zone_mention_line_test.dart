import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/core/widgets/zone_mention_line.dart';

import '../../support/localization.dart';

/// La seconde ligne d'un rendez-vous lu d'ailleurs (docs/LEDGER_*.md API-60,
/// plan §7).
void main() {
  setUpAll(loadTestTranslations);
  tearDown(() => AppFormatters.setDisplayTimezone(null));

  Future<void> pump(WidgetTester tester, String iso, String zone) =>
      tester.pumpWidget(
        MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: ZoneMentionLine.maybe(iso, zone) ?? const SizedBox.shrink(),
          ),
        ),
      );

  testWidgets('Paris lu de Bruxelles : rien', (WidgetTester tester) async {
    AppFormatters.setDisplayTimezone('Europe/Brussels');
    await pump(tester, '2026-10-11T06:00:00Z', 'Europe/Paris');

    expect(find.byType(ZoneMentionLine), findsNothing);
    expect(find.byIcon(PdlIcons.otherTimezone), findsNothing);
  });

  testWidgets('Tokyo lu de Paris : icône et mention, jour compris', (
    WidgetTester tester,
  ) async {
    AppFormatters.setDisplayTimezone('Europe/Paris');
    await pump(tester, '2026-10-10T21:00:00Z', 'Asia/Tokyo');

    expect(find.byIcon(PdlIcons.otherTimezone), findsOneWidget);
    expect(find.text('heure de Tokyo (sam. 23:00 chez vous)'), findsOneWidget);
  });
}
