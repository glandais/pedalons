import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/routes/domain/route_retouch.dart';
import 'package:pedalons/features/routes/presentation/pages/route_generator_page.dart';
import 'package:pedalons/features/routes/presentation/pages/route_retouch_page.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';
import 'route_fixtures.dart';

/// La retouche d'un parcours (docs/LEDGER_*.md MOB-185) : la demande, les
/// propositions, les refus, et ce que l'écran rend à la fiche.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  const RouteRetouchOfferDto offer = RouteRetouchOfferDto(
    available: true,
    operations: <RouteRetouchOperation>[
      RouteRetouchOperation.resize,
      RouteRetouchOperation.moveEnd,
    ],
    originalDistanceM: 82000,
    minDistanceKm: 62,
    maxDistanceKm: 103,
    minChangeKm: 2,
    maxChangeShare: 0.25,
    rideType: 'GRAVEL',
  );

  late SharedPreferences prefs;
  late _FakeRetouch client;
  RetouchChoice? choice;
  bool closed = false;

  setUp(() async {
    setCurrentLocale('fr');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    client = _FakeRetouch();
    choice = null;
    closed = false;
  });

  Future<void> pumps(WidgetTester tester, [int n = 10]) async {
    for (int i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester, {bool canEdit = true}) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final RouteDetailDto route = fixtureRouteDetail(
      permissions: permissionsFor(member: true, role: 'ORGANIZER'),
      tracks: const <TrackDto>[fixtureTrack],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          teamDetailProvider.overrideWith(
            (Ref ref, String _) async =>
                fixtureRouteTeam(role: 'ORGANIZER', enableRoutePlanner: true),
          ),
          mapStyleProvider.overrideWith(
            (Ref ref, Brightness _) =>
                const AsyncValue<ResolvedMapStyle?>.data(null),
          ),
          generatorPlacesProvider.overrideWith(
            (Ref ref, String _) async => const <PlaceDetailDto>[
              PlaceDetailDto(
                id: 'p1',
                name: 'Café du port',
                startPlace: false,
                endPlace: true,
                geometry: GeoJsonPoint(
                  type: GeoJsonPointTypeType.point,
                  coordinates: <double>[5.02, 45.02],
                ),
              ),
            ],
          ),
          routeGeneratorClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                choice = await openRouteRetouch(
                  context,
                  route: route,
                  offer: offer,
                  canEdit: canEdit,
                );
                closed = true;
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await pumps(tester);
  }

  testWidgets('ajuster la distance : la cible, l’appel, puis « Modifier »', (
    WidgetTester tester,
  ) async {
    await open(tester);
    // Rien à proposer tant qu'aucune distance n'est visée.
    await tester.tap(find.byKey(keys.routeRetouch.submitButton));
    await pumps(tester);
    expect(client.requests, isEmpty);

    await tester.tap(find.byKey(keys.routeRetouch.step(10)));
    await tester.pump();
    await tester.tap(find.byKey(keys.routeRetouch.submitButton));
    await pumps(tester);

    final RouteRetouchRequest request = client.requests.single;
    expect(request.targetDistanceKm, 92);
    expect(request.end, isNull);
    expect(find.byKey(keys.routeRetouch.card(0)), findsOneWidget);
    expect(find.text('88 % du parcours gardé'), findsOneWidget);

    await tester.tap(find.byKey(keys.routeRetouch.moreButton));
    await pumps(tester);
    expect(client.requests.last.seed, 1);

    await tester.tap(find.byKey(keys.routeRetouch.editButton));
    await pumps(tester);
    expect(closed, isTrue);
    expect(choice?.opening, RetouchOpening.edit);
    expect(choice?.handoff?.polyline, 'abc');
    expect(choice?.handoff?.type, RouteGeneratorType.gravel);
    // « Modifier » garde le nom du parcours.
    expect(choice?.handoff?.name, fixtureRouteDetail().name);
  });

  testWidgets('la zone morte : dite, et « Proposer » reste fermé', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(keys.routeRetouch.plusButton));
    await tester.pump();
    expect(find.textContaining('Visez au moins'), findsOneWidget);
    await tester.tap(find.byKey(keys.routeRetouch.submitButton));
    await pumps(tester);
    expect(client.requests, isEmpty);
  });

  testWidgets('déplacer l’arrivée vers un lieu, puis « Nouveau parcours »', (
    WidgetTester tester,
  ) async {
    await open(tester, canEdit: false);
    await tester.tap(find.text('Déplacer l\'arrivée'));
    // Les lieux de l'équipe ne sont lus qu'à l'ouverture de ce mode.
    await pumps(tester);
    await tester.tap(find.byKey(keys.routeRetouch.place('p1')));
    await tester.pump();
    await tester.tap(find.byKey(keys.routeRetouch.submitButton));
    await pumps(tester);
    expect(client.requests.single.end?.placeId, 'p1');
    // Pas de « Modifier » pour qui ne peut pas modifier ce parcours.
    expect(find.byKey(keys.routeRetouch.editButton), findsNothing);

    await tester.tap(find.byKey(keys.routeRetouch.openButton));
    await pumps(tester);
    expect(choice?.opening, RetouchOpening.newRoute);
    expect(choice?.handoff?.name, '${fixtureRouteDetail().name} (retouché)');
  });

  testWidgets('raccourcir refusé : la réponse en bleu et ses suites', (
    WidgetTester tester,
  ) async {
    client.refusal = 'ROUTE_RETOUCH_NO_SHORTER';
    await open(tester);
    await tester.tap(find.byKey(keys.routeRetouch.step(-10)));
    await tester.pump();
    await tester.tap(find.byKey(keys.routeRetouch.submitButton));
    await pumps(tester);

    expect(find.byKey(keys.routeRetouch.error), findsOneWidget);
    expect(find.textContaining('ne se raccourcit pas'), findsOneWidget);
    expect(find.byKey(keys.routeRetouch.retryButton), findsNothing);
    expect(find.byKey(keys.routeRetouch.moreAfterError), findsOneWidget);

    await tester.tap(find.byKey(keys.routeRetouch.generatorButton));
    await pumps(tester);
    expect(choice?.opening, RetouchOpening.generator);
    // Le générateur part de la distance demandée et du type de l'offre,
    // comme au site (docs/LEDGER_*.md MOB-186).
    expect(choice?.handoff, isNull);
    expect(choice?.generator?.distanceKm, 72);
    expect(choice?.generator?.type, RouteGeneratorType.gravel);
    expect(choice?.generator?.start, isNotNull);
  });
}

class _FakeRetouch implements RouteGeneratorClient {
  final List<RouteRetouchRequest> requests = <RouteRetouchRequest>[];
  String? refusal;

  @override
  Future<RouteRetouchResponse> retouchRoute({
    required String routeSlug,
    required String teamSlug,
    required RouteRetouchRequest body,
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
    return const RouteRetouchResponse(
      operation: 'RESIZE',
      originalDistanceM: 82000,
      originalAscentM: 950,
      candidates: <RetouchedRouteDto>[
        RetouchedRouteDto(
          polyline: 'abc',
          distanceM: 92300,
          kind: 'LENGTHEN',
          keptShare: 0.88,
          unmatchedM: 0,
          ascentM: 1120,
          changed: RetouchedSpanDto(
            fromM: 10000,
            toM: 19600,
            newM: 22900,
            startIndex: 0,
            endIndex: 1,
            teamShare: 0.5,
            unpavedShare: 0.1,
            crossings: 0,
          ),
          bounds: BoundsDto(minLon: 5, minLat: 45, maxLon: 5.1, maxLat: 45.1),
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
