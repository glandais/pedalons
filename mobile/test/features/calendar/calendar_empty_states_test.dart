import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/calendar/presentation/pages/calendar_page.dart';
import 'package:pedalons/features/calendar/presentation/widgets/calendar_subscription_card.dart';
import 'package:pedalons/features/calendar/providers/calendar_month_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

import '../../support/localization.dart';

/// Les deux vides du calendrier (audit des listes, défauts DL3 et DL4) :
///
/// * « Ce mois contient des événements, mais aucun ne correspond… » ne se dit
///   que si le mois **a** des événements ; un mois vide, filtre posé ou non,
///   reste le vide du mois ;
/// * dans le calendrier d'une équipe, c'est « L'équipe n'a publié… », pas
///   « Vos équipes n'ont publié… ».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  /// Une étape de voyage au milieu du mois courant — celui où le calendrier
  /// s'ouvre.
  CalendarEventDto stageThisMonth() {
    final DateTime now = AppFormatters.displayNow();
    final String start = DateTime.utc(
      now.year,
      now.month,
      15,
      8,
    ).toIso8601String();
    return CalendarEventDto(
      timezone: 'Europe/Paris',
      id: start,
      title: 'Étape $start',
      start: start,
      allDay: false,
      type: 'TRIP_STAGE',
      teamSlug: 'n-peloton',
      teamName: 'N-Peloton',
      entitySlug: 'etape',
      registered: false,
      status: 'PUBLISHED',
      finished: false,
    );
  }

  Future<void> open(
    WidgetTester tester, {
    required String? teamSlug,
    required List<CalendarEventDto> events,
    CalendarTypeFilter type = CalendarTypeFilter.all,
    bool registeredOnly = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarMonthProvider.overrideWith(
            (ref, key) async => CalendarMonth.fromEvents(events),
          ),
          calendarNextMonthWithEventsProvider.overrideWith(
            (ref, key) async => null,
          ),
          calendarTokenProvider.overrideWith(
            (ref) => Completer<CalendarTokenDto>().future,
          ),
          myTeamsProvider.overrideWith((ref) async => <TeamDetailDto>[]),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: CalendarPage(
              teamSlug: teamSlug,
              embedded: true,
              typeFilter: type,
              onTypeChanged: (_) {},
              registeredOnly: registeredOnly,
            ),
          ),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  const String filteredTitle = 'Aucun événement pour ces filtres';
  const String monthEmptyTitle = 'Aucun événement ce mois-ci';

  group('DL3 — vide filtré seulement si le mois a des événements', () {
    testWidgets('un mois qui a des événements, aucun du type choisi : le '
        'vide filtré', (WidgetTester tester) async {
      await open(
        tester,
        teamSlug: 'n-peloton',
        events: <CalendarEventDto>[stageThisMonth()],
        type: CalendarTypeFilter.rides,
      );

      expect(find.text(filteredTitle), findsOneWidget);
      // RL10 : le message nomme les filtres posés.
      expect(find.text('Rien ne correspond à : Sorties.'), findsOneWidget);
      expect(find.text('Effacer les filtres'), findsOneWidget);
      expect(find.text(monthEmptyTitle), findsNothing);
    });

    testWidgets('RL10 — « Je participe » est nommé avec le type', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teamSlug: 'n-peloton',
        events: <CalendarEventDto>[stageThisMonth()],
        type: CalendarTypeFilter.rides,
        registeredOnly: true,
      );

      expect(
        find.text('Rien ne correspond à : Je participe · Sorties.'),
        findsOneWidget,
      );
    });

    testWidgets('un mois vide, filtre posé : le vide du mois', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teamSlug: 'n-peloton',
        events: const <CalendarEventDto>[],
        type: CalendarTypeFilter.rides,
        registeredOnly: true,
      );

      expect(find.text(monthEmptyTitle), findsOneWidget);
      expect(find.text(filteredTitle), findsNothing);
      expect(
        find.textContaining('Ce mois contient des événements'),
        findsNothing,
      );
    });
  });

  group('DL4 — le message du mois vide nomme la bonne portée', () {
    testWidgets('dans une équipe : « L\'équipe n\'a publié… »', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teamSlug: 'n-peloton',
        events: const <CalendarEventDto>[],
      );

      expect(find.textContaining("L'équipe n'a publié"), findsOneWidget);
      expect(find.textContaining("Vos équipes n'ont publié"), findsNothing);
    });

    testWidgets('au calendrier global : « Vos équipes n\'ont publié… »', (
      WidgetTester tester,
    ) async {
      await open(tester, teamSlug: null, events: const <CalendarEventDto>[]);

      expect(find.textContaining("Vos équipes n'ont publié"), findsOneWidget);
    });
  });

  testWidgets('RL10 — le mois s\'écrit en minuscule dans la phrase', (
    WidgetTester tester,
  ) async {
    await open(tester, teamSlug: null, events: const <CalendarEventDto>[]);

    final String month = AppFormatters.formatMonthAndYear(
      AppFormatters.displayNow(),
    );
    expect(month, month.toLowerCase());
    expect(
      find.text(
        "Vos équipes n'ont publié aucune sortie ni étape de voyage en $month.",
      ),
      findsOneWidget,
    );
  });
}
