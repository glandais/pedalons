import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/calendar/presentation/pages/calendar_page.dart';
import 'package:pedalons/features/calendar/presentation/widgets/calendar_subscription_card.dart';
import 'package:pedalons/features/calendar/providers/calendar_month_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import '../teams/team_fixtures.dart';

/// Règle RL2 des listes (KIT §10) au calendrier global : la puce « Portée »,
/// neutre sur « Toutes mes équipes », teintée sur une équipe, dont la feuille
/// à coche liste « Toutes mes équipes / {équipe}… » — à la place de la rangée
/// de puces d'équipe, coupée dès trois équipes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  Future<ProviderContainer> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        calendarMonthProvider.overrideWith(
          (ref, key) async =>
              CalendarMonth.fromEvents(const <CalendarEventDto>[]),
        ),
        calendarNextMonthWithEventsProvider.overrideWith(
          (ref, key) async => null,
        ),
        calendarTokenProvider.overrideWith(
          (ref) => Completer<CalendarTokenDto>().future,
        ),
        myTeamsProvider.overrideWith(
          (ref) async => <TeamDetailDto>[
            fixtureTeam(slug: 'velo-club', name: 'Vélo Club des Monts'),
            fixtureTeam(slug: 'gravel', name: 'Gravel Bretagne'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(body: CalendarPage(embedded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  PdlChip chip(WidgetTester tester) => tester.widget<PdlChip>(
    find.descendant(
      of: find.byKey(keys.calendar.scopeChip),
      matching: find.byType(PdlChip),
    ),
  );

  testWidgets('une seule puce de portée, en tête, sans puce par équipe', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(find.byKey(keys.calendar.scopeChip), findsOneWidget);
    expect(chip(tester).label, 'Toutes mes équipes');
    expect(chip(tester).selected, isFalse);
    expect(find.text('Vélo Club des Monts'), findsNothing);
    expect(find.text('Gravel Bretagne'), findsNothing);
  });

  testWidgets('la feuille à coche liste les équipes ; en choisir une teinte '
      'la puce et change d\'endpoint', (WidgetTester tester) async {
    final ProviderContainer container = await open(tester);

    await tester.tap(find.byKey(keys.calendar.scopeChip));
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Portée'), findsOneWidget);
    expect(find.text('Vélo Club des Monts'), findsOneWidget);
    expect(find.text('Gravel Bretagne'), findsOneWidget);
    expect(find.byIcon(PdlIcons.check), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PdlSheet),
        matching: find.byIcon(PdlIcons.chevronRight),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Gravel Bretagne'));
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(calendarMonthKeyProvider(null)).teamSlug, 'gravel');
    expect(chip(tester).label, 'Gravel Bretagne');
    expect(chip(tester).selected, isTrue);
  });
}
