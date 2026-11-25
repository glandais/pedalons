import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/domain/route_filters.dart';
import 'package:pedalons/features/routes/presentation/pages/routes_page.dart';
import 'package:pedalons/features/routes/providers/route_editor_providers.dart';
import 'package:pedalons/features/routes/providers/route_list_provider.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';

/// Le bouton « Créer » de la section Parcours (ledger `MOB-79`, règle RL13) : pour un
/// organisateur de l'équipe, à droite de la recherche — ni pour un simple
/// membre, ni sur l'onglet Explorer de toutes les équipes.
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
    required String? teamSlug,
    required bool canManage,
    bool planner = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) =>
              RoutesPage(teamSlug: teamSlug),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/parcours/nouveau',
          builder: (BuildContext _, GoRouterState state) => Text(
            'nouveau ${state.pathParameters['teamSlug']} '
            '${state.uri.queryParameters['gpx'] ?? '-'}',
          ),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/parcours/generer',
          builder: (BuildContext _, GoRouterState state) =>
              Text('générer ${state.pathParameters['teamSlug']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routeListProvider.overrideWith(
            (ref, key) => _StuckRouteListNotifier(key),
          ),
          teamTagsProvider.overrideWith(
            (ref, key) async => const <TagWithUsageDto>[],
          ),
          canManageRoutesProvider.overrideWith((ref, slug) => canManage),
          teamDetailProvider.overrideWith(
            (Ref ref, String slug) async => _team(planner: planner),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  // Les squelettes de la liste s'animent sans fin : pas de pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('RL13 — un organisateur voit « Créer » et ouvre la création', (
    WidgetTester tester,
  ) async {
    await open(tester, teamSlug: 'n-peloton', canManage: true);

    expect(find.byKey(keys.routes.createButton), findsOneWidget);
    // Le texte visible est court ; le lecteur d'écran lit le nom complet.
    expect(find.text('Créer'), findsOneWidget);
    expect(find.bySemanticsLabel('Créer un parcours'), findsOneWidget);

    await tester.tap(find.byKey(keys.routes.createButton));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('nouveau n-peloton -'), findsOneWidget);
  });

  testWidgets(
    'le chevron ouvre la feuille : formulaire, import d\'un GPX, générateur',
    (WidgetTester tester) async {
      await open(tester, teamSlug: 'n-peloton', canManage: true);

      await tester.tap(find.byKey(keys.routes.createMenuButton));
      await settle(tester);
      expect(find.byKey(keys.routes.createRouteRow), findsOneWidget);
      expect(find.byKey(keys.routes.generateRow), findsOneWidget);

      await tester.tap(find.byKey(keys.routes.importGpxRow));
      await settle(tester);
      // L'éditeur s'ouvre en lançant le choix du fichier.
      expect(find.text('nouveau n-peloton import'), findsOneWidget);
    },
  );

  testWidgets('sans planificateur, pas de générateur dans la feuille', (
    WidgetTester tester,
  ) async {
    await open(tester, teamSlug: 'n-peloton', canManage: true, planner: false);

    await tester.tap(find.byKey(keys.routes.createMenuButton));
    await settle(tester);
    expect(find.byKey(keys.routes.importGpxRow), findsOneWidget);
    expect(find.byKey(keys.routes.generateRow), findsNothing);
  });

  testWidgets('un simple membre ne voit rien', (WidgetTester tester) async {
    await open(tester, teamSlug: 'n-peloton', canManage: false);

    expect(find.byKey(keys.routes.createButton), findsNothing);
  });

  testWidgets('l\'onglet Explorer de toutes les équipes non plus', (
    WidgetTester tester,
  ) async {
    await open(tester, teamSlug: null, canManage: true);

    expect(find.byKey(keys.routes.createButton), findsNothing);
  });
}

TeamDetailDto _team({bool planner = true}) => TeamDetailDto(
  allowedContentVisibilities: kAllContentVisibilities,
  defaultContentVisibility: 'PUBLIC',
  publicContentAllowed: false,
  tier: 'FREE',
  timezone: 'Europe/Paris',
  role: 'ORGANIZER',
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
  enableRoutePlanner: planner,
  memberCount: 40,
  upcomingRideCount: 3,
  routeCount: 12,
  upcomingTripCount: 0,
  recentPostCount: 0,
  createdAt: '2024-01-01T00:00:00Z',
);

/// Ne répond jamais : la page reste sur son squelette, aucun appel HTTP.
class _StuckRouteListNotifier extends RouteListNotifier {
  _StuckRouteListNotifier(RouteFilters filters)
    : super(RouteRepository(RoutesClient(Dio())), filters);

  @override
  Future<PageResult<RouteDto>> fetchPage(int page) =>
      Completer<PageResult<RouteDto>>().future;
}
