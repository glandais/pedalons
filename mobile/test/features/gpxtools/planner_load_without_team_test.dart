import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/routes/data/planner_bridge.dart';
import 'package:pedalons/features/routes/data/planner_load.dart';

/// docs/LEDGER_*.md MOB-178 : un aperçu des outils GPX n'est d'aucune équipe —
/// `load` ne porte ni `teamSlug` (le serveur applique le quota personnel) ni
/// position d'équipe (la carte s'ouvre sur `defaultCenter`).
void main() {
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

  Future<PlannerLoad> build({PlannerTrack? route}) => buildPlannerLoad(
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
  );

  test('création : ni équipe ni position, tout le tracé partira', () async {
    final Map<String, dynamic> input = (await build()).input;
    expect(input.containsKey('teamSlug'), isFalse);
    expect(input.containsKey('teamLocation'), isFalse);
    expect(input['create'], isTrue);
    expect(input['defaultCenter'], isNotNull);
  });

  test('modification : le tracé de l’aperçu s’ouvre', () async {
    final Map<String, dynamic> input = (await build(
      route: (
        line: <List<double>>[
          <double>[5, 45, 100, 0],
          <double>[5.01, 45.01, 110, 1400],
        ],
        ascend: 10,
        waypoints: const <WaypointDto>[],
        distance: 1400,
      ),
    )).input;
    expect(input.containsKey('teamSlug'), isFalse);
    expect(input['create'], isFalse);
    expect(input['track'], hasLength(2));
    expect(input['waypointsTotal'], 1400);
  });
}
