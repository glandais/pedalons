import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/comments/data/comment_repository.dart';
import 'package:pedalons/features/comments/presentation/widgets/comment_thread.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/features/routes/presentation/widgets/gps_button.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_map.dart';
import 'package:pedalons/features/routes/providers/route_detail_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/trips/data/trip_repository.dart';
import 'package:pedalons/features/trips/presentation/pages/stage_detail_page.dart';
import 'package:pedalons/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:pedalons/features/trips/presentation/widgets/stage_card.dart';
import 'package:pedalons/features/rides/presentation/widgets/weather_section.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import '../rides/ride_fixtures.dart';
import 'trip_fixtures.dart';

/// S24-1, S24-6, S25-2 et S25-4 — les deux écrans montés en entier.
///
/// La carte se réduit à un squelette sans style servi ; ce qui se vérifie ici
/// est le reste, et surtout **ce qui n'est pas rendu** : pas de bouton
/// « Participer » sur un voyage passé ou annulé, pas de fil de commentaires sur
/// une étape dont le lecteur ne peut pas lire les commentaires, et pas de ligne
/// d'adresse vide quand `PlaceDetailDto.address` manque.
class _StubTripRepository implements TripRepository {
  _StubTripRepository(this.trip, {this.neverCompletes = false, this.weather});

  /// Ce que le serveur rend **maintenant** : un test peut le changer entre
  /// deux lectures, comme un organisateur qui annule le voyage.
  TripDto trip;
  final bool neverCompletes;

  /// La météo servie ; `OUT_OF_RANGE` sans rien à montrer par défaut.
  final TripWeatherDto? weather;
  int reads = 0;

  @override
  Future<TripDto> getTrip(String teamSlug, String tripSlug) {
    reads++;
    if (neverCompletes) return Completer<TripDto>().future;
    return Future<TripDto>.value(trip);
  }

  /// Pas de météo à montrer par défaut : `trip_weather_test.dart` couvre ses
  /// états.
  @override
  Future<TripWeatherDto> getTripWeather(String t, String s) async =>
      weather ??
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
    List<Override> overrides = const <Override>[],
  }) {
    return ProviderScope(
      overrides: [
        ...overrides,
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
    TripWeatherDto? weather,
    double? height,
  }) async {
    // Une page assez haute pour que ce qui est sous le pli soit construit :
    // un `CustomScrollView` ne livre pas aux `find` ce qu'il n'affiche pas.
    if (height != null) {
      tester.view.physicalSize = Size(402 * 3, height * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      app(
        trip,
        member: member,
        brightness: brightness,
        repository: weather == null
            ? null
            : _StubTripRepository(trip, weather: weather),
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

    testWidgets('sans distance, ni tuile Distance ni « 0 km »', (
      WidgetTester tester,
    ) async {
      await openTrip(
        tester,
        fixtureTrip(totalDistance: null, totalElevationGain: null),
      );

      final Finder tiles = find.byKey(keys.trip.statTiles);
      expect(tiles, findsOneWidget);
      expect(
        find.descendant(of: tiles, matching: find.text('Distance totale')),
        findsNothing,
      );
      expect(find.text('0 km'), findsNothing);
      expect(find.text('—'), findsNothing);
    });

    for (final Brightness brightness in Brightness.values) {
      testWidgets('BRAND-8 : le bloc de départ est sous le titre, avant les '
          'tuiles, au format unique (${brightness.name})', (
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
        // Sous le titre, au-dessus des tuiles.
        expect(
          tester.getTopLeft(block).dy,
          greaterThan(tester.getTopLeft(find.text('GTMC Bromance')).dy),
        );
        expect(
          tester.getTopLeft(block).dy,
          lessThan(tester.getTopLeft(find.byKey(keys.trip.statTiles)).dy),
        );
        // Les tuiles ne redisent pas les dates : la durée seule.
        final Finder tiles = find.byKey(keys.trip.statTiles);
        expect(
          find.descendant(of: tiles, matching: find.text('7 jours')),
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
          of: find.byKey(keys.trip.statTiles),
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
      expect(find.byKey(keys.trip.joinButton), findsNothing);
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
        expect(find.byKey(keys.trip.joinButton), findsOneWidget);
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
        expect(find.byKey(keys.trip.joinButton), findsNothing);
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

      expect(find.byKey(keys.trip.joinButton), findsNothing);
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
      expect(find.byKey(keys.trip.joinButton), findsNothing);
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

  /// Les deux maquettes cibles du voyage (ledger `MOB-134`, lot 9, KIT §8) :
  /// le même écran pour une ou plusieurs étapes, dans le même ordre de blocs,
  /// sans section Météo ni légende des étapes sous la carte.
  group('écran du voyage — maquettes cibles', () {
    const MediaDto described = MediaDto(
      markdown: 'Trois jours à travers le Morvan.',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
    );
    const RideWeatherSummaryDto summary = RideWeatherSummaryDto(
      status: 'OK',
      condition: 'CLOUDY',
      daylight: true,
      temperature: 8,
      temperatureMin: 6,
      temperatureMax: 11,
      maxPrecipitationProbability: 20,
      wind: WindDto(speed: 18, direction: 270, compass: 'W'),
    );
    TripWeatherDto weatherFor(List<String> stageIds) => TripWeatherDto(
      status: 'OK',
      stages: <TripStageWeatherDto>[
        for (final String id in stageIds)
          TripStageWeatherDto(
            departure: const DepartureWeatherDto(status: 'OK'),
            stageId: id,
            summary: summary,
            leg: fixtureLeg(groupId: null),
          ),
      ],
      attribution: const WeatherAttributionDto(
        name: 'Open-Meteo.com',
        url: 'https://open-meteo.com/',
      ),
      fetchedAt: '2099-08-10T17:00:00Z',
    );

    void expectOrder(WidgetTester tester, List<Key> order) {
      final List<double> tops = <double>[
        for (final Key k in order) tester.getTopLeft(find.byKey(k)).dy,
      ];
      for (int i = 1; i < tops.length; i++) {
        expect(
          tops[i],
          greaterThan(tops[i - 1]),
          reason: '${order[i]} doit suivre ${order[i - 1]}',
        );
      }
    }

    final List<Key> order = <Key>[
      keys.trip.title,
      keys.trip.departureBlock,
      keys.trip.statTiles,
      keys.trip.routeSection,
      keys.trip.descriptionSection,
      keys.trip.stagesSection,
      keys.trip.participants,
      keys.trip.commentsSection,
    ];

    Finder inBlock(Finder f) =>
        find.descendant(of: find.byKey(keys.trip.departureBlock), matching: f);
    Finder inTiles(String text) => find.descendant(
      of: find.byKey(keys.trip.statTiles),
      matching: find.text(text),
    );

    void expectNoWeatherSectionNorLegend() {
      expect(find.byType(WeatherSection), findsNothing);
      expect(find.byKey(keys.ride.weatherBlock), findsNothing);
      expect(find.byType(PdlLegendRow), findsNothing);
      expect(find.byType(PdlActionBar), findsNothing);
    }

    testWidgets('voyage-etapes-mobile-cible', (WidgetTester tester) async {
      final TripDto trip = fixtureTrip(
        participantCount: 12,
        participants: <PublicUserDto>[
          for (int i = 0; i < 3; i++)
            PublicUserDto(id: 'u$i', displayName: 'Membre $i'),
        ],
        stages: <TripStageDto>[
          fixtureStage(
            index: 1,
            route: fixtureStageRoute(),
            startPlaceName: 'Place du Champ-de-Mars, Autun',
          ),
          fixtureStage(
            index: 2,
            route: fixtureStageRoute(slug: 'gtmc-j2', name: 'GTMC J2'),
          ),
          fixtureStage(index: 3),
        ],
      ).copyWith(media: described);
      await openTrip(
        tester,
        trip,
        height: 6000,
        weather: weatherFor(<String>['s1', 's2']),
      );

      expectOrder(tester, order);
      expectNoWeatherSectionNorLegend();
      // L'inscription et le lieu de la première étape, dans le bloc.
      expect(inBlock(find.byKey(keys.trip.joinButton)), findsOneWidget);
      expect(inBlock(find.byKey(keys.trip.startPlaceLink)), findsOneWidget);
      // Les tuiles, dans l'ordre fixe ; « Étapes 3 », la valeur seule.
      for (final String label in <String>[
        'Distance totale',
        'Dénivelé cumulé',
        'Durée',
        'Étapes',
      ]) {
        expect(inTiles(label), findsOneWidget);
      }
      expect(inTiles('3'), findsOneWidget);
      expect(
        tester.getTopLeft(inTiles('Durée')).dy,
        greaterThan(tester.getTopLeft(inTiles('Distance totale')).dy),
      );
      expect(find.text('3 étapes'), findsOneWidget);
      // Les cartes d'étape : la ligne météo, ni vignette ni nom de parcours.
      expect(
        find.descendant(
          of: find.byKey(keys.trip.stageCard('j1')),
          matching: find.byKey(keys.ride.weatherSummary),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StageCard),
          matching: find.byType(PdlThumb),
        ),
        findsNothing,
      );
      expect(find.text('GTMC J1'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('voyage-une-etape-mobile-cible', (WidgetTester tester) async {
      final TripDto trip = fixtureTrip(
        endDate: null,
        totalDistance: 96000,
        totalElevationGain: 1650,
        stages: <TripStageDto>[
          fixtureStage(
            index: 1,
            stageCount: 1,
            route: fixtureStageRoute(),
            startPlaceName: 'Place du Champ-de-Mars, Autun',
          ),
        ],
      ).copyWith(media: described);
      await openTrip(
        tester,
        trip,
        height: 6000,
        weather: weatherFor(<String>['s1']),
      );

      expectOrder(tester, order);
      // Pas de disposition dédiée à une étape : ni section Météo, ni légende.
      expectNoWeatherSectionNorLegend();
      expect(inBlock(find.byKey(keys.trip.joinButton)), findsOneWidget);
      expect(inBlock(find.byKey(keys.trip.startPlaceLink)), findsOneWidget);
      expect(inTiles('1 jour'), findsOneWidget);
      expect(inTiles('1'), findsOneWidget);
      expect(find.text('1 étape'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(keys.trip.stageCard('j1')),
          matching: find.byKey(keys.ride.weatherSummary),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('inscrit : « J\'y vais » dans le bloc, « Se désinscrire » au '
        'pied de « Personnes inscrites »', (WidgetTester tester) async {
      await openTrip(tester, fixtureTrip(registered: true), height: 6000);

      expect(inBlock(find.byKey(keys.trip.goingBadge)), findsOneWidget);
      expect(find.byKey(keys.trip.joinButton), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(keys.trip.participants),
          matching: find.byKey(keys.trip.leaveButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('non-membre : le compte seul, ni visages ni liste (API-144)', (
      WidgetTester tester,
    ) async {
      await openTrip(
        tester,
        fixtureTrip(
          participantCount: 12,
          participants: const <PublicUserDto>[],
        ),
        member: false,
        height: 6000,
      );

      final Finder section = find.byKey(keys.trip.participants);
      expect(
        find.descendant(of: section, matching: find.text('12')),
        findsOneWidget,
      );
      expect(find.byKey(keys.trip.participantsAvatars), findsNothing);
      expect(find.byKey(keys.trip.viewAllParticipants), findsNothing);
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

    testWidgets('le rail est épinglé et porte « Aperçu » puis les étapes ; '
        '« Étape 1 sur 2 » est dans la barre du haut', (
      WidgetTester tester,
    ) async {
      await openStage(tester, tripWithPlaces(), 'j1');

      expect(find.byType(PdlStageRail), findsOneWidget);
      expect(find.text('Aperçu'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(keys.trip.stagePosition),
          matching: find.text('Étape 1 sur 2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PdlAppBar),
          matching: find.text('GTMC Bromance'),
        ),
        findsOneWidget,
      );
      // Plus de badge « Étape 1 sur 2 » dans le corps.
      expect(find.text('ÉTAPE 1 SUR 2'), findsNothing);
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
      expect(find.textContaining('Départ groupé'), findsNothing);
      // Sans `estimatedArrival` (une API plus ancienne), pas d'arrivée.
      expect(find.textContaining('Arrivée estimée'), findsNothing);
      expect(
        tester.getTopLeft(block).dy,
        greaterThan(tester.getTopLeft(find.byKey(keys.trip.stageTitle)).dy),
      );
      // Le lieu de départ, dans le bloc.
      expect(
        find.descendant(
          of: block,
          matching: find.byKey(keys.trip.stageStartPlaceLink),
        ),
        findsOneWidget,
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

    testWidgets('les lieux sont des liens d\'itinéraire, le nom seul', (
      WidgetTester tester,
    ) async {
      await openStage(tester, tripWithPlaces(), 'j1');

      final Finder block = find.byKey(keys.trip.stageDepartureBlock);
      expect(
        find.descendant(
          of: block,
          matching: find.byKey(keys.trip.stageStartPlaceLink),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: block,
          matching: find.byKey(keys.trip.stageEndPlaceLink),
        ),
        findsOneWidget,
      );
      expect(find.text('Clermont-Ferrand'), findsOneWidget);
      expect(find.text('Issoire'), findsOneWidget);
      // L'adresse sert l'itinéraire ; elle ne s'écrit plus (KIT §8).
      expect(find.text('Place de Jaude, 63000'), findsNothing);
    });

    testWidgets('sans parcours : « Parcours » et un état vide', (
      WidgetTester tester,
    ) async {
      await openStage(
        tester,
        fixtureTrip(
          stages: <TripStageDto>[
            fixtureStage(index: 1, stageCount: 2),
            fixtureStage(index: 2, stageCount: 2),
          ],
        ),
        'j1',
      );

      expect(
        find.descendant(
          of: find.byKey(keys.trip.stageRouteSection),
          matching: find.text('Aucun parcours'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(keys.trip.stageStatTiles), findsNothing);
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

  group('écran de l\'étape — maquette cible', () {
    setUp(() => RouteMap.debugSkipNativeMap = true);
    tearDown(() => RouteMap.debugSkipNativeMap = false);

    const AssetDto gpx = AssetDto(
      id: 'a-gpx',
      fileName: 'j2.gpx',
      contentType: 'application/gpx+xml',
      url: '/api/download/public/j2.gpx',
    );

    // 68,2 km plein nord, une montée, deux points.
    final RouteDetailDto route = RouteDetailDto(
      elevationState: 'HD',
      tags: const [],
      id: 'route-gtmc-j2',
      slug: 'gtmc-j2',
      team: kFixtureTeam,
      name: 'GTMC J2',
      media: kEmptyMedia.copyWith(
        assets: kEmptyMedia.assets.copyWith(gpx: gpx),
      ),
      distance: 68200,
      elevationGain: 1120,
      elevationLoss: 1000,
      surfaceType: 'ROAD',
      visibility: 'PUBLIC',
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
      tracks: <TrackDto>[
        TrackDto(
          line: GeoJsonLineString(
            type: GeoJsonLineStringTypeType.lineString,
            coordinates: <List<double>>[
              for (int i = 0; i <= 68; i++)
                <double>[4, 47 + i * 0.009, 300 + (i % 10) * 20, i * 1000.0],
            ],
          ),
          climbs: const <ClimbDto>[
            ClimbDto(
              startDistance: 20000,
              endDistance: 24000,
              elevationGain: 200,
              averageGradient: 5,
              maxGradient: 8,
              parts: <ClimbPartDto>[],
              name: 'Haut-Folin',
            ),
          ],
        ),
      ],
      waypoints: <WaypointDto>[
        for (final (String id, double km) in <(String, double)>[
          ('w1', 10),
          ('w2', 40),
        ])
          WaypointDto(
            id: id,
            geometry: GeoJsonPoint(
              type: GeoJsonPointTypeType.point,
              coordinates: <double>[4, 47 + km * 0.009],
            ),
            name: 'Point $id',
            type: 'WATER',
            distance: km * 1000,
            origin: 'AUTHOR',
          ),
      ],
      deleted: false,
    );

    TripDto morvan() => fixtureTrip(
      stages: <TripStageDto>[
        fixtureStage(index: 1, route: fixtureStageRoute()),
        fixtureStage(
          index: 2,
          name: 'Château-Chinon → Saulieu',
          // 08:00Z le sam. 21 nov. 2036 : 09:00 à Paris ; arrivée 10:50Z,
          // 11:50.
          dateTime: '2036-11-21T08:00:00Z',
          route: fixtureStageRoute(
            slug: 'gtmc-j2',
            name: 'GTMC J2',
            distance: 68200,
          ),
          startPlaceName: 'Place Notre-Dame, Château-Chinon',
          endPlaceName: 'Basilique Saint-Andoche, Saulieu',
          commentCount: 2,
        ).copyWith(
          averageSpeed: 24,
          estimatedArrival: '2036-11-21T10:50:00Z',
          estimatedDurationMinutes: 170,
          media: kEmptyMedia.copyWith(
            markdown: 'Étape de liaison par le lac des Settons.',
          ),
        ),
        fixtureStage(index: 3),
      ],
    );

    TripWeatherDto weather() => TripWeatherDto(
      status: 'OK',
      stages: <TripStageWeatherDto>[
        TripStageWeatherDto(
          departure: DepartureWeatherDto(
            status: 'OK',
            conditions: fixtureConditions(),
          ),
          stageId: 's2',
          leg: fixtureLeg(groupId: null),
        ),
      ],
      attribution: const WeatherAttributionDto(
        name: 'Open-Meteo.com',
        url: 'https://open-meteo.com/',
      ),
      fetchedAt: '2099-08-10T07:30:00Z',
    );

    testWidgets('etape-mobile-cible', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(402 * 3, 6000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final TripDto trip = morvan();
      await tester.pumpWidget(
        app(
          trip,
          repository: _StubTripRepository(trip, weather: weather()),
          overrides: [
            routeDetailProvider(
              const RouteKey(teamSlug: 'n-peloton', routeSlug: 'gtmc-j2'),
            ).overrideWith((Ref ref) async => route),
            appConfigProvider.overrideWith(
              (Ref ref) => Completer<ConfigDto>().future,
            ),
            mapStyleProvider.overrideWith(
              (Ref ref, Brightness b) =>
                  const AsyncValue<ResolvedMapStyle?>.data(null),
            ),
          ],
          home: StageDetailPage(
            teamSlug: trip.team.slug,
            tripSlug: trip.slug,
            stageSlug: 'j2',
          ),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      // L'ordre des sections, de haut en bas.
      final List<Key> order = <Key>[
        keys.trip.stageTitle,
        keys.trip.stageDepartureBlock,
        keys.trip.stageStatTiles,
        keys.trip.stageRouteSection,
        keys.trip.stageWaypoints,
        keys.trip.stageClimbs,
        keys.trip.stageDescriptionSection,
        keys.trip.stageWeatherSection,
        keys.trip.stageCommentsSection,
      ];
      final List<double> tops = <double>[
        for (final Key k in order) tester.getTopLeft(find.byKey(k)).dy,
      ];
      for (int i = 1; i < tops.length; i++) {
        expect(
          tops[i],
          greaterThan(tops[i - 1]),
          reason: '${order[i]} doit suivre ${order[i - 1]}',
        );
      }

      // La barre du haut : « Étape 2 sur 3 » sur le nom du voyage.
      expect(
        find.descendant(
          of: find.byKey(keys.trip.stagePosition),
          matching: find.text('Étape 2 sur 3'),
        ),
        findsOneWidget,
      );
      // Ni lien vers le voyage ni badges dans le corps.
      expect(find.byType(PdlTeamLine), findsNothing);
      expect(find.byType(PdlBadge), findsNothing);

      // Le bloc de départ : l'heure, l'arrivée estimée, les deux lieux.
      Finder inBlock(Finder f) => find.descendant(
        of: find.byKey(keys.trip.stageDepartureBlock),
        matching: f,
      );
      expect(inBlock(find.text('Départ 09:00')), findsOneWidget);
      expect(inBlock(find.text('Arrivée estimée 11:50')), findsOneWidget);
      expect(
        inBlock(find.byKey(keys.trip.stageStartPlaceLink)),
        findsOneWidget,
      );
      expect(inBlock(find.byKey(keys.trip.stageEndPlaceLink)), findsOneWidget);

      // Les tuiles, dans l'ordre fixe.
      Finder inTiles(String text) => find.descendant(
        of: find.byKey(keys.trip.stageStatTiles),
        matching: find.text(text),
      );
      for (final String text in <String>[
        'Distance',
        'Dénivelé positif',
        'Durée estimée',
        'Vitesse moyenne',
        AppFormatters.formatDurationMinutes(170),
      ]) {
        expect(inTiles(text), findsOneWidget, reason: text);
      }
      expect(
        tester.getTopLeft(inTiles('Durée estimée')).dy,
        greaterThan(tester.getTopLeft(inTiles('Distance')).dy),
      );

      // Parcours : un seul bouton « GPS », et « Détails ».
      expect(find.byType(GpsButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(keys.trip.stageRouteSection),
          matching: find.byKey(keys.routeDetail.gps),
        ),
        findsOneWidget,
      );
      expect(find.byKey(keys.routeDetail.details), findsOneWidget);
      // Points et montées repliés.
      expect(find.text('2 points'), findsOneWidget);
      expect(find.text('1 montée'), findsOneWidget);
      expect(find.text('Point w1'), findsNothing);

      // La météo en section, sur la page : le départ, la frise repliée
      // (les commentaires suivent), la source.
      Finder inWeather(Finder f) => find.descendant(
        of: find.byKey(keys.trip.stageWeatherSection),
        matching: f,
      );
      expect(inWeather(find.byKey(keys.ride.weatherSection)), findsOneWidget);
      expect(
        inWeather(find.byKey(keys.rideGroup.departureWeatherTitle)),
        findsOneWidget,
      );
      expect(
        inWeather(
          find.byWidgetPredicate(
            (Widget w) =>
                w is PdlDisclosure && w.key == keys.ride.weatherAlongRoute,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);
      expect(inWeather(find.textContaining('Prévision du')), findsOneWidget);
      expect(find.text('Voir la fiche complète'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
