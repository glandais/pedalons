import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/enum_colors.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_elevation_section.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/features/routes/domain/track_surfaces.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import '../routes/route_fixtures.dart';
import 'ride_fixtures.dart';

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
    RouteColorBy? colorBy = RouteColorBy.grade,
    WeatherLegDto? windLeg,
    bool? mapWind,
    ValueChanged<bool>? onMapWindChanged,
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
          home: Scaffold(
            body: SingleChildScrollView(
              child: RideElevationSection(
                teamSlug: 'n-peloton',
                rideSlug: 'sortie',
                routeSlug: 'col-de-la-croix',
                colorBy: colorBy,
                windLeg: windLeg,
                mapWind: mapWind,
                onMapWindChanged: onMapWindChanged,
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

  testWidgets('le profil suit le mode choisi sous la carte, sans bascule à '
      'lui', (WidgetTester tester) async {
    await pump(tester, _track(spans: _spans));

    expect(find.byKey(keys.routeDetail.surfaceSection), findsOneWidget);
    expect(find.byKey(keys.routeDetail.surfaceColorBy), findsNothing);
    // La pente des montées : aucune ici, tout au bleu neutre (ledger
    // `MOB-105`).
    expect(profile(tester).barColors, everyElement(slopeNeutral));
  });

  testWidgets('mode Revêtement : le revêtement sur le profil', (
    WidgetTester tester,
  ) async {
    await pump(tester, _track(spans: _spans), colorBy: RouteColorBy.surface);

    expect(profile(tester).barColors, isNotEmpty);
    expect(profile(tester).barColors, isNot(everyElement(slopeNeutral)));
  });

  testWidgets('mode Météo : le profil reste sur la pente', (
    WidgetTester tester,
  ) async {
    await pump(tester, _track(spans: _spans), colorBy: RouteColorBy.wind);

    expect(profile(tester).barColors, everyElement(slopeNeutral));
  });

  testWidgets('en cours de calcul, une ligne d\'attente et la pente', (
    WidgetTester tester,
  ) async {
    await pump(tester, _track(state: 'PENDING'));

    expect(find.byKey(keys.routeDetail.surfacePending), findsOneWidget);
    expect(find.byKey(keys.routeDetail.surfaceColorBy), findsNothing);
    expect(profile(tester).barColors, everyElement(slopeNeutral));
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

  String tip(WidgetTester tester, double at) => profile(tester)
      .tipLabel!(ElevationReading(distance: at, elevation: 120, grade: null));

  testWidgets('mode Météo : la bande du vent sous le profil, toujours en '
      'pente, et le vent dans l\'info-bulle (ledger `MOB-106`)', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _track(),
      colorBy: RouteColorBy.wind,
      windLeg: fixtureLeg(),
    );

    expect(profile(tester).barColors, everyElement(slopeNeutral));
    expect(profile(tester).bandColors, isNotEmpty);
    expect(profile(tester).bandColors, everyElement(RelativeWind.head.stroke));
    expect(tip(tester, 500), contains('Vent de face'));
  });

  testWidgets('mode Météo, vent inconnu : bleu neutre et « Vent inconnu »', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _track(),
      colorBy: RouteColorBy.wind,
      // Aucun tronçon ne couvre le premier kilomètre.
      windLeg: fixtureLeg().copyWith(
        segments: const <WindSegmentDto>[
          WindSegmentDto(
            fromDistance: 5000,
            toDistance: 30000,
            relativeWind: 'HEAD',
            headwind: 10,
          ),
        ],
      ),
    );

    expect(profile(tester).bandColors, everyElement(slopeNeutral));
    expect(tip(tester, 500), contains('Vent inconnu'));
  });

  testWidgets('interrupteur propre au profil, Météo proposé (MOB-152) : '
      'Pente | Revêtement | Météo, le choix remonte à l\'appelant', (
    WidgetTester tester,
  ) async {
    final List<bool> changes = <bool>[];
    await pump(
      tester,
      _track(spans: _spans),
      colorBy: null,
      mapWind: false,
      onMapWindChanged: changes.add,
    );

    for (final RouteColorBy mode in RouteColorBy.values) {
      expect(find.byKey(keys.routeDetail.colorByMode(mode.name)), findsOne);
    }
    await tester.tap(find.byKey(keys.routeDetail.colorByMode('wind')));
    await tester.pump();
    expect(changes, <bool>[true]);
    // Le revêtement, lui, reste l'affaire du profil.
    await tester.tap(find.byKey(keys.routeDetail.colorByMode('surface')));
    await tester.pump();
    expect(changes, <bool>[true]);
    expect(profile(tester).barColors, isNot(everyElement(slopeNeutral)));
  });

  testWidgets('interrupteur propre au profil en Météo (MOB-152) : le profil '
      'sur la pente, la bande du vent, et la pente choisie quitte Météo', (
    WidgetTester tester,
  ) async {
    final List<bool> changes = <bool>[];
    await pump(
      tester,
      _track(spans: _spans),
      colorBy: null,
      mapWind: true,
      windLeg: fixtureLeg(),
      onMapWindChanged: changes.add,
    );

    expect(profile(tester).barColors, everyElement(slopeNeutral));
    expect(profile(tester).bandColors, isNotNull);
    await tester.tap(find.byKey(keys.routeDetail.colorByMode('grade')));
    await tester.pump();
    expect(changes, <bool>[false]);
  });

  testWidgets('interrupteur propre au profil sans Météo proposé : Pente | '
      'Revêtement seulement', (WidgetTester tester) async {
    await pump(tester, _track(spans: _spans), colorBy: null);

    expect(find.byKey(keys.routeDetail.colorByMode('wind')), findsNothing);
    expect(find.byKey(keys.routeDetail.colorByMode('surface')), findsOne);
  });

  testWidgets('hors mode Météo, ni bande ni vent, même avec un leg', (
    WidgetTester tester,
  ) async {
    await pump(tester, _track(), windLeg: fixtureLeg());

    expect(profile(tester).bandColors, isNull);
    expect(tip(tester, 500), isNot(contains('Vent')));
  });
}
