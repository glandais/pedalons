import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/domain/route_filters.dart';
import 'package:pedalons/features/routes/presentation/pages/routes_page.dart';
import 'package:pedalons/features/routes/providers/route_editor_providers.dart';
import 'package:pedalons/features/routes/providers/route_list_provider.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';

/// Le bouton « Ajouter » de la section Parcours (ledger `MOB-79`) : pour un
/// organisateur de l'équipe, à droite de la recherche — ni pour un simple
/// membre, ni sur l'onglet Parcours de toutes les équipes.
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
          builder: (BuildContext _, GoRouterState state) =>
              Text('nouveau ${state.pathParameters['teamSlug']}'),
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
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('un organisateur voit « Ajouter » et ouvre la création', (
    WidgetTester tester,
  ) async {
    await open(tester, teamSlug: 'n-peloton', canManage: true);

    expect(find.byKey(keys.routes.addButton), findsOneWidget);
    expect(find.text('Ajouter'), findsOneWidget);

    await tester.tap(find.byKey(keys.routes.addButton));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('nouveau n-peloton'), findsOneWidget);
  });

  testWidgets('un simple membre ne voit rien', (WidgetTester tester) async {
    await open(tester, teamSlug: 'n-peloton', canManage: false);

    expect(find.byKey(keys.routes.addButton), findsNothing);
  });

  testWidgets('l\'onglet Parcours de toutes les équipes non plus', (
    WidgetTester tester,
  ) async {
    await open(tester, teamSlug: null, canManage: true);

    expect(find.byKey(keys.routes.addButton), findsNothing);
  });
}

/// Ne répond jamais : la page reste sur son squelette, aucun appel HTTP.
class _StuckRouteListNotifier extends RouteListNotifier {
  _StuckRouteListNotifier(RouteFilters filters)
    : super(RouteRepository(RoutesClient(Dio())), filters);

  @override
  Future<PageResult<RouteDto>> fetchPage(int page) =>
      Completer<PageResult<RouteDto>>().future;
}
