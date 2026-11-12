import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/profile/presentation/widgets/data_and_account_section.dart';

import '../../support/localization.dart';

/// MOB-32 — la carte « Vos données » lit les statuts du contrat.
///
/// Elle comparait à `COMPLETED`, statut que `UserExportStatus` n'a pas : un
/// export `READY` restait « En préparation… » pour toujours.
void main() {
  setUpAll(loadTestTranslations);

  Future<void> pumpCard(WidgetTester tester, UserExportDto? export) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [latestExportProvider.overrideWith((ref) async => export)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(body: DataExportCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  UserExportDto exportWith(String status, {String? expiresAt}) => UserExportDto(
    id: 'e1',
    status: status,
    requestedAt: '2026-09-01T10:00:00Z',
    expiresAt: expiresAt,
  );

  testWidgets('un export READY est prêt, avec sa date de fin', (
    WidgetTester tester,
  ) async {
    await pumpCard(
      tester,
      exportWith('READY', expiresAt: '2026-10-08T10:00:00Z'),
    );

    expect(find.textContaining('Prêt · valable jusqu'), findsOneWidget);
    expect(find.text('En préparation…'), findsNothing);
    expect(find.text('Nouvel export'), findsOneWidget);
  });

  testWidgets('un export EXPIRED le dit, et propose un nouvel export', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, exportWith('EXPIRED'));

    expect(
      find.text('Expiré · vous pouvez en demander un nouveau'),
      findsOneWidget,
    );
    expect(find.text('Nouvel export'), findsOneWidget);
  });

  testWidgets('un export PROCESSING est en préparation', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, exportWith('PROCESSING'));

    expect(find.text('En préparation…'), findsOneWidget);
    expect(find.text('Demander mes données'), findsOneWidget);
  });

  testWidgets('sans export, rien n\'a été demandé', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, null);

    expect(find.text('Jamais demandé'), findsOneWidget);
  });
}
