import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/calendar/presentation/pages/calendar_page.dart';
import 'package:pedalons/features/calendar/presentation/widgets/calendar_subscription_card.dart';
import 'package:pedalons/features/calendar/providers/calendar_month_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

import 'package:shared_preferences/shared_preferences.dart';

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
    List<CalendarEventDto> Function()? read,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Une carte d'agenda lit les préférences (unités) : sans miroir, elle ne
    // se construit pas.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          calendarMonthProvider.overrideWith(
            (ref, key) async =>
                CalendarMonth.fromEvents(read?.call() ?? events),
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

  group('tirer pour rafraîchir relit le mois', () {
    Future<void> pull(WidgetTester tester, Finder from) async {
      // La secousse de `PdlRefresh` passe par le canal de plate-forme : sans
      // réponse, le rafraîchissement l'attendrait indéfiniment.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      // L'écran de test fait 3 000 px de haut, et l'indicateur s'arme au
      // sixième de la hauteur du défileur : un geste court n'y suffirait pas.
      await tester.fling(from, const Offset(0, 900), 1000);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('un mois vide se tire : l\'événement publié depuis apparaît', (
      WidgetTester tester,
    ) async {
      int reads = 0;
      List<CalendarEventDto> events = const <CalendarEventDto>[];
      await open(
        tester,
        teamSlug: 'n-peloton',
        events: events,
        read: () {
          reads++;
          return events;
        },
      );
      expect(reads, 1);
      expect(find.text(monthEmptyTitle), findsOneWidget);

      final CalendarEventDto stage = stageThisMonth();
      events = <CalendarEventDto>[stage];
      await pull(tester, find.text(monthEmptyTitle));

      expect(reads, 2);
      expect(find.text(monthEmptyTitle), findsNothing);
      expect(find.text(stage.title), findsOneWidget);
    });

    testWidgets('un agenda rempli se tire : l\'événement retiré disparaît', (
      WidgetTester tester,
    ) async {
      int reads = 0;
      final CalendarEventDto stage = stageThisMonth();
      List<CalendarEventDto> events = <CalendarEventDto>[stage];
      await open(
        tester,
        teamSlug: 'n-peloton',
        events: events,
        read: () {
          reads++;
          return events;
        },
      );
      expect(reads, 1);

      events = const <CalendarEventDto>[];
      await pull(tester, find.text(stage.title));

      expect(reads, 2);
      expect(find.text(stage.title), findsNothing);
      expect(find.text(monthEmptyTitle), findsOneWidget);
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
