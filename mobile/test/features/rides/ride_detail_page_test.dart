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
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/data/ride_repository.dart';
import 'package:pedalons/features/rides/domain/ride_group_tab.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_detail_page.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_group_page.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/features/participants/data/participant_repository.dart';
import 'package:pedalons/features/participants/domain/participant_query.dart';
import 'package:pedalons/features/participants/presentation/widgets/participants_sheet.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_group_card.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_solo_group_section.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/features/rides/providers/ride_weather_provider.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
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
  @override
  Future<RoutesBulkResponse> getRoutesBulk(
    String teamSlug,
    List<String> slugs, {
    bool geometry = true,
  }) async => const RoutesBulkResponse(routes: <RouteDetailDto>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
        routeRepositoryProvider.overrideWithValue(_StubRoutes()),
      ],
      child: MaterialApp(
        theme: PedalonsTheme.build(brightness ?? Brightness.light),
        home: RideDetailPage(teamSlug: ride.team.slug, rideSlug: ride.slug),
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
  }) async {
    await tester.pumpWidget(
      app(
        ride,
        member: member,
        brightness: brightness,
        repository: repository,
        role: role,
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

  testWidgets('une sortie sans groupe le dit, plutôt que de ne rien rendre', (
    WidgetTester tester,
  ) async {
    await open(tester, fixtureRide(groups: <RideGroupDto>[]));
    await scrollToGroups(tester);

    expect(find.text('Aucun groupe'), findsOneWidget);
    expect(find.byType(RideGroupCard), findsNothing);
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
      expect(find.byKey(keys.ride.soloGroupSection), findsOneWidget);
    });
  }

  group('météo', () {
    RideWeatherDto ok({String status = 'OK'}) => fixtureWeather(
      status: status,
      departure: fixtureConditions(),
      fetchedAt: '2099-07-29T17:00:00Z',
      legs: <WeatherLegDto>[
        fixtureLeg(
          rainAlert: const WeatherRainAlertDto(
            probability: 70,
            time: '2099-07-29T20:05:00Z',
            condition: 'RAIN',
            distance: 15000,
          ),
        ),
      ],
    );

    testWidgets('la carte dit la météo au départ, et elle seule', (
      WidgetTester tester,
    ) async {
      final RideDto ride = twoGroups();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: ok()),
      );

      expect(find.byKey(keys.ride.weatherCard), findsOneWidget);
      expect(find.text('Météo au départ'), findsOneWidget);
      expect(find.text('14\u00a0°C'), findsWidgets);
      expect(find.text('Partiellement nuageux'), findsWidgets);
      expect(find.textContaining('Ressenti'), findsOneWidget);
      // Ni le vent le long du parcours ni l'alerte pluie d'un groupe : ils
      // vivent dans la page du groupe (ledger `MOB-67`).
      expect(find.byType(PdlSegmentBar), findsNothing);
      expect(find.textContaining('Pluie probable'), findsNothing);
      expect(find.byKey(keys.ride.weatherOpenButton), findsNothing);
      expect(find.text('Voir la météo du parcours'), findsNothing);
      expect(find.text('Prévision ancienne'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('une sortie sans groupe garde son vent et sa pluie', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide(groups: const <RideGroupDto>[]);
      final RideWeatherDto weather = fixtureWeather(
        status: 'OK',
        departure: fixtureConditions(),
        legs: <WeatherLegDto>[
          fixtureLeg(
            groupId: null,
            rainAlert: const WeatherRainAlertDto(
              probability: 70,
              time: '2099-07-29T20:05:00Z',
              condition: 'RAIN',
              distance: 15000,
            ),
          ),
        ],
      );
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: weather),
      );

      expect(find.byKey(keys.ride.weatherCard), findsOneWidget);
      expect(find.byType(PdlSegmentBar), findsOneWidget);
      expect(find.textContaining('Pluie probable (70\u00a0%)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('une sortie à un groupe déroule le leg de son groupe', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(402 * 3, 4000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: ok()),
      );

      expect(find.byKey(keys.ride.weatherCard), findsOneWidget);
      // Un seul « Météo au départ » : le leg se déroule dessous, pas dans un
      // second bloc.
      expect(find.text('Météo au départ'), findsOneWidget);
      expect(find.text('Météo du parcours'), findsOneWidget);
      expect(find.textContaining('Pluie probable (70\u00a0%)'), findsOneWidget);
      expect(find.text('Exposition au vent'), findsOneWidget);
      expect(find.byType(PdlSegmentBar), findsOneWidget);
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
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(
            status: 'OK',
            departure: fixtureConditions(),
            legs: <WeatherLegDto>[fixtureLeg(groupId: 'other')],
          ),
        ),
      );

      expect(find.byKey(keys.ride.weatherCard), findsOneWidget);
      expect(find.byType(PdlSegmentBar), findsNothing);
      expect(find.byKey(keys.ride.weatherCheckpoint(0)), findsNothing);
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
          matching: find.textContaining('PLUIE 70'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('la carte compacte crédite Open-Meteo (CC BY 4.0)', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: ok()),
      );

      expect(find.byKey(keys.ride.weatherAttribution), findsOneWidget);
      expect(find.text('Prévisions : Open-Meteo.com'), findsOneWidget);
    });

    group('pendant le chargement', () {
      final Finder weatherSkeleton = find.byWidgetPredicate(
        (Widget w) => w is PdlSkeleton && w.height == 96,
      );

      Future<void> openLoading(WidgetTester tester, RideDto ride) => open(
        tester,
        ride,
        repository: _StubRideRepository(ride)..weatherNeverCompletes = true,
      );

      testWidgets('un squelette quand le résumé annonce une prévision', (
        WidgetTester tester,
      ) async {
        await openLoading(
          tester,
          fixtureRide().copyWith(
            weather: const RideWeatherSummaryDto(status: 'OK', temperature: 14),
          ),
        );

        expect(weatherSkeleton, findsOneWidget);
      });

      testWidgets('NOT_YET_AVAILABLE : la carte, tout de suite', (
        WidgetTester tester,
      ) async {
        await openLoading(
          tester,
          fixtureRide().copyWith(
            weather: const RideWeatherSummaryDto(
              status: 'NOT_YET_AVAILABLE',
              availableFrom: '2099-07-22T19:30:00Z',
            ),
          ),
        );

        expect(weatherSkeleton, findsNothing);
        expect(find.byKey(keys.ride.weatherNotYetAvailable), findsOneWidget);
      });

      testWidgets('sans résumé, rien : le bloc sera peut-être masqué', (
        WidgetTester tester,
      ) async {
        await openLoading(tester, fixtureRide());

        expect(weatherSkeleton, findsNothing);
        expect(find.byKey(keys.ride.weatherCard), findsNothing);
      });
    });

    testWidgets('STALE se montre, et se signale', (WidgetTester tester) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: ok(status: 'STALE')),
      );

      expect(find.byKey(keys.ride.weatherCard), findsOneWidget);
      expect(find.text('PRÉVISION ANCIENNE'), findsOneWidget);
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
                initialTab: RideGroupTab.fromQuery(
                  state.uri.queryParameters['tab'],
                ),
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
      expect(find.byKey(keys.rideGroup.tabOverview), findsOneWidget);
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
      await open(tester, ride, repository: repository);

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
      await open(tester, ride, repository: repository);

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
        find.textContaining('Prévision disponible à partir du'),
        findsOneWidget,
      );
    });

    testWidgets('NOT_YET_AVAILABLE sans date : la règle des sept jours', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(status: 'NOT_YET_AVAILABLE'),
        ),
      );

      expect(find.byKey(keys.ride.weatherNotYetAvailable), findsOneWidget);
      expect(
        find.text('La météo sera disponible sept jours avant le départ.'),
        findsOneWidget,
      );
    });

    testWidgets('NO_LOCATION : rien pour un membre', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        role: 'MEMBER',
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(status: 'NO_LOCATION'),
        ),
      );

      expect(find.byKey(keys.ride.weatherNoLocation), findsNothing);
    });

    testWidgets('NO_LOCATION : un mot pour l\'organisateur', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        role: 'ORGANIZER',
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(status: 'NO_LOCATION'),
        ),
      );

      expect(find.byKey(keys.ride.weatherNoLocation), findsOneWidget);
    });

    testWidgets('un statut inconnu ne rend rien', (WidgetTester tester) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(
          ride,
          weather: fixtureWeather(status: 'SOMETHING_NEW'),
        ),
      );

      expect(find.byKey(keys.ride.weatherCard), findsNothing);
      expect(find.byKey(keys.ride.weatherUnavailable), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('une sortie terminée ne demande même pas la météo', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide(dateTime: '2020-01-01T08:00:00Z');
      final _StubRideRepository repository = _StubRideRepository(
        ride,
        weather: ok(),
      );
      await open(tester, ride, repository: repository);

      expect(find.byKey(keys.ride.weatherCard), findsNothing);
      expect(repository.weatherCalls, 0);
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

  // ─────────────────────────────────────────── sortie solo (ledger MOB-69)

  group('sortie à un seul groupe', () {
    RideWeatherDto ok() => fixtureWeather(
      status: 'OK',
      departure: fixtureConditions(),
      fetchedAt: '2099-07-29T17:00:00Z',
      legs: <WeatherLegDto>[fixtureLeg()],
    );

    testWidgets('la section du groupe remplace les cartes, sans lien', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
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

      expect(find.byType(RideSoloGroupSection), findsOneWidget);
      expect(find.byKey(keys.ride.soloGroupHeader), findsOneWidget);
      expect(find.text('Groupe Chill Route Long'), findsOneWidget);
      expect(find.byType(RideGroupCard), findsNothing);
      expect(find.text('Groupes'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(RideSoloGroupSection),
          matching: find.byIcon(PdlIcons.chevronRight),
        ),
        findsNothing, // ni lien d'en-tête, ni second « Voir la liste »
      );
      // Un seul « voir les participants » : celui du bloc méta, au-dessus.
      expect(find.byKey(keys.rideGroup.viewAllParticipants), findsNothing);

      await tester.tap(find.byKey(keys.ride.soloGroupHeader));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RideGroupPage), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Rejoindre » est dans la barre d\'action, avec les places', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      final _StubRideRepository repository = _StubRideRepository(ride);
      await open(tester, ride, repository: repository);

      expect(find.byKey(keys.rideGroup.participantsCount), findsOneWidget);
      expect(find.text('3/16 personnes'), findsOneWidget);
      expect(find.text('13 places restantes'), findsOneWidget);
      expect(find.byKey(keys.rideGroup.viewMyGroup), findsNothing);

      await tester.tap(find.byKey(keys.rideGroup.joinButton));
      await tester.pump();
      await tester.pump();

      expect(repository.joined, <String>['g1']);
    });

    testWidgets('un refus de « Rejoindre » fait défiler jusqu\'à son bandeau', (
      WidgetTester tester,
    ) async {
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
      // La section du groupe est sous le pli : le bandeau n'y est pas bâti.
      expect(find.byKey(keys.ride.soloGroupSection), findsNothing);

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
    });

    testWidgets('inscrit : « Quitter » dans la barre', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide(
        registered: true,
        registeredGroupId: 'g1',
        groups: <RideGroupDto>[fixtureGroup(registered: true)],
      );
      final _StubRideRepository repository = _StubRideRepository(ride);
      await open(tester, ride, repository: repository);

      expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
      await tester.tap(find.byKey(keys.rideGroup.leaveButton));
      await tester.pump();
      await tester.pump();

      expect(repository.left, <String>['g1']);
    });

    testWidgets('un groupe complet : le badge, aucun bouton', (
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
          (
            'une sortie passée',
            fixtureRide(dateTime: '2020-01-01T08:00:00Z'),
            true,
          ),
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
        await open(tester, ride, member: member);

        expect(find.byKey(keys.rideGroup.joinButton), findsNothing);
        expect(find.byKey(keys.rideGroup.leaveButton), findsNothing);
        expect(find.text('Rejoindre'), findsNothing);
        expect(find.text('Quitter'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('les chiffres du groupe, et son arrivée estimée', (
      WidgetTester tester,
    ) async {
      final RideDto ride = fixtureRide();
      await open(
        tester,
        ride,
        repository: _StubRideRepository(ride, weather: ok()),
      );
      await scrollToGroups(tester);

      expect(find.text('Départ'), findsOneWidget);
      expect(find.text('Allure moyenne'), findsOneWidget);
      expect(find.text('Dénivelé positif'), findsOneWidget);
      expect(find.textContaining('Arrivée estimée'), findsOneWidget);
    });

    testWidgets('meneur nul : rien, jamais de repli', (
      WidgetTester tester,
    ) async {
      await open(tester, fixtureRide());
      await scrollToGroups(tester);

      expect(find.byKey(keys.ride.soloGroupSection), findsOneWidget);
      expect(find.byKey(keys.rideGroup.leader), findsNothing);
      expect(find.text('CAPITAINE'), findsNothing);
    });

    testWidgets('un meneur désigné : son nom et le badge', (
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
      );
      await scrollToGroups(tester);

      expect(find.byKey(keys.rideGroup.leader), findsOneWidget);
      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('CAPITAINE'), findsOneWidget);
    });

    testWidgets('les visages du groupe ouvrent la feuille du groupe', (
      WidgetTester tester,
    ) async {
      await open(tester, fixtureRide());
      await scrollToGroups(tester);

      await tester.ensureVisible(find.byKey(keys.ride.soloGroupParticipants));
      await tester.tap(find.byKey(keys.ride.soloGroupParticipants));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(ParticipantsSheet), findsOneWidget);
      expect(find.text('Membre 0'), findsWidgets);
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

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(RideDetailPage)));

    testWidgets('une prévision : la puce sous la carte, éteinte par défaut', (
      WidgetTester tester,
    ) async {
      tall(tester);
      await open(
        tester,
        solo,
        repository: _StubRideRepository(solo, weather: served()),
      );

      final Finder chip = find.byKey(keys.ride.windMapChip);
      expect(chip, findsOneWidget);
      expect(tester.widget<PdlChip>(chip).selected, isFalse);
      expect(containerOf(tester).read(rideMapWindModeProvider(key)), isFalse);

      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
      expect(containerOf(tester).read(rideMapWindModeProvider(key)), isTrue);
      expect(tester.widget<PdlChip>(chip).selected, isTrue);
    });

    testWidgets('le parcours du groupe masqué dans les couches : plus de '
        'puce', (WidgetTester tester) async {
      tall(tester);
      final RideDto twoLayers = solo.copyWith(routeSlug: 'principal');
      await open(
        tester,
        twoLayers,
        repository: _StubRideRepository(twoLayers, weather: served()),
      );
      expect(find.byKey(keys.ride.windMapChip), findsOneWidget);

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
      testWidgets('$status : pas de puce', (WidgetTester tester) async {
        tall(tester);
        await open(
          tester,
          solo,
          repository: _StubRideRepository(
            solo,
            weather: served(status: status),
          ),
        );
        expect(find.byKey(keys.ride.windMapChip), findsNothing);
      });
    }

    testWidgets('une sortie terminée : pas de puce, pas de météo', (
      WidgetTester tester,
    ) async {
      tall(tester);
      final RideDto past = fixtureRide(
        dateTime: '2020-07-29T19:30:00Z',
        groups: <RideGroupDto>[fixtureGroup(routeSlug: 'court')],
      );
      final _StubRideRepository repository = _StubRideRepository(
        past,
        weather: served(),
      );
      await open(tester, past, repository: repository);
      expect(find.byKey(keys.ride.windMapChip), findsNothing);
      expect(repository.weatherCalls, 0);
    });

    testWidgets('une sortie annulée : pas de puce', (
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
      expect(find.byKey(keys.ride.windMapChip), findsNothing);
    });

    testWidgets('plusieurs groupes : pas de puce sous la carte de la sortie', (
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
        repository: _StubRideRepository(two, weather: served()),
      );
      expect(find.byKey(keys.ride.windMapChip), findsNothing);
    });

    testWidgets('une prévision perdue au refetch éteint le mode, qui ne '
        'revient pas seul', (WidgetTester tester) async {
      tall(tester);
      final _StubRideRepository repository = _StubRideRepository(
        solo,
        weather: served(),
      );
      await open(tester, solo, repository: repository);
      final ProviderContainer container = containerOf(tester);
      container.read(rideMapWindModeProvider(key).notifier).state = true;
      await tester.pump();

      repository.weather = served(status: 'UNAVAILABLE');
      container.invalidate(rideWeatherProvider(key));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(container.read(rideMapWindModeProvider(key)), isFalse);
      expect(find.byKey(keys.ride.windMapChip), findsNothing);

      // Revenue, la prévision rend la puce, éteinte.
      repository.weather = served();
      container.invalidate(rideWeatherProvider(key));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.byKey(keys.ride.windMapChip), findsOneWidget);
      expect(container.read(rideMapWindModeProvider(key)), isFalse);
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
      container.read(rideMapWindModeProvider(key).notifier).state = true;
      // La page défile : la carte et sa puce quittent l'écran.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(container.read(rideMapWindModeProvider(key)), isTrue);
    });
  });
}
