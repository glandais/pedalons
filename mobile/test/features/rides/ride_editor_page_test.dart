import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.generated.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/data/ride_editor_repository.dart';
import 'package:pedalons/features/rides/data/ride_repository.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_editor_page.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// L'éditeur de sortie (ledger `MOB-80`) : le refus pour qui n'organise pas,
/// et surtout **ce qui part** — la requête que le serveur appliquera champ par
/// champ, absents compris.
class _StubRides implements RideRepository {
  _StubRides(this.ride);

  final RideDto ride;
  final List<RideRequest> created = <RideRequest>[];
  final List<RideRequest> updated = <RideRequest>[];

  @override
  Future<RideDto> getRide(String teamSlug, String rideSlug) async => ride;

  @override
  Future<RideDto> createRide(String teamSlug, RideRequest request) async {
    created.add(request);
    return ride.copyWith(slug: 'nouvelle-sortie', name: request.name);
  }

  @override
  Future<RideDto> updateRide(
    String teamSlug,
    String rideSlug,
    RideRequest request,
  ) async {
    updated.add(request);
    return ride.copyWith(name: request.name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubEditor implements RideEditorRepository {
  @override
  Future<RideTemplateListResponse> searchTemplates(
    String teamSlug, {
    String? search,
    int page = 0,
  }) async => const RideTemplateListResponse(
    templates: <RideTemplateDto>[],
    total: 0,
    page: 0,
    size: 20,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TeamDetailDto _team({String? role}) => TeamDetailDto(
  timezone: 'Europe/Paris',
  role: role,
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  about: const MediaDto(
    markdown: '',
    assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
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
);

class _StubTeams implements TeamRepository {
  _StubTeams(this.role);

  final String? role;

  @override
  Future<TeamDetailDto> getTeam(String slug) async => _team(role: role);

  @override
  Future<List<TeamDetailDto>> getMyTeams() async =>
      role == null ? <TeamDetailDto>[] : <TeamDetailDto>[_team(role: role)];

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

  Future<void> open(
    WidgetTester tester, {
    required _StubRides rides,
    String? role = 'ORGANIZER',
    String? rideSlug,
  }) async {
    // Un écran haut : le formulaire est long, et seul ce qui est construit
    // se trouve.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/editor',
      routes: <RouteBase>[
        GoRoute(
          path: '/editor',
          builder: (BuildContext _, GoRouterState _) =>
              RideEditorPage(teamSlug: 'n-peloton', rideSlug: rideSlug),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/sorties/:rideSlug',
          builder: (BuildContext _, GoRouterState state) =>
              Text('fiche ${state.pathParameters['rideSlug']}'),
        ),
        GoRoute(
          path: PathVariants.rideTemplates(':teamSlug')['fr']!,
          builder: (BuildContext _, GoRouterState state) =>
              Text('liste modèles ${state.pathParameters['teamSlug']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          rideRepositoryProvider.overrideWithValue(rides),
          rideEditorRepositoryProvider.overrideWithValue(_StubEditor()),
          teamRepositoryProvider.overrideWithValue(_StubTeams(role)),
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
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('un simple membre lit un refus, pas un formulaire', (
    WidgetTester tester,
  ) async {
    await open(tester, rides: _StubRides(fixtureRide()), role: 'MEMBER');

    expect(find.byKey(keys.rideEditor.forbidden), findsOneWidget);
    expect(find.byKey(keys.rideEditor.saveButton), findsNothing);
  });

  testWidgets('un nom trop court bloque l\'envoi et le dit', (
    WidgetTester tester,
  ) async {
    final _StubRides rides = _StubRides(fixtureRide());
    await open(tester, rides: rides);

    await tester.enterText(find.byKey(keys.rideEditor.nameField), 'ab');
    await tester.tap(find.byKey(keys.rideEditor.saveButton));
    await tester.pump();

    expect(rides.created, isEmpty);
    expect(find.byKey(keys.rideEditor.errorBanner), findsOneWidget);
    expect(find.text('Entre 3 et 200 caractères'), findsOneWidget);
  });

  testWidgets('créer envoie un brouillon d\'un groupe, puis ouvre la fiche', (
    WidgetTester tester,
  ) async {
    final _StubRides rides = _StubRides(fixtureRide());
    await open(tester, rides: rides);

    await tester.enterText(
      find.byKey(keys.rideEditor.nameField),
      'Sortie du dimanche',
    );
    await tester.tap(find.byKey(keys.rideEditor.saveButton));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    final RideRequest request = rides.created.single;
    expect(request.name, 'Sortie du dimanche');
    expect(request.status, 'DRAFT');
    expect(request.visibility, 'PUBLIC');
    expect(request.groups.single.name, 'Groupe 1');
    expect(request.groups.single.id, isNull);
    // Une heure murale, sans offset : le serveur refuse un `Z`.
    expect(request.dateTime, matches(RegExp(r'^\d{4}-\d\d-\d\dT08:00:00$')));
    expect(find.text('fiche nouvelle-sortie'), findsOneWidget);
  });

  testWidgets('modifier renvoie groupes, meneur et lieux tels quels', (
    WidgetTester tester,
  ) async {
    final RideDto ride =
        fixtureRide(
          dateTime: '2026-07-29T19:30:00Z',
          groups: <RideGroupDto>[
            fixtureGroup(
              id: 'g1',
              leader: const PublicUserDto(id: 'u9', displayName: 'Léa'),
            ),
            fixtureGroup(id: 'g2', name: 'B'),
          ],
        ).copyWith(
          startPlace: const PlaceDetailDto(
            id: 'p1',
            name: 'Fonderies',
            startPlace: true,
            endPlace: false,
          ),
        );
    final _StubRides rides = _StubRides(ride);
    await open(tester, rides: rides, rideSlug: ride.slug);

    // Le nom du meneur vient de la sortie, pas d'un appel de plus.
    expect(find.text('Léa'), findsOneWidget);

    await tester.enterText(
      find.byKey(keys.rideEditor.nameField),
      'Nouveau nom',
    );
    await tester.tap(find.byKey(keys.rideEditor.saveButton));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    final RideRequest request = rides.updated.single;
    expect(request.name, 'Nouveau nom');
    expect(request.groups.map((GroupRequest g) => g.id), <String>['g1', 'g2']);
    expect(request.groups.first.leaderId, 'u9');
    expect(request.startPlaceId, 'p1');
    expect(request.dateTime, '2026-07-29T21:30:00');
  });

  testWidgets('la feuille « Charger un modèle » mène à la gestion des modèles '
      '(MOB-78)', (WidgetTester tester) async {
    await open(tester, rides: _StubRides(fixtureRide()));

    await tester.tap(find.byKey(keys.rideEditor.templateButton));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Choisir un modèle'), findsOneWidget);
    expect(find.byKey(keys.rideEditor.manageTemplatesButton), findsOneWidget);
    expect(find.text('Gérer les modèles'), findsOneWidget);

    // Le toucher ferme la feuille et pousse la liste des modèles de l'équipe.
    await tester.tap(find.byKey(keys.rideEditor.manageTemplatesButton));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('liste modèles n-peloton'), findsOneWidget);
    expect(find.text('Choisir un modèle'), findsNothing);
    expect(find.byKey(keys.rideEditor.manageTemplatesButton), findsNothing);
  });
}
