import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/models/unit_system.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/core/widgets/detail_section.dart';
import 'package:pedalons/core/widgets/detail_stat_tiles.dart';
import 'package:pedalons/core/widgets/publication_stats_line.dart';

/// Les briques partagées des écrans de détail refondus (ledger `MOB-132`,
/// lot 3) : tuiles de chiffres, rythme des sections, ligne de chiffres d'une
/// carte.
void main() {
  setUpAll(() {
    final Map<String, dynamic> fr = json.decode(
      File('assets/l10n/fr.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    Localization.load(
      const Locale('fr'),
      translations: Translations(fr),
      fallbackTranslations: Translations(fr),
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(brightness),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 390, child: child),
          ),
        ),
      ),
    );
  }

  group('DetailStatTiles', () {
    const List<DetailStatTile> four = <DetailStatTile>[
      DetailStatTile(label: 'Distance', value: '92,4 km'),
      DetailStatTile(label: 'Dénivelé positif', value: '1 240 m'),
      DetailStatTile(label: 'Durée estimée', value: '3 h 18'),
      DetailStatTile(label: 'Vitesse moyenne', value: '28 km/h'),
    ];

    testWidgets('quatre tuiles : deux lignes, dans l’ordre de l’appelant', (
      WidgetTester tester,
    ) async {
      await pump(tester, const DetailStatTiles(tiles: four));
      final Rect distance = tester.getRect(find.text('Distance'));
      final Rect elevation = tester.getRect(find.text('Dénivelé positif'));
      final Rect duration = tester.getRect(find.text('Durée estimée'));
      final Rect speed = tester.getRect(find.text('Vitesse moyenne'));
      expect(elevation.top, distance.top);
      expect(elevation.left, greaterThan(distance.left));
      expect(duration.top, greaterThan(distance.top));
      expect(duration.left, distance.left);
      expect(speed.top, duration.top);
      // Libellé au-dessus de sa valeur.
      expect(
        tester.getRect(find.text('92,4 km')).top,
        greaterThan(distance.top),
      );
      expect(find.byType(PdlCard), findsOne);
    });

    testWidgets('deux tuiles : une seule ligne', (WidgetTester tester) async {
      await pump(tester, DetailStatTiles(tiles: four.take(2).toList()));
      expect(
        tester.getRect(find.text('Dénivelé positif')).top,
        tester.getRect(find.text('Distance')).top,
      );
    });

    testWidgets('l’intitulé en tête, pleine largeur, en primaryOnSoft', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const DetailStatTiles(heading: 'Votre groupe : B', tiles: four),
      );
      final Rect heading = tester.getRect(find.text('Votre groupe : B'));
      expect(
        heading.bottom,
        lessThanOrEqualTo(tester.getRect(find.text('Distance')).top),
      );
      final BuildContext context = tester.element(find.text('Distance'));
      expect(
        tester.widget<Text>(find.text('Votre groupe : B')).style?.color,
        context.pdl.primaryOnSoft,
      );
    });

    testWidgets('chaque tuile se lit d’un tenant : libellé puis valeur', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester, const DetailStatTiles(tiles: four));
      expect(find.bySemanticsLabel('Distance\n92,4 km'), findsOne);
      handle.dispose();
    });

    testWidgets('se construit en sombre', (WidgetTester tester) async {
      await pump(
        tester,
        const DetailStatTiles(heading: 'Votre groupe : B', tiles: four),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('DetailSection', () {
    testWidgets('24 px au-dessus d’une section, 20 au-dessus d’un sous-titre', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(key: Key('top'), height: 10),
            DetailSection(title: 'Météo', child: SizedBox(height: 10)),
            DetailSection(
              title: 'Météo au départ de 09:00',
              level: DetailSectionLevel.subsection,
            ),
          ],
        ),
      );
      final double top = tester.getRect(find.byKey(const Key('top'))).bottom;
      final List<Rect> sections = tester
          .widgetList<DetailSection>(find.byType(DetailSection))
          .map((DetailSection s) => tester.getRect(find.byWidget(s)))
          .toList();
      final double firstHeader = tester
          .getRect(find.widgetWithText(PdlSectionHeader, 'Météo'))
          .top;
      expect(firstHeader - top, PdlSpacing.detailSectionGap);
      final double secondHeader = tester
          .getRect(
            find.widgetWithText(PdlSectionHeader, 'Météo au départ de 09:00'),
          )
          .top;
      expect(secondHeader - sections[1].top, PdlSpacing.detailSubsectionGap);
    });

    testWidgets('compte à droite, marge latérale, et bleed pleine largeur', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DetailSection(
              title: 'Groupes',
              count: '3 groupes',
              child: SizedBox(key: Key('inset'), height: 10),
            ),
            DetailSection(
              title: 'Parcours',
              bleed: true,
              child: SizedBox(key: Key('bleed'), height: 10),
            ),
          ],
        ),
      );
      expect(
        tester.getRect(find.byKey(const Key('inset'))).left,
        PdlSpacing.section,
      );
      expect(tester.getRect(find.byKey(const Key('bleed'))).left, 0);
      expect(tester.getRect(find.byKey(const Key('bleed'))).width, 390);
      expect(
        tester.getRect(find.text('3 groupes')).right,
        390 - PdlSpacing.section,
      );
    });

    testWidgets('le titre se lit comme un en-tête', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester, const DetailSection(title: 'Commentaires'));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Commentaires')),
        isSemantics(isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('DetailSection.sliver se pose dans un CustomScrollView', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: CustomScrollView(
              slivers: <Widget>[
                DetailSection.sliver(title: 'Étapes', count: '3 étapes'),
                SliverList.list(children: const <Widget>[Text('Étape 1')]),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Étapes'), findsOne);
      expect(find.text('3 étapes'), findsOne);
      expect(find.text('Étape 1'), findsOne);
    });
  });

  group('PublicationStatsLine', () {
    testWidgets('distance · D+ · vitesse, chacune avec son icône', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const PublicationStatsLine(
          distanceMeters: 78000,
          elevationGainMeters: 980,
          speedKmh: 25,
        ),
      );
      final List<String> texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((Text t) => t.data!)
          .toList();
      // Les formateurs de l'app, pas une seconde mise en forme.
      expect(texts, <String>[
        AppFormatters.formatDistance(78000),
        AppFormatters.formatElevationGain(980),
        AppFormatters.formatSpeed(25),
      ]);
      expect(texts[1], endsWith('D+'));
      final List<IconData?> icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((Icon i) => i.icon)
          .toList();
      expect(icons, <IconData>[
        PdlIcons.distance,
        PdlIcons.elevationUp,
        PdlIcons.speed,
      ]);
      final Icon first = tester.widget<Icon>(find.byType(Icon).first);
      expect(first.size, 14);
      final BuildContext context = tester.element(find.byType(Icon).first);
      expect(first.color, context.pdl.textDimmed);
    });

    testWidgets('une valeur absente disparaît, aucune : rien', (
      WidgetTester tester,
    ) async {
      await pump(tester, const PublicationStatsLine(speedKmh: 28));
      expect(find.byType(Text), findsOne);
      expect(find.byType(Icon), findsOne);

      await pump(tester, const PublicationStatsLine());
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('unités impériales', (WidgetTester tester) async {
      await pump(
        tester,
        const PublicationStatsLine(
          distanceMeters: 16093.44,
          units: UnitSystem.imperial,
        ),
      );
      expect(find.textContaining('mi'), findsOne);
    });

    testWidgets('passe à la ligne entre deux valeurs, sans déborder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 140,
                child: PublicationStatsLine(
                  distanceMeters: 78000,
                  elevationGainMeters: 980,
                  speedKmh: 25,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.textContaining('km/h')).top,
        greaterThan(tester.getRect(find.textContaining('78')).top),
      );
    });
  });
}
