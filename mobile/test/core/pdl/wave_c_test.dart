import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/dev/pdl_shell_demo_page.dart';

/// Les coquilles de la vague C ne se vérifient pas en les regardant : ce
/// qu'elles promettent — un ordre de superposition, une barre qui reste, un
/// contenu qui ne déborde pas — ne se voit qu'en défilant, en ouvrant une
/// feuille, et en agrandissant la typographie.
void main() {
  const Size kPhone = Size(402 * 3, 874 * 3);

  Future<void> pumpDemo(
    WidgetTester tester, {
    double textScale = 1.0,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = kPhone;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(brightness),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const PdlShellDemoPage(),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'la coquille empile app bar, barre d\'outils, liste, barre d\'action et onglets',
    (WidgetTester tester) async {
      await pumpDemo(tester);

      expect(find.byType(PdlAppBar), findsOneWidget);
      expect(find.byType(PdlPinnedToolbar), findsOneWidget);
      expect(find.byType(PdlActionBar), findsOneWidget);
      expect(find.byType(PdlBottomTabs), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la barre d\'outils reste visible au défilement', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester);

    final Finder toolbar = find.byType(PdlChipRow);
    final double before = tester.getTopLeft(toolbar).dy;
    expect(before, greaterThan(0));

    // 40 cartes : de quoi faire disparaître n'importe quel en-tête non épinglé.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pump();

    expect(
      toolbar,
      findsOneWidget,
      reason: 'la barre d\'outils a quitté l\'arbre au défilement',
    );
    final double after = tester.getTopLeft(toolbar).dy;
    expect(
      (after - before).abs(),
      lessThan(2),
      reason:
          'la barre d\'outils a glissé de ${(after - before).abs()} px : elle '
          'n\'est pas épinglée',
    );
  });

  testWidgets(
    'une feuille ouverte depuis la page recouvre la barre d\'onglets',
    (WidgetTester tester) async {
      await pumpDemo(tester);

      final Rect tabsBefore = tester.getRect(find.byType(PdlBottomTabs));

      await tester.tap(find.text('Trier'));
      await tester.pumpAndSettle();

      expect(find.byType(PdlSheet), findsOneWidget);
      final Rect sheet = tester.getRect(find.byType(PdlSheet));

      // Recouvrement géométrique : la feuille descend jusqu'au bas de l'écran,
      // donc sur les 52 px + inset de la barre d'onglets.
      expect(
        sheet.bottom,
        greaterThanOrEqualTo(tabsBefore.bottom - 0.5),
        reason:
            'la feuille s\'arrête à ${sheet.bottom} alors que les onglets vont '
            'jusqu\'à ${tabsBefore.bottom} : elle est rendue sous la barre',
      );

      // Et elle est bien peinte après : la barre d'onglets n'est plus dans
      // l'arbre visible au-dessus d'elle, la feuille étant une route du
      // navigateur racine posée par-dessus toute la coquille.
      final Element sheetElement = tester.element(find.byType(PdlSheet));
      expect(
        sheetElement.findAncestorWidgetOfExactType<PdlScreenScaffold>(),
        isNull,
        reason:
            'la feuille est un descendant de la coquille : elle passera '
            'sous la barre d\'onglets',
      );
    },
  );

  testWidgets('rien ne déborde à 130 % d\'agrandissement typographique', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);

    // Les libellés d'onglet — 10/500 agrandis à 13 — sont le premier candidat
    // au rognage.
    expect(find.text('Calendrier'), findsOneWidget);
    final Size tabs = tester.getSize(find.byType(PdlBottomTabs));
    expect(tabs.height, greaterThanOrEqualTo(PdlMetrics.tabItem));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Trier'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('la coquille tient aussi en mode sombre', (
    WidgetTester tester,
  ) async {
    await pumpDemo(tester, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  group('PdlStageRail.truncate', () {
    test('ne coupe pas un cluster de graphèmes', () {
      // Un e + accent combinant : `substring(0, 5)` couperait entre les deux
      // et rendrait un caractère de remplacement.
      const String combining = 'Créteil-en-Brie';
      expect(PdlStageRail.truncate(combining, 5), 'Créte…');

      // Un emoji occupe deux unités UTF-16 : `substring` le couperait en deux.
      expect(PdlStageRail.truncate('Col 🚴 raide', 5), 'Col 🚴…');
    });

    test('rend la chaîne telle quelle si elle tient', () {
      expect(PdlStageRail.truncate('J1', 18), 'J1');
    });
  });

  testWidgets('PdlPrevNextNav disparaît sans voisins', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: const Scaffold(body: PdlPrevNextNav()),
      ),
    );
    expect(tester.getSize(find.byType(PdlPrevNextNav)), Size.zero);
  });

  testWidgets('PdlAppBar mesure 56 px et ses actions 44', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: PdlAppBar(
            title: 'Le Peloton',
            onBack: () {},
            actions: <Widget>[
              PdlAppBarAction(icon: Icons.abc, onPressed: () {}),
            ],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(PdlAppBar)).height, PdlMetrics.appBar);
    for (final Element action
        in find.byType(PdlAppBarAction).evaluate().toList()) {
      final Size size = action.size!;
      expect(size.height, greaterThanOrEqualTo(PdlMetrics.tapTarget));
      expect(size.width, greaterThanOrEqualTo(PdlMetrics.tapTarget));
    }
  });

  testWidgets('le titre de PdlAppBar se pose sous la barre système', (
    WidgetTester tester,
  ) async {
    const double kTopInset = 59;

    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(padding: const EdgeInsets.only(top: kTopInset)),
          child: child!,
        ),
        home: Scaffold(
          appBar: PdlAppBar(title: 'Profil'),
          body: const SizedBox.expand(),
        ),
      ),
    );

    // Le fond couvre l'encoche — 56 + l'inset —, mais le titre commence
    // franchement en dessous : c'était le défaut, le titre chevauchait l'heure.
    expect(
      tester.getSize(find.byType(PdlAppBar)).height,
      PdlMetrics.appBar + kTopInset,
    );
    expect(
      tester.getTopLeft(find.text('Profil')).dy,
      greaterThanOrEqualTo(kTopInset),
    );
  });
}
