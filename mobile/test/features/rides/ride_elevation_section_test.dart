import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_elevation_section.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import '../routes/route_fixtures.dart';

/// Le revêtement sur le profil du groupe sélectionné (ledger `MOB-81`) : la
/// même bascule Pente / Revêtement que la fiche parcours.
TrackDto _track({String? state = 'READY', List<SurfaceSpanDto>? spans}) =>
    TrackDto(
      line: GeoJsonLineString(
        type: GeoJsonLineStringTypeType.lineString,
        coordinates: <List<double>>[
          for (int i = 0; i <= 10; i++)
            <double>[5, 45 + i * 100 / 111195, 100.0 + i * 5, i * 100],
        ],
      ),
      climbs: const <ClimbDto>[],
      surfaceState: state,
      surfaces: spans,
    );

const List<SurfaceSpanDto> _spans = <SurfaceSpanDto>[
  SurfaceSpanDto(from: 0, to: 400, surface: TrackSurface.paved),
  SurfaceSpanDto(from: 400, to: 1000, surface: TrackSurface.gravel),
];

const RouteRef _ref = RouteRef(
  teamSlug: 'n-peloton',
  rideSlug: 'sortie',
  routeSlug: 'col-de-la-croix',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> pump(
    WidgetTester tester,
    TrackDto track, {
    List<WaypointDto> waypoints = const <WaypointDto>[],
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final RouteDetailDto route = fixtureRouteDetail().copyWith(
      distance: 1000,
      tracks: <TrackDto>[track],
      waypoints: waypoints,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          rideRouteGeometryProvider(
            _ref,
          ).overrideWith((Ref ref) => AsyncValue<RouteDetailDto>.data(route)),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RideElevationSection(
                teamSlug: 'n-peloton',
                rideSlug: 'sortie',
                routeSlug: 'col-de-la-croix',
              ),
            ),
          ),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  PdlElevationProfile profile(WidgetTester tester) =>
      tester.widget<PdlElevationProfile>(find.byType(PdlElevationProfile));

  testWidgets('avec un revêtement, la bascule colore le profil', (
    WidgetTester tester,
  ) async {
    await pump(tester, _track(spans: _spans));

    expect(find.byKey(keys.routeDetail.surfaceSection), findsOneWidget);
    expect(profile(tester).barColors, isNull);

    await tester.ensureVisible(find.text('Revêtement'));
    await tester.tap(find.text('Revêtement'));
    await tester.pump();

    expect(profile(tester).barColors, isNotNull);
    expect(profile(tester).barColors, isNotEmpty);
  });

  testWidgets('en cours de calcul, une ligne d\'attente et la pente', (
    WidgetTester tester,
  ) async {
    await pump(tester, _track(state: 'PENDING'));

    expect(find.byKey(keys.routeDetail.surfacePending), findsOneWidget);
    expect(find.byKey(keys.routeDetail.surfaceColorBy), findsNothing);
    expect(profile(tester).barColors, isNull);
  });

  testWidgets('sans revêtement, rien', (WidgetTester tester) async {
    await pump(tester, _track(state: null));

    expect(find.byKey(keys.routeDetail.surfaceSection), findsNothing);
    expect(find.byKey(keys.routeDetail.surfacePending), findsNothing);
    expect(find.byType(PdlElevationProfile), findsOneWidget);
  });

  testWidgets('les points de parcours : la section et les repères du profil', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _track(),
      waypoints: <WaypointDto>[
        fixtureWaypoint(id: 'a', distance: 200),
        fixtureWaypoint(id: 'b', distance: 800),
        fixtureWaypoint(id: 'hors', distance: null),
      ],
    );

    expect(find.byKey(keys.routeWaypoints.section), findsOneWidget);
    expect(find.byType(PdlWaypointRow), findsNWidgets(3));
    // Les points hors tracé ne figurent jamais sur le profil.
    expect(profile(tester).markers, hasLength(2));
  });

  testWidgets('sans point de parcours, ni section ni repère', (
    WidgetTester tester,
  ) async {
    await pump(tester, _track());

    expect(find.byKey(keys.routeWaypoints.section), findsNothing);
    expect(profile(tester).markers, isEmpty);
  });
}
