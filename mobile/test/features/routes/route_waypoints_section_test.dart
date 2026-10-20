import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_waypoints_section.dart';
import 'package:pedalons/features/routes/presentation/widgets/waypoint_selection.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'route_fixtures.dart';

/// La liste « Points du parcours » (ledger `MOB-84`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<WaypointSelectionController> pump(
    WidgetTester tester,
    List<WaypointDto> waypoints, {
    Brightness brightness = Brightness.light,
    void Function(String key, WaypointDto w)? onSelect,
    WaypointSelectionController? selection,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final WaypointSelectionController controller =
        selection ?? WaypointSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: PedalonsTheme.build(brightness),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RouteWaypointsSection(
                waypoints: waypoints,
                selection: controller,
                onSelect: onSelect ?? (String _, WaypointDto _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('une liste vide ne rend rien', (WidgetTester tester) async {
    await pump(tester, const <WaypointDto>[]);
    expect(find.byKey(keys.routeWaypoints.section), findsNothing);
    expect(find.text('Points du parcours'), findsNothing);
  });

  testWidgets('triée par distance, hors tracé en dernier avec « Hors tracé »', (
    WidgetTester tester,
  ) async {
    await pump(tester, <WaypointDto>[
      fixtureWaypoint(id: 'hors', name: 'Loin', distance: null),
      fixtureWaypoint(id: 'b', name: 'Second', distance: 9000),
      fixtureWaypoint(id: 'a', name: 'Premier', distance: 1000),
    ]);

    final double first = tester.getTopLeft(find.text('Premier')).dy;
    final double second = tester.getTopLeft(find.text('Second')).dy;
    final double off = tester.getTopLeft(find.text('Loin')).dy;
    expect(first, lessThan(second));
    expect(second, lessThan(off));
    expect(find.text('Hors tracé'), findsOneWidget);
    expect(find.text(AppFormatters.formatDistance(1000)), findsOneWidget);
  });

  testWidgets(
    'se replie à 10 lignes, « Voir les 2 autres points » puis « Réduire »',
    (WidgetTester tester) async {
      await pump(tester, <WaypointDto>[
        for (int i = 0; i < 12; i++)
          fixtureWaypoint(id: 'w$i', name: 'Point $i', distance: i * 1000.0),
      ]);

      expect(find.byKey(keys.routeWaypoints.row('w9')), findsOneWidget);
      expect(find.byKey(keys.routeWaypoints.row('w10')), findsNothing);
      expect(find.text('Voir les 2 autres points'), findsOneWidget);

      await tester.ensureVisible(find.text('Voir les 2 autres points'));
      await tester.tap(find.text('Voir les 2 autres points'));
      await tester.pump();
      expect(find.byKey(keys.routeWaypoints.row('w11')), findsOneWidget);
      expect(find.text('Réduire'), findsOneWidget);

      await tester.ensureVisible(find.text('Réduire'));
      await tester.tap(find.text('Réduire'));
      await tester.pump();
      expect(find.byKey(keys.routeWaypoints.row('w11')), findsNothing);
    },
  );

  testWidgets('un type inconnu s\'affiche comme « Information »', (
    WidgetTester tester,
  ) async {
    await pump(tester, <WaypointDto>[
      fixtureWaypoint(type: 'CAMPSITE', name: ''),
    ]);
    expect(find.text('Information'), findsOneWidget);
  });

  testWidgets('toucher une ligne appelle onSelect avec la clé du point', (
    WidgetTester tester,
  ) async {
    final List<String> picked = <String>[];
    await pump(tester, <WaypointDto>[
      fixtureWaypoint(id: null, name: 'Sans id'),
    ], onSelect: (String key, WaypointDto _) => picked.add(key));
    await tester.tap(find.text('Sans id'));
    expect(picked, <String>['i0']);
  });

  testWidgets('la ligne choisie est « selected » dans la sémantique', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final WaypointSelectionController selection = WaypointSelectionController();
    await pump(tester, <WaypointDto>[
      fixtureWaypoint(id: 'a', name: 'Café du Port', distance: 12300),
    ], selection: selection);

    final Finder row = find.byKey(keys.routeWaypoints.row('a'));
    expect(tester.getSemantics(row), isNot(matchesSemantics(isSelected: true)));

    selection.select('a');
    await tester.pump();
    final SemanticsNode node = tester.getSemantics(row);
    expect(
      node.getSemanticsData().flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
    expect(
      node.label,
      'Ravitaillement, Café du Port, '
      'À ${AppFormatters.formatDistance(12300)} du départ',
    );
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('chaque ligne fait au moins 44 px en ${brightness.name}', (
      WidgetTester tester,
    ) async {
      await pump(tester, <WaypointDto>[
        fixtureWaypoint(id: 'a', name: 'Court'),
        fixtureWaypoint(id: 'b', type: 'INFO', name: '', distance: null),
      ], brightness: brightness);
      for (final String id in <String>['a', 'b']) {
        expect(
          tester.getSize(find.byKey(keys.routeWaypoints.row(id))).height,
          greaterThanOrEqualTo(44),
        );
      }
      expect(find.byType(PdlWaypointRow), findsNWidgets(2));
    });
  }
}
