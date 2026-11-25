import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/routes/data/planner_load.dart';
import 'package:pedalons/features/routes/domain/route_generator.dart';

/// Le générateur de parcours dans l'app (docs/LEDGER_*.md MOB-154) : les règles
/// du site (`frontend/src/lib/routeGenerator.ts`), et la proposition passée au
/// planificateur embarqué.
void main() {
  const GeneratorPoint start = GeneratorPoint(
    lng: 2.35,
    lat: 48.85,
    kind: GeneratorPointKind.picked,
  );
  // À environ 11 km au nord du départ.
  const GeneratorPoint end = GeneratorPoint(
    lng: 2.35,
    lat: 48.95,
    kind: GeneratorPointKind.picked,
  );

  group('buildGeneratorRequest', () {
    test('une boucle depuis l’équipe : ni départ, ni arrivée, ni chemins', () {
      const GeneratorSettings settings = GeneratorSettings(
        bearing: CompassPoint.ne,
        unpaved: RouteGeneratorUnpaved.high,
      );
      final RouteGeneratorRequest request = buildGeneratorRequest(
        settings,
        RouteGeneratorType.road,
      );
      expect(request.start, isNull);
      expect(request.end, isNull);
      expect(request.bearing, 'NE');
      expect(request.type, 'ROAD');
      expect(request.distanceKm, kGeneratorDefaultKm);
      expect(request.discovery, kGeneratorDefaultDiscovery);
      // Les chemins ne veulent rien dire sur la route.
      expect(request.unpaved, isNull);
    });

    test('hors route, la part de chemins part, sauf l’habituelle', () {
      expect(
        buildGeneratorRequest(
          const GeneratorSettings(unpaved: RouteGeneratorUnpaved.low),
          RouteGeneratorType.gravel,
        ).unpaved,
        'LOW',
      );
      expect(
        buildGeneratorRequest(
          const GeneratorSettings(),
          RouteGeneratorType.mtb,
        ).unpaved,
        isNull,
      );
    });

    test('une arrivée loin fait taire la direction', () {
      final RouteGeneratorRequest request = buildGeneratorRequest(
        const GeneratorSettings(
          start: start,
          end: end,
          loop: false,
          distanceKm: 20,
          bearing: CompassPoint.s,
        ),
        RouteGeneratorType.road,
      );
      expect(request.end, isNotNull);
      expect(request.bearing, isNull);
    });

    test(
      'une arrivée choisie ne part pas tant que « Au départ » est coché',
      () {
        final RouteGeneratorRequest request = buildGeneratorRequest(
          const GeneratorSettings(start: start, end: end),
          RouteGeneratorType.road,
        );
        expect(request.end, isNull);
      },
    );
  });

  test('isEndFar : la moitié de la distance voulue', () {
    expect(isEndFar(start, end, 20), isTrue);
    expect(isEndFar(start, end, 50), isFalse);
    expect(isEndFar(null, end, 20), isFalse);
  });

  test('dominantGeneratorType : le plus nombreux, ROAD à égalité', () {
    expect(dominantGeneratorType(), RouteGeneratorType.road);
    expect(
      dominantGeneratorType(road: 3, gravel: 5, mtb: 1),
      RouteGeneratorType.gravel,
    );
    expect(
      dominantGeneratorType(road: 2, gravel: 2, mtb: 2),
      RouteGeneratorType.road,
    );
    expect(dominantGeneratorType(mtb: 1), RouteGeneratorType.mtb);
  });

  test('surfaceTypeOfGenerated', () {
    expect(surfaceTypeOfGenerated(RouteGeneratorType.road), SurfaceType.road);
    expect(
      surfaceTypeOfGenerated(RouteGeneratorType.gravel),
      SurfaceType.gravel,
    );
    expect(surfaceTypeOfGenerated(RouteGeneratorType.mtb), SurfaceType.mtb);
  });

  group('erreurs', () {
    DioException refusal(String code, {int status = 400}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: <String, dynamic>{'code': code},
      ),
    );

    test('« Réessayer » : panne, serveur occupé, inconnu — pas un refus', () {
      expect(
        isRetryableGeneratorError(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            type: DioExceptionType.connectionError,
          ),
        ),
        isTrue,
      );
      expect(
        isRetryableGeneratorError(refusal('ROUTE_GENERATOR_BUSY', status: 503)),
        isTrue,
      );
      expect(isRetryableGeneratorError(refusal('GENERATOR_NO_ROUTE')), isFalse);
      expect(
        isRetryableGeneratorError(refusal('ROUTE_GENERATOR_RATE_LIMITED')),
        isFalse,
      );
    });

    test('les refus qui invitent à changer les réglages', () {
      expect(
        isSettingsGeneratorError(refusal('GENERATOR_NETWORK_TOO_SMALL')),
        isTrue,
      );
      expect(
        isSettingsGeneratorError(refusal('GENERATOR_UNAVAILABLE')),
        isFalse,
      );
    });

    test('generatorErrorCode', () {
      expect(
        generatorErrorCode(refusal('GENERATOR_NO_ROUTE')),
        'GENERATOR_NO_ROUTE',
      );
      expect(generatorErrorCode(StateError('x')), isNull);
    });
  });

  group('buildPlannerLoad', () {
    const ConfigDto config = ConfigDto(
      webAuthnRpId: 'localhost',
      appName: 'Pédalons',
      singleTeam: false,
      enableGpxPlanner: true,
      mapStyles: <MapStyleDto>[],
      tileServerBaseUrl: 'https://tiles.test',
      defaultCenter: MapCenterDto(lat: 46.6, lon: 2.5, zoom: 5),
      gpsAutoSyncEnabled: false,
    );
    const GeneratedHandoff handoff = GeneratedHandoff(
      polyline: '_p~iF~ps|U_ulLnnqC',
      type: RouteGeneratorType.gravel,
      distanceM: 82000,
      name: 'Parcours généré de 82 km',
    );

    Future<Map<String, dynamic>> input({PlannerTrack? route}) async =>
        (await buildPlannerLoad(
          team: null,
          route: route,
          routeName: 'Boucle',
          config: config,
          dio: Dio(),
          apiBaseUrl: 'https://api.test',
          readState: () async => null,
          dark: false,
          locale: 'fr',
          units: UnitSystem.metric,
          generated: handoff,
        )).input;

    test('une création porte la proposition à importer', () async {
      final Map<String, dynamic> load = await input();
      expect(load['create'], isTrue);
      expect(load['generated'], <String, dynamic>{
        'polyline': handoff.polyline,
        'name': handoff.name,
      });
    });

    test('jamais sur un parcours existant', () async {
      final Map<String, dynamic> load = await input(
        route: (
          line: <List<double>>[
            <double>[5, 45, 100, 0],
            <double>[5.01, 45.01, 110, 1400],
          ],
          ascend: 10,
          waypoints: const <WaypointDto>[],
          distance: 1400,
        ),
      );
      expect(load.containsKey('generated'), isFalse);
    });
  });
}
