import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pdl_typography.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// Les composants Pdl des écrans de détail refondus (ledger `MOB-132`,
/// lot 3) : le bloc repliable, la ligne de lieu cliquable, les emplacements
/// du bloc de départ et le compte à droite du titre de section.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(brightness),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }

  const PdlDayBox dayBox = PdlDayBox(weekday: 'sam.', day: '14', month: 'nov.');

  group('PdlDisclosure', () {
    testWidgets('replié par défaut : le contenu n’est pas construit', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const PdlDisclosure(
          title: 'Points du parcours',
          subtitles: <String>['2 points'],
          child: Text('Fontaine de Huelgoat'),
        ),
      );
      expect(find.text('Points du parcours'), findsOneWidget);
      expect(find.text('2 points'), findsOneWidget);
      expect(find.text('Fontaine de Huelgoat'), findsNothing);
    });

    testWidgets('un tap sur toute la ligne déplie, un second replie', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await pump(
        tester,
        PdlDisclosure(
          title: 'Cols et montées',
          onChanged: changes.add,
          child: const Text('Roc’h Trévezel'),
        ),
      );
      // Tout à droite, près du chevron : la ligne entière est tactile.
      final Rect header = tester.getRect(find.byType(InkWell));
      await tester.tapAt(Offset(header.right - 4, header.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Roc’h Trévezel'), findsOneWidget);

      await tester.tapAt(Offset(header.left + 4, header.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('Roc’h Trévezel'), findsNothing);
      expect(changes, <bool>[true, false]);
    });

    testWidgets('initiallyExpanded montre le contenu d’emblée', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const PdlDisclosure(
          title: 'Météo le long du parcours',
          initiallyExpanded: true,
          child: Text('09:00 · Départ'),
        ),
      );
      expect(find.text('09:00 · Départ'), findsOneWidget);
    });

    testWidgets('l’en-tête mesure au moins 56 px', (WidgetTester tester) async {
      await pump(
        tester,
        const PdlDisclosure(title: 'Points', child: SizedBox()),
      );
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(PdlDisclosure.headerMinHeight),
      );
    });

    testWidgets('le lecteur d’écran lit un bouton et son état déplié', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(
        tester,
        const PdlDisclosure(
          title: 'Points du parcours',
          subtitles: <String>['2 points'],
          child: Text('Fontaine'),
        ),
      );
      final Finder node = find.bySemanticsLabel(RegExp('Points du parcours'));
      expect(
        tester.getSemantics(node),
        isSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          label: 'Points du parcours\n2 points',
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(node),
        isSemantics(hasExpandedState: true, isExpanded: true),
      );
      handle.dispose();
    });

    testWidgets('se construit en sombre sans lever', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const PdlDisclosure(
          title: 'Points',
          initiallyExpanded: true,
          child: Text('x'),
        ),
        brightness: Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PdlPlaceRow.link', () {
    testWidgets('cliquable : un lien nommé, 44 px, souligné', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int taps = 0;
      await pump(
        tester,
        PdlPlaceRow.link(
          kind: PdlPlaceKind.start,
          name: 'Place de la Mairie',
          semanticLabel: 'Itinéraire vers Place de la Mairie',
          onTap: () => taps++,
        ),
      );
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(PdlMetrics.tapTarget),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Itinéraire vers Place de la Mairie'),
        ),
        isSemantics(isLink: true),
      );
      final Text label = tester.widget<Text>(find.text('Place de la Mairie'));
      expect(label.style?.decoration, TextDecoration.underline);

      await tester.tap(find.byType(PdlPlaceRow));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('drapeau vert au départ, rouge à l’arrivée', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const Column(
          children: <Widget>[
            PdlPlaceRow.link(kind: PdlPlaceKind.start, name: 'A'),
            PdlPlaceRow.link(kind: PdlPlaceKind.end, name: 'B'),
          ],
        ),
      );
      final BuildContext context = tester.element(find.text('A'));
      final List<Icon> flags = tester
          .widgetList<Icon>(find.byType(Icon))
          .toList();
      expect(flags[0].color, context.pdl.mapStart);
      expect(flags[1].color, context.pdl.mapEnd);
    });

    testWidgets('sans onTap : texte simple, ni lien ni soulignement', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const PdlPlaceRow.link(kind: PdlPlaceKind.end, name: 'Café du Lac'),
      );
      expect(find.byType(InkWell), findsNothing);
      final Text label = tester.widget<Text>(find.text('Café du Lac'));
      expect(label.style?.decoration, isNot(TextDecoration.underline));
    });
  });

  group('PdlDepartureBlock — emplacements', () {
    testWidgets('sans emplacement : lu d’un tenant, comme avant', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(
        tester,
        const PdlDepartureBlock(
          dayBox: dayBox,
          headline: 'Départ 09:00',
          semanticLabel: 'Départ 09:00, sam. 14 nov.',
        ),
      );
      expect(find.bySemanticsLabel('Départ 09:00, sam. 14 nov.'), findsOne);
      expect(find.bySemanticsLabel('14'), findsNothing);
      handle.dispose();
    });

    testWidgets('trailing, lieux et note restent atteignables', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int joins = 0;
      int directions = 0;
      await pump(
        tester,
        PdlDepartureBlock(
          dayBox: dayBox,
          headline: 'Départ 09:00',
          details: const <String>['Arrivée estimée 12:18'],
          semanticLabel: 'Départ 09:00, sam. 14 nov., Arrivée estimée 12:18',
          trailing: PdlButton(
            label: 'Rejoindre',
            size: PdlButtonSize.sm,
            onPressed: () => joins++,
          ),
          places: <Widget>[
            PdlPlaceRow.link(
              kind: PdlPlaceKind.start,
              name: 'Place de la Mairie',
              semanticLabel: 'Itinéraire vers Place de la Mairie',
              onTap: () => directions++,
            ),
          ],
          footnote: 'Sortie sans groupe, inscription impossible',
        ),
      );
      expect(
        find.bySemanticsLabel(
          'Départ 09:00, sam. 14 nov., Arrivée estimée 12:18',
        ),
        findsOne,
      );
      expect(find.bySemanticsLabel('Rejoindre'), findsOne);
      expect(
        find.bySemanticsLabel('Itinéraire vers Place de la Mairie'),
        findsOne,
      );
      expect(
        find.bySemanticsLabel('Sortie sans groupe, inscription impossible'),
        findsOne,
      );

      // Le bouton est à droite de l'en-tête, les lieux et la note dessous.
      final Rect headline = tester.getRect(find.text('Départ 09:00'));
      final Rect button = tester.getRect(find.byType(PdlButton));
      final Rect place = tester.getRect(find.byType(PdlPlaceRow));
      final Rect note = tester.getRect(
        find.text('Sortie sans groupe, inscription impossible'),
      );
      expect(button.left, greaterThan(headline.right));
      expect(place.top, greaterThan(headline.bottom));
      expect(note.top, greaterThanOrEqualTo(place.bottom));

      await tester.tap(find.byType(PdlButton));
      await tester.tap(find.byType(PdlPlaceRow));
      expect(joins, 1);
      expect(directions, 1);
      handle.dispose();
    });

    testWidgets('note seule, sans lieu ni bouton', (WidgetTester tester) async {
      await pump(
        tester,
        const PdlDepartureBlock(
          dayBox: dayBox,
          headline: 'Départ 09:00',
          footnote: 'Sortie sans groupe, inscription impossible',
        ),
        brightness: Brightness.dark,
      );
      expect(find.text('Sortie sans groupe, inscription impossible'), findsOne);
      expect(tester.takeException(), isNull);
    });
  });

  group('PdlSectionHeader', () {
    testWidgets('countAtEnd pose le compte à droite, en xs', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const PdlSectionHeader(
          title: 'Groupes',
          count: '3 groupes',
          countAtEnd: true,
        ),
      );
      final Rect title = tester.getRect(find.text('Groupes'));
      final Rect count = tester.getRect(find.text('3 groupes'));
      final Rect header = tester.getRect(find.byType(PdlSectionHeader));
      expect(count.right, closeTo(header.right, 0.5));
      expect(count.left - title.right, greaterThan(100));
      final BuildContext context = tester.element(find.text('3 groupes'));
      expect(
        tester.widget<Text>(find.text('3 groupes')).style,
        context.pdlText.xs,
      );
    });

    testWidgets('par défaut le compte reste collé au titre', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const PdlSectionHeader(title: 'Participants', count: '40'),
      );
      final Rect title = tester.getRect(find.text('Participants'));
      final Rect count = tester.getRect(find.text('40'));
      expect(count.left - title.right, lessThan(12));
    });
  });
}
