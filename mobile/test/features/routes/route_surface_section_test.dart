import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/keys.dart';
import 'package:pedalons/features/routes/domain/track_surfaces.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_color_mode_switch.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_surface_section.dart';

import '../../support/localization.dart';

/// Le revêtement sur la fiche parcours (ledger `MOB-81`).
TrackDto _track({String? state = 'READY', List<SurfaceSpanDto>? spans}) =>
    TrackDto(
      line: GeoJsonLineString(
        type: GeoJsonLineStringTypeType.lineString,
        coordinates: <List<double>>[
          for (int i = 0; i <= 10; i++)
            <double>[5, 45 + i * 100 / 111195, 100, i * 100],
        ],
      ),
      climbs: const <ClimbDto>[],
      surfaceState: state,
      surfaces: spans,
    );

final List<SurfaceSpanDto> _spans = <SurfaceSpanDto>[
  const SurfaceSpanDto(from: 0, to: 400, surface: TrackSurface.paved),
  const SurfaceSpanDto(from: 400, to: 996, surface: TrackSurface.gravel),
  const SurfaceSpanDto(from: 996, to: 1000, surface: TrackSurface.dirt),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> pump(
    WidgetTester tester,
    List<TrackDto> tracks, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(brightness),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RouteSurfaceSection(tracks: tracks),
          ),
        ),
      ),
    );
  }

  for (final Brightness brightness in Brightness.values) {
    testWidgets('prêt : barre, légende et attribution ($brightness)', (
      WidgetTester tester,
    ) async {
      await pump(tester, <TrackDto>[
        _track(spans: _spans),
      ], brightness: brightness);

      expect(find.byKey(keys.routeDetail.surfaceSection), findsOneWidget);
      // La bascule est sous la carte (ledger `MOB-105`), plus ici.
      expect(find.byKey(keys.routeDetail.surfaceColorBy), findsNothing);
      expect(find.byKey(keys.routeDetail.surfaceBar), findsOneWidget);
      expect(find.text('Pente'), findsNothing);
      expect(find.text('Asphalte 40 %'), findsOneWidget);
      expect(find.text('Compacté, gravier 60 %'), findsOneWidget);
      expect(find.text('Terre < 1 %'), findsOneWidget);
      expect(find.text('© contributeurs OpenStreetMap'), findsOneWidget);
      expect(find.byKey(keys.routeDetail.surfacePending), findsNothing);
    });
  }

  group('RouteColorModeSwitch', () {
    Future<void> pumpSwitch(
      WidgetTester tester,
      List<RouteColorBy> modes, {
      RouteColorBy value = RouteColorBy.grade,
      ValueChanged<RouteColorBy>? onChanged,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: RouteColorModeSwitch(
            modes: modes,
            value: value,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    );

    testWidgets('les seuls modes proposés, dans l\'ordre', (
      WidgetTester tester,
    ) async {
      await pumpSwitch(tester, <RouteColorBy>[
        RouteColorBy.grade,
        RouteColorBy.surface,
        RouteColorBy.wind,
      ]);
      expect(find.text('Pente'), findsOneWidget);
      expect(find.text('Revêtement'), findsOneWidget);
      expect(find.text('Météo'), findsOneWidget);

      await pumpSwitch(tester, <RouteColorBy>[
        RouteColorBy.grade,
        RouteColorBy.wind,
      ]);
      expect(find.text('Revêtement'), findsNothing);
      expect(find.byKey(keys.routeDetail.colorByMode('wind')), findsOneWidget);
    });

    testWidgets('la pente seule : rien à choisir, rien de rendu', (
      WidgetTester tester,
    ) async {
      await pumpSwitch(tester, <RouteColorBy>[RouteColorBy.grade]);
      expect(find.text('Pente'), findsNothing);
    });

    testWidgets('toucher « Météo » appelle onChanged', (
      WidgetTester tester,
    ) async {
      RouteColorBy? chosen;
      await pumpSwitch(tester, <RouteColorBy>[
        RouteColorBy.grade,
        RouteColorBy.wind,
      ], onChanged: (RouteColorBy v) => chosen = v);
      await tester.tap(find.text('Météo'));
      expect(chosen, RouteColorBy.wind);
    });

    testWidgets('chaque segment garde la cible de 44 px', (
      WidgetTester tester,
    ) async {
      await pumpSwitch(tester, <RouteColorBy>[
        RouteColorBy.grade,
        RouteColorBy.surface,
        RouteColorBy.wind,
      ]);
      for (final String mode in <String>['grade', 'surface', 'wind']) {
        expect(
          tester.getSize(find.byKey(keys.routeDetail.colorByMode(mode))).height,
          greaterThanOrEqualTo(44),
        );
      }
    });
  });

  testWidgets('en cours : la seule ligne d\'attente', (
    WidgetTester tester,
  ) async {
    await pump(tester, <TrackDto>[_track(state: 'PENDING')]);

    expect(find.text('Revêtement en cours de calcul'), findsOneWidget);
    expect(find.byKey(keys.routeDetail.surfacePending), findsOneWidget);
    expect(find.byKey(keys.routeDetail.surfaceSection), findsNothing);
    expect(find.byKey(keys.routeDetail.surfaceColorBy), findsNothing);
  });

  testWidgets('sans revêtement : rien', (WidgetTester tester) async {
    await pump(tester, <TrackDto>[_track(state: null)]);

    expect(find.byType(Text), findsNothing);
    expect(find.byKey(keys.routeDetail.surfaceSection), findsNothing);
  });

  testWidgets('indisponible, ou prêt sans plage : rien', (
    WidgetTester tester,
  ) async {
    for (final TrackDto t in <TrackDto>[
      _track(state: 'UNAVAILABLE'),
      _track(spans: const <SurfaceSpanDto>[]),
      _track(state: 'SOMETHING_NEW'),
    ]) {
      await pump(tester, <TrackDto>[t]);

      expect(find.byType(Text), findsNothing);
      expect(find.byKey(keys.routeDetail.surfacePending), findsNothing);
    }
  });

  testWidgets('l\'attribution s\'annonce comme un lien', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, <TrackDto>[_track(spans: _spans)]);

    expect(
      tester.getSemantics(find.byKey(keys.routeDetail.surfaceAttribution)),
      matchesSemantics(
        label: '© contributeurs OpenStreetMap',
        isLink: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('la cible de l\'attribution fait au moins 44 px', (
    WidgetTester tester,
  ) async {
    await pump(tester, <TrackDto>[_track(spans: _spans)]);

    final Size size = tester.getSize(
      find.byKey(keys.routeDetail.surfaceAttribution),
    );
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
