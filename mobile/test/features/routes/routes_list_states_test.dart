import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/dev/card_gallery/gallery_data.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/domain/route_filters.dart';
import 'package:pedalons/features/routes/presentation/pages/routes_page.dart';
import 'package:pedalons/features/routes/presentation/widgets/compact_route_row.dart';
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
    await open(
      tester,
      teamSlug: null,
      routes: <RouteDto>[GalleryData(images: false).route()],
    );

    expect(find.text('Toutes les équipes'), findsOneWidget);
    expect(find.text('Toutes mes équipes'), findsNothing);
  });

  group('RL2 — la portée d\'Explorer', () {
    testWidgets('une puce « Portée » en tête des puces, dont la feuille a '
        'quatre valeurs et aucune équipe', (WidgetTester tester) async {
      await open(
        tester,
        teamSlug: null,
        routes: <RouteDto>[GalleryData(images: false).route()],
        filters: const RouteFilters(
          minRole: MinRole.member,
          defaultMinRole: MinRole.member,
        ),
      );

      expect(find.byKey(keys.routes.scopeChip), findsOneWidget);
      expect(find.byType(PdlScopeSelector), findsOneWidget);
      // La puce précède le tri.
      expect(
        tester.getTopLeft(find.byKey(keys.routes.scopeChip)).dx,
        lessThan(tester.getTopLeft(find.byKey(keys.routes.sortChip)).dx),
      );

      await tester.tap(find.byKey(keys.routes.scopeChip));
      await tester.pumpAndSettle();
      expect(find.text('Organisateur'), findsOneWidget);
      expect(find.text('Administrateur'), findsOneWidget);
      expect(find.text('Rôle minimum'), findsNothing);
      expect(find.text('Tous les rôles'), findsNothing);
    });

    testWidgets('la section d\'une équipe n\'en a pas', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teamSlug: 'n-peloton',
        routes: <RouteDto>[GalleryData(images: false).route()],
      );
      expect(find.byKey(keys.routes.scopeChip), findsNothing);
    });
  });

  group('RL4 — la pastille compte ce que « Effacer les filtres » lève', () {
    int badge(WidgetTester tester) => tester
        .widget<PdlFilterButton>(find.byKey(keys.routes.filterButton))
        .activeCount;

    testWidgets('au repos, aucune pastille : l\'équipe de la page n\'est '
        'pas un filtre', (WidgetTester tester) async {
      await open(
        tester,
        teamSlug: 'n-peloton',
        routes: <RouteDto>[GalleryData(images: false).route()],
      );
      expect(badge(tester), 0);
    });

    testWidgets('la recherche, chaque critère et la portée écartée de son '
        'défaut comptent ; le tri non', (WidgetTester tester) async {
      await open(
        tester,
        teamSlug: null,
        routes: <RouteDto>[GalleryData(images: false).route()],
        filters: const RouteFilters(
          defaultMinRole: MinRole.member,
          search: 'col',
          surfaceType: SurfaceType.gravel,
          sortBy: RouteSortBy.distance,
        ),
      );
      expect(badge(tester), 3);
    });

    testWidgets('le vide filtré nomme la portée et « Effacer les filtres » '
        'la remet à son défaut, en gardant le tri', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teamSlug: null,
        filters: const RouteFilters(
          defaultMinRole: MinRole.member,
          sortBy: RouteSortBy.distance,
          sortDir: SortDirection.asc,
        ),
      );

      expect(find.byKey(keys.routes.emptyState), findsOneWidget);
      expect(
        find.text('Rien ne correspond à : Toutes les équipes.'),
        findsOneWidget,
      );
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(RoutesPage)),
      );
      await tester.tap(find.text('Effacer les filtres'));
      await tester.pump();
      final RouteFilters after = container.read(routeFiltersProvider(null));
      expect(after.minRole, MinRole.member);
      expect(after.sortBy, RouteSortBy.distance);
      expect(after.sortDir, SortDirection.asc);
    });
  });

  group('RL9 — un seul contrôle de vue', () {
    testWidgets('« Vignettes · Lignes · Carte » sur la ligne du compteur', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teamSlug: 'n-peloton',
        routes: <RouteDto>[GalleryData(images: false).route()],
      );

      expect(find.byKey(keys.routes.listViewSegment), findsOneWidget);
      expect(find.byKey(keys.routes.rowsViewSegment), findsOneWidget);
      expect(find.byKey(keys.routes.mapViewSegment), findsOneWidget);
      expect(find.text('Compact'), findsNothing);
      expect(find.text('Liste'), findsNothing);
      // Sur la même ligne que le compteur.
      expect(
        tester.getCenter(find.byKey(keys.routes.rowsViewSegment)).dy,
        closeTo(tester.getCenter(find.byKey(keys.routes.resultCount)).dy, 12),
      );

      await tester.tap(find.byKey(keys.routes.rowsViewSegment));
      await tester.pump();
      expect(find.byType(CompactRouteRow), findsOneWidget);
    });

    testWidgets('la vue choisie dans une équipe ne change pas celle '
        'd\'Explorer', (WidgetTester tester) async {
      await open(
        tester,
        teamSlug: 'n-peloton',
        routes: <RouteDto>[GalleryData(images: false).route()],
      );
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(RoutesPage)),
      );

      await tester.tap(find.byKey(keys.routes.rowsViewSegment));
      await tester.pump();

      expect(
        container.read(routeDensityProvider(RouteListKind.team)),
        RouteListDensity.compact,
      );
      expect(
        container.read(routeDensityProvider(RouteListKind.explore)),
        isNull,
      );
      expect(prefs.getString('routes.density'), isNull);
      expect(prefs.getString('routes.team.density'), 'compact');
    });
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
