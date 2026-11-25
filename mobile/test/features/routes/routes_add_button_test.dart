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
    bool quotaSpent = false,
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
            '${state.uri.queryParameters['gpx'] ?? (state.uri.queryParameters.containsKey('tracer') ? 'tracer' : '-')}',
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
            (Ref ref, String slug) async =>
                _team(planner: planner, quotaSpent: quotaSpent),
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
    expect(find.bySemanticsLabel('Tracer sur la carte'), findsOneWidget);

    // Le bouton ouvre l'éditeur sur le planificateur, sans la page de choix.
    await tester.tap(find.byKey(keys.routes.createButton));
    await settle(tester);
    expect(find.text('nouveau n-peloton tracer'), findsOneWidget);
  });

  testWidgets(
    'le chevron ouvre la feuille : tracer, importer un GPX, générer',
    (WidgetTester tester) async {
      await open(tester, teamSlug: 'n-peloton', canManage: true);

      await tester.tap(find.byKey(keys.routes.createMenuButton));
      await settle(tester);
      expect(find.byKey(keys.routes.drawRow), findsOneWidget);
      expect(find.byKey(keys.routes.generateRow), findsOneWidget);

      await tester.tap(find.byKey(keys.routes.importGpxRow));
      await settle(tester);
      // L'éditeur s'ouvre en lançant le choix du fichier.
      expect(find.text('nouveau n-peloton import'), findsOneWidget);
    },
  );

  testWidgets('sans planificateur : un seul bouton, qui importe un GPX', (
    WidgetTester tester,
  ) async {
    await open(tester, teamSlug: 'n-peloton', canManage: true, planner: false);

    expect(find.byKey(keys.routes.createMenuButton), findsNothing);
    expect(find.bySemanticsLabel('Importer des GPX'), findsOneWidget);
    await tester.tap(find.byKey(keys.routes.createButton));
    await settle(tester);
    expect(find.text('nouveau n-peloton import'), findsOneWidget);
  });

  testWidgets('quota du mois épuisé : tracer et générer fermés avec leur '
      'raison, le bouton importe (MOB-189)', (WidgetTester tester) async {
    await open(
      tester,
      teamSlug: 'n-peloton',
      canManage: true,
      quotaSpent: true,
    );
    expect(find.bySemanticsLabel('Importer des GPX'), findsOneWidget);

    await tester.tap(find.byKey(keys.routes.createMenuButton));
    await settle(tester);
    expect(
      find.text('Les enregistrements de tracés du mois sont épuisés.'),
      findsNWidgets(2),
    );
    await tester.tap(find.byKey(keys.routes.drawRow));
    await settle(tester);
    // La ligne est inerte : la feuille reste.
    expect(find.byKey(keys.routes.drawRow), findsOneWidget);
    expect(find.textContaining('nouveau n-peloton'), findsNothing);
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

TeamDetailDto _team({bool planner = true, bool quotaSpent = false}) =>
    TeamDetailDto(
      plannerQuota: quotaSpent
          ? const PlannerQuotaDto(limit: 20, used: 20, resetsOn: '2026-12-01')
          : null,
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
