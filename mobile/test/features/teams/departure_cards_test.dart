import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/core/widgets/zone_mention_line.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/calendar/presentation/widgets/agenda_card.dart';
import 'package:pedalons/features/rides/providers/participation_changes.dart';
import 'package:pedalons/features/teams/presentation/widgets/publication_card.dart';
import 'package:pedalons/features/trips/presentation/widgets/stage_card.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import '../trips/trip_fixtures.dart';

/// Ledgers `MOB-114` et `MOB-115` (règle `BRAND-8`, BRANDING §7.1, §7.8,
/// §8.3) : sur les cartes du fil, la date quitte la rangée de statistiques
/// pour la boîte du jour posée sur l'image et une ligne « Départ 09:00 » en
/// 700 sous le titre ; l'agenda met l'heure en tête et en gras ; la carte
/// d'étape ne tronque plus l'heure.
///
/// Dates en 2036 : la base des fuseaux embarquée s'arrête en 2037.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    AppFormatters.setDisplayTimezone('Europe/Paris');
  });
  tearDown(() => AppFormatters.setDisplayTimezone(null));

  const TeamPublicationDto team = TeamPublicationDto(
    id: 't1',
    slug: 'n-peloton',
    name: 'N-Peloton',
    visibility: 'PUBLIC',
  );
  const MediaDto media = MediaDto(
    markdown: '',
    assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
  );

  // Mardi 29 juillet 2036, 21:30 à Paris ; retour à 23:40.
  PublicationDtoRide ride({
    String dateTime = '2036-07-29T19:30:00Z',
    String endDateTime = '2036-07-29T21:40:00Z',
    bool finished = false,
    int groupCount = 2,
  }) => PublicationDtoRide(
    timezone: 'Europe/Paris',
    tags: const <TagDto>[],
    groupSummaries: const <RideGroupSummaryDto>[],
    team: team,
    id: 'r1',
    slug: 'np-665',
    name: 'N-Peloton #665',
    media: media,
    dateTime: dateTime,
    endDateTime: endDateTime,
    status: 'PUBLISHED',
    visibility: 'TEAM',
    participantCount: 10,
    groupCount: groupCount,
    groups: const <RideGroupDto>[],
    topParticipants: const <PublicUserDto>[],
    deleted: false,
    registered: false,
    full: false,
    finished: finished,
  );

  // Du vendredi 17 octobre 2036, 09:00 à Paris, au dimanche 19.
  const PublicationDtoTrip trip = PublicationDtoTrip(
    team: team,
    id: 'trip1',
    slug: 'gtmc',
    name: 'GTMC',
    media: media,
    dateTime: '2036-10-17T07:00:00Z',
    timezone: 'Europe/Paris',
    endDateTime: '2036-10-19T16:00:00Z',
    status: 'PUBLISHED',
    finished: false,
    visibility: 'PUBLIC',
    participantCount: 3,
    stageCount: 3,
    stages: <TripStageDto>[],
    participants: <PublicUserDto>[],
    deleted: false,
    registered: false,
    tags: <TagDto>[],
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 1000,
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          unitSystemProvider.overrideWithValue(UnitSystem.metric),
          authProvider.overrideWith((ref) => _StubAuthNotifier(ref)),
          registrationOverridesProvider.overrideWith(
            (ref) => const <String, bool>{},
          ),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(brightness),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 3000),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder onImage(Type type) => find.descendant(
    of: find.byType(PdlCardMedia),
    matching: find.byType(type),
  );

  group('carte de sortie du fil', () {
    testWidgets('une sortie sans groupe n’a pas de compteur de personnes', (
      WidgetTester tester,
    ) async {
      await pump(tester, PublicationCard(publication: ride(groupCount: 0)));
      expect(find.textContaining('personne'), findsNothing);
      await pump(tester, PublicationCard(publication: ride()));
      expect(find.textContaining('10 personnes'), findsOneWidget);
    });

    testWidgets('boîte du jour posée sur l’image, « Départ 21:30 » en 700 '
        'sous le titre, et plus de date dans les statistiques', (
      WidgetTester tester,
    ) async {
      await pump(tester, PublicationCard(publication: ride()));

      expect(onImage(PdlDayBox), findsOneWidget);
      final PdlDayBox box = tester.widget<PdlDayBox>(find.byType(PdlDayBox));
      expect(box.posed, isTrue);
      expect(box.weekday, 'mar.');
      expect(box.day, '29');

      final Text headline = tester.widget<Text>(find.text('Départ 21:30'));
      expect(headline.style?.fontWeight, FontWeight.w700);
      expect(headline.style?.fontSize, 16);
      expect(find.textContaining('retour vers'), findsNothing);

      // La date n'est plus une statistique (BRAND-8).
      expect(
        tester
            .widgetList<PdlStat>(find.byType(PdlStat))
            .where((PdlStat s) => s.icon == PdlIcons.date),
        isEmpty,
      );
      // Ni « Aujourd'hui » ni « Demain » : pas de pastille.
      expect(find.byType(PdlDayPill), findsNothing);
    });

    testWidgets('demain : la pastille « Demain » en haut de l’image', (
      WidgetTester tester,
    ) async {
      final DateTime tomorrow = DateTime.now().toUtc().add(
        const Duration(days: 1),
      );
      await pump(
        tester,
        PublicationCard(
          publication: ride(
            dateTime: tomorrow.toIso8601String(),
            endDateTime: tomorrow
                .add(const Duration(hours: 3))
                .toIso8601String(),
          ),
        ),
      );

      expect(onImage(PdlDayPill), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PdlDayPill),
          matching: find.text('Demain'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('une sortie passée n’annonce pas « Aujourd’hui »', (
      WidgetTester tester,
    ) async {
      final DateTime earlier = DateTime.now().toUtc().subtract(
        const Duration(minutes: 1),
      );
      await pump(
        tester,
        PublicationCard(
          publication: ride(
            dateTime: earlier.toIso8601String(),
            endDateTime: earlier.toIso8601String(),
            finished: true,
          ),
        ),
      );

      expect(find.byType(PdlDayPill), findsNothing);
    });

    testWidgets('le lecteur d’écran lit le départ et son jour d’un tenant', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pump(tester, PublicationCard(publication: ride()));

      expect(
        find.bySemanticsLabel('Départ 21:30, mar. 29 juil. 2036'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    for (final Brightness brightness in Brightness.values) {
      testWidgets('à 320 px en ${brightness.name}, rien ne déborde', (
        WidgetTester tester,
      ) async {
        await pump(
          tester,
          PublicationCard(publication: ride()),
          width: 320,
          brightness: brightness,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Départ 21:30'), findsOneWidget);
      });
    }
  });

  group('carte de voyage du fil', () {
    testWidgets('boîte du jour turquoise posée, « Départ 09:00 » et la plage '
        'du voyage', (WidgetTester tester) async {
      await pump(tester, const PublicationCard(publication: trip));

      expect(onImage(PdlDayBox), findsOneWidget);
      final PdlDayBox box = tester.widget<PdlDayBox>(find.byType(PdlDayBox));
      expect(box.posed, isTrue);
      expect(box.tone, isNotNull);
      expect(box.day, '17');
      expect(find.text('Départ 09:00'), findsOneWidget);
      // 2036 n'est pas l'année en cours : la plage la dit (BRANDING §8.3).
      expect(find.text('ven. 17 → dim. 19 oct. 2036'), findsOneWidget);
      expect(
        tester
            .widgetList<PdlStat>(find.byType(PdlStat))
            .where((PdlStat s) => s.icon == PdlIcons.date),
        isEmpty,
      );
    });

    testWidgets('lu d’ailleurs, la mention commente l’heure affichée', (
      WidgetTester tester,
    ) async {
      AppFormatters.setDisplayTimezone('America/New_York');
      await pump(tester, const PublicationCard(publication: trip));

      // 07:00Z en octobre : 09:00 à Paris, 03:00 à New York.
      expect(find.text('Départ 09:00'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ZoneMentionLine),
          matching: find.textContaining('03:00'),
        ),
        findsOneWidget,
      );
    });
  });

  group('agenda du calendrier', () {
    const CalendarEventDto event = CalendarEventDto(
      id: 'e1',
      title: 'N-Peloton #665',
      start: '2036-07-29T19:30:00Z',
      allDay: false,
      type: 'RIDE',
      teamSlug: 'n-peloton',
      teamName: 'N-Peloton des collines et des vallées',
      entitySlug: 'np-665',
      registered: false,
      status: 'PUBLISHED',
      timezone: 'Europe/Paris',
      finished: false,
      startPlaceName: 'Parking du lac de la Cassière, côté plage',
    );

    testWidgets('l’heure en tête et en gras, jamais tronquée, même étroit', (
      WidgetTester tester,
    ) async {
      await pump(tester, const AgendaCard(event: event), width: 260);

      final Finder time = find.text('21:30');
      expect(time, findsOneWidget);
      expect(tester.widget<Text>(time).style?.fontWeight, FontWeight.w700);
      expect(
        tester.renderObject<RenderParagraph>(time).didExceedMaxLines,
        isFalse,
      );
      // L'heure n'est plus au milieu de « Équipe · 21:30 · Lieu ».
      expect(find.textContaining('· 21:30 ·'), findsNothing);
      expect(
        find.textContaining('N-Peloton des collines et des vallées · Parking'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    test('l’en-tête de jour dit le jour de semaine, et « Demain »', () {
      final DateTime day = DateTime(2036, 7, 29);
      expect(
        calendarDayLabel(day, now: DateTime(2036, 7, 29, 10)),
        'Aujourd\'hui · mardi 29 juillet',
      );
      expect(
        calendarDayLabel(day, now: DateTime(2036, 7, 28, 23)),
        'Demain · mardi 29 juillet',
      );
      expect(
        calendarDayLabel(day, now: DateTime(2036, 7, 27)),
        'mardi 29 juillet',
      );
    });
  });

  group('carte d’étape', () {
    // Mardi 12 août 2036, 08:30 à Paris.
    final TripStageDto stage = fixtureStage(
      index: 1,
      name: 'Clermont-Ferrand → Issoire par les crêtes',
      dateTime: '2036-08-12T06:30:00Z',
    );

    testWidgets('« mar. 12 août 2036 · 08:30 » sur une ligne en 600, '
        'l’heure jamais tronquée, même étroit et en grand texte', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        StageCard(stage: stage, selected: false, onTap: () {}),
        width: 300,
        textScale: 1.3,
      );

      final Finder line = find.byKey(keys.trip.stageDeparture('j1'));
      expect(line, findsOneWidget);
      final Finder text = find.descendant(
        of: line,
        matching: find.text('mar. 12 août 2036 · 08:30'),
      );
      expect(text, findsOneWidget);
      expect(tester.widget<Text>(text).style?.fontWeight, FontWeight.w600);
      expect(
        tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(Ref ref)
    : super(_FakeAuthRepository(), _FakeSecureStorage(), ref) {
    state = const AuthState(isInitialized: true);
  }
}
