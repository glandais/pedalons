import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/map/pdl_map_buttons.dart';
import 'package:pedalons/core/pdl/map/pdl_waypoint_mark.dart';
import 'package:pedalons/core/pdl/pdl_waypoint_row.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// Le contrat de `core/pdl` (README, point 2) : aucune action ne descend sous
/// 44 px. Les commandes de carte sont celles qu'on presse en roulant, d'une
/// main — elles sont donc les moins négociables de toutes.
void main() {
  Future<void> pump(WidgetTester tester, Brightness brightness, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(brightness),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  for (final Brightness brightness in Brightness.values) {
    testWidgets('PdlMapButton fait 44 × 44 en ${brightness.name}', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        brightness,
        PdlMapButton(
          icon: PdlIcons.fullscreen,
          semanticLabel: 'Plein écran',
          onPressed: () {},
        ),
      );
      final Size size = tester.getSize(find.byType(PdlMapButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('PdlWaypointRow fait au moins 44 px en ${brightness.name}', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        brightness,
        PdlWaypointRow(
          mark: const PdlWaypointMark(
            glyph: IconData(0xe318, fontFamily: 'MaterialIcons'),
            disc: Color(0xFFFD7E14),
            onDisc: Color(0xFFFFFFFF),
          ),
          distanceLabel: '1,0 km',
          title: 'Ravitaillement',
          onTap: () {},
        ),
      );
      expect(
        tester.getSize(find.byType(PdlWaypointRow)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets(
      'PdlMapPill actionnable tient 44 px de haut en ${brightness.name}',
      (WidgetTester tester) async {
        await pump(
          tester,
          brightness,
          PdlMapPill(
            label: 'Rechercher dans cette zone',
            icon: PdlIcons.refresh,
            onPressed: () {},
          ),
        );
        expect(tester.getSize(find.byType(PdlMapPill)).height, 44);
      },
    );
  }

  testWidgets('une pilule non actionnable reste compacte', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      Brightness.light,
      const PdlMapPill(label: '12 parcours'),
    );
    // Pas d'action, pas de cible : la pilule ne réserve pas 44 px pour rien.
    expect(tester.getSize(find.byType(PdlMapPill)).height, lessThan(44));
  });

  testWidgets('PdlMapButtonColumn empile ses boutons sans les rétrécir', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      Brightness.light,
      PdlMapButtonColumn(
        children: <Widget>[
          PdlMapButton(
            icon: PdlIcons.fullscreen,
            semanticLabel: 'Plein écran',
            onPressed: () {},
          ),
          PdlMapButton(
            icon: PdlIcons.layers,
            semanticLabel: 'Fond de carte',
            onPressed: () {},
          ),
        ],
      ),
    );
    for (final Element e in find.byType(PdlMapButton).evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)).height, 44);
    }
  });

  testWidgets('PdlMapFloatingCard rend son contenu', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      Brightness.dark,
      const PdlMapFloatingCard(child: Text('Boucle des Puys')),
    );
    expect(find.text('Boucle des Puys'), findsOneWidget);
  });
}
