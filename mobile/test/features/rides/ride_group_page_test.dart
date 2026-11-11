import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/comments/presentation/widgets/comment_thread.dart';
import 'package:pedalons/features/participants/data/participant_repository.dart';
import 'package:pedalons/features/participants/domain/participant_query.dart';
import 'package:pedalons/features/participants/presentation/widgets/participants_sheet.dart';
import 'package:pedalons/features/rides/data/ride_repository.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_detail_page.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_group_page.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_groups_map.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/features/rides/providers/ride_weather_provider.dart';
import 'package:pedalons/features/rides/providers/ride_scroll_target_provider.dart';
import 'package:pedalons/features/routes/domain/track_surfaces.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_color_mode_switch.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import '../routes/route_fixtures.dart';
import 'ride_fixtures.dart';
import '../../support/content_permissions.dart';

/// La page d'un groupe de sortie (ledgers `MOB-67`, `MOB-134`) : une page qui
/// défile, sans onglets ni barre d'action — bloc de départ et inscription,
/// tuiles, « Parcours », « Personnes inscrites », « Météo » —, les pastilles
/// qui partagent la sélection avec le détail, `?tab=weather` toléré, et le
/// groupe disparu.
class _Repository implements RideRepository {
  _Repository(this.ride, this.weather, {this.permissions});

  final RideDto ride;

  /// Le bloc `permissions` que le serveur calcule pour l'appelant (docs/
  /// LEDGER_*.md MOB-137) ; nul, celui du jeu d'essai.
  final ContentPermissionsDto? permissions;
  RideWeatherDto weather;
  final List<String> joined = <String>[];
  final List<String> left = <String>[];
  final List<String> switched = <String>[];
  int weatherCalls = 0;

  @override
  Future<RideDto> getRide(String teamSlug, String rideSlug) async =>
      permissions == null ? ride : ride.copyWith(permissions: permissions!);

  @override
  Future<RideWeatherDto> getRideWeather(String t, String r) async {
    weatherCalls++;
    return weather;
  }

  @override
  Future<RideParticipationDto> joinGroup(String t, String r, String g) async {
    joined.add(g);
    return const RideParticipationDto(id: 'p', userId: 'u');
  }

  @override
  Future<RideParticipationDto> switchGroup(String t, String r, String g) async {
    switched.add(g);
    return const RideParticipationDto(id: 'p', userId: 'u');
  }

  @override
  Future<void> leaveGroup(String t, String r, String g) async => left.add(g);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le serveur des participants : la liste de la feuille « Voir toutes ».
class _Participants implements ParticipantRepository {
  final List<PublicUserDto> people = <PublicUserDto>[
    const PublicUserDto(id: 'u2', displayName: 'Hélène Ebrard'),
  ];
  int calls = 0;

  @override
  Future<PageResult<PublicUserDto>> fetchPage(
    ParticipantQuery query, {
    required int page,
    required int size,
  }) async {
    calls++;
    return PageResult<PublicUserDto>(
      items: List<PublicUserDto>.of(people),
      total: people.length,
    );
  }
}

/// « Mes équipes » : membre, non-membre, ou jamais répondu (appartenance
/// inconnue).
class _Teams implements TeamRepository {
  _Teams({required this.member, this.pending = false});

  final bool member;
  final bool pending;

  @override
  Future<List<TeamDetailDto>> getMyTeams() async {
    if (pending) return Completer<List<TeamDetailDto>>().future;
    return member
        ? <TeamDetailDto>[
            const TeamDetailDto(
              allowedContentVisibilities: kAllContentVisibilities,
              defaultContentVisibility: 'PUBLIC',
              publicContentAllowed: false,
              tier: 'FREE',
              timezone: 'Europe/Paris',
              id: 't1',
              slug: 'n-peloton',
              name: 'N-Peloton',
              about: MediaDto(
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
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Les paliers asynchrones d'une navigation : traductions, détail,
/// appartenance, puis le départ planifié après le cadre.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// L'instant des tests : avant le départ des groupes des fixtures
/// (`2026-10-11T06:00:00Z`).
final DateTime _now = DateTime.utc(2026, 1, 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  final RideDto twoGroups = fixtureRide(
    groups: <RideGroupDto>[
      fixtureGroup(id: 'g1', name: 'Rapide'),
      fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
    ],
  );
  const RideKey key = RideKey(teamSlug: 'n-peloton', rideSlug: 'np-665');

  RideWeatherDto weather({String status = 'OK', List<WeatherLegDto>? legs}) =>
      fixtureWeather(
        status: status,
        departure: fixtureConditions(),
        fetchedAt: '2099-07-29T17:00:00Z',
        legs:
            legs ??
            <WeatherLegDto>[
              fixtureLeg(
                groupId: 'g1',
                rainAlert: _rain70,
                summary: fixtureLegSummary(rainAlert: _rain70),
              ),
              fixtureLeg(
                groupId: 'g2',
                speedIsDefault: true,
                relativeWind: 'CROSS',
                summary: fixtureLegSummary(),
              ),
            ],
      );

  late ProviderContainer container;
  late _Repository repository;
  late _Participants participants;

  Future<void> open(
    WidgetTester tester,
    RideWeatherDto dto, {
    RideDto? ride,
    String groupId = 'g1',
    UnitSystem units = UnitSystem.metric,
    bool member = true,
    bool membershipPending = false,
    bool scrollToWeather = false,
    DateTime? now,
    double height = 6000,
    List overrides = const [],
  }) async {
    tester.view.physicalSize = Size(402 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // L'écran lit le droit dans la sortie, plus dans « Mes équipes » : un
    // membre l'a, une appartenance inconnue ne vaut rien (docs/LEDGER_*.md
    // MOB-137).
    repository = _Repository(
      ride ?? twoGroups,
      dto,
      permissions: permissionsFor(member: member && !membershipPending),
    );
    participants = _Participants();
    container = ProviderContainer(
      retry: (int _, Object _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        unitSystemProvider.overrideWithValue(units),
        rideRepositoryProvider.overrideWithValue(repository),
        participantRepositoryProvider.overrideWithValue(participants),
        teamRepositoryProvider.overrideWithValue(
          _Teams(member: member, pending: membershipPending),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: RideGroupPage(
            teamSlug: key.teamSlug,
            rideSlug: key.rideSlug,
            groupId: groupId,
            scrollToWeather: scrollToWeather,
            now: now ?? _now,
          ),
        ),
      ),
    );
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Finder inBlock(Finder matching) => find.descendant(
    of: find.byKey(keys.rideGroup.departureBlock),
    matching: matching,
  );

  Finder inParticipants(Finder matching) => find.descendant(
    of: find.byKey(keys.rideGroup.participantsSection),
    matching: matching,
  );

  // ─────────────────────────────────────────────── la carte et son parcours

  TrackDto trackOf(List<List<double>> coordinates) => TrackDto(
    line: GeoJsonLineString(
      type: GeoJsonLineStringTypeType.lineString,
      coordinates: coordinates,
    ),
    climbs: const <ClimbDto>[],
  );
  final RideDto routed = fixtureRide(
    groups: <RideGroupDto>[
      fixtureGroup(id: 'g1', name: 'Rapide', routeSlug: 'court'),
      fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
    ],
  );
  // Deux traces : 10 km plein nord, un saut de ~8 km vers l'est, puis 20 km
  // dont la distance repart de 0 — 30 km chaînés, saut nul.
  RouteDetailDto route({List<WaypointDto> waypoints = const <WaypointDto>[]}) =>
      RouteDetailDto(
        permissions: kNoPermissions,
        elevationState: 'HD',
        tags: const [],
        id: 'r-court',
        slug: 'court',
        team: routed.team,
        name: 'Court',
        media: routed.media,
        distance: 30000,
        elevationGain: 0,
        elevationLoss: 0,
        surfaceType: 'ROAD',
        visibility: 'PUBLIC',
        createdBy: const PublicUserDto(id: 'u9', displayName: 'Créatrice'),
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-01T00:00:00Z',
        tracks: <TrackDto>[
          trackOf(<List<double>>[
            for (int i = 0; i <= 10; i++)
              <double>[5, 45 + i * 0.009, 300, i * 1000.0],
          ]),
          trackOf(<List<double>>[
            for (int j = 0; j <= 20; j++)
              <double>[5.1, 45 + (10 + j) * 0.009, 300, j * 1000.0],
          ]),
        ],
        waypoints: waypoints,
        deleted: false,
      );
  List mapOverrides({RouteDetailDto? geometry, bool loading = false}) => [
    appConfigProvider.overrideWith((Ref ref) => Completer<ConfigDto>().future),
    mapStyleProvider.overrideWith(
      (Ref ref, Brightness b) => const AsyncValue<ResolvedMapStyle?>.data(
        ResolvedMapStyle(
          selectedId: 's',
          style: MapStyleDto(
            id: 'plan',
            label: 'Plan',
            group: 'vector',
            url: 'https://tiles.example/plan.json',
          ),
          url: 'https://tiles.example/plan.json',
        ),
      ),
    ),
    rideRouteGeometryProvider.overrideWith(
      (Ref ref, RouteRef r) => loading
          ? const AsyncValue<RouteDetailDto>.loading()
          : AsyncValue<RouteDetailDto>.data(geometry ?? route()),
    ),
  ];

  PdlMap probe(WidgetTester tester) =>
      tester.widget<RideGroupsMapProbe>(find.byType(RideGroupsMapProbe)).map;

  // ─────────────────────────────────────────── l'ordre des maquettes

  /// Les ordonnées des sections, dans l'ordre des maquettes (ledger
  /// `MOB-134`) : bloc de départ, tuiles, « Parcours », « Personnes
  /// inscrites », « Météo ».
  void expectSectionOrder(WidgetTester tester) {
    final List<Key> order = <Key>[
      keys.rideGroup.departureBlock,
      keys.rideGroup.statTiles,
      keys.rideGroup.routeSection,
      keys.rideGroup.participantsSection,
      keys.rideGroup.weatherSection,
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
    // Les pastilles, épinglées, au-dessus de tout.
    expect(
      tester.getTopLeft(find.byKey(keys.rideGroup.groupChip('g1'))).dy,
      lessThan(tops.first),
    );
  }

  group('l\'ordre des maquettes', () {
    setUp(() => RideGroupsMap.debugSkipNativeMap = true);
    tearDown(() => RideGroupsMap.debugSkipNativeMap = false);

    testWidgets('groupe-mobile-cible : pas inscrit', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          groups: <RideGroupDto>[
            fixtureGroup(
              id: 'g1',
              name: 'A',
              routeSlug: 'court',
              leader: const PublicUserDto(id: 'u0', displayName: 'Léa Martin'),
            ).copyWith(estimatedDurationMinutes: 198),
            fixtureGroup(id: 'g2', name: 'B', sortOrder: 1),
          ],
        ),
        overrides: mapOverrides(),
      );

      expectSectionOrder(tester);
      // « Rejoindre » à droite de l'heure, ni badge ni « Quitter ».
      expect(inBlock(find.byKey(keys.rideGroup.joinButton)), findsOneWidget);
      expect(find.byKey(keys.rideGroup.goingBadge), findsNothing);
      expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);
      // Plus d'onglets ni de barre d'action.
      expect(find.byType(PdlSegmented<Object>), findsNothing);
      expect(find.byType(PdlActionBar), findsNothing);
      // Ni description ni commentaires sur la page d'un groupe.
      expect(find.byType(CommentThread), findsNothing);
      expect(find.text('Description'), findsNothing);
      // Aucune pastille ne porte de coche : je ne suis inscrit nulle part.
      for (final String id in <String>['g1', 'g2']) {
        expect(
          tester.widget<PdlChip>(find.byKey(keys.rideGroup.groupChip(id))).icon,
          isNull,
        );
      }
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('groupe-inscrit-mobile-cible : inscrit dans ce groupe', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          registered: true,
          registeredGroupId: 'g1',
          groups: <RideGroupDto>[
            fixtureGroup(
              id: 'g1',
              name: 'A',
              routeSlug: 'court',
              registered: true,
              leader: const PublicUserDto(id: 'u0', displayName: 'Léa Martin'),
            ).copyWith(estimatedDurationMinutes: 198),
            fixtureGroup(id: 'g2', name: 'B', sortOrder: 1),
          ],
        ),
        overrides: mapOverrides(),
      );

      expectSectionOrder(tester);
      // « J'y vais » à la place de « Rejoindre ».
      expect(inBlock(find.byKey(keys.rideGroup.goingBadge)), findsOneWidget);
      expect(inBlock(find.text('J\'Y VAIS')), findsOneWidget);
      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      // La coche sur la pastille de mon groupe, et sur elle seule.
      expect(
        tester.widget<PdlChip>(find.byKey(keys.rideGroup.groupChip('g1'))).icon,
        PdlIcons.check,
      );
      expect(
        tester.widget<PdlChip>(find.byKey(keys.rideGroup.groupChip('g2'))).icon,
        isNull,
      );
      // « Quitter le groupe » en bas de « Personnes inscrites », avant la
      // météo.
      final Finder leave = find.byKey(keys.rideGroup.leaveButton);
      expect(inParticipants(leave), findsOneWidget);
      expect(
        tester.getTopLeft(leave).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(keys.rideGroup.viewAllParticipants)).dy,
        ),
      );
      expect(
        tester.getTopLeft(leave).dy,
        lessThan(
          tester.getTopLeft(find.byKey(keys.rideGroup.weatherSection)).dy,
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  // ──────────────────────────────────────────────────── le bloc de départ

  group('le bloc de départ', () {
    testWidgets('l\'heure du groupe et son arrivée estimée, sans relation '
        'quand il part avec la sortie', (WidgetTester tester) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          dateTime: '2036-07-29T19:30:00Z',
          groups: <RideGroupDto>[
            fixtureGroup(
              id: 'g1',
              startAt: '2036-07-29T19:30:00Z',
            ).copyWith(estimatedArrival: '2036-07-29T22:48:00Z'),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(inBlock(find.text('Départ 21:30')), findsOneWidget);
      // L'arrivée du groupe (API-172), pas celle du leg météo.
      expect(inBlock(find.text('Arrivée estimée 00:48')), findsOneWidget);
      expect(find.textContaining('la sortie de'), findsNothing);
      // La date, dite une fois, par la boîte du jour (« mar. / 29 / juil. »).
      expect(inBlock(find.text('juil.')), findsOneWidget);
      expect(inBlock(find.textContaining('29 juil.')), findsNothing);
    });

    testWidgets('sans arrivée du groupe : celle de son leg météo', (
      WidgetTester tester,
    ) async {
      await open(tester, weather());

      expect(inBlock(find.textContaining('Arrivée estimée')), findsOneWidget);
    });

    testWidgets('ni arrivée du groupe ni leg prévu : pas d\'arrivée', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(legs: <WeatherLegDto>[]));

      expect(inBlock(find.textContaining('Arrivée estimée')), findsNothing);
    });

    testWidgets('un groupe à heure propre donne la sienne', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          dateTime: '2036-07-29T19:30:00Z',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', startAt: '2036-07-29T20:00:00Z'),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(inBlock(find.text('Départ 22:00')), findsOneWidget);
      expect(inBlock(find.textContaining('la sortie de')), findsNothing);
    });

    testWidgets('les lieux de départ et d\'arrivée, en liens d\'itinéraire', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        ride: twoGroups.copyWith(
          startPlace: const PlaceDetailDto(
            id: 'p1',
            name: 'Place de la Mairie, Huelgoat',
            startPlace: true,
            endPlace: false,
            geometry: GeoJsonPoint(
              type: GeoJsonPointTypeType.point,
              coordinates: <double>[-3.74, 48.36],
            ),
          ),
          endPlace: const PlaceDetailDto(
            id: 'p2',
            name: 'Café du Lac, Huelgoat',
            startPlace: false,
            endPlace: true,
          ),
        ),
      );

      final Finder start = inBlock(find.byKey(keys.ride.startPlaceLink));
      expect(start, findsOneWidget);
      expect(tester.widget<PdlPlaceRow>(start).onTap, isNotNull);
      // Ni coordonnées ni adresse : un texte, pas un lien.
      final Finder end = inBlock(find.byKey(keys.ride.endPlaceLink));
      expect(end, findsOneWidget);
      expect(tester.widget<PdlPlaceRow>(end).onTap, isNull);
      expect(find.text('Café du Lac, Huelgoat'), findsOneWidget);
    });

    testWidgets('sans lieu d\'arrivée : le départ seul', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        ride: twoGroups.copyWith(
          startPlace: const PlaceDetailDto(
            id: 'p1',
            name: 'Place de la Mairie',
            startPlace: true,
            endPlace: false,
            address: '1 place de la Mairie, Huelgoat',
          ),
        ),
      );

      expect(find.byKey(keys.ride.startPlaceLink), findsOneWidget);
      expect(find.byKey(keys.ride.endPlaceLink), findsNothing);
    });
  });

  // ──────────────────────────────────────────────────────────── les tuiles

  group('les tuiles', () {
    testWidgets('Distance, Dénivelé positif, Durée estimée, Vitesse moyenne', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1').copyWith(estimatedDurationMinutes: 198),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      Finder tile(String text) => find.descendant(
        of: find.byKey(keys.rideGroup.statTiles),
        matching: find.text(text),
      );
      expect(tile('Distance'), findsOneWidget);
      expect(tile('Dénivelé positif'), findsOneWidget);
      expect(tile('Durée estimée'), findsOneWidget);
      expect(tile(AppFormatters.formatDurationMinutes(198)), findsOneWidget);
      expect(tile('Vitesse moyenne'), findsOneWidget);
      // L'ordre de la règle : Distance avant Durée, Dénivelé avant Vitesse.
      expect(
        tester.getTopLeft(tile('Distance')).dy,
        lessThan(tester.getTopLeft(tile('Durée estimée')).dy),
      );
      // Le départ est dans le bloc en tête, plus dans les chiffres.
      expect(tile('Départ'), findsNothing);
    });

    testWidgets('une tuile sans donnée disparaît', (WidgetTester tester) async {
      await open(tester, weather());

      expect(find.byKey(keys.rideGroup.statTiles), findsOneWidget);
      expect(find.text('Durée estimée'), findsNothing);
      expect(find.text('Vitesse moyenne'), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────── le contrôle d'inscription

  group('le contrôle d\'inscription', () {
    testWidgets('un membre rejoint le groupe, sans confirmation', (
      WidgetTester tester,
    ) async {
      await open(tester, weather());

      expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);
      await tester.tap(find.byKey(keys.rideGroup.joinButton));
      await tester.pump();
      await tester.pump();

      expect(repository.joined, <String>['g1']);
      expect(find.byType(PdlSheet), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('inscrit ici : « J\'y vais », et « Quitter le groupe » en bas '
        'des personnes inscrites, sans confirmation', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          registered: true,
          registeredGroupId: 'g1',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', registered: true),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.goingBadge), findsOneWidget);
      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      expect(find.text('Quitter le groupe'), findsOneWidget);
      await tester.tap(find.byKey(keys.rideGroup.leaveButton));
      await tester.pump();
      await tester.pump();

      expect(repository.left, <String>['g1']);
      expect(find.byType(PdlSheet), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('un groupe complet : « Complet » désactivé, aucun bouton', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          groups: <RideGroupDto>[
            fixtureGroup(
              id: 'g1',
              full: true,
              countParticipants: 16,
              maxParticipants: 16,
            ),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      final Finder full = find.byKey(keys.rideGroup.fullBadge);
      expect(inBlock(full), findsOneWidget);
      expect(tester.widget<PdlButton>(full).enabled, isFalse);
      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);
      expect(inParticipants(find.text('16/16')), findsOneWidget);
      // Plein, il ne reste rien à compter : la barre seule.
      expect(find.textContaining('place'), findsNothing);
    });

    testWidgets('inscrit dans un autre groupe : « Changer pour Rapide », un '
        'seul appel, sans confirmation', (WidgetTester tester) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          registered: true,
          registeredGroupId: 'g2',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', name: 'Rapide'),
            fixtureGroup(
              id: 'g2',
              name: 'Cool',
              sortOrder: 1,
              registered: true,
            ),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);
      // La coche est sur la pastille de mon groupe, pas sur celle affichée.
      expect(
        tester.widget<PdlChip>(find.byKey(keys.rideGroup.groupChip('g2'))).icon,
        PdlIcons.check,
      );
      final Finder change = find.byKey(keys.rideGroup.switchButton);
      expect(inBlock(change), findsOneWidget);
      expect(find.text('Changer pour Rapide'), findsOneWidget);

      await tester.tap(change);
      await tester.pump();
      await tester.pump();

      expect(repository.switched, <String>['g1']);
      expect(repository.joined, isEmpty);
      expect(repository.left, isEmpty);
      expect(find.byType(PdlSheet), findsNothing);
    });

    testWidgets('mon groupe ouvert depuis sa pastille : « J\'y vais » et '
        '« Quitter le groupe »', (WidgetTester tester) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          registered: true,
          registeredGroupId: 'g2',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', name: 'Rapide'),
            fixtureGroup(
              id: 'g2',
              name: 'Cool',
              sortOrder: 1,
              registered: true,
            ),
          ],
        ),
      );

      await tester.tap(find.byKey(keys.rideGroup.groupChip('g2')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Groupe Cool'), findsOneWidget);
      expect(find.byKey(keys.rideGroup.goingBadge), findsOneWidget);
      expect(find.byKey(keys.rideGroup.leaveButton), findsOneWidget);
      expect(container.read(selectedRideGroupProvider(key)), 'g2');
    });

    testWidgets('un non-membre : aucun contrôle, le compte reste', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(), member: false);

      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      expect(find.byKey(keys.rideGroup.goingBadge), findsNothing);
      expect(find.byKey(keys.rideGroup.participantsCount), findsOneWidget);
      expect(inParticipants(find.text('3/16')), findsOneWidget);
    });

    testWidgets('appartenance inconnue : pas de « Rejoindre » tant qu\'on ne '
        'sait pas', (WidgetTester tester) async {
      await open(tester, weather(), membershipPending: true);

      expect(find.byKey(keys.rideGroup.departureBlock), findsOneWidget);
      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      expect(find.byKey(keys.rideGroup.switchButton), findsNothing);
    });

    testWidgets('appartenance inconnue, inscrit ici : « J\'y vais » quand '
        'même — le serveur le dit', (WidgetTester tester) async {
      await open(
        tester,
        weather(),
        membershipPending: true,
        ride: fixtureRide(
          registered: true,
          registeredGroupId: 'g1',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', registered: true),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.goingBadge), findsOneWidget);
    });

    testWidgets('un groupe parti, inscrit : « J\'y vais » et « Quitter le '
        'groupe » restent, la météo aussi', (WidgetTester tester) async {
      await open(
        tester,
        weather(),
        now: DateTime.utc(2026, 10, 11, 7),
        ride: fixtureRide(
          registered: true,
          registeredGroupId: 'g1',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', registered: true),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      // Se désinscrire après le départ corrige qui est vraiment venu : le
      // serveur l'autorise (décision du 2026-11-10, MOB-134).
      expect(inBlock(find.byKey(keys.rideGroup.goingBadge)), findsOneWidget);
      expect(
        inParticipants(find.byKey(keys.rideGroup.leaveButton)),
        findsOneWidget,
      );
      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      // En cours (départ + 3 h, sans arrivée estimée) : l'API sert encore la
      // météo (API-170).
      expect(repository.weatherCalls, 1);
      expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
    });

    testWidgets('un groupe parti, pas inscrit : ni « Rejoindre » ni « Changer '
        'pour »', (WidgetTester tester) async {
      await open(
        tester,
        weather(),
        groupId: 'g2',
        now: DateTime.utc(2026, 10, 11, 7),
        ride: fixtureRide(
          registered: true,
          registeredGroupId: 'g1',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', registered: true),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      expect(find.byKey(keys.rideGroup.switchButton), findsNothing);
      expect(find.byKey(keys.rideGroup.goingBadge), findsNothing);
      expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);
    });

    testWidgets('API-170 : la sortie partie, un groupe plus tardif reste '
        'ouvert', (WidgetTester tester) async {
      await open(
        tester,
        weather(),
        groupId: 'g2',
        now: DateTime.utc(2036, 7, 29, 19, 45),
        ride: fixtureRide(
          dateTime: '2036-07-29T19:30:00Z',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', startAt: '2036-07-29T19:30:00Z'),
            fixtureGroup(
              id: 'g2',
              name: 'Cool',
              sortOrder: 1,
              startAt: '2036-07-29T20:30:00Z',
            ),
          ],
        ).copyWith(finished: true),
      );

      expect(find.byKey(keys.rideGroup.joinButton), findsOneWidget);
    });

    testWidgets('une sortie annulée : rien, pas même la météo', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          status: 'CANCELLED',
          registered: true,
          registeredGroupId: 'g1',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', registered: true),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.goingBadge), findsNothing);
      expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);
      expect(find.byKey(keys.rideGroup.weatherSection), findsNothing);
      expect(repository.weatherCalls, 0);
    });
  });

  // ──────────────────────────────────────────── « Personnes inscrites »

  group('« Personnes inscrites »', () {
    testWidgets('le compte, la barre de places, les places restantes', (
      WidgetTester tester,
    ) async {
      await open(tester, weather());

      expect(inParticipants(find.text('Personnes inscrites')), findsOneWidget);
      expect(inParticipants(find.text('3/16')), findsOneWidget);
      expect(inParticipants(find.byType(PdlProgressBar)), findsOneWidget);
      expect(find.text('13 places restantes'), findsOneWidget);
    });

    testWidgets('capitaine nul : rien, et jamais le créateur de la sortie', (
      WidgetTester tester,
    ) async {
      await open(tester, weather());

      expect(find.byKey(keys.rideGroup.leader), findsNothing);
      expect(find.text('CAPITAINE'), findsNothing);
      // Tout le monde dans la grappe.
      expect(
        tester
            .widget<PdlAvatarStack>(
              find.byKey(keys.rideGroup.participantsAvatars),
            )
            .people
            .length,
        3,
      );
    });

    testWidgets('une personne capitaine : son nom, son badge, et la grappe '
        'sans elle', (WidgetTester tester) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          groups: <RideGroupDto>[
            fixtureGroup(
              id: 'g1',
              leader: const PublicUserDto(id: 'u0', displayName: 'Membre 0'),
            ),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(inParticipants(find.byKey(keys.rideGroup.leader)), findsOneWidget);
      expect(find.text('Membre 0'), findsOneWidget);
      expect(find.text('CAPITAINE'), findsOneWidget);
      final PdlAvatarStack stack = tester.widget<PdlAvatarStack>(
        find.byKey(keys.rideGroup.participantsAvatars),
      );
      expect(stack.people.map((PdlAvatarEntry e) => e.name), <String>[
        'Membre 1',
        'Membre 2',
      ]);
      expect(stack.total, 2);
    });

    testWidgets('« Voir toutes les personnes inscrites » ouvre la feuille', (
      WidgetTester tester,
    ) async {
      await open(tester, weather());

      await tester.tap(find.byKey(keys.rideGroup.viewAllParticipants));
      await settle(tester);

      expect(find.byType(ParticipantsSheet), findsOneWidget);
      expect(participants.calls, greaterThan(0));
      expect(find.text('Hélène Ebrard'), findsOneWidget);
    });

    testWidgets('un non-membre ne reçoit que le nombre : ni capitaine, ni '
        'visages, ni liste', (WidgetTester tester) async {
      // Le serveur lui envoie `participants: []` et une capitaine nulle ; la
      // page ne rend pas de nom même si elle en recevait un.
      final RideDto stripped = fixtureRide(
        groups: <RideGroupDto>[
          fixtureGroup(
            id: 'g1',
            leader: const PublicUserDto(id: 'l1', displayName: 'Léa'),
          ).copyWith(participants: const <PublicUserDto>[]),
          fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
        ],
      );
      await open(tester, weather(), ride: stripped, member: false);

      expect(inParticipants(find.text('3/16')), findsOneWidget);
      expect(find.byKey(keys.rideGroup.viewAllParticipants), findsNothing);
      expect(find.byKey(keys.rideGroup.participantsAvatars), findsNothing);
      expect(find.byKey(keys.rideGroup.leader), findsNothing);
      expect(find.text('Léa'), findsNothing);
      expect(participants.calls, 0);
      expect(tester.takeException(), isNull);
    });
  });

  // ──────────────────────────────────────────────────────── section Météo

  group('section Météo', () {
    testWidgets('dépliée, dernier bloc : départ, alerte, exposition, frise, '
        'prévision', (WidgetTester tester) async {
      await open(tester, weather());

      expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
      expect(find.textContaining('Météo au départ de '), findsOneWidget);
      expect(find.text('14 °C'), findsWidgets);
      expect(find.textContaining('Pluie probable (70 %)'), findsOneWidget);
      expect(find.text('Exposition au vent'), findsOneWidget);
      // Rien ne suit la section : la frise est dépliée, sous son sous-titre.
      expect(find.text('Météo le long du parcours'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(keys.rideGroup.weatherSection),
          matching: find.byType(PdlDisclosure),
        ),
        findsNothing,
      );
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(2)), findsOneWidget);
      expect(find.text('FACE'), findsOneWidget);
      expect(find.text('DOS'), findsOneWidget);
      // Le crédit est derrière ⓘ.
      expect(find.byKey(keys.ride.weatherForecastOf), findsOneWidget);
      expect(find.byKey(keys.ride.weatherSourceButton), findsOneWidget);
      expect(find.text('Prévisions : Open-Meteo.com'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un leg qui porte son départ : l\'heure et les conditions du '
        'groupe', (WidgetTester tester) async {
      AppFormatters.setDisplayTimezone('Europe/Paris');
      addTearDown(() => AppFormatters.setDisplayTimezone(null));
      await open(
        tester,
        weather(
          legs: <WeatherLegDto>[
            fixtureLeg(
              groupId: 'g1',
              departure: DepartureWeatherDto(
                status: 'OK',
                conditions: fixtureConditions(temperature: 9),
              ),
            ).copyWith(startTime: '2036-07-29T20:00:00Z'),
          ],
        ),
        ride: fixtureRide(
          dateTime: '2036-07-29T19:30:00Z',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', startAt: '2036-07-29T20:00:00Z'),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(keys.rideGroup.departureWeatherTitle),
          matching: find.text('Météo au départ de 22:00'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('de la sortie'), findsNothing);
      expect(find.text('9 °C'), findsOneWidget);
    });

    testWidgets('BRAND-8 : un groupe à heure propre — le titre du départ dit '
        'qu\'il s\'agit de l\'heure de la sortie, celle de la prévision', (
      WidgetTester tester,
    ) async {
      AppFormatters.setDisplayTimezone('Europe/Paris');
      addTearDown(() => AppFormatters.setDisplayTimezone(null));
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          dateTime: '2036-07-29T19:30:00Z',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', startAt: '2036-07-29T20:00:00Z'),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      final Finder title = find.byKey(keys.rideGroup.departureWeatherTitle);
      expect(
        find.descendant(
          of: title,
          matching: find.text('Météo au départ de la sortie, 21:30'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Météo au départ de 22:00'), findsNothing);
    });

    testWidgets('BRAND-8 : un groupe qui part avec la sortie garde « Météo au '
        'départ de 21:30 »', (WidgetTester tester) async {
      AppFormatters.setDisplayTimezone('Europe/Paris');
      addTearDown(() => AppFormatters.setDisplayTimezone(null));
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          dateTime: '2036-07-29T19:30:00Z',
          groups: <RideGroupDto>[
            fixtureGroup(id: 'g1', startAt: '2036-07-29T19:30:00Z'),
            fixtureGroup(id: 'g2', name: 'Cool', sortOrder: 1),
          ],
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(keys.rideGroup.departureWeatherTitle),
          matching: find.text('Météo au départ de 21:30'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('une pastille change de groupe, et le partage avec le détail', (
      WidgetTester tester,
    ) async {
      await open(tester, weather());

      // La page pose son groupe dans la sélection partagée.
      expect(container.read(selectedRideGroupProvider(key)), 'g1');
      expect(find.textContaining('Pluie probable'), findsOneWidget);
      expect(find.textContaining('vitesse par défaut'), findsNothing);

      await tester.tap(find.byKey(keys.rideGroup.groupChip('g2')));
      await tester.pump();
      await tester.pump();

      expect(container.read(selectedRideGroupProvider(key)), 'g2');
      expect(find.text('Groupe Cool'), findsOneWidget);
      expect(find.textContaining('Pluie probable'), findsNothing);
      expect(find.textContaining('vitesse par défaut'), findsOneWidget);
      expect(find.text('TRAVERS'), findsOneWidget);
    });

    testWidgets('STALE se signale par un bandeau', (WidgetTester tester) async {
      await open(tester, weather(status: 'STALE'));

      expect(
        find.textContaining('Prévision ancienne', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('un leg sans parcours dit qu\'il n\'y a que le départ', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(
          legs: <WeatherLegDto>[
            WeatherLegDto(
              status: 'NO_LOCATION',
              groupId: 'g1',
              startTime: '2099-07-29T19:30:00Z',
              averageSpeed: 25,
              speedIsDefault: true,
              distance: 0,
              arrivalTime: '2099-07-29T19:30:00Z',
              checkpoints: const <WeatherCheckpointDto>[],
              segments: const <WindSegmentDto>[],
              windExposure: const WindExposureDto(head: 0, cross: 0, tail: 0),
            ),
          ],
        ),
      );

      expect(
        find.textContaining('n\'a pas de parcours', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    for (final String legStatus in <String>[
      'UNAVAILABLE',
      'NOT_YET_AVAILABLE',
      'SOMETHING_NEW',
    ]) {
      testWidgets('un leg $legStatus : un bandeau, pas de frise', (
        WidgetTester tester,
      ) async {
        await open(
          tester,
          weather(legs: <WeatherLegDto>[fixtureLeg(status: legStatus)]),
        );

        expect(find.byKey(keys.ride.weatherLegUnavailable), findsOneWidget);
        expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);
        expect(find.textContaining('Météo au départ de '), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('le leg d\'un autre groupe n\'est jamais prêté à celui-ci', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(legs: <WeatherLegDto>[fixtureLeg(groupId: 'g2')]),
      );

      expect(find.textContaining('Météo au départ de '), findsOneWidget);
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en impérial, des °F et des mph', (WidgetTester tester) async {
      await open(tester, weather(), units: UnitSystem.imperial);

      expect(find.text('58 °F'), findsWidgets);
      expect(find.textContaining('mph'), findsWidgets);
      expect(find.textContaining('°C'), findsNothing);
    });

    testWidgets('une prévision perdue ramène le mode « Météo » sur la pente', (
      WidgetTester tester,
    ) async {
      await open(tester, weather());
      container.read(rideMapColorModeProvider(key).notifier).state =
          RouteColorBy.wind;

      repository.weather = fixtureWeather(status: 'UNAVAILABLE');
      container.invalidate(rideWeatherProvider(key));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);

      // Revenue, la prévision ne rallume pas le mode toute seule.
      repository.weather = weather();
      container.invalidate(rideWeatherProvider(key));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);
    });

    testWidgets('UNAVAILABLE : un état d\'erreur et « Réessayer »', (
      WidgetTester tester,
    ) async {
      await open(tester, fixtureWeather(status: 'UNAVAILABLE'));

      expect(find.byKey(keys.ride.weatherUnavailable), findsOneWidget);
      expect(find.byKey(keys.ride.weatherRetryButton), findsOneWidget);
    });

    // `NO_LOCATION` ici pour un membre qui n'organise pas.
    for (final String status in <String>[
      'OUT_OF_RANGE',
      'NO_LOCATION',
      'SOMETHING_NEW',
    ]) {
      testWidgets('$status : le titre « Météo » reste, avec une ligne '
          'd\'explication', (WidgetTester tester) async {
        await open(tester, fixtureWeather(status: status));

        expect(find.byKey(keys.ride.weatherSection), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(keys.rideGroup.weatherSection),
            matching: find.text(
              'Aucune prévision n\'est à afficher pour cette sortie.',
            ),
          ),
          findsOneWidget,
        );
        expect(find.byKey(keys.ride.weatherNoLocation), findsNothing);
        expect(find.byKey(keys.rideGroup.departureWeatherTitle), findsNothing);
        expect(find.byKey(keys.rideGroup.participantsSection), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('un groupe arrivé ne demande pas sa météo', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(),
        ride: fixtureRide(
          dateTime: '2020-07-29T17:30:00Z',
          groups: <RideGroupDto>[
            fixtureGroup(
              id: 'g1',
              name: 'Rapide',
              startAt: '2020-07-29T17:30:00Z',
            ),
            fixtureGroup(
              id: 'g2',
              name: 'Cool',
              sortOrder: 1,
              startAt: '2020-07-29T17:30:00Z',
            ),
          ],
        ),
      );

      expect(find.byKey(keys.rideGroup.weatherSection), findsNothing);
      expect(repository.weatherCalls, 0);
    });

    testWidgets('NOT_YET_AVAILABLE donne la date d\'ouverture', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        fixtureWeather(
          status: 'NOT_YET_AVAILABLE',
          availableFrom: '2099-07-22T19:30:00Z',
        ),
      );

      expect(find.byKey(keys.ride.weatherNotYetAvailable), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────── section « Parcours »

  group('section « Parcours »', () {
    setUp(() => RideGroupsMap.debugSkipNativeMap = true);
    tearDown(() => RideGroupsMap.debugSkipNativeMap = false);

    testWidgets('le titre, une seule carte, « Profil » et sa source, '
        '« Détails »', (WidgetTester tester) async {
      await open(tester, weather(), ride: routed, overrides: mapOverrides());

      final Finder section = find.byKey(keys.rideGroup.routeSection);
      expect(
        find.descendant(of: section, matching: find.text('Parcours')),
        findsOneWidget,
      );
      expect(find.byType(RideGroupsMap), findsOneWidget);
      expect(
        tester.widget<RideGroupsMap>(find.byType(RideGroupsMap)).onlyGroup?.id,
        'g1',
      );
      expect(find.text('Profil'), findsOneWidget);
      expect(find.byKey(keys.rideRoute.details), findsOneWidget);
      // La source des altitudes, derrière ⓘ, plus sous le profil.
      expect(
        find.text(
          'Données : IGN LiDAR HD, Mapterhorn et ses sources, © OpenStreetMap',
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(keys.rideRoute.profileSource));
      await settle(tester);
      expect(find.byKey(keys.rideRoute.profileSourceSheet), findsOneWidget);
      expect(
        find.text(
          'Données : IGN LiDAR HD, Mapterhorn et ses sources, © OpenStreetMap',
        ),
        findsOneWidget,
      );
    });

    testWidgets('« Points du parcours », replié', (WidgetTester tester) async {
      await open(
        tester,
        weather(),
        ride: routed,
        overrides: mapOverrides(
          geometry: route(
            waypoints: <WaypointDto>[
              fixtureWaypoint(),
              fixtureWaypoint(id: 'w2', name: 'Col du Roc', type: 'SUMMIT'),
            ],
          ),
        ),
      );

      final Finder waypoints = find.byKey(keys.rideRoute.waypoints);
      expect(waypoints, findsOneWidget);
      expect(
        find.descendant(of: waypoints, matching: find.text('2 points')),
        findsOneWidget,
      );
      // Replié : les lignes ne sont pas construites.
      expect(find.text('Café du Port'), findsNothing);

      await tester.tap(find.text('Points du parcours'));
      await tester.pump();
      expect(find.text('Café du Port'), findsOneWidget);
    });

    testWidgets('un groupe sans parcours : ni section ni carte, la frise ne '
        'se touche pas', (WidgetTester tester) async {
      await open(tester, weather(), overrides: mapOverrides());

      expect(find.byKey(keys.rideGroup.routeSection), findsNothing);
      expect(find.byType(RideGroupsMap), findsNothing);
      expect(find.byKey(keys.ride.weatherCheckpoint(1)), findsOneWidget);
    });

    testWidgets('sans prévision chargée (leg nul) : pas de Météo', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        fixtureWeather(),
        ride: routed,
        overrides: mapOverrides(loading: true),
      );

      expect(find.byType(RideGroupsMap), findsOneWidget);
      expect(find.byKey(keys.routeDetail.colorByMode('wind')), findsNothing);
    });

    testWidgets('NOT_YET_AVAILABLE : pas de Météo', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        weather(
          status: 'NOT_YET_AVAILABLE',
          legs: <WeatherLegDto>[fixtureLeg(status: 'NOT_YET_AVAILABLE')],
        ),
        ride: routed,
        overrides: mapOverrides(loading: true),
      );

      expect(find.byType(RideGroupsMap), findsOneWidget);
      expect(find.byKey(keys.routeDetail.colorByMode('wind')), findsNothing);
    });

    for (final String status in <String>['OK', 'STALE']) {
      testWidgets(
        '$status : l\'interrupteur, sur la pente par défaut ; Météo au toucher',
        (WidgetTester tester) async {
          await open(
            tester,
            weather(
              status: status,
              legs: <WeatherLegDto>[fixtureLeg(status: status)],
            ),
            ride: routed,
            overrides: mapOverrides(loading: true),
          );

          final Finder toggle = find.byKey(keys.rideGroup.mapColorBy);
          expect(toggle, findsOneWidget);
          expect(
            tester.widget<RouteColorModeSwitch>(toggle).value,
            RouteColorBy.grade,
          );

          final Finder wind = find.byKey(keys.routeDetail.colorByMode('wind'));
          await tester.ensureVisible(wind);
          await tester.tap(wind);
          await tester.pump();

          expect(
            container.read(rideMapColorModeProvider(key)),
            RouteColorBy.wind,
          );
          expect(
            tester.widget<RouteColorModeSwitch>(toggle).value,
            RouteColorBy.wind,
          );
        },
      );
    }

    testWidgets('toucher un point de la frise pose le réticule sur la carte, '
        'à sa distance chaînée ; le retoucher l\'ôte', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(), ride: routed, overrides: mapOverrides());
      expect(probe(tester).cursor, isNull);

      // 15 km chaînés : le 5ᵉ kilomètre de la seconde trace, saut ignoré.
      final Finder enRoute = find.byKey(keys.ride.weatherCheckpoint(1));
      await tester.ensureVisible(enRoute);
      await tester.tap(enRoute);
      await tester.pump();
      expect(
        tester.widget<RideGroupsMap>(find.byType(RideGroupsMap)).cursorDistance,
        15000,
      );
      expect(probe(tester).cursor!.lon, 5.1);
      expect(probe(tester).cursor!.lat, closeTo(45 + 15 * 0.009, 1e-9));
      expect(
        tester.getSemantics(enRoute),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );

      final Finder finish = find.byKey(keys.ride.weatherCheckpoint(2));
      await tester.tap(finish);
      await tester.pump();
      expect(probe(tester).cursor!.lat, closeTo(45 + 30 * 0.009, 1e-9));

      await tester.tap(finish);
      await tester.pump();
      expect(probe(tester).cursor, isNull);
      // Le réticule ne touche pas au choix de la personne sous la carte.
      expect(container.read(rideMapColorModeProvider(key)), RouteColorBy.grade);
    });

    testWidgets('toucher un point de la frise remonte la page jusqu\'à la '
        'carte, sous les pastilles ; le retoucher ne défile pas', (
      WidgetTester tester,
    ) async {
      // Une page de téléphone : la frise est loin sous la carte.
      await open(
        tester,
        weather(),
        ride: routed,
        overrides: mapOverrides(),
        height: 800,
      );
      final Finder point = find.byKey(
        keys.ride.weatherCheckpoint(1),
        skipOffstage: false,
      );
      await tester.ensureVisible(point);
      await tester.pump();
      final Finder map = find.byType(RideGroupsMap, skipOffstage: false);
      expect(tester.getTopLeft(map).dy, lessThan(0));

      await tester.tap(point);
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(probe(tester).cursor, isNotNull);
      final double chipsBottom = tester
          .getBottomLeft(find.byKey(keys.rideGroup.groupChip('g1')))
          .dy;
      final double top = tester.getTopLeft(map).dy;
      expect(top, greaterThanOrEqualTo(chipsBottom - 1));
      expect(top, lessThan(800));

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
      expect(tester.widget<RideGroupsMap>(map).cursorDistance, isNull);
      expect(position.pixels, offset);
    });

    testWidgets(
      '« Réduire les animations » : la page saute jusqu\'à la carte',
      (WidgetTester tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await open(
          tester,
          weather(),
          ride: routed,
          overrides: mapOverrides(),
          height: 800,
        );
        final Finder point = find.byKey(
          keys.ride.weatherCheckpoint(1),
          skipOffstage: false,
        );
        await tester.ensureVisible(point);
        await tester.pump();

        await tester.tap(point);
        await tester.pump();
        await tester.pump();
        final double top = tester
            .getTopLeft(find.byType(RideGroupsMap, skipOffstage: false))
            .dy;
        expect(top, greaterThanOrEqualTo(0));
        expect(top, lessThan(800));
      },
    );

    testWidgets('changer de groupe ôte le réticule', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(), ride: routed, overrides: mapOverrides());
      await tester.tap(find.byKey(keys.ride.weatherCheckpoint(1)));
      await tester.pump();
      expect(probe(tester).cursor, isNotNull);

      await tester.tap(find.byKey(keys.rideGroup.groupChip('g2')));
      await tester.pump();
      await tester.tap(find.byKey(keys.rideGroup.groupChip('g1')));
      await tester.pump();
      expect(probe(tester).cursor, isNull);
      await settle(tester);
    });
  });

  // ───────────────────────────────────────────────────────── `?tab=weather`

  group('?tab=', () {
    testWidgets('?tab=weather : la page défile jusqu\'à sa section Météo', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(), height: 800, scrollToWeather: true);
      await settle(tester);

      final ScrollableState scroll = tester.state<ScrollableState>(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      expect(scroll.position.pixels, greaterThan(0));
      final double top = tester
          .getTopLeft(find.byKey(keys.rideGroup.weatherSection))
          .dy;
      // Calée sous les pastilles épinglées, dans l'écran.
      expect(
        top,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byKey(keys.rideGroup.groupChip('g1'))).dy -
              1,
        ),
      );
      expect(top, lessThan(800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sans ?tab= : la page s\'ouvre en haut', (
      WidgetTester tester,
    ) async {
      await open(tester, weather(), height: 800);
      await settle(tester);

      final ScrollableState scroll = tester.state<ScrollableState>(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      expect(scroll.position.pixels, 0);
      expect(find.byKey(keys.rideGroup.departureBlock), findsOneWidget);
    });
  });

  testWidgets('un groupe disparu : un état vide et le retour à la sortie', (
    WidgetTester tester,
  ) async {
    await open(tester, weather(), groupId: 'gone');

    expect(find.byKey(keys.rideGroup.notFound), findsOneWidget);
    expect(find.text('Ce groupe n\'existe plus'), findsOneWidget);
    expect(find.byKey(keys.rideGroup.backToRide), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ─────────────────── par le routeur : `?tab=`, sortie solo ou sans groupe

  group('par le routeur', () {
    final RideDto solo = fixtureRide(
      groups: <RideGroupDto>[fixtureGroup(id: 'g1', name: 'Rapide')],
    );
    const Key home = Key('home');

    late GoRouter router;

    Future<void> mount(
      WidgetTester tester,
      RideDto ride, {
      String initialLocation = '/',
      bool nested = false,
    }) async {
      repository = _Repository(
        ride,
        weather(),
        permissions: permissionsFor(member: true),
      );
      participants = _Participants();
      container = ProviderContainer(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          rideRepositoryProvider.overrideWithValue(repository),
          participantRepositoryProvider.overrideWithValue(participants),
          teamRepositoryProvider.overrideWithValue(_Teams(member: true)),
        ],
      );
      addTearDown(container.dispose);
      // Comme `router.dart` : `?tab=weather` seul compte.
      GoRoute groupRoute(String path) => GoRoute(
        path: path,
        builder: (BuildContext _, GoRouterState state) => RideGroupPage(
          teamSlug: state.pathParameters['teamSlug']!,
          rideSlug: state.pathParameters['rideSlug']!,
          groupId: state.pathParameters['groupId']!,
          scrollToWeather:
              state.uri.queryParameters['tab'] == kRideGroupWeatherTab,
        ),
      );
      router = GoRouter(
        initialLocation: initialLocation,
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext _, GoRouterState _) =>
                const Scaffold(body: Text('Accueil', key: home)),
          ),
          for (final MapEntry<String, String> ridePath in PathVariants.ride(
            ':teamSlug',
            ':rideSlug',
          ).entries)
            GoRoute(
              path: ridePath.value,
              builder: (BuildContext _, GoRouterState state) => RideDetailPage(
                teamSlug: state.pathParameters['teamSlug']!,
                rideSlug: state.pathParameters['rideSlug']!,
              ),
              // Comme `router.dart` : la page d'un groupe est une route fille
              // du détail, qu'un lien profond reconstruit dessous.
              routes: <RouteBase>[
                if (nested)
                  groupRoute(
                    PathVariants.rideGroup(
                      ':teamSlug',
                      ':rideSlug',
                      ':groupId',
                    )[ridePath.key]!.substring(ridePath.value.length + 1),
                  ),
              ],
            ),
          if (!nested)
            for (final String path in PathVariants.rideGroup(
              ':teamSlug',
              ':rideSlug',
              ':groupId',
            ).values)
              groupRoute(path),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: PedalonsTheme.build(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
    }

    final String ridePath = Paths.ride(key.teamSlug, key.rideSlug);
    String groupPath(String id) =>
        Paths.rideGroup(key.teamSlug, key.rideSlug, id);

    testWidgets('?tab=weather demande le défilement ; ?tab=participants est '
        'ignoré', (WidgetTester tester) async {
      await mount(tester, twoGroups);

      unawaited(router.push('${groupPath('g1')}?tab=weather'));
      await settle(tester);
      expect(
        tester
            .widget<RideGroupPage>(find.byType(RideGroupPage))
            .scrollToWeather,
        isTrue,
      );

      router.pop();
      await settle(tester);
      unawaited(router.push('${groupPath('g1')}?tab=participants'));
      await settle(tester);
      expect(
        tester
            .widget<RideGroupPage>(find.byType(RideGroupPage))
            .scrollToWeather,
        isFalse,
      );
      expect(find.byType(ParticipantsSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sortie solo, poussée au-dessus du détail : elle s\'efface, le détail '
        'reste', (WidgetTester tester) async {
      await mount(tester, solo);
      unawaited(router.push(ridePath));
      await settle(tester);
      expect(find.byType(RideDetailPage), findsOneWidget);

      unawaited(router.push('${groupPath('g1')}?tab=weather'));
      await settle(tester);

      expect(find.byType(RideGroupPage), findsNothing);
      expect(find.byType(RideDetailPage), findsOneWidget);
      // `?tab=weather` devient un défilement du détail, consommé par lui.
      expect(container.read(rideScrollToWeatherProvider(key)), isFalse);

      // Un seul retour mène à l'écran d'avant le détail : pas d'entrée laissée.
      router.pop();
      await settle(tester);
      expect(find.byKey(home), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'sortie solo, poussée au-dessus d\'un autre écran : remplacée par le '
      'détail',
      (WidgetTester tester) async {
        await mount(tester, solo);
        unawaited(router.push(groupPath('g1')));
        await settle(tester);

        expect(find.byType(RideGroupPage), findsNothing);
        expect(find.byType(RideDetailPage), findsOneWidget);

        router.pop();
        await settle(tester);
        expect(find.byKey(home), findsOneWidget);
        expect(find.byType(RideDetailPage), findsNothing);
      },
    );

    testWidgets('sortie solo, ouverte à froid : le détail', (
      WidgetTester tester,
    ) async {
      await mount(tester, solo, initialLocation: groupPath('g1'));

      expect(find.byType(RideGroupPage), findsNothing);
      expect(find.byType(RideDetailPage), findsOneWidget);
      expect(router.canPop(), isFalse);
    });

    testWidgets(
      'sortie solo, lien profond dans la hiérarchie de l\'app : retour au '
      'détail reconstruit dessous',
      (WidgetTester tester) async {
        await mount(
          tester,
          solo,
          initialLocation: '${groupPath('g1')}?tab=weather',
          nested: true,
        );

        expect(find.byType(RideGroupPage), findsNothing);
        expect(find.byType(RideDetailPage), findsOneWidget);
        expect(router.routerDelegate.currentConfiguration.uri.path, ridePath);
        expect(container.read(rideScrollToWeatherProvider(key)), isFalse);
        expect(router.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('un groupe disparu d\'une sortie solo : le détail aussi', (
      WidgetTester tester,
    ) async {
      await mount(tester, solo, initialLocation: groupPath('gone'));

      expect(find.byKey(keys.rideGroup.notFound), findsNothing);
      expect(find.byType(RideDetailPage), findsOneWidget);
    });

    testWidgets('une sortie sans groupe : le détail', (
      WidgetTester tester,
    ) async {
      await mount(
        tester,
        fixtureRide(groups: const <RideGroupDto>[]),
        initialLocation: groupPath('g1'),
      );

      expect(find.byType(RideGroupPage), findsNothing);
      expect(find.byType(RideDetailPage), findsOneWidget);
    });

    testWidgets('deux groupes et un id inconnu : l\'état vide, inchangé', (
      WidgetTester tester,
    ) async {
      await mount(tester, twoGroups, initialLocation: groupPath('gone'));

      expect(find.byType(RideGroupPage), findsOneWidget);
      expect(find.byKey(keys.rideGroup.notFound), findsOneWidget);
    });
  });
}

const WeatherRainAlertDto _rain70 = WeatherRainAlertDto(
  probability: 70,
  time: '2099-07-29T20:05:00Z',
  condition: 'RAIN',
  distance: 15000,
);
