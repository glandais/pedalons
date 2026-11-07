import 'package:flutter/material.dart';
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
import 'package:pedalons/features/rides/providers/participation_changes.dart';
import 'package:pedalons/features/teams/presentation/widgets/dashboard/dashboard_rides.dart';
import 'package:pedalons/features/teams/presentation/widgets/publication_card.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';

/// `docs/LEDGER_*.md MOB-112` : la carte du fil, la carte « Sorties à venir »
/// et la ligne « Vos prochaines sorties » donnent le départ **qui concerne la
/// personne** — celui de son groupe quand elle y est inscrite, celui de la
/// sortie sinon, y compris après une désinscription faite dans l'app.
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

  // 19:30Z le 29 juillet 2036 (la base des fuseaux s'arrête en 2037) : 21:30
  // à Paris. Le groupe B part une heure plus tard : 22:30.
  const String rideAt = '2036-07-29T19:30:00Z';
  const String groupAt = '2036-07-29T20:30:00Z';

  const RideGroupDto groupB = RideGroupDto(
    startAt: groupAt,
    id: 'g-b',
    name: 'Groupe B',
    countParticipants: 5,
    participants: <PublicUserDto>[],
    sortOrder: 1,
    registered: true,
    full: false,
  );

  RideGroupSummaryDto summary(String id, String name, String startAt) =>
      RideGroupSummaryDto(
        startAt: startAt,
        id: id,
        name: name,
        countParticipants: 5,
        maxParticipants: 16,
        full: false,
        sortOrder: id == 'g-a' ? 0 : 1,
      );

  PublicationDtoRide row({
    bool registered = false,
    RideGroupDto? registeredGroup,
  }) => PublicationDtoRide(
    timezone: 'Europe/Paris',
    tags: const <TagDto>[],
    groupSummaries: <RideGroupSummaryDto>[
      summary('g-a', 'Groupe A', rideAt),
      summary('g-b', 'Groupe B', groupAt),
    ],
    team: const TeamPublicationDto(
      id: 't1',
      slug: 'n-peloton',
      name: 'N-Peloton',
      visibility: 'PUBLIC',
    ),
    id: 'r1',
    slug: 'np-665',
    name: 'N-Peloton #665',
    media: const MediaDto(
      markdown: '',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
    ),
    dateTime: rideAt,
    endDateTime: '2036-07-29T22:30:00Z',
    status: 'PUBLISHED',
    visibility: 'TEAM',
    participantCount: 10,
    groupCount: 2,
    groups: const <RideGroupDto>[],
    topParticipants: const <PublicUserDto>[],
    deleted: false,
    registered: registered,
    registeredGroup: registeredGroup,
    registeredGroupId: registeredGroup?.id,
    full: false,
    finished: false,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Map<String, bool> overrides = const <String, bool>{},
  }) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          unitSystemProvider.overrideWithValue(UnitSystem.metric),
          authProvider.overrideWith((ref) => _StubAuthNotifier(ref)),
          registrationOverridesProvider.overrideWith((ref) => overrides),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  Finder shows(String text) => find.textContaining(text, findRichText: true);

  group('la carte du fil', () {
    testWidgets('inscrit dans un groupe à l’heure propre : son heure', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        PublicationCard(
          publication: row(registered: true, registeredGroup: groupB),
        ),
      );
      expect(shows('22:30'), findsWidgets);
      expect(shows('21:30'), findsNothing);
    });

    testWidgets('lu d’ailleurs, la mention commente l’heure du groupe', (
      WidgetTester tester,
    ) async {
      AppFormatters.setDisplayTimezone('America/New_York');
      await pump(
        tester,
        PublicationCard(
          publication: row(registered: true, registeredGroup: groupB),
        ),
      );
      // 20:30Z en juillet : 16:30 à New York, pas les 15:30 de la sortie.
      expect(shows('16:30'), findsOneWidget);
      expect(shows('15:30'), findsNothing);
    });

    testWidgets('désinscrit depuis le chargement : l’heure de la sortie', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        PublicationCard(
          publication: row(registered: true, registeredGroup: groupB),
        ),
        overrides: <String, bool>{'r1': false},
      );
      expect(shows('21:30'), findsWidgets);
      expect(shows('22:30'), findsNothing);
    });

    testWidgets('sans inscription : l’heure de la sortie', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        PublicationCard(publication: row(registeredGroup: groupB)),
      );
      expect(shows('21:30'), findsWidgets);
      expect(shows('22:30'), findsNothing);
    });
  });

  group('la carte « Sorties à venir »', () {
    Finder card() => find.byKey(keys.teamDashboard.rideCard('np-665'));
    Finder inCard(String text) => find.descendant(
      of: card(),
      matching: find.textContaining(text, findRichText: true),
    );

    testWidgets('inscrit dans un groupe à l’heure propre : son heure en tête, '
        'et l’autre groupe dit la sienne', (WidgetTester tester) async {
      AppFormatters.setDisplayTimezone('America/New_York');
      await pump(
        tester,
        DashboardRideCard(
          ride: row(registered: true, registeredGroup: groupB),
          canEdit: false,
        ),
      );
      // L'en-tête : 22:30 à Paris, la mention à 16:30 à New York.
      expect(inCard('22:30'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ZoneMentionLine),
          matching: find.textContaining('16:30'),
        ),
        findsOneWidget,
      );
      // Le groupe B part à l'heure de l'en-tête : rien à redire ; le groupe A,
      // à celle de la sortie, la dit.
      expect(inCard('Groupe A · départ 21:30'), findsOneWidget);
      expect(inCard('départ 22:30'), findsNothing);
    });

    testWidgets('désinscrit depuis le chargement : l’heure de la sortie', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        DashboardRideCard(
          ride: row(registered: true, registeredGroup: groupB),
          canEdit: false,
        ),
        overrides: <String, bool>{'r1': false},
      );
      expect(inCard('Groupe B · départ 22:30'), findsOneWidget);
      expect(inCard('départ 21:30'), findsNothing);
    });

    testWidgets('sans inscription : l’heure de la sortie, et le groupe à '
        'l’heure propre la dit, lecteur d’écran compris', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pump(tester, DashboardRideCard(ride: row(), canEdit: false));
      expect(inCard('Groupe A · départ'), findsNothing);
      expect(inCard('Groupe B · départ 22:30'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Groupe B · départ 22:30')),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  group('« Vos prochaines sorties »', () {
    Widget section(PublicationDtoRide ride) => DashboardMyUpcoming(
      list: PublicationListResponse(
        publications: <PublicationDto>[ride],
        total: 1,
        page: 0,
        size: 3,
      ),
      onViewAll: () {},
    );
    Finder inRow(String text) => find.descendant(
      of: find.byKey(keys.teamDashboard.myUpcomingRow('np-665')),
      matching: find.textContaining(text),
    );

    testWidgets('un groupe à l’heure propre : son heure', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        section(row(registered: true, registeredGroup: groupB)),
      );
      expect(inRow('22:30'), findsOneWidget);
      expect(inRow('21:30'), findsNothing);
    });

    testWidgets('un groupe qui part avec la sortie : l’heure de la sortie', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        section(
          row(
            registered: true,
            registeredGroup: groupB.copyWith(startAt: rideAt),
          ),
        ),
      );
      expect(inRow('21:30'), findsOneWidget);
    });

    testWidgets('BRAND-8 : l’heure sort des statistiques atténuées pour une '
        'ligne de départ en 700', (WidgetTester tester) async {
      await pump(
        tester,
        section(row(registered: true, registeredGroup: groupB)),
      );

      final Finder line = find.byKey(
        keys.teamDashboard.myUpcomingDeparture('np-665'),
      );
      expect(line, findsOneWidget);
      expect(
        find.descendant(of: line, matching: find.byType(PdlDepartureLine)),
        findsOneWidget,
      );
      final Text headline = tester.widget<Text>(
        find.descendant(of: line, matching: find.text('Départ 22:30')),
      );
      expect(headline.style?.fontWeight, FontWeight.w700);
      // La fin de la sortie, le lendemain à Paris.
      expect(
        find.descendant(
          of: line,
          matching: find.text('retour vers mer. 30 juil. 00:30'),
        ),
        findsOneWidget,
      );
      // Plus d'horloge atténuée parmi les faits.
      expect(
        find.descendant(
          of: find.byKey(keys.teamDashboard.myUpcomingRow('np-665')),
          matching: find.byIcon(PdlIcons.time),
        ),
        findsOneWidget, // celle de la ligne de départ
      );
      expect(inRow('Groupe B'), findsOneWidget);
    });

    testWidgets('BRAND-8 : un voyage montre son heure et sa plage au format '
        'unique, dans une boîte turquoise', (WidgetTester tester) async {
      // Du vendredi 17 octobre 2036, 09:00 à Paris, au dimanche 19.
      const PublicationDtoTrip trip = PublicationDtoTrip(
        team: TeamPublicationDto(
          id: 't1',
          slug: 'n-peloton',
          name: 'N-Peloton',
          visibility: 'PUBLIC',
        ),
        id: 'trip1',
        slug: 'gtmc',
        name: 'GTMC',
        media: MediaDto(
          markdown: '',
          assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
        ),
        dateTime: '2036-10-17T07:00:00Z',
        timezone: 'Europe/Paris',
        endDateTime: '2036-10-19T16:00:00Z',
        endDate: '2036-10-19T07:00:00Z',
        status: 'PUBLISHED',
        finished: false,
        visibility: 'PUBLIC',
        participantCount: 3,
        stageCount: 3,
        stages: <TripStageDto>[],
        participants: <PublicUserDto>[],
        deleted: false,
        registered: true,
        tags: <TagDto>[],
      );
      await pump(
        tester,
        DashboardMyUpcoming(
          list: const PublicationListResponse(
            publications: <PublicationDto>[trip],
            total: 1,
            page: 0,
            size: 3,
          ),
          onViewAll: () {},
        ),
      );

      final Finder line = find.byKey(
        keys.teamDashboard.myUpcomingDeparture('gtmc'),
      );
      expect(
        find.descendant(of: line, matching: find.text('Départ 09:00')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: line,
          matching: find.text('ven. 17 → dim. 19 oct. 2036'),
        ),
        findsOneWidget,
      );
      // Plus de « 17 octobre → 19 octobre » atténué.
      expect(find.textContaining('octobre'), findsNothing);
      final PdlDayBox box = tester.widget<PdlDayBox>(find.byType(PdlDayBox));
      expect(box.day, '17');
      expect(box.tone, isNotNull);
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
