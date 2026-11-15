import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.generated.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/data/ride_editor_repository.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/trips/data/trip_repository.dart';
import 'package:pedalons/features/trips/presentation/pages/trip_editor_page.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';
import 'trip_fixtures.dart';

/// L'éditeur de voyage (ledger `MOB-162`) : le refus pour qui n'organise pas,
/// et surtout **ce qui part** — la requête que le serveur appliquera champ par
/// champ, étapes comprises.
class _StubTrips implements TripRepository {
  _StubTrips(this.trip);

  final TripDto trip;
  final List<TripRequest> created = <TripRequest>[];
  final List<TripRequest> updated = <TripRequest>[];
  ContentPermissionsDto? permissions;

  @override
  Future<TripDto> getTrip(String teamSlug, String tripSlug) async =>
      permissions == null ? trip : trip.copyWith(permissions: permissions!);

  @override
  Future<TripDto> createTrip(String teamSlug, TripRequest request) async {
    created.add(request);
    return trip.copyWith(slug: 'nouveau-voyage', name: request.name);
  }

  @override
  Future<TripDto> updateTrip(
    String teamSlug,
    String tripSlug,
    TripRequest request,
  ) async {
    updated.add(request);
    return trip.copyWith(name: request.name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubEditor implements RideEditorRepository {
  @override
  Future<List<RouteDetailDto>> routesBulk(
    String teamSlug,
    List<String> slugs,
  ) async => const <RouteDetailDto>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TeamDetailDto _team({String? role, bool enableTrips = true}) => TeamDetailDto(
  allowedContentVisibilities: kAllContentVisibilities,
  defaultContentVisibility: 'PUBLIC',
  publicContentAllowed: false,
  tier: 'FREE',
  timezone: 'Europe/Paris',
  role: role,
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  about: kEmptyMedia,
  visibility: 'PUBLIC',
  enableTrips: enableTrips,
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
);

class _StubTeams implements TeamRepository {
  _StubTeams(this.role, {this.enableTrips = true});

  final String? role;
  final bool enableTrips;

  @override
  Future<TeamDetailDto> getTeam(String slug) async =>
      _team(role: role, enableTrips: enableTrips);

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => role == null
      ? <TeamDetailDto>[]
      : <TeamDetailDto>[_team(role: role, enableTrips: enableTrips)];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;
  setUp(() async {
    setCurrentLocale('fr');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> settle(WidgetTester tester, [int pumps = 6]) async {
    for (int i = 0; i < pumps; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    required _StubTrips trips,
    String? role = 'ORGANIZER',
    String? tripSlug,
    bool enableTrips = true,
  }) async {
    // Un écran haut : le formulaire est long, et seul ce qui est construit
    // se trouve.
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/editor',
      routes: <RouteBase>[
        GoRoute(
          path: '/editor',
          builder: (BuildContext _, GoRouterState _) =>
              TripEditorPage(teamSlug: 'n-peloton', tripSlug: tripSlug),
        ),
        GoRoute(
          path: PathVariants.trip(':teamSlug', ':tripSlug')['fr']!,
          builder: (BuildContext _, GoRouterState state) =>
              Text('voyage ${state.pathParameters['tripSlug']}'),
        ),
      ],
    );
    // Le droit sur le voyage modifié, tel que le serveur le calcule pour ce
    // rôle (docs/LEDGER_*.md MOB-137).
    trips.permissions ??= permissionsFor(member: role != null, role: role);
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tripRepositoryProvider.overrideWithValue(trips),
          rideEditorRepositoryProvider.overrideWithValue(_StubEditor()),
          teamRepositoryProvider.overrideWithValue(
            _StubTeams(role, enableTrips: enableTrips),
          ),
          teamTagsProvider.overrideWith(
            (Ref ref, ({String teamSlug, TagTarget type}) key) async =>
                <TagWithUsageDto>[],
          ),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('un simple membre lit un refus, pas un formulaire', (
    WidgetTester tester,
  ) async {
    await open(tester, trips: _StubTrips(fixtureTrip()), role: 'MEMBER');

    expect(find.byKey(keys.tripEditor.forbidden), findsOneWidget);
    expect(find.byKey(keys.tripEditor.saveButton), findsNothing);
  });

  testWidgets('module voyages coupé : le même écran, un autre message', (
    WidgetTester tester,
  ) async {
    await open(tester, trips: _StubTrips(fixtureTrip()), enableTrips: false);

    expect(find.byKey(keys.tripEditor.forbidden), findsOneWidget);
    expect(
      find.text(
        'Les voyages ou les parcours sont désactivés pour cette équipe.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('modifier sans canEdit : le refus, même pour un organisateur', (
    WidgetTester tester,
  ) async {
    final _StubTrips trips = _StubTrips(fixtureTrip())
      ..permissions = kNoPermissions;
    await open(tester, trips: trips, tripSlug: 'gtmc-bromance');

    expect(find.byKey(keys.tripEditor.forbidden), findsOneWidget);
  });

  testWidgets('sans nom : rien ne part, le champ le dit', (
    WidgetTester tester,
  ) async {
    final _StubTrips trips = _StubTrips(fixtureTrip());
    await open(tester, trips: trips);

    await tester.tap(find.byKey(keys.tripEditor.saveButton));
    await tester.pump();

    expect(trips.created, isEmpty);
    expect(find.byKey(keys.tripEditor.errorBanner), findsOneWidget);
    expect(find.text('Entre 1 et 200 caractères'), findsOneWidget);
  });

  testWidgets('créer envoie un brouillon d\'une étape, puis ouvre le voyage', (
    WidgetTester tester,
  ) async {
    final _StubTrips trips = _StubTrips(fixtureTrip());
    await open(tester, trips: trips);

    await tester.enterText(find.byKey(keys.tripEditor.nameField), 'GTMC');
    await tester.tap(find.byKey(keys.tripEditor.saveButton));
    await settle(tester, 4);

    final TripRequest request = trips.created.single;
    expect(request.name, 'GTMC');
    expect(request.status, 'DRAFT');
    expect(request.visibility, 'PUBLIC');
    // Une heure murale, sans offset : le serveur refuse un `Z`.
    expect(request.dateTime, matches(RegExp(r'^\d{4}-\d\d-\d\dT08:00:00$')));
    expect(request.stages.single.name, 'Étape 1');
    expect(request.stages.single.id, isNull);
    expect(request.stages.single.dateTime, request.dateTime);
    expect(find.text('voyage nouveau-voyage'), findsOneWidget);
  });

  testWidgets('« Ajouter une étape » la pose le lendemain, à la même heure', (
    WidgetTester tester,
  ) async {
    final _StubTrips trips = _StubTrips(fixtureTrip());
    await open(tester, trips: trips);

    await tester.enterText(find.byKey(keys.tripEditor.nameField), 'GTMC');
    await tester.tap(find.byKey(keys.tripEditor.addStageButton));
    await tester.pump();
    expect(find.byKey(keys.tripEditor.stage(1)), findsOneWidget);

    await tester.tap(find.byKey(keys.tripEditor.saveButton));
    await settle(tester, 4);

    final List<StageRequest> stages = trips.created.single.stages;
    expect(stages.map((StageRequest s) => s.name), <String>[
      'Étape 1',
      'Étape 2',
    ]);
    final DateTime first = DateTime.parse(stages.first.dateTime);
    final DateTime second = DateTime.parse(stages.last.dateTime);
    expect(second.difference(first), const Duration(days: 1));
    expect(second.hour, 8);
  });

  testWidgets('modifier renvoie les étapes, leur parcours et leurs lieux tels '
      'quels', (WidgetTester tester) async {
    final TripDto trip = fixtureTrip(
      dateTime: '2026-08-12T07:00:00Z',
      stages: <TripStageDto>[
        fixtureStage(
          index: 1,
          stageCount: 2,
          dateTime: '2026-08-12T07:00:00Z',
          route: fixtureStageRoute(),
          startPlaceName: 'Clermont',
          endPlaceName: 'Volvic',
        ),
        fixtureStage(index: 2, stageCount: 2, dateTime: '2026-08-13T07:00:00Z'),
      ],
    );
    final _StubTrips trips = _StubTrips(trip);
    await open(tester, trips: trips, tripSlug: trip.slug);

    // Les noms viennent du voyage, pas d'un appel de plus.
    expect(find.text('Clermont'), findsOneWidget);
    expect(find.textContaining('GTMC J1'), findsOneWidget);

    await tester.enterText(
      find.byKey(keys.tripEditor.nameField),
      'Nouveau nom',
    );
    await tester.tap(find.byKey(keys.tripEditor.saveButton));
    await settle(tester, 4);

    final TripRequest request = trips.updated.single;
    expect(request.name, 'Nouveau nom');
    expect(request.stages.map((StageRequest s) => s.id), <String>['s1', 's2']);
    expect(request.stages.first.routeSlug, 'gtmc-j1');
    expect(request.stages.first.startPlaceId, 'p-start-1');
    expect(request.stages.first.endPlaceId, 'p-end-1');
    expect(request.stages.first.dateTime, '2026-08-12T09:00:00');
    expect(request.stages.last.dateTime, '2026-08-13T09:00:00');
    expect(request.dateTime, '2026-08-12T09:00:00');
  });

  testWidgets('descendre une étape échange les rangs, ids gardés', (
    WidgetTester tester,
  ) async {
    final TripDto trip = fixtureTrip(
      stages: <TripStageDto>[
        fixtureStage(index: 1, stageCount: 2),
        fixtureStage(index: 2, stageCount: 2),
      ],
    );
    final _StubTrips trips = _StubTrips(trip);
    await open(tester, trips: trips, tripSlug: trip.slug);

    await tester.tap(find.byKey(keys.tripEditor.stageDown(0)));
    await tester.pump();
    await tester.tap(find.byKey(keys.tripEditor.saveButton));
    await settle(tester, 4);

    expect(trips.updated.single.stages.map((StageRequest s) => s.id), <String>[
      's2',
      's1',
    ]);
  });

  testWidgets('retirer une étape enregistrée demande confirmation', (
    WidgetTester tester,
  ) async {
    final TripDto trip = fixtureTrip(
      stages: <TripStageDto>[
        fixtureStage(index: 1, stageCount: 2),
        fixtureStage(index: 2, stageCount: 2),
      ],
    );
    final _StubTrips trips = _StubTrips(trip);
    await open(tester, trips: trips, tripSlug: trip.slug);

    await tester.tap(find.byKey(keys.tripEditor.stageRemove(0)));
    await settle(tester, 20);
    expect(find.text('Retirer cette étape ?'), findsOneWidget);
    expect(find.byKey(keys.tripEditor.stage(1)), findsOneWidget);

    await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
    await settle(tester, 20);
    expect(find.byKey(keys.tripEditor.stage(1)), findsNothing);

    await tester.tap(find.byKey(keys.tripEditor.saveButton));
    await settle(tester, 4);
    expect(trips.updated.single.stages.map((StageRequest s) => s.id), <String>[
      's2',
    ]);
  });
}
