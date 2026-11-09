import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/comments/data/comment_repository.dart';
import 'package:pedalons/features/comments/presentation/widgets/comment_thread.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/trips/data/trip_repository.dart';
import 'package:pedalons/features/trips/presentation/pages/stage_detail_page.dart';
import 'package:pedalons/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:pedalons/features/trips/presentation/widgets/stage_card.dart';
import 'package:pedalons/features/trips/presentation/widgets/trip_summary_card.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'trip_fixtures.dart';

/// S24-1, S24-6, S25-2 et S25-4 — les deux écrans montés en entier.
///
/// La carte se réduit à un squelette sans style servi ; ce qui se vérifie ici
/// est le reste, et surtout **ce qui n'est pas rendu** : pas de bouton
/// « Participer » sur un voyage passé ou annulé, pas de fil de commentaires sur
/// une étape dont le lecteur ne peut pas lire les commentaires, et pas de ligne
/// d'adresse vide quand `PlaceDetailDto.address` manque.
class _StubTripRepository implements TripRepository {
  _StubTripRepository(this.trip, {this.neverCompletes = false});

  /// Ce que le serveur rend **maintenant** : un test peut le changer entre
  /// deux lectures, comme un organisateur qui annule le voyage.
  TripDto trip;
  final bool neverCompletes;
  int reads = 0;

  @override
  Future<TripDto> getTrip(String teamSlug, String tripSlug) {
    reads++;
    if (neverCompletes) return Completer<TripDto>().future;
    return Future<TripDto>.value(trip);
  }

  /// Pas de météo à montrer : `trip_weather_test.dart` couvre ses états.
  @override
  Future<TripWeatherDto> getTripWeather(String t, String s) async =>
      const TripWeatherDto(
        status: 'OUT_OF_RANGE',
        stages: <TripStageWeatherDto>[],
        attribution: WeatherAttributionDto(
          name: 'Open-Meteo.com',
          url: 'https://open-meteo.com/',
        ),
      );

  @override
  Future<TripParticipationDto> joinTrip(String t, String s) async =>
      const TripParticipationDto(id: 'p', userId: 'u');

  @override
  Future<void> leaveTrip(String t, String s) async {}
}

/// Un fil vide : seul compte ici la cible qu'on lui demande.
class _StubCommentRepository implements CommentRepository {
  final List<CommentTarget> targets = <CommentTarget>[];

  @override
  Future<CommentListResponse> list(
    CommentTarget target, {
    int page = 0,
    int size = 20,
    String? parentId,
    SortDirection? sort,
  }) async {
    targets.add(target);
    return CommentListResponse(
      items: const <CommentDto>[],
      total: 0,
      itemTotal: 0,
      page: page,
      size: size,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubTeamRepository implements TeamRepository {
  _StubTeamRepository({required this.member});

  final bool member;

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => member
      ? <TeamDetailDto>[
          const TeamDetailDto(
            timezone: 'Europe/Paris',
            id: 't1',
            slug: 'n-peloton',
            name: 'N-Peloton',
            about: kEmptyMedia,
            visibility: 'PUBLIC',
            enableTrips: true,
            enableAds: true,
            enablePosts: true,
            enableRides: true,
            enableRoutes: true,
            visibilityEditable: true,
            joinable: true,
            addMemberAllowed: true,
            enableMemberDirectory: false,
            postsAsTeamByDefault: true,
            enableRoutePlanner: false,
            memberCount: 40,
            upcomingRideCount: 3,
            routeCount: 12,
            upcomingTripCount: 0,
            recentPostCount: 0,
            createdAt: '2024-01-01T00:00:00Z',
          ),
        ]
      : <TeamDetailDto>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Widget app(
    TripDto trip, {
    required Widget home,
    bool member = true,
    bool loading = false,
    Brightness brightness = Brightness.light,
    _StubTripRepository? repository,
    _StubCommentRepository? comments,
  }) {
    return ProviderScope(
      overrides: [
        commentRepositoryProvider.overrideWithValue(
          comments ?? _StubCommentRepository(),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        tripRepositoryProvider.overrideWithValue(
          repository ?? _StubTripRepository(trip, neverCompletes: loading),
        ),
        teamRepositoryProvider.overrideWithValue(
          _StubTeamRepository(member: member),
        ),
      ],
      child: MaterialApp(theme: PedalonsTheme.build(brightness), home: home),
    );
  }

  Future<void> openTrip(
    WidgetTester tester,
    TripDto trip, {
    bool member = true,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      app(
        trip,
        member: member,
        brightness: brightness,
        home: TripDetailPage(teamSlug: trip.team.slug, tripSlug: trip.slug),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> openStage(
    WidgetTester tester,
    TripDto trip,
    String stageSlug, {
    _StubCommentRepository? comments,
  }) async {
    await tester.pumpWidget(
      app(
        trip,
        comments: comments,
        home: StageDetailPage(
          teamSlug: trip.team.slug,
          tripSlug: trip.slug,
          stageSlug: stageSlug,
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  group('écran 24 — le voyage', () {
    testWidgets('le squelette est structuré, pas un rond qui tourne', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        app(
          fixtureTrip(),
          loading: true,
          home: const TripDetailPage(
            teamSlug: 'n-peloton',
            tripSlug: 'gtmc-bromance',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PdlSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('la synthèse rend « — » et jamais « 0 » sans distance', (
      WidgetTester tester,
    ) async {
      await openTrip(
        tester,
        fixtureTrip(totalDistance: null, totalElevationGain: null),
      );

      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0 km'), findsNothing);
    });

    for (final Brightness brightness in Brightness.values) {
      testWidgets('BRAND-8 : le bloc de départ est sous le titre, avant la '
          'synthèse, au format unique (${brightness.name})', (
        WidgetTester tester,
      ) async {
        // 07:00Z le mardi 12 août 2036 : 09:00 à Paris ; dernière étape le
        // lundi 18, fin à 12:00 (la base des fuseaux s'arrête en 2037).
        await openTrip(
          tester,
          fixtureTrip(
            dateTime: '2036-08-12T07:00:00Z',
            endDate: '2036-08-18T07:00:00Z',
          ),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);

        final Finder block = find.byKey(keys.trip.departureBlock);
        expect(block, findsOneWidget);
        Finder inBlock(String text) =>
            find.descendant(of: block, matching: find.text(text));
        expect(inBlock('Départ 09:00'), findsOneWidget);
        expect(inBlock('mar. 12 → lun. 18 août 2036'), findsOneWidget);
        // La boîte du jour, au turquoise d'un voyage.
        final PdlDayBox box = tester.widget<PdlDayBox>(
          find.descendant(of: block, matching: find.byType(PdlDayBox)),
        );
        expect(box.day, '12');
        expect(box.tone, isNotNull);
        // Sous le titre, au-dessus de la synthèse.
        expect(
          tester.getTopLeft(block).dy,
          greaterThan(tester.getTopLeft(find.text('GTMC Bromance')).dy),
        );
        expect(
          tester.getTopLeft(block).dy,
          lessThan(tester.getTopLeft(find.byType(TripSummaryCard)).dy),
        );
        // La synthèse ne redit plus les dates : la durée seule.
        final Finder duration = find.byKey(keys.trip.summaryDuration);
        expect(
          find.descendant(of: duration, matching: find.text('7 jours')),
          findsOneWidget,
        );
        expect(
          find.textContaining('août 2036', findRichText: true),
          findsOneWidget,
        );
        expect(find.textContaining('mardi'), findsNothing);
      });
    }

    testWidgets('BRAND-8 : sans dernière étape connue, pas de retour annoncé', (
      WidgetTester tester,
    ) async {
      await openTrip(
        tester,
        fixtureTrip(dateTime: '2036-08-12T07:00:00Z', endDate: null),
      );

      final Finder block = find.byKey(keys.trip.departureBlock);
      expect(
        find.descendant(of: block, matching: find.text('mar. 12 août 2036')),
        findsOneWidget,
      );
      expect(find.textContaining('retour vers'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(keys.trip.summaryDuration),
          matching: find.text('1 jour'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('un voyage annulé porte son bandeau et aucune action', (
      WidgetTester tester,
    ) async {
      await openTrip(tester, fixtureTrip(status: 'CANCELLED'));

      // `PdlBanner` compose titre et message dans un seul `RichText`.
      expect(
        find.textContaining('Voyage annulé.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Rejoindre'), findsNothing);
      expect(find.byType(PdlActionBar), findsNothing);
    });

    testWidgets(
      'tirer pour rafraîchir relit le voyage : l\'annulation apparaît',
      (WidgetTester tester) async {
        final TripDto trip = fixtureTrip();
        final _StubTripRepository repository = _StubTripRepository(trip);
        await tester.pumpWidget(
          app(
            trip,
            repository: repository,
            home: TripDetailPage(teamSlug: trip.team.slug, tripSlug: trip.slug),
          ),
        );
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(find.byType(PdlActionBar), findsOneWidget);
        expect(repository.reads, 1);
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

        repository.trip = fixtureTrip(status: 'CANCELLED');
        // Depuis le titre : le milieu de l'écran est la carte, qui garde ses
        // gestes pour elle.
        await tester.fling(find.text(trip.name), const Offset(0, 400), 1000);
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(repository.reads, 2);
        expect(
          find.textContaining('Voyage annulé.', findRichText: true),
          findsOneWidget,
        );
        expect(find.byType(PdlActionBar), findsNothing);
      },
    );

    testWidgets('refermé, le voyage n\'est pas gardé : rouvert, il est relu', (
      WidgetTester tester,
    ) async {
      final TripDto trip = fixtureTrip();
      final _StubTripRepository repository = _StubTripRepository(trip);
      Future<void> mount(Widget home) async {
        await tester.pumpWidget(app(trip, repository: repository, home: home));
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
      }

      final Widget page = TripDetailPage(
        teamSlug: trip.team.slug,
        tripSlug: trip.slug,
      );
      await mount(page);
      expect(repository.reads, 1);

      repository.trip = fixtureTrip(status: 'CANCELLED');
      await mount(const SizedBox());
      await mount(page);

      expect(repository.reads, 2);
      expect(
        find.textContaining('Voyage annulé.', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('un voyage passé n\'offre plus de participer', (
      WidgetTester tester,
    ) async {
      await openTrip(
        tester,
        fixtureTrip(
          dateTime: '2020-08-12T07:00:00Z',
          endDate: '2020-08-18T07:00:00Z',
        ),
      );

      expect(find.byType(PdlActionBar), findsNothing);
      expect(find.text('TERMINÉ'), findsOneWidget);
    });

    testWidgets('un non-membre est renvoyé vers l\'équipe, sans action', (
      WidgetTester tester,
    ) async {
      await openTrip(tester, fixtureTrip(), member: false);

      expect(
        find.textContaining('Rejoignez cette équipe', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(PdlActionBar), findsNothing);
    });

    testWidgets('les étapes se rendent en cartes, dans l\'ordre', (
      WidgetTester tester,
    ) async {
      await openTrip(tester, fixtureTrip());
      // Défiler **jusqu'à** les cartes, et non d'une distance magique : celle
      // d'avant valait la hauteur du hero, et le jour où il a disparu elle
      // emmenait la liste au-delà des étapes, dans les commentaires.
      for (
        int i = 0;
        i < 12 && find.byType(StageCard).evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();
      }

      expect(find.byType(StageCard), findsWidgets);
    });
  });

  group('écran 25 — l\'étape', () {
    TripDto tripWithPlaces({String? address = 'Place de Jaude, 63000'}) =>
        fixtureTrip(
          stages: <TripStageDto>[
            fixtureStage(
              index: 1,
              stageCount: 2,
              route: fixtureStageRoute(),
              startPlaceName: 'Clermont-Ferrand',
              startAddress: address,
              endPlaceName: 'Issoire',
            ),
            fixtureStage(index: 2, stageCount: 2),
          ],
        );

    testWidgets('le rail est épinglé et porte « Aperçu » puis les étapes', (
      WidgetTester tester,
    ) async {
      await openStage(tester, tripWithPlaces(), 'j1');

      expect(find.byType(PdlStageRail), findsOneWidget);
      expect(find.text('Aperçu'), findsOneWidget);
      // `PdlBadge` capitalise ses libellés.
      expect(find.text('ÉTAPE 1 SUR 2'), findsOneWidget);
    });

    testWidgets('le bloc de départ est sous le titre, sans « Départ groupé » '
        '(MOB-114)', (WidgetTester tester) async {
      // 06:30Z le mardi 12 août 2036 : 08:30 à Paris.
      final TripDto trip = fixtureTrip(
        stages: <TripStageDto>[
          fixtureStage(
            index: 1,
            stageCount: 2,
            dateTime: '2036-08-12T06:30:00Z',
            startPlaceName: 'Clermont-Ferrand',
          ),
          fixtureStage(index: 2, stageCount: 2),
        ],
      );
      await openStage(tester, trip, 'j1');

      final Finder block = find.byKey(keys.trip.stageDepartureBlock);
      expect(block, findsOneWidget);
      expect(
        find.descendant(of: block, matching: find.text('Départ 08:30')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: block, matching: find.byType(PdlDayBox)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: block,
          matching: find.textContaining('mar. 12 août 2036'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Départ groupé'), findsNothing);
      // Sous le titre : au-dessus des lieux.
      expect(
        tester.getTopLeft(block).dy,
        greaterThan(tester.getTopLeft(find.byKey(keys.trip.stageTitle)).dy),
      );
      expect(
        tester.getTopLeft(block).dy,
        lessThan(tester.getTopLeft(find.text('Clermont-Ferrand').last).dy),
      );
    });

    testWidgets('BRAND-8 : le rail date chaque étape au format unique, dans '
        'son fuseau', (WidgetTester tester) async {
      // 06:30Z le mardi 12 août 2036 à Paris ; 23:30Z le mercredi 13 août,
      // jeudi 14 à Tokyo.
      final TripDto trip = fixtureTrip(
        stages: <TripStageDto>[
          fixtureStage(
            index: 1,
            stageCount: 2,
            dateTime: '2036-08-12T06:30:00Z',
          ),
          fixtureStage(
            index: 2,
            stageCount: 2,
            dateTime: '2036-08-13T23:30:00Z',
            timezone: 'Asia/Tokyo',
          ),
        ],
      );
      await openStage(tester, trip, 'j1');

      final PdlStageRail rail = tester.widget<PdlStageRail>(
        find.byType(PdlStageRail),
      );
      expect(
        rail.items.map((PdlStageRailItem i) => i.sublabel).toList(),
        <String?>[null, 'mar. 12 août 2036', 'jeu. 14 août 2036'],
      );
    });

    testWidgets('l\'adresse s\'affiche sous le nom du lieu', (
      WidgetTester tester,
    ) async {
      await openStage(tester, tripWithPlaces(), 'j1');

      expect(find.text('Clermont-Ferrand'), findsWidgets);
      expect(find.text('Place de Jaude, 63000'), findsOneWidget);
    });

    testWidgets('sans adresse, la ligne se réduit sans espace vide', (
      WidgetTester tester,
    ) async {
      await openStage(tester, tripWithPlaces(address: null), 'j1');

      expect(find.text('Clermont-Ferrand'), findsWidgets);
      expect(find.text('Place de Jaude, 63000'), findsNothing);
    });

    testWidgets(
      'sans `commentCount`, aucun fil : le lecteur ne peut pas lire',
      (WidgetTester tester) async {
        await openStage(tester, tripWithPlaces(), 'j1');
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -1400),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(CommentThread), findsNothing);
      },
    );

    testWidgets('le fil est celui de l\'étape, pas celui du voyage', (
      WidgetTester tester,
    ) async {
      final _StubCommentRepository comments = _StubCommentRepository();
      await openStage(
        tester,
        fixtureTrip(
          stages: <TripStageDto>[
            fixtureStage(index: 1, stageCount: 2, commentCount: 0),
            fixtureStage(index: 2, stageCount: 2),
          ],
        ),
        'j1',
        comments: comments,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CommentThread), findsOneWidget);
      expect(
        comments.targets.first,
        const CommentTarget(
          entity: CommentEntity.stage,
          teamSlug: 'n-peloton',
          slug: 'j1',
        ),
      );
    });

    testWidgets('une étape inconnue rend un état introuvable, pas un vide', (
      WidgetTester tester,
    ) async {
      await openStage(tester, tripWithPlaces(), 'j9');

      expect(find.text('Étape introuvable'), findsOneWidget);
      expect(find.text('Retour au voyage'), findsWidgets);
    });
  });
}
