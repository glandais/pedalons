import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/rides/data/ride_repository.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_detail_page.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_group_page.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/features/participants/data/participant_repository.dart';
import 'package:pedalons/features/participants/domain/participant_query.dart';
import 'package:pedalons/features/participants/presentation/widgets/participants_sheet.dart';
import 'package:pedalons/features/comments/data/comment_repository.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_group_card.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_groups_map.dart';
import 'package:pedalons/features/rides/providers/ride_scroll_target_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/domain/track_surfaces.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_color_mode_switch.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/features/rides/providers/ride_weather_provider.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import '../routes/route_fixtures.dart';
import 'ride_fixtures.dart';

/// S12-8 — l'assemblage de l'écran 12 et ses états.
///
/// L'écran est monté en entier, carte comprise : `PdlMap` se réduit à un
/// squelette tant qu'aucun style n'est résolu, ce qui est le cas sans serveur.
/// Ce qui est vérifié est le reste — les bandeaux d'état et, surtout, **ce qui
/// n'est pas rendu** quand la sortie est annulée, passée, ou que l'utilisateur
/// n'est pas membre. C'est exactement là que la v1 se trompait : elle
/// proposait « Participer » sur une sortie déjà courue.
class _StubRideRepository implements RideRepository {
  _StubRideRepository(this.ride, {this.neverCompletes = false, this.weather});

  final RideDto ride;

  /// La météo servie ; `null` sert `OUT_OF_RANGE`, qui ne rend rien.
  RideWeatherDto? weather;

  /// L'erreur que `getRideWeather` lève au lieu de répondre.
  Object? weatherError;

  int weatherCalls = 0;

  /// Laisse la météo en vol indéfiniment, pour observer son chargement.
  bool weatherNeverCompletes = false;

  @override
  Future<RideWeatherDto> getRideWeather(String teamSlug, String rideSlug) {
    weatherCalls++;
    if (weatherNeverCompletes) return Completer<RideWeatherDto>().future;
    if (weatherError != null) {
      return Future<RideWeatherDto>.error(weatherError!);
    }
    return Future<RideWeatherDto>.value(weather ?? fixtureWeather());
  }

  /// Laisse le détail en vol indéfiniment, pour observer l'état de chargement.
  final bool neverCompletes;

  int rideCalls = 0;

  @override
  Future<RideDto> getRide(String teamSlug, String rideSlug) {
    rideCalls++;
    if (neverCompletes) return Completer<RideDto>().future;
    return Future<RideDto>.value(ride);
  }

  final List<String> joined = <String>[];
  final List<String> left = <String>[];

  /// L'erreur que rend l'inscription, à défaut un succès.
  Object? joinError;

  @override
  Future<RideParticipationDto> joinGroup(String t, String r, String g) async {
    joined.add(g);
    if (joinError != null) throw joinError!;
    return const RideParticipationDto(id: 'p', userId: 'u');
  }

  @override
  Future<void> leaveGroup(String t, String r, String g) async => left.add(g);

  // Les gestes d'organisateur (ledger `MOB-80`) ne sont pas exercés ici.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Les participants d'un groupe, pour la feuille qu'ouvrent ses visages.
class _StubParticipants implements ParticipantRepository {
  @override
  Future<PageResult<PublicUserDto>> fetchPage(
    ParticipantQuery query, {
    required int page,
    required int size,
  }) async => const PageResult<PublicUserDto>(
    items: <PublicUserDto>[PublicUserDto(id: 'u0', displayName: 'Membre 0')],
    total: 1,
  );
}

/// Le lot de tracés : vide — la carte n'a pas de style résolu ici, elle
/// reste un squelette ; ce qui est vérifié est ce qui l'entoure.
class _StubRoutes implements RouteRepository {
  _StubRoutes([this.routes = const <RouteDetailDto>[]]);

  /// Les géométries servies, par slug ; aucune par défaut.
  final List<RouteDetailDto> routes;

  @override
  Future<RoutesBulkResponse> getRoutesBulk(
    String teamSlug,
    List<String> slugs, {
    bool geometry = true,
  }) async => RoutesBulkResponse(
    routes: <RouteDetailDto>[
      for (final RouteDetailDto r in routes)
        if (slugs.contains(r.slug)) r,
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le fil de commentaires : vide, sans appel réseau.
class _StubComments implements CommentRepository {
  @override
  Future<CommentListResponse> list(
    CommentTarget target, {
    int page = 0,
    int size = 20,
    String? parentId,
    SortDirection? sort,
  }) async => CommentListResponse(
    items: const <CommentDto>[],
    total: 0,
    itemTotal: 0,
    page: page,
    size: size,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// « Maintenant » des tests : avant le départ des groupes du jeu d'essai
/// (`fixtureGroup`, le 11 octobre 2026 à 06:00 UTC).
final DateTime _now = DateTime.utc(2026, 10, 1);

class _StubTeamRepository implements TeamRepository {
  _StubTeamRepository({required this.member, this.role});

  final bool member;
  final String? role;

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => member
      ? <TeamDetailDto>[
          TeamDetailDto(
            timezone: 'Europe/Paris',
            role: role,
            id: 't1',
            slug: 'n-peloton',
            name: 'N-Peloton',
            about: const MediaDto(
              markdown: '',
              assets: AssetsDto(
                images: <AssetDto>[],
                attachments: <AssetDto>[],
              ),
            ),
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
    RideDto ride, {
    required bool member,
    Brightness? brightness,
    bool loading = false,
    _StubRideRepository? repository,
    String? role,
    List<RouteDetailDto> routes = const <RouteDetailDto>[],
    DateTime? now,
  }) {
    return ProviderScope(
      // Pas de nouvel essai : une erreur se lit tout de suite, comme avec la
      // politique de l'app sur un 4xx (`providerRetry`).
      retry: (int _, Object _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        rideRepositoryProvider.overrideWithValue(
          repository ?? _StubRideRepository(ride, neverCompletes: loading),
        ),
        teamRepositoryProvider.overrideWithValue(
          _StubTeamRepository(member: member, role: role),
        ),
        participantRepositoryProvider.overrideWithValue(_StubParticipants()),
        // Les tracés d'une sortie qui a un parcours : aucun appel réseau.
        routeRepositoryProvider.overrideWithValue(_StubRoutes(routes)),
        commentRepositoryProvider.overrideWithValue(_StubComments()),
      ],
      child: MaterialApp(
        theme: PedalonsTheme.build(brightness ?? Brightness.light),
        home: RideDetailPage(
          teamSlug: ride.team.slug,
          rideSlug: ride.slug,
          now: now ?? _now,
        ),
      ),
    );
  }

  Future<void> open(
    WidgetTester tester,
    RideDto ride, {
    bool member = true,
    Brightness brightness = Brightness.light,
    _StubRideRepository? repository,
    String? role,
    List<RouteDetailDto> routes = const <RouteDetailDto>[],
    DateTime? now,
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
        ride,
        member: member,
        brightness: brightness,
        repository: repository,
        role: role,
        routes: routes,
        now: now,
      ),
    );
    // Trois paliers asynchrones s'enchaînent : le chargement des traductions,
    // le détail, puis l'appartenance à l'équipe. Chacun demande un tour de
    // boucle d'événements ; `pumpAndSettle` est exclu, le scintillement des
    // squelettes ne se stabilise jamais.
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  /// La section Groupes vit sous la ligne de flottaison, et un
  /// `CustomScrollView` ne construit pas ce qu'il n'affiche pas.
  Future<void> scrollToGroups(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pump();
    await tester.pump();
  }

  /// Une sortie à deux groupes : ses cartes, et la page de chacun (ledger
  /// `MOB-67`). Une sortie à un seul groupe n'en a pas (ledger `MOB-69`).
  RideDto twoGroups({
    String status = 'PUBLISHED',
    String dateTime = '2099-07-29T19:30:00Z',
    bool registeredInFirst = false,
  }) => fixtureRide(
    status: status,
    dateTime: dateTime,
    registered: registeredInFirst,
    registeredGroupId: registeredInFirst ? 'g1' : null,
    groups: <RideGroupDto>[
      fixtureGroup(id: 'g1', registered: registeredInFirst),
      fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
    ],
  );

  testWidgets('le squelette est structuré, pas un rond qui tourne', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(fixtureRide(), member: true, loading: true));
    await tester.pump();

    expect(find.byType(PdlSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('une sortie annulée porte son bandeau et aucun bouton', (
    WidgetTester tester,
  ) async {
    await open(tester, twoGroups(status: 'CANCELLED', registeredInFirst: true));

    // `PdlBanner` compose titre et message dans un seul `RichText`.
    expect(
      find.textContaining('Sortie annulée.', findRichText: true),
      findsOneWidget,
    );

    await scrollToGroups(tester);
    // Pas même « Quitter » : la sortie n'a plus lieu, s'en désinscrire n'a
    // plus de sens.
    expect(find.byType(RideGroupCard), findsWidgets);
    expect(find.text('Quitter'), findsNothing);
    expect(find.text('Rejoindre'), findsNothing);
  });

  testWidgets('une sortie passée porte « Terminée » et n\'inscrit plus', (
    WidgetTester tester,
  ) async {
    await open(tester, twoGroups(dateTime: '2020-01-01T08:00:00Z'));

    expect(find.text('TERMINÉE'), findsOneWidget);

    await scrollToGroups(tester);
    expect(find.byType(RideGroupCard), findsWidgets);
    expect(find.text('Rejoindre'), findsNothing);
  });

  testWidgets('un non-membre voit le bandeau et aucun bouton d\'inscription', (
    WidgetTester tester,
  ) async {
    await open(tester, twoGroups(), member: false);

    expect(
      find.textContaining(
        'Rejoignez cette équipe pour participer aux sorties.',
        findRichText: true,
      ),
      findsOneWidget,
    );

    await scrollToGroups(tester);
    expect(find.text('Rejoindre'), findsNothing);
  });

  testWidgets('un membre se voit proposer « Rejoindre »', (
    WidgetTester tester,
  ) async {
    await open(tester, twoGroups());
    await scrollToGroups(tester);

    expect(find.byKey(keys.ride.groupJoinButton('g1')), findsOneWidget);
    expect(find.byKey(keys.ride.groupJoinButton('g2')), findsOneWidget);
  });

  testWidgets(
    'le départ est un bloc sous l\'identité : l\'heure de la sortie, puis '
    'celle du groupe de la personne',
    (WidgetTester tester) async {
      await open(
        tester,
        fixtureRide(
          dateTime: '2036-07-29T19:30:00Z',
          registered: true,
          registeredGroupId: 'g1',
          groups: <RideGroupDto>[
            fixtureGroup(
              id: 'g1',
              name: 'B',
              registered: true,
              startAt: '2036-07-29T20:00:00Z',
            ),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      final Finder block = find.byKey(keys.ride.departureBlock);
      expect(block, findsOneWidget);
      // Sous le titre (ledger `MOB-113`) : au-dessus de la grille méta.
      expect(
        tester.getTopLeft(block).dy,
        greaterThan(tester.getTopLeft(find.byKey(keys.ride.title)).dy),
      );
      expect(
        tester.getTopLeft(block).dy,
        lessThan(tester.getTopLeft(find.text('Personnes inscrites')).dy),
      );
      expect(
        find.descendant(of: block, matching: find.text('Départ 21:30')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: block,
          matching: find.text('Votre groupe : B · 22:00'),
        ),
        findsOneWidget,
      );
      expect(find.text('Date et heure'), findsNothing);
    },
  );

  /// Le bloc de départ, et ce qu'il contient.
  Finder inBlock(Finder matching) => find.descendant(
    of: find.byKey(keys.ride.departureBlock),
    matching: matching,
  );

  /// « Personnes inscrites » d'une sortie solo, et ce qu'elle contient.
  Finder inParticipants(Finder matching) => find.descendant(
    of: find.byKey(keys.ride.participantsSection),
    matching: matching,
  );

  /// Une sortie solo dont le départ — celui de la sortie et de son groupe —
  /// est passé depuis longtemps.
  RideDto pastSolo({bool registered = false}) => fixtureRide(
    dateTime: '2020-07-29T19:30:00Z',
    registered: registered,
    registeredGroupId: registered ? 'g1' : null,
    groups: <RideGroupDto>[
      fixtureGroup(
        registered: registered,
        startAt: '2020-07-29T19:30:00Z',
        routeSlug: 'court',
      ),
    ],
  );

  // ─────────────────────────────── sortie sans groupe (MOB-134, lot 7)

  testWidgets('une sortie sans groupe le dit dans son bloc de départ, sans '
      'bouton ni section Groupes', (WidgetTester tester) async {
    await open(tester, fixtureRide(groups: <RideGroupDto>[]), height: 4000);

    expect(
      inBlock(find.text('Sortie sans groupe, inscription impossible')),
      findsOneWidget,
    );
    expect(find.text('Aucun groupe'), findsNothing);
    expect(find.byType(RideGroupCard), findsNothing);
    expect(find.text('Groupes'), findsNothing);
    expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
    expect(find.byType(PdlActionBar), findsNothing);
  });

  testWidgets('une sortie sans groupe ne dit pas « Personnes inscrites »', (
    WidgetTester tester,
  ) async {
    await open(tester, fixtureRide(groups: <RideGroupDto>[]), height: 4000);
    expect(find.text('Personnes inscrites'), findsNothing);
    expect(find.byKey(keys.ride.participantsSection), findsNothing);
  });

  testWidgets('une sortie sans groupe : Distance | Dénivelé positif, sur une '
      'ligne', (WidgetTester tester) async {
    await open(
      tester,
      fixtureRide(groups: <RideGroupDto>[])
          .copyWith(distance: 92400, elevationGain: 1240),
      height: 4000,
    );

    final Finder tiles = find.byKey(keys.ride.statTiles);
    expect(tiles, findsOneWidget);
    for (final String label in <String>['Distance', 'Dénivelé positif']) {
      expect(
        find.descendant(of: tiles, matching: find.text(label)),
        findsOneWidget,
      );
    }
    for (final String label in <String>['Durée estimée', 'Vitesse moyenne']) {
      expect(find.text(label), findsNothing);
    }
  });

  for (final Brightness brightness in Brightness.values) {
    final String mode = brightness == Brightness.light ? 'clair' : 'sombre';
    testWidgets('l\'écran se rend sans débordement — $mode', (
      WidgetTester tester,
    ) async {
      await open(tester, twoGroups(), brightness: brightness);
      expect(tester.takeException(), isNull);
      expect(find.text('N-Peloton #665'), findsWidgets);

      await scrollToGroups(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Groupes'), findsOneWidget);
    });

    testWidgets('une sortie solo se rend sans débordement — $mode', (
      WidgetTester tester,
    ) async {
      await open(tester, fixtureRide(), brightness: brightness);
      expect(tester.takeException(), isNull);

      await scrollToGroups(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(keys.ride.participantsSection), findsOneWidget);
    });

    testWidgets('une sortie sans groupe se rend sans débordement — $mode', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        fixtureRide(groups: <RideGroupDto>[]),
        brightness: brightness,
        height: 4000,
      );
      expect(tester.takeException(), isNull);
    });
  }

  // ─────────────────────────────── l'ordre des maquettes (MOB-134, lot 7)

  group('l\'ordre des maquettes', () {
    setUp(() => RideGroupsMap.debugSkipNativeMap = true);
    tearDown(() => RideGroupsMap.debugSkipNativeMap = false);

    const MediaDto described = MediaDto(
      markdown: 'Boucle vallonnée par le Roc\'h Trévezel.',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
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

    testWidgets('sortie-solo-mobile-cible', (WidgetTester tester) async {
      final RideDto ride = fixtureRide(
        groups: <RideGroupDto>[fixtureGroup(routeSlug: 'court')],
      ).copyWith(media: described, commentCount: 2);
      await open(
        tester,
        ride,
        height: 6000,
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(
            status: 'OK',
            departure: fixtureConditions(),
            fetchedAt: '2099-07-29T17:00:00Z',
            legs: <WeatherLegDto>[fixtureLeg()],
          ),
        ),
      );

      expectOrder(tester, <Key>[
        keys.ride.title,
        keys.ride.departureBlock,
        keys.ride.statTiles,
        keys.ride.routeSection,
        keys.ride.descriptionSection,
        keys.ride.participantsSection,
        keys.ride.weatherBlock,
        keys.ride.commentsSection,
      ]);
      // L'inscription est dans le bloc de départ ; ni barre d'action, ni
      // carte météo au-dessus de la carte, ni section du groupe.
      expect(inBlock(find.byKey(keys.rideGroup.joinButton)), findsOneWidget);
      expect(find.byType(PdlActionBar), findsNothing);
      expect(find.byKey(keys.ride.weatherCard), findsNothing);
      expect(find.byType(RideGroupCard), findsNothing);
      // « Météo le long du parcours » replié : des commentaires suivent.
      expect(find.byKey(keys.ride.weatherAlongRoute), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sortie-sans-groupe-mobile-cible', (WidgetTester tester) async {
      final RideDto ride = fixtureRide(groups: <RideGroupDto>[]).copyWith(
        routeSlug: 'court',
        distance: 92400,
        elevationGain: 1240,
        media: described,
        commentCount: 2,
      );
      await open(
        tester,
        ride,
        height: 6000,
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(
            status: 'OK',
            departure: fixtureConditions(),
            fetchedAt: '2099-07-29T17:00:00Z',
            legs: <WeatherLegDto>[
              fixtureLeg(groupId: null, speedIsDefault: true),
            ],
          ),
        ),
      );

      expectOrder(tester, <Key>[
        keys.ride.title,
        keys.ride.departureBlock,
        keys.ride.statTiles,
        keys.ride.routeSection,
        keys.ride.descriptionSection,
        keys.ride.weatherBlock,
        keys.ride.commentsSection,
      ]);
      expect(find.byKey(keys.ride.participantsSection), findsNothing);
      expect(find.text('Groupes'), findsNothing);
      // La vitesse par défaut n'est le fait d'aucun groupe.
      expect(find.textContaining(', vitesse par défaut'), findsOneWidget);
      expect(find.textContaining('le groupe n\'en indique pas'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sans parcours : pas de section Parcours', (
      WidgetTester tester,
    ) async {
      await open(tester, fixtureRide(groups: <RideGroupDto>[]), height: 4000);
      expect(find.byKey(keys.ride.routeSection), findsNothing);
      expect(find.text('Parcours'), findsNothing);
    });
  });

  // ──────────────────────────────────────── badges de phase (SYNTHESE §6.2)

  group('badges de phase', () {
    RideDto leaving() => fixtureRide(
      dateTime: '2026-10-11T06:00:00Z',
      groups: <RideGroupDto>[fixtureGroup(startAt: '2026-10-11T06:00:00Z')],
    );

    testWidgets('« En cours » entre le départ et l\'arrivée', (
      WidgetTester tester,
    ) async {
      await open(tester, leaving(), now: DateTime.utc(2026, 10, 11, 7));

      expect(find.byKey(keys.ride.underWayBadge), findsOneWidget);
      expect(find.text('EN COURS'), findsOneWidget);
      expect(find.byKey(keys.ride.finishedBadge), findsNothing);
    });

    testWidgets('« Terminée » une fois arrivée, plus « En cours »', (
      WidgetTester tester,
    ) async {
      await open(tester, leaving(), now: DateTime.utc(2026, 10, 11, 10));

      expect(find.byKey(keys.ride.finishedBadge), findsOneWidget);
      expect(find.byKey(keys.ride.underWayBadge), findsNothing);
    });

    testWidgets('à venir : ni l\'un ni l\'autre', (WidgetTester tester) async {
      await open(tester, leaving());

      expect(find.byKey(keys.ride.finishedBadge), findsNothing);
      expect(find.byKey(keys.ride.underWayBadge), findsNothing);
    });
  });

  group('météo', () {
    RideWeatherDto ok({String status = 'OK'}) => fixtureWeather(
      status: status,
      departure: fixtureConditions(),
      fetchedAt: '2099-07-29T17:00:00Z',
      legs: <WeatherLegDto>[
        fixtureLeg(
          rainAlert: _rain70,
          summary: fixtureLegSummary(rainAlert: _rain70),
        ),
      ],
    );

    testWidgets('plusieurs groupes : la carte dit la météo au départ, et elle '
        'seule', (WidgetTester tester) async {
      final RideDto ride = twoGroups();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: ok()),
      );

      expect(find.byKey(keys.ride.weatherCard), findsOneWidget);
      expect(find.textContaining('Météo au départ de '), findsOneWidget);
      expect(find.text('14 °C'), findsWidgets);
      expect(find.text('Partiellement nuageux'), findsWidgets);
      expect(find.textContaining('Ressenti'), findsOneWidget);
      // Ni le vent le long du parcours ni l'alerte pluie d'un groupe : ils
      // vivent dans la page du groupe (ledger `MOB-67`).
      expect(find.byType(PdlSegmentBar), findsNothing);
      expect(find.textContaining('Pluie probable'), findsNothing);
      expect(find.byKey(keys.ride.weatherOpenButton), findsNothing);
      expect(find.text('Voir la météo du parcours'), findsNothing);
      expect(find.text('Prévision ancienne'), findsNothing);
      expect(find.byKey(keys.ride.weatherSection), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('une sortie sans groupe : la section Météo garde son vent et '
        'sa pluie', (WidgetTester tester) async {
      final RideDto ride = fixtureRide(groups: const <RideGroupDto>[]);
      final RideWeatherDto weather = fixtureWeather(
        status: 'OK',
        departure: fixtureConditions(),
        legs: <WeatherLegDto>[fixtureLeg(groupId: null, rainAlert: _rain70)],
      );
      await open(
        tester,
        ride,
        height: 4000,
        repository: _StubRideRepository(ride, weather: weather),
      );

      expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCard), findsNothing);
      expect(find.byKey(keys.ride.weatherExposure), findsOneWidget);
      expect(
        find.textContaining('Pluie probable (70 %)', findRichText: true),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('une sortie à un groupe déroule le leg de son groupe, frise '
        'repliée', (WidgetTester tester) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        height: 4000,
        repository: _StubRideRepository(ride, weather: ok()),
      );

      expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCard), findsNothing);
      // Un seul « Météo au départ ».
      expect(find.textContaining('Météo au départ de '), findsOneWidget);
      expect(
        find.textContaining('Pluie probable (70 %)', findRichText: true),
        findsWidgets,
      );
      expect(find.text('Exposition au vent'), findsOneWidget);
      expect(find.byKey(keys.ride.weatherExposure), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);

      await tester.tap(find.byKey(keys.ride.weatherAlongRoute));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(2)), findsOneWidget);
      // Ni carte de groupe, ni sa ligne météo courte.
      expect(find.byKey(keys.ride.groupWeatherLine('g1')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('une sortie à un groupe ne prête pas le leg d\'un autre', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        height: 4000,
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(
            status: 'OK',
            departure: fixtureConditions(),
            legs: <WeatherLegDto>[fixtureLeg(groupId: 'other')],
          ),
        ),
      );

      expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
      expect(find.byKey(keys.ride.weatherExposure), findsNothing);
      expect(find.byKey(keys.ride.weatherAlongRoute), findsNothing);
    });

    testWidgets('la carte d\'un groupe porte sa ligne météo', (
      WidgetTester tester,
    ) async {
      final RideDto ride = twoGroups();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: ok()),
      );
      await scrollToGroups(tester);

      expect(find.byKey(keys.ride.groupWeatherLine('g1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(keys.ride.groupWeatherLine('g1')),
          matching: find.textContaining('Pluie 70\u00a0% vers'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('plusieurs groupes : la carte compacte crédite Open-Meteo '
        '(CC BY 4.0)', (WidgetTester tester) async {
      final RideDto ride = twoGroups();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: ok()),
      );

      expect(find.byKey(keys.ride.weatherAttribution), findsOneWidget);
      expect(find.text('Prévisions : Open-Meteo.com'), findsOneWidget);
    });

    testWidgets('une sortie solo : la prévision et sa source au pied de la '
        'section', (WidgetTester tester) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        height: 4000,
        repository: _StubRideRepository(ride, weather: ok()),
      );

      expect(find.byKey(keys.ride.weatherForecastOf), findsOneWidget);
      expect(find.byKey(keys.ride.weatherSourceButton), findsOneWidget);
    });

    group('pendant le chargement', () {
      final Finder weatherSkeleton = find.byWidgetPredicate(
        (Widget w) => w is PdlSkeleton && w.height == 96,
      );

      Future<void> openLoading(
        WidgetTester tester,
        RideDto ride, {
        double? height,
      }) => open(
        tester,
        ride,
        height: height,
        repository: _StubRideRepository(ride)..weatherNeverCompletes = true,
      );

      testWidgets('plusieurs groupes : un squelette quand le résumé annonce '
          'une prévision', (WidgetTester tester) async {
        await openLoading(
          tester,
          twoGroups().copyWith(
            weather: const RideWeatherSummaryDto(status: 'OK', temperature: 14),
          ),
        );

        expect(weatherSkeleton, findsOneWidget);
      });

      testWidgets('plusieurs groupes, NOT_YET_AVAILABLE : la carte, tout de '
          'suite', (WidgetTester tester) async {
        await openLoading(
          tester,
          twoGroups().copyWith(
            weather: const RideWeatherSummaryDto(
              status: 'NOT_YET_AVAILABLE',
              availableFrom: '2099-07-22T19:30:00Z',
            ),
          ),
        );

        expect(weatherSkeleton, findsNothing);
        expect(find.byKey(keys.ride.weatherNotYetAvailable), findsOneWidget);
      });

      testWidgets('plusieurs groupes, sans résumé : rien', (
        WidgetTester tester,
      ) async {
        await openLoading(tester, twoGroups());

        expect(weatherSkeleton, findsNothing);
        expect(find.byKey(keys.ride.weatherCard), findsNothing);
      });

      testWidgets('une sortie solo : l\'attente de la section', (
        WidgetTester tester,
      ) async {
        await openLoading(tester, fixtureRide(), height: 4000);

        expect(find.byKey(keys.ride.weatherLoading), findsOneWidget);
        expect(find.byKey(keys.ride.weatherSection), findsNothing);
      });
    });

    testWidgets('plusieurs groupes : STALE se montre, et se signale', (
      WidgetTester tester,
    ) async {
      final RideDto ride = twoGroups();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: ok(status: 'STALE')),
      );

      expect(find.byKey(keys.ride.weatherCard), findsOneWidget);
      expect(find.text('PRÉVISION ANCIENNE'), findsOneWidget);
    });

    testWidgets('une sortie solo : STALE se signale par un bandeau', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        height: 4000,
        repository: _StubRideRepository(ride, weather: ok(status: 'STALE')),
      );

      expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
      expect(
        find.textContaining('Prévision ancienne', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('toucher la carte d\'un groupe ouvre sa page', (
      WidgetTester tester,
    ) async {
      final RideDto ride = twoGroups();
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext _, GoRouterState _) =>
                RideDetailPage(teamSlug: ride.team.slug, rideSlug: ride.slug),
          ),
          for (final String path in PathVariants.rideGroup(
            ':teamSlug',
            ':rideSlug',
            ':groupId',
          ).values)
            GoRoute(
              path: path,
              builder: (BuildContext _, GoRouterState state) => RideGroupPage(
                teamSlug: state.pathParameters['teamSlug']!,
                rideSlug: state.pathParameters['rideSlug']!,
                groupId: state.pathParameters['groupId']!,
                scrollToWeather:
                    state.uri.queryParameters['tab'] == kRideGroupWeatherTab,
              ),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          retry: (int _, Object _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            rideRepositoryProvider.overrideWithValue(
              _StubRideRepository(ride, weather: ok()),
            ),
            teamRepositoryProvider.overrideWithValue(
              _StubTeamRepository(member: true),
            ),
            participantRepositoryProvider.overrideWithValue(
              _StubParticipants(),
            ),
          ],
          child: MaterialApp.router(
            theme: PedalonsTheme.build(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await scrollToGroups(tester);

      await tester.tap(find.byKey(keys.ride.group('g1')));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(RideGroupPage), findsOneWidget);
      expect(find.byKey(keys.rideGroup.departureBlock), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UNAVAILABLE propose de réessayer, et réessaie', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      final _StubRideRepository repository = _StubRideRepository(
        ride,
        weather: fixtureWeather(status: 'UNAVAILABLE'),
      );
      await open(tester, ride, repository: repository, height: 4000);

      expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
      expect(find.byKey(keys.ride.weatherUnavailable), findsOneWidget);
      final int before = repository.weatherCalls;
      await tester.tap(find.byKey(keys.ride.weatherRetryButton));
      await tester.pump();
      await tester.pump();
      expect(repository.weatherCalls, before + 1);
    });

    testWidgets('un échec de l\'appel se lit comme UNAVAILABLE', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      final _StubRideRepository repository = _StubRideRepository(ride)
        ..weatherError = Exception('réseau');
      await open(tester, ride, repository: repository, height: 4000);

      expect(find.byKey(keys.ride.weatherUnavailable), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NOT_YET_AVAILABLE donne la date d\'ouverture', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        height: 4000,
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(
            status: 'NOT_YET_AVAILABLE',
            availableFrom: '2099-07-22T19:30:00Z',
          ),
        ),
      );

      expect(find.byKey(keys.ride.weatherNotYetAvailable), findsOneWidget);
      expect(
        find.textContaining(
          'Prévision disponible à partir du',
          findRichText: true,
        ),
        findsWidgets,
      );
    });

    testWidgets('NOT_YET_AVAILABLE sans date : la règle des sept jours', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        height: 4000,
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(status: 'NOT_YET_AVAILABLE'),
        ),
      );

      expect(find.byKey(keys.ride.weatherNotYetAvailable), findsOneWidget);
      expect(
        find.textContaining(
          'La météo sera disponible sept jours avant le départ.',
          findRichText: true,
        ),
        findsWidgets,
      );
    });

    testWidgets('NO_LOCATION pour un membre : le titre et une ligne, pas le '
        'mot aux organisateurs', (WidgetTester tester) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        role: 'MEMBER',
        height: 4000,
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(status: 'NO_LOCATION'),
        ),
      );

      expect(find.byKey(keys.ride.weatherNoLocation), findsNothing);
      expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
      expect(find.byKey(keys.ride.weatherEmpty), findsOneWidget);
    });

    testWidgets('NO_LOCATION : un mot pour l\'organisateur', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        role: 'ORGANIZER',
        height: 4000,
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(status: 'NO_LOCATION'),
        ),
      );

      expect(find.byKey(keys.ride.weatherNoLocation), findsOneWidget);
    });

    for (final String status in <String>['OUT_OF_RANGE', 'SOMETHING_NEW']) {
      testWidgets('$status : le titre « Météo » et une ligne d\'explication', (
        WidgetTester tester,
      ) async {
        final RideDto ride = fixtureRide();
        await open(
          tester,
          ride,
          height: 4000,
          repository: _StubRideRepository(
            ride,
            weather: fixtureWeather(status: status),
          ),
        );

        expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
        expect(
          find.text('Aucune prévision n\'est à afficher pour cette sortie.'),
          findsOneWidget,
        );
        expect(find.byKey(keys.ride.weatherUnavailable), findsNothing);
        expect(find.byKey(keys.ride.weatherCard), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('une sortie terminée ne demande même pas la météo', (
      WidgetTester tester,
    ) async {
      final RideDto ride = pastSolo();
      final _StubRideRepository repository = _StubRideRepository(
        ride,
        weather: ok(),
      );
      await open(tester, ride, repository: repository, height: 4000);

      expect(find.byKey(keys.ride.weatherBlock), findsNothing);
      expect(find.byKey(keys.ride.weatherSection), findsNothing);
      expect(repository.weatherCalls, 0);
    });

    testWidgets('une sortie en cours garde sa météo', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide(
        dateTime: '2026-10-11T06:00:00Z',
        groups: <RideGroupDto>[fixtureGroup(startAt: '2026-10-11T06:00:00Z')],
      );
      final _StubRideRepository repository = _StubRideRepository(
        ride,
        weather: ok(),
      );
      await open(
        tester,
        ride,
        repository: repository,
        height: 4000,
        now: DateTime.utc(2026, 10, 11, 7),
      );

      expect(repository.weatherCalls, 1);
      expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
    });

    testWidgets('le pull-to-refresh reprend aussi la météo', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      final _StubRideRepository repository = _StubRideRepository(
        ride,
        weather: ok(),
      );
      // `PdlRefresh` attend sa secousse avant de rafraîchir : sans réponse du
      // canal de la plateforme, elle n'arrive jamais.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform,
            (MethodCall _) async => null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await open(tester, ride, repository: repository);
      final int before = repository.weatherCalls;

      // Le geste lui-même est l'affaire de `pdl_refresh_test.dart` ; ici, ce
      // qu'il déclenche.
      unawaited(
        tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show(),
      );
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(repository.rideCalls, greaterThan(1));
      expect(repository.weatherCalls, greaterThan(before));
    });
  });

  // ─────────────────────────────────── sortie solo (ledgers MOB-69, MOB-134)

  group('sortie à un seul groupe', () {
    RideWeatherDto ok() => fixtureWeather(
      status: 'OK',
      departure: fixtureConditions(),
      fetchedAt: '2099-07-29T17:00:00Z',
      legs: <WeatherLegDto>[fixtureLeg()],
    );

    testWidgets('ni carte de groupe ni barre d\'action : le détail est la '
        'page du groupe', (WidgetTester tester) async {
      await open(tester, fixtureRide(), height: 4000);

      expect(find.byType(RideGroupCard), findsNothing);
      expect(find.text('Groupes'), findsNothing);
      expect(find.byType(PdlActionBar), findsNothing);
      expect(find.byKey(keys.ride.participantsSection), findsOneWidget);
      // « Voir toutes les personnes inscrites » est dans la section.
      expect(
        inParticipants(find.byKey(keys.rideGroup.viewAllParticipants)),
        findsOneWidget,
      );
      // Plus de « Voir la liste » de l'ancien bloc méta.
      expect(find.byKey(keys.ride.participantsButton), findsNothing);
    });

    testWidgets('une seule heure à l\'écran : celle du groupe', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        fixtureRide(
          dateTime: '2026-10-11T05:30:00Z',
          groups: <RideGroupDto>[fixtureGroup(startAt: '2026-10-11T06:00:00Z')],
        ),
      );

      // 06:00 UTC, à Paris en octobre : 08:00.
      expect(inBlock(find.text('Départ 08:00')), findsOneWidget);
      expect(find.text('Départ 07:30'), findsNothing);
      expect(inBlock(find.textContaining('Votre groupe')), findsNothing);
    });

    testWidgets('les tuiles du groupe, et son arrivée estimée dans le bloc', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: ok()),
      );

      final Finder tiles = find.byKey(keys.ride.statTiles);
      for (final String label in <String>[
        'Distance',
        'Dénivelé positif',
        'Vitesse moyenne',
      ]) {
        expect(
          find.descendant(of: tiles, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(inBlock(find.textContaining('Arrivée estimée')), findsOneWidget);
    });

    testWidgets('« Rejoindre » dans le bloc de départ, sans confirmation ; '
        'les places dans « Personnes inscrites »', (WidgetTester tester) async {
      final RideDto ride = fixtureRide();
      final _StubRideRepository repository = _StubRideRepository(ride);
      await open(tester, ride, repository: repository, height: 4000);

      expect(inParticipants(find.text('3/16')), findsOneWidget);
      expect(inParticipants(find.text('13 places restantes')), findsOneWidget);

      await tester.tap(inBlock(find.byKey(keys.rideGroup.joinButton)));
      await tester.pump();
      await tester.pump();

      expect(repository.joined, <String>['g1']);
    });

    testWidgets('un refus de « Rejoindre » pose son bandeau au-dessus du bloc '
        'de départ, à l\'écran', (WidgetTester tester) async {
      final RideDto ride = fixtureRide();
      final _StubRideRepository repository = _StubRideRepository(ride)
        ..joinError = DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 409,
            data: <String, dynamic>{'code': 'GROUP_FULL'},
          ),
        );
      await open(tester, ride, repository: repository);

      await tester.tap(find.byKey(keys.rideGroup.joinButton));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final Finder banner = find.byKey(keys.ride.registrationFailure);
      expect(banner, findsOneWidget);
      final Rect shown = tester.getRect(banner);
      final Size screen =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(shown.top, greaterThanOrEqualTo(0));
      expect(shown.bottom, lessThanOrEqualTo(screen.height));
      expect(
        shown.top,
        lessThan(tester.getTopLeft(find.byKey(keys.ride.departureBlock)).dy),
      );
    });

    testWidgets('inscrit : « J\'y vais » dans le bloc, « Quitter le groupe » '
        'au pied de « Personnes inscrites »', (WidgetTester tester) async {
      final RideDto ride = fixtureRide(
        registered: true,
        registeredGroupId: 'g1',
        groups: <RideGroupDto>[fixtureGroup(registered: true)],
      );
      final _StubRideRepository repository = _StubRideRepository(ride);
      await open(tester, ride, repository: repository, height: 4000);

      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      expect(inBlock(find.byKey(keys.rideGroup.goingBadge)), findsOneWidget);
      final Finder leave = inParticipants(
        find.byKey(keys.rideGroup.leaveButton),
      );
      expect(leave, findsOneWidget);
      await tester.tap(leave);
      await tester.pump();
      await tester.pump();

      expect(repository.left, <String>['g1']);
    });

    testWidgets('le groupe parti, inscrit : « J\'y vais » et « Quitter le '
        'groupe » restent', (WidgetTester tester) async {
      await open(
        tester,
        fixtureRide(
          dateTime: '2026-10-11T06:00:00Z',
          registered: true,
          registeredGroupId: 'g1',
          groups: <RideGroupDto>[
            fixtureGroup(registered: true, startAt: '2026-10-11T06:00:00Z'),
          ],
        ),
        now: DateTime.utc(2026, 10, 11, 7),
        height: 4000,
      );

      expect(find.byKey(keys.rideGroup.goingBadge), findsOneWidget);
      expect(find.byKey(keys.rideGroup.leaveButton), findsOneWidget);
      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
    });

    testWidgets('le groupe parti, pas inscrit : plus de « Rejoindre »', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        fixtureRide(
          dateTime: '2026-10-11T06:00:00Z',
          groups: <RideGroupDto>[fixtureGroup(startAt: '2026-10-11T06:00:00Z')],
        ),
        now: DateTime.utc(2026, 10, 11, 7),
      );

      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      expect(find.byKey(keys.rideGroup.goingBadge), findsNothing);
    });

    testWidgets('un groupe complet : « Complet », aucun bouton', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        fixtureRide(
          groups: <RideGroupDto>[
            fixtureGroup(full: true, countParticipants: 16),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.fullBadge), findsOneWidget);
      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
    });

    for (final (String label, RideDto ride, bool member)
        in <(String, RideDto, bool)>[
          ('un non-membre', fixtureRide(), false),
          ('une sortie passée', pastSolo(), true),
          (
            'une sortie annulée',
            fixtureRide(
              status: 'CANCELLED',
              registered: true,
              registeredGroupId: 'g1',
              groups: <RideGroupDto>[fixtureGroup(registered: true)],
            ),
            true,
          ),
        ]) {
      testWidgets('$label : aucun bouton d\'inscription', (
        WidgetTester tester,
      ) async {
        await open(tester, ride, member: member, height: 4000);

        expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
        expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);
        expect(find.byKey(keys.rideGroup.goingBadge), findsNothing);
        expect(find.text('Rejoindre'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('capitaine nul : rien, jamais de repli', (
      WidgetTester tester,
    ) async {
      await open(tester, fixtureRide(), height: 4000);

      expect(find.byKey(keys.ride.participantsSection), findsOneWidget);
      expect(find.byKey(keys.rideGroup.leader), findsNothing);
      expect(find.text('CAPITAINE'), findsNothing);
    });

    testWidgets('une personne capitaine : son nom et le badge', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        fixtureRide(
          groups: <RideGroupDto>[
            fixtureGroup(
              leader: const PublicUserDto(id: 'l1', displayName: 'Léa'),
            ),
          ],
        ),
        height: 4000,
      );

      expect(inParticipants(find.byKey(keys.rideGroup.leader)), findsOneWidget);
      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('CAPITAINE'), findsOneWidget);
    });

    testWidgets('les visages du groupe ouvrent la feuille du groupe', (
      WidgetTester tester,
    ) async {
      await open(tester, fixtureRide(), height: 4000);

      await tester.tap(find.byKey(keys.rideGroup.participantsAvatars));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(ParticipantsSheet), findsOneWidget);
      expect(find.text('Membre 0'), findsWidgets);
    });

    testWidgets('un non-membre ne reçoit que le nombre : ni capitaine, ni '
        'visages, ni liste', (WidgetTester tester) async {
      await open(
        tester,
        fixtureRide(
          groups: <RideGroupDto>[
            fixtureGroup(
              leader: const PublicUserDto(id: 'l1', displayName: 'Léa'),
            ),
          ],
        ),
        member: false,
        height: 4000,
      );

      expect(inParticipants(find.text('3/16')), findsOneWidget);
      expect(find.byKey(keys.rideGroup.leader), findsNothing);
      expect(find.byKey(keys.rideGroup.participantsAvatars), findsNothing);
      expect(find.byKey(keys.rideGroup.viewAllParticipants), findsNothing);
      expect(find.text('Léa'), findsNothing);
    });
  });

  // ───────────────────────────── défilements (MOB-69, MOB-134 retouche 1)

  group('défilements', () {
    RideWeatherDto served() => fixtureWeather(
      status: 'OK',
      departure: fixtureConditions(),
      fetchedAt: '2099-07-29T17:00:00Z',
      legs: <WeatherLegDto>[fixtureLeg()],
    );

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(RideDetailPage)));

    const RideKey key = RideKey(teamSlug: 'n-peloton', rideSlug: 'np-665');

    testWidgets('?tab=weather d\'une sortie solo : le détail défile jusqu\'à '
        'sa section Météo', (WidgetTester tester) async {
      final RideDto ride = fixtureRide(
        groups: <RideGroupDto>[fixtureGroup(routeSlug: 'court')],
      );
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: served()),
      );
      expect(find.byKey(keys.ride.weatherBlock), findsNothing);

      containerOf(tester)
              .read(rideScrollToWeatherProvider(key).notifier)
              .state =
          true;
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final Finder weather = find.byKey(keys.ride.weatherBlock);
      expect(weather, findsOneWidget);
      final Size screen =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getTopLeft(weather).dy, lessThan(screen.height));
      expect(
        containerOf(tester).read(rideScrollToWeatherProvider(key)),
        isFalse,
      );
    });

    testWidgets('toucher un point de la frise remonte jusqu\'à la carte ; le '
        'retoucher ôte le réticule sans défiler', (WidgetTester tester) async {
      final RideDto ride = fixtureRide(
        groups: <RideGroupDto>[fixtureGroup(routeSlug: 'court')],
      );
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: served()),
      );

      final Finder along = find.byKey(
        keys.ride.weatherAlongRoute,
        skipOffstage: false,
      );
      await tester.ensureVisible(along);
      await tester.pump();
      await tester.tap(along);
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final Finder point = find.byKey(
        keys.ride.weatherCheckpoint(1),
        skipOffstage: false,
      );
      await tester.ensureVisible(point);
      await tester.pump();
      final Finder map = find.byType(RideGroupsMap, skipOffstage: false);
      // La frise à l'écran, la carte est loin au-dessus.
      expect(tester.getTopLeft(map).dy, lessThan(0));

      await tester.tap(point);
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(map, findsOneWidget);
      expect(tester.widget<RideGroupsMap>(map).cursorDistance, isNotNull);
      final Size screen =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      final double top = tester.getTopLeft(map).dy;
      expect(top, greaterThanOrEqualTo(0));
      expect(top, lessThan(screen.height));

      await tester.ensureVisible(point);
      await tester.pump();
      final ScrollPosition position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final double offset = position.pixels;
      await tester.tap(point);
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(position.pixels, offset);
      expect(find.byKey(keys.ride.weatherCheckpoint(1)), findsOneWidget);
    });
  });

  // ─────────────────── sortie solo : le mode « Météo » de la carte (MOB-94)

  group('sortie solo, mode « Météo » de la carte', () {
    final RideDto solo = fixtureRide(
      groups: <RideGroupDto>[fixtureGroup(routeSlug: 'court')],
    );
    const RideKey key = RideKey(teamSlug: 'n-peloton', rideSlug: 'np-665');

    RideWeatherDto served({String status = 'OK'}) => fixtureWeather(
      status: status,
      departure: fixtureConditions(),
      fetchedAt: '2099-07-29T17:00:00Z',
      legs: <WeatherLegDto>[fixtureLeg(status: status)],
    );

    /// Une page assez haute pour que la carte et sa puce soient construites :
    /// un `CustomScrollView` ne construit pas ce qu'il n'affiche pas, et un
    /// « rien » ne prouverait alors rien.
    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(402 * 3, 4000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    /// Le segment « Météo » de l'interrupteur unique (ledger `MOB-105`).
    Finder windSegment() => find.byKey(keys.routeDetail.colorByMode('wind'));

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(RideDetailPage)));

    testWidgets('une prévision : l\'interrupteur sous la carte, sur la pente '
        'par défaut', (WidgetTester tester) async {
      tall(tester);
      await open(
        tester,
        solo,
        repository: _StubRideRepository(solo, weather: served()),
      );

      final Finder toggle = find.byKey(keys.ride.mapColorBy);
      expect(toggle, findsOneWidget);
      expect(
        tester.widget<RouteColorModeSwitch>(toggle).value,
        RouteColorBy.grade,
      );
      expect(
        containerOf(tester).read(rideMapColorModeProvider(key)),
        RouteColorBy.grade,
      );

      final Finder chip = windSegment();
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
      expect(
        containerOf(tester).read(rideMapColorModeProvider(key)),
        RouteColorBy.wind,
      );
      expect(
        tester.widget<RouteColorModeSwitch>(toggle).value,
        RouteColorBy.wind,
      );
    });

    testWidgets('deux parcours : la puce « Météo », que le parcours du groupe '
        'masqué dans les couches retire', (WidgetTester tester) async {
      tall(tester);
      final RideDto twoLayers = solo.copyWith(routeSlug: 'principal');
      await open(
        tester,
        twoLayers,
        repository: _StubRideRepository(twoLayers, weather: served()),
      );
      // La carte garde ses couleurs de couche, comme au site : pas
      // d'interrupteur Pente | Revêtement | Météo sous elle.
      expect(find.byKey(keys.ride.mapColorBy), findsNothing);
      expect(windSegment(), findsNothing);
      final Finder chip = find.byKey(keys.ride.windMapChip);
      expect(chip, findsOneWidget);

      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
      expect(
        containerOf(tester).read(rideMapColorModeProvider(key)),
        RouteColorBy.wind,
      );
      await tester.tap(chip);
      await tester.pump();
      expect(
        containerOf(tester).read(rideMapColorModeProvider(key)),
        RouteColorBy.grade,
      );

      containerOf(tester)
          .read(hiddenRideRoutesProvider(key).notifier)
          .state = <String>{
        'court',
      };
      await tester.pump();
      expect(find.byKey(keys.ride.windMapChip), findsNothing);
    });

    for (final String status in <String>[
      'NOT_YET_AVAILABLE',
      'UNAVAILABLE',
      'NO_LOCATION',
    ]) {
      testWidgets('$status : pas de « Météo »', (WidgetTester tester) async {
        tall(tester);
        await open(
          tester,
          solo,
          repository: _StubRideRepository(
            solo,
            weather: served(status: status),
          ),
        );
        expect(windSegment(), findsNothing);
      });
    }

    testWidgets('une sortie terminée : pas de « Météo », pas de météo', (
      WidgetTester tester,
    ) async {
      tall(tester);
      final RideDto past = pastSolo();
      final _StubRideRepository repository = _StubRideRepository(
        past,
        weather: served(),
      );
      await open(tester, past, repository: repository);
      expect(windSegment(), findsNothing);
      expect(repository.weatherCalls, 0);
    });

    testWidgets('une sortie annulée : pas de « Météo »', (
      WidgetTester tester,
    ) async {
      tall(tester);
      final RideDto cancelled = fixtureRide(
        status: 'CANCELLED',
        groups: <RideGroupDto>[fixtureGroup(routeSlug: 'court')],
      );
      await open(
        tester,
        cancelled,
        repository: _StubRideRepository(cancelled, weather: served()),
      );
      expect(windSegment(), findsNothing);
    });

    testWidgets(
      'plusieurs groupes : pas de « Météo » sous la carte de la sortie',
      (WidgetTester tester) async {
        tall(tester);
        final RideDto two = fixtureRide(
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', routeSlug: 'court'),
            fixtureGroup(id: 'g2', name: 'Cool', routeSlug: 'long'),
          ],
        );
        await open(
          tester,
          two,
          repository: _StubRideRepository(two, weather: served()),
        );
        expect(windSegment(), findsNothing);
      },
    );

    testWidgets('une prévision perdue au refetch ramène le mode sur la pente, '
        'il ne revient pas seul', (WidgetTester tester) async {
      tall(tester);
      final _StubRideRepository repository = _StubRideRepository(
        solo,
        weather: served(),
      );
      await open(tester, solo, repository: repository);
      final ProviderContainer container = containerOf(tester);
      container.read(rideMapColorModeProvider(key).notifier).state =
          RouteColorBy.wind;
      await tester.pump();

      repository.weather = served(status: 'UNAVAILABLE');
      container.invalidate(rideWeatherProvider(key));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);
      expect(windSegment(), findsNothing);

      // Revenue, la prévision rend « Météo », sans le choisir.
      repository.weather = served();
      container.invalidate(rideWeatherProvider(key));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(windSegment(), findsOneWidget);
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);
    });

    testWidgets('le choix survit tant que la page est montée', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        solo,
        repository: _StubRideRepository(solo, weather: served()),
      );
      final ProviderContainer container = containerOf(tester);
      container.read(rideMapColorModeProvider(key).notifier).state =
          RouteColorBy.wind;
      // La page défile : la carte et sa puce quittent l'écran.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.wind);
    });
  });

  // ─────── carte aux couleurs de ses couches : le profil a son interrupteur

  group('carte aux couleurs de ses couches, Pente | Revêtement avec le '
      'profil (MOB-105)', () {
    const RideKey key = RideKey(teamSlug: 'n-peloton', rideSlug: 'np-665');

    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(402 * 3, 4000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    /// Un parcours au revêtement connu : le profil peut se colorer par lui.
    RouteDetailDto surfaced(String slug) => fixtureRouteDetail(slug: slug)
        .copyWith(
          tracks: <TrackDto>[
            TrackDto(
              line: GeoJsonLineString(
                type: GeoJsonLineStringTypeType.lineString,
                coordinates: <List<double>>[
                  for (int i = 0; i <= 10; i++)
                    <double>[5, 45 + i * 100 / 111195, 100.0 + i * 5, i * 100],
                ],
              ),
              climbs: const <ClimbDto>[],
              surfaceState: 'READY',
              surfaces: const <SurfaceSpanDto>[
                SurfaceSpanDto(from: 0, to: 400, surface: TrackSurface.paved),
                SurfaceSpanDto(
                  from: 400,
                  to: 1000,
                  surface: TrackSurface.gravel,
                ),
              ],
            ),
          ],
        );

    RideWeatherDto served() => fixtureWeather(
      departure: fixtureConditions(),
      fetchedAt: '2099-07-29T17:00:00Z',
      legs: <WeatherLegDto>[fixtureLeg()],
    );

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(RideDetailPage)));

    Finder profileSegment(String mode) => find.descendant(
      of: find.byKey(keys.ride.profileColorBy),
      matching: find.byKey(keys.routeDetail.colorByMode(mode)),
    );

    Future<void> chooseSurface(WidgetTester tester) async {
      await tester.ensureVisible(profileSegment('surface'));
      await tester.pump();
      await tester.tap(profileSegment('surface'));
      await tester.pump();
    }

    testWidgets('plusieurs groupes : l\'interrupteur va avec le profil, ne '
        'parle que de lui, et n\'écrit pas le choix partagé', (
      WidgetTester tester,
    ) async {
      tall(tester);
      final RideDto two = fixtureRide(
        groups: <RideGroupDto>[
          fixtureGroup(id: 'g1', routeSlug: 'court'),
          fixtureGroup(id: 'g2', name: 'Cool', routeSlug: 'long'),
        ],
      );
      await open(
        tester,
        two,
        repository: _StubRideRepository(two),
        routes: <RouteDetailDto>[surfaced('court'), surfaced('long')],
      );

      expect(find.byKey(keys.ride.mapColorBy), findsNothing);
      final Finder toggle = find.byKey(keys.ride.profileColorBy);
      expect(toggle, findsOneWidget);
      final RouteColorModeSwitch widget = tester.widget<RouteColorModeSwitch>(
        toggle,
      );
      expect(widget.modes, <RouteColorBy>[
        RouteColorBy.grade,
        RouteColorBy.surface,
      ]);
      expect(widget.semanticLabel, 'Colorer le profil selon');
      // Au-dessus du profil.
      expect(
        tester.getTopLeft(toggle).dy,
        lessThan(tester.getTopLeft(find.byType(PdlElevationProfile)).dy),
      );

      await chooseSurface(tester);
      expect(
        tester.widget<RouteColorModeSwitch>(toggle).value,
        RouteColorBy.surface,
      );
      expect(
        containerOf(tester).read(rideMapColorModeProvider(key)),
        RouteColorBy.grade,
      );
    });

    testWidgets(
      'sortie solo à deux parcours : la carte aux couleurs de ses '
      'couches, Pente | Revêtement avec le profil, la puce « Météo » à part',
      (WidgetTester tester) async {
        tall(tester);
        final RideDto twoLayers = fixtureRide(
          groups: <RideGroupDto>[fixtureGroup(routeSlug: 'court')],
        ).copyWith(routeSlug: 'principal');
        await open(
          tester,
          twoLayers,
          repository: _StubRideRepository(twoLayers, weather: served()),
          routes: <RouteDetailDto>[surfaced('principal'), surfaced('court')],
        );

        expect(find.byKey(keys.ride.mapColorBy), findsNothing);
        expect(find.byKey(keys.ride.windMapChip), findsOneWidget);
        expect(find.byKey(keys.ride.profileColorBy), findsOneWidget);

        await chooseSurface(tester);
        expect(
          containerOf(tester).read(rideMapColorModeProvider(key)),
          RouteColorBy.grade,
        );

        // Le vent sur la carte ne touche pas au profil.
        await tester.ensureVisible(find.byKey(keys.ride.windMapChip));
        await tester.pump();
        await tester.tap(find.byKey(keys.ride.windMapChip));
        await tester.pump();
        expect(
          containerOf(tester).read(rideMapColorModeProvider(key)),
          RouteColorBy.wind,
        );
        expect(
          tester
              .widget<RouteColorModeSwitch>(
                find.byKey(keys.ride.profileColorBy),
              )
              .value,
          RouteColorBy.surface,
        );
      },
    );

    testWidgets(
      'sortie solo à un seul parcours : un seul interrupteur, sous la '
      'carte, partagé',
      (WidgetTester tester) async {
        tall(tester);
        final RideDto solo = fixtureRide(
          groups: <RideGroupDto>[fixtureGroup(routeSlug: 'court')],
        );
        await open(
          tester,
          solo,
          repository: _StubRideRepository(solo),
          routes: <RouteDetailDto>[surfaced('court')],
        );

        expect(find.byKey(keys.ride.profileColorBy), findsNothing);
        final Finder toggle = find.byKey(keys.ride.mapColorBy);
        expect(toggle, findsOneWidget);
        final Finder surface = find.descendant(
          of: toggle,
          matching: find.byKey(keys.routeDetail.colorByMode('surface')),
        );
        await tester.ensureVisible(surface);
        await tester.pump();
        await tester.tap(surface);
        await tester.pump();
        expect(
          containerOf(tester).read(rideMapColorModeProvider(key)),
          RouteColorBy.surface,
        );
      },
    );
  });

  group('le bouton « GPS » (MOB-134, lot 4)', () {
    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(402 * 3, 4000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    RouteDetailDto withGpx(String slug) =>
        fixtureRouteDetail(slug: slug).copyWith(
          media: const MediaDto(
            markdown: '',
            assets: AssetsDto(
              images: <AssetDto>[],
              attachments: <AssetDto>[],
              gpx: AssetDto(
                id: 'a-gpx',
                fileName: 'court.gpx',
                contentType: 'application/gpx+xml',
                url: '/api/download/public/court.gpx',
              ),
            ),
          ),
        );

    Future<void> openSheet(WidgetTester tester, Key gps) async {
      await tester.ensureVisible(find.byKey(gps));
      await tester.pump();
      await tester.tap(find.byKey(gps));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('la carte d\'un groupe porte « GPS », qui ouvre la feuille '
        'nommant le groupe', (WidgetTester tester) async {
      tall(tester);
      final RideDto two = fixtureRide(
        dateTime: '2099-07-29T19:30:00Z',
        groups: <RideGroupDto>[
          fixtureGroup(id: 'g1', routeSlug: 'court'),
          fixtureGroup(id: 'g2', name: 'Cool', routeSlug: 'sans-trace'),
        ],
      );
      await open(
        tester,
        two,
        repository: _StubRideRepository(two),
        routes: <RouteDetailDto>[withGpx('court')],
      );

      expect(find.byKey(keys.ride.groupGps('g1')), findsOneWidget);
      // Ni fichier ni service : pas de bouton.
      expect(find.byKey(keys.ride.groupGps('g2')), findsNothing);

      await openSheet(tester, keys.ride.groupGps('g1'));
      expect(find.byKey(keys.gpsSheet.sheet), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(keys.gpsSheet.subtitle)).data,
        'Groupe Chill Route Long · '
        '${AppFormatters.formatDistance(two.groups.first.distance!)}',
      );
      expect(find.byKey(keys.gpsSheet.gpxShare), findsOneWidget);
      expect(find.byKey(keys.gpsSheet.connectDevice), findsOneWidget);
    });

    testWidgets('une sortie solo porte « GPS » dans sa section Parcours', (
      WidgetTester tester,
    ) async {
      tall(tester);
      final RideDto solo = fixtureRide(
        dateTime: '2099-07-29T19:30:00Z',
        groups: <RideGroupDto>[fixtureGroup(routeSlug: 'court')],
      );
      await open(
        tester,
        solo,
        repository: _StubRideRepository(solo),
        routes: <RouteDetailDto>[withGpx('court')],
      );

      final Finder gps = find.descendant(
        of: find.byKey(keys.ride.routeSection),
        matching: find.byKey(keys.rideGroup.gps),
      );
      expect(gps, findsOneWidget);
      await openSheet(tester, keys.rideGroup.gps);
      expect(find.byKey(keys.gpsSheet.sheet), findsOneWidget);
      expect(find.byKey(keys.gpsSheet.gpxShare), findsOneWidget);
    });
  });
}

const WeatherRainAlertDto _rain70 = WeatherRainAlertDto(
  probability: 70,
  time: '2099-07-29T20:05:00Z',
  condition: 'RAIN',
  distance: 15000,
);
