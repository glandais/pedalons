import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/dev/card_gallery/gallery_data.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/domain/route_filters.dart';
import 'package:pedalons/features/routes/presentation/pages/routes_page.dart';
import 'package:pedalons/features/routes/providers/route_count_provider.dart';
import 'package:pedalons/features/routes/providers/route_editor_providers.dart';
import 'package:pedalons/features/routes/providers/route_list_provider.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';

/// Les états de la parcothèque (audit des listes, défauts DL1, DL6, DL8) :
///
/// * une équipe **sans parcours** lit « Aucun parcours » — pas « Aucun
///   parcours pour ces filtres » avec un « Tout réinitialiser » sans effet —,
///   et qui gère les parcours y trouve « Ajouter un parcours » ;
/// * Explorer nomme sa portée « Toutes les équipes » : sans rôle, l'API rend
///   aussi le contenu public des équipes publiques ;
/// * les nombres passent par le formateur, et le pied nomme ce qu'il compte.
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
    List<RouteDto> routes = const <RouteDto>[],
    int? total,
    RouteFilters? filters,
    bool canManage = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
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
          builder: (BuildContext _, GoRouterState state) =>
              Text('nouveau ${state.pathParameters['teamSlug']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          unitSystemProvider.overrideWithValue(UnitSystem.metric),
          if (filters != null)
            routeFiltersProvider(teamSlug).overrideWith((ref) => filters),
          routeListProvider.overrideWith(
            (ref, key) => _FixedRouteListNotifier(key, routes, total),
          ),
          routeCountProvider.overrideWith(
            (ref, key) async => total ?? routes.length,
          ),
          routePreviewProvider.overrideWith(
            (ref, key) async => const <RouteDto>[],
          ),
          teamTagsProvider.overrideWith(
            (ref, key) async => const <TagWithUsageDto>[],
          ),
          myTeamsProvider.overrideWith((ref) async => <TeamDetailDto>[]),
          canManageRoutesProvider.overrideWith((ref, slug) => canManage),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  group('DL1 — vide sans filtre', () {
    testWidgets('une équipe sans parcours lit « Aucun parcours », sans '
        '« Tout réinitialiser »', (WidgetTester tester) async {
      await open(tester, teamSlug: 'n-peloton');

      expect(find.byKey(keys.routes.noneState), findsOneWidget);
      expect(find.text('Aucun parcours'), findsOneWidget);
      expect(
        find.text("Aucun parcours n'est disponible pour le moment."),
        findsOneWidget,
      );
      expect(find.byKey(keys.routes.emptyState), findsNothing);
      expect(find.text('Tout réinitialiser'), findsNothing);
      expect(find.byKey(keys.routes.emptyAddButton), findsNothing);
    });

    testWidgets('qui gère les parcours y trouve « Ajouter un parcours »', (
      WidgetTester tester,
    ) async {
      await open(tester, teamSlug: 'n-peloton', canManage: true);

      expect(find.byKey(keys.routes.emptyAddButton), findsOneWidget);
      await tester.tap(find.byKey(keys.routes.emptyAddButton));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('nouveau n-peloton'), findsOneWidget);
    });

    testWidgets('avec un filtre posé, le cul-de-sac reste', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teamSlug: 'n-peloton',
        filters: const RouteFilters(teamSlug: 'n-peloton', search: 'col'),
      );

      expect(find.byKey(keys.routes.emptyState), findsOneWidget);
      // RL10 : le titre commun, les filtres nommés, « Effacer les filtres ».
      expect(find.text('Aucun parcours pour ces filtres'), findsOneWidget);
      expect(find.text('Rien ne correspond à : « col ».'), findsOneWidget);
      expect(find.text('Effacer les filtres'), findsOneWidget);
      expect(find.byKey(keys.routes.noneState), findsNothing);
    });

    testWidgets('RL10 — les filtres sont nommés par leur valeur', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teamSlug: 'n-peloton',
        filters: const RouteFilters(
          teamSlug: 'n-peloton',
          search: 'col',
          minDistance: 50000,
          maxDistance: 100000,
          surfaceType: SurfaceType.gravel,
        ),
      );

      expect(
        find.textContaining(RegExp(r'^Rien ne correspond à : « col » · .*50')),
        findsOneWidget,
      );
      expect(find.textContaining('Gravel'), findsWidgets);
    });
  });

  testWidgets('RL8 — sous un filtre, le total filtré seul', (
    WidgetTester tester,
  ) async {
    final RouteDto route = GalleryData(images: false).route();
    await open(
      tester,
      teamSlug: 'n-peloton',
      routes: <RouteDto>[
        route,
        route.copyWith(id: 'r2', slug: 'r2'),
      ],
      total: 2,
      filters: const RouteFilters(teamSlug: 'n-peloton', search: 'monts'),
    );

    expect(
      tester.widget<Text>(find.byKey(keys.routes.resultCount)).data,
      '2 parcours',
    );
  });

  testWidgets('DL6 — Explorer nomme sa portée « Toutes les équipes »', (
    WidgetTester tester,
  ) async {
    await open(tester, teamSlug: null);

    expect(find.text('Toutes les équipes'), findsOneWidget);
    expect(find.text('Toutes mes équipes'), findsNothing);
  });

  testWidgets('DL8 — compteur formaté, pied nommé', (
    WidgetTester tester,
  ) async {
    final RouteDto route = GalleryData(images: false).route();
    await open(
      tester,
      teamSlug: 'n-peloton',
      routes: <RouteDto>[route],
      total: 2585,
    );

    expect(find.text('2 585 parcours'), findsOneWidget);
    expect(find.text('2585 parcours'), findsNothing);
    final PdlPagedListFooter footer = tester.widget<PdlPagedListFooter>(
      find.byType(PdlPagedListFooter),
    );
    expect(footer.progressLabel, '1 parcours sur 2 585');
  });
}

/// Rend [routes] en page 0 et rien ensuite, sous le [total] annoncé.
class _FixedRouteListNotifier extends RouteListNotifier {
  _FixedRouteListNotifier(RouteFilters filters, this._routes, this._total)
    : super(RouteRepository(RoutesClient(Dio())), filters);

  final List<RouteDto> _routes;
  final int? _total;

  @override
  Future<PageResult<RouteDto>> fetchPage(int page) async =>
      PageResult<RouteDto>(
        items: page == 0 ? _routes : const <RouteDto>[],
        total: _total ?? _routes.length,
      );
}
