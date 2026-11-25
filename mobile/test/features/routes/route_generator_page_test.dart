import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/routes/domain/route_generator.dart';
import 'package:pedalons/features/routes/presentation/pages/route_generator_page.dart';
import 'package:pedalons/features/routes/providers/route_editor_providers.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'route_fixtures.dart';

/// Le générateur de parcours (docs/LEDGER_*.md MOB-154) : réglages, appel,
/// propositions, refus, et la proposition remise à l'éditeur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;
  late _FakeGenerator generator;
  GeneratedHandoff? handedOff;

  setUp(() async {
    setCurrentLocale('fr');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    generator = _FakeGenerator();
    handedOff = null;
  });

  Future<void> pumps(WidgetTester tester, [int n = 10]) async {
    for (int i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    bool canManage = true,
    bool planner = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final TeamDetailDto team =
        fixtureRouteTeam(
          role: 'ORGANIZER',
          enableRoutePlanner: planner,
        ).copyWith(
          geometry: const TeamDetailDtoGeometry(
            type: TeamDetailDtoGeometryTypeType.point,
            coordinates: <double>[2.35, 48.85],
          ),
        );
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) =>
              RouteGeneratorPage(teamSlug: team.slug),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/parcours/nouveau',
          builder: (BuildContext _, GoRouterState state) {
            handedOff = state.extra as GeneratedHandoff?;
            return const Text('éditeur');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          teamDetailProvider.overrideWith((Ref ref, String slug) async => team),
          canManageRoutesProvider.overrideWith(
            (Ref ref, String _) => canManage,
          ),
          mapStyleProvider.overrideWith(
            (Ref ref, Brightness _) =>
                const AsyncValue<ResolvedMapStyle?>.data(null),
          ),
          generatorDominantTypeProvider.overrideWith(
            (Ref ref, String _) async => RouteGeneratorType.gravel,
          ),
          generatorPlacesProvider.overrideWith(
            (Ref ref, String _) async => const <PlaceDetailDto>[],
          ),
          routeGeneratorClientProvider.overrideWithValue(generator),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await pumps(tester);
  }

  testWidgets('sans le droit : un refus, aucun réglage', (
    WidgetTester tester,
  ) async {
    await open(tester, canManage: false);
    expect(find.byKey(keys.routeGenerator.generateButton), findsNothing);
    expect(generator.requests, isEmpty);
  });

  testWidgets('planificateur fermé à l’équipe : le refus le dit', (
    WidgetTester tester,
  ) async {
    await open(tester, planner: false);
    expect(find.byKey(keys.routeGenerator.generateButton), findsNothing);
    expect(
      find.text(
        'La génération de parcours n\'est pas activée pour cette équipe.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('générer : la requête, les propositions, puis l’éditeur', (
    WidgetTester tester,
  ) async {
    await open(tester);
    // Le type par défaut est celui des parcours les plus nombreux.
    expect(find.byKey(keys.routeGenerator.unpavedSegments), findsOneWidget);

    await tester.tap(find.byKey(keys.routeGenerator.bearing('NE')));
    await tester.pump();
    await tester.tap(find.byKey(keys.routeGenerator.generateButton));
    await pumps(tester);

    final RouteGeneratorRequest request = generator.requests.single;
    expect(request.type, 'GRAVEL');
    expect(request.bearing, 'NE');
    expect(request.distanceKm, kGeneratorDefaultKm);
    // Le départ est celui de l'équipe : le serveur le prend d'office.
    expect(request.start, isNull);

    expect(find.byKey(keys.routeGenerator.card(0)), findsOneWidget);
    expect(find.text('2 propositions'), findsOneWidget);
    expect(find.text('72 % sur les routes de l\'équipe'), findsOneWidget);

    await tester.tap(find.byKey(keys.routeGenerator.moreButton));
    await pumps(tester);
    expect(generator.requests.last.seed, 1);

    await tester.tap(find.byKey(keys.routeGenerator.useButton));
    await pumps(tester);
    expect(find.text('éditeur'), findsOneWidget);
    expect(handedOff?.polyline, 'abc');
    expect(handedOff?.type, RouteGeneratorType.gravel);
    // Le nombre et son unité sont séparés par une espace insécable.
    expect(
      handedOff?.name.replaceAll(RegExp(r'\s'), ' '),
      'Parcours généré de 81 km',
    );
  });

  testWidgets('un refus du moteur : son message et des réglages proposés', (
    WidgetTester tester,
  ) async {
    generator.refusal = 'GENERATOR_NETWORK_TOO_SMALL';
    await open(tester);
    await tester.tap(find.byKey(keys.routeGenerator.generateButton));
    await pumps(tester);

    expect(find.byKey(keys.routeGenerator.error), findsOneWidget);
    expect(find.textContaining('ne suffisent pas pour'), findsOneWidget);
    // Une seconde requête identique rencontrerait le même refus.
    expect(find.byKey(keys.routeGenerator.retryButton), findsNothing);
    expect(find.text('Plus de découverte'), findsOneWidget);

    generator.refusal = null;
    await tester.tap(find.text('Plus de découverte'));
    await pumps(tester);
    expect(generator.requests.last.discovery, 0.5);
    expect(find.byKey(keys.routeGenerator.card(0)), findsOneWidget);
  });
}

class _FakeGenerator implements RouteGeneratorClient {
  final List<RouteGeneratorRequest> requests = <RouteGeneratorRequest>[];
  String? refusal;

  @override
  Future<RouteGeneratorResponse> generateRoutes({
    required String teamSlug,
    required RouteGeneratorRequest body,
  }) async {
    requests.add(body);
    final String? code = refusal;
    if (code != null) {
      final RequestOptions options = RequestOptions(path: '/x');
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 400,
          data: <String, dynamic>{'code': code},
        ),
      );
    }
    GeneratedRouteDto candidate(String polyline, double m, double share) =>
        GeneratedRouteDto(
          polyline: polyline,
          distanceM: m,
          teamShare: share,
          unpavedShare: 0.04,
          sharedM: 0,
          crossings: 0,
          bounds: const BoundsDto(
            minLon: 2.3,
            minLat: 48.8,
            maxLon: 2.4,
            maxLat: 48.9,
          ),
          ascentM: 920,
        );
    return RouteGeneratorResponse(
      candidates: <GeneratedRouteDto>[
        candidate('abc', 81400, 0.72),
        candidate('def', 78900, 0.6),
      ],
      partialCoverage: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
