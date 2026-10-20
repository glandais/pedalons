import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/routes/presentation/widgets/embedded_route_sheet.dart';
import 'package:pedalons/features/routes/providers/route_detail_provider.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'route_fixtures.dart';

/// Le revêtement sur la fiche embarquée d'une étape (ledger `MOB-82`) : la même
/// bascule que l'écran 13, qui colore le profil.
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

const RouteKey _key = RouteKey(
  teamSlug: 'n-peloton',
  routeSlug: 'col-de-la-croix',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> pump(WidgetTester tester, TrackDto track) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final RouteDetailDto route = fixtureRouteDetail().copyWith(
      distance: 1000,
      tracks: <TrackDto>[track],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routeDetailProvider(_key).overrideWith((Ref ref) async => route),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: EmbeddedRouteSheet(
                routeKey: _key,
                showOpenFullAction: false,
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
}
