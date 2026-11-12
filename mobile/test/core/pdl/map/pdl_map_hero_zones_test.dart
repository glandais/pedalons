import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// Les zones de `PdlMapHero` (ledger `MOB-129`) : la place qu'occupe le bas
/// de la carte, mesurée et publiée par `PdlMapBottomInset` ; le crédit posé
/// au-dessus ; la colonne en bas à droite, au-dessus du crédit ; « Fermer »
/// en haut à gauche en plein écran ; une vignette sans Calques.
///
/// MapLibre ne tourne pas dans un test : `mapBuilder` rend une sonde qui lit
/// l'inset, et le crédit posé à la main, comme le fait `PdlMap`. La barre
/// d'échelle, elle, ne se rend pas sans `MapController` : elle partage
/// l'enveloppe du crédit (`PdlMapBottomInset.safeArea`), que ces tests
/// couvrent par lui.
void main() {
  const PdlMapHeroLabels labels = PdlMapHeroLabels(
    enterFullscreen: 'Plein écran',
    exitFullscreen: 'Quitter le plein écran',
    chooseBackground: 'Choisir le fond',
    backgroundSheetTitle: 'Fond de carte',
  );
  const List<PdlMapStyleOption> styles = <PdlMapStyleOption>[
    PdlMapStyleOption(id: 'plan', label: 'Plan'),
    PdlMapStyleOption(id: 'satellite', label: 'Satellite'),
  ];
  const double heroWidth = 400;
  const double heroHeight = 320;
  // 12 : la marge du hero ; 8 + 28 + 8 : la ligne du bas, le crédit replié,
  // l'écart.
  const double edge = 12;
  const double creditSlot =
      PdlMapBottomInset.rowPadding +
      PdlMapBottomInset.creditExtent +
      PdlSpacing.chipGap;

  Widget probeMap(BuildContext context) => Stack(
    children: <Widget>[
      Text('inset:${PdlMapBottomInset.of(context)}'),
      const PdlMapAttribution(
        credit: PdlMapCredit(
          toggleLabel: 'Crédits de la carte',
          extra: 'IGN — Geoportail',
        ),
      ),
    ],
  );

  Widget host(Widget hero, {double safeBottom = 0}) => MaterialApp(
    theme: PedalonsTheme.build(Brightness.light),
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(padding: EdgeInsets.only(bottom: safeBottom)),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: heroWidth, height: heroHeight, child: hero),
          ),
        ),
      ),
    ),
  );

  PdlMapHero hero({
    Widget? bottomLayer,
    Widget? floatingCard,
    double bottomInset = 0,
    bool isFullscreen = false,
    bool vignette = false,
    Widget? pill,
    WidgetBuilder? fullscreenBuilder,
  }) => PdlMapHero(
    labels: labels,
    styles: styles,
    onStyleSelected: (String _) {},
    isFullscreen: isFullscreen,
    vignette: vignette,
    fullscreenBuilder:
        fullscreenBuilder ??
        (isFullscreen ? null : (BuildContext context) => const Text('page')),
    bottomLayer: bottomLayer,
    floatingCard: floatingCard,
    bottomInset: bottomInset,
    pill: pill,
    mapBuilder: probeMap,
  );

  /// Le pavé du crédit ⓘ, tel que rendu.
  Rect creditRect(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byType(PdlMapAttribution),
      matching: find.byType(PdlBlurSurface),
    ),
  );

  Rect heroRect(WidgetTester tester) => tester.getRect(find.byType(PdlMapHero));

  /// La mesure est remontée après l'image : une seconde pour la publier.
  Future<void> pumpHero(
    WidgetTester tester,
    Widget hero, {
    double safeBottom = 0,
  }) async {
    await tester.pumpWidget(host(hero, safeBottom: safeBottom));
    await tester.pump();
  }

  group('l\'inset', () {
    testWidgets('sans occupant : 0, le crédit au bord', (
      WidgetTester tester,
    ) async {
      await pumpHero(tester, hero());
      expect(find.text('inset:0.0'), findsOneWidget);
      // La hauteur que la colonne enjambe est bien celle du crédit rendu.
      expect(creditRect(tester).height, PdlMapBottomInset.creditExtent);
      expect(
        creditRect(tester).bottom,
        heroRect(tester).bottom - PdlMapBottomInset.rowPadding,
      );
    });

    testWidgets('vaut la hauteur mesurée du calque du bas, marge comprise, '
        'et le crédit se pose au-dessus', (WidgetTester tester) async {
      await pumpHero(tester, hero(bottomLayer: const SizedBox(height: 60)));
      expect(find.text('inset:${60 + edge}'), findsOneWidget);
      expect(
        creditRect(tester).bottom,
        heroRect(tester).bottom - (60 + edge) - PdlMapBottomInset.rowPadding,
      );
    });

    testWidgets('vaut la hauteur mesurée de la carte flottante', (
      WidgetTester tester,
    ) async {
      await pumpHero(tester, hero(floatingCard: const SizedBox(height: 80)));
      expect(find.text('inset:${80 + edge}'), findsOneWidget);
    });

    testWidgets('suit l\'occupant : le plus haut des deux, puis 0 au retrait', (
      WidgetTester tester,
    ) async {
      await pumpHero(
        tester,
        hero(
          bottomLayer: const SizedBox(height: 60),
          floatingCard: const SizedBox(height: 100),
        ),
      );
      expect(find.text('inset:${100 + edge}'), findsOneWidget);

      await pumpHero(tester, hero(bottomLayer: const SizedBox(height: 40)));
      expect(find.text('inset:${40 + edge}'), findsOneWidget);

      await pumpHero(tester, hero());
      expect(find.text('inset:0.0'), findsOneWidget);
    });

    testWidgets('l\'occupant externe se combine par le plus grand', (
      WidgetTester tester,
    ) async {
      await pumpHero(tester, hero(bottomInset: 150));
      expect(find.text('inset:150.0'), findsOneWidget);

      await pumpHero(
        tester,
        hero(bottomInset: 150, bottomLayer: const SizedBox(height: 60)),
      );
      expect(find.text('inset:150.0'), findsOneWidget);

      await pumpHero(
        tester,
        hero(bottomInset: 30, bottomLayer: const SizedBox(height: 60)),
      );
      expect(find.text('inset:${60 + edge}'), findsOneWidget);
    });

    testWidgets('zone sûre : le crédit prend le plus grand d\'elle et de '
        'l\'inset, jamais leur somme', (WidgetTester tester) async {
      await pumpHero(tester, hero(), safeBottom: 34);
      expect(
        creditRect(tester).bottom,
        heroRect(tester).bottom - 34 - PdlMapBottomInset.rowPadding,
      );

      // Encastrée, le calque n'enjambe pas la zone sûre : 72 > 34.
      await pumpHero(
        tester,
        hero(bottomLayer: const SizedBox(height: 60)),
        safeBottom: 34,
      );
      expect(find.text('inset:${60 + edge}'), findsOneWidget);
      expect(
        creditRect(tester).bottom,
        heroRect(tester).bottom - (60 + edge) - PdlMapBottomInset.rowPadding,
      );
    });

    testWidgets('plein écran : le calque se pose au-dessus de la zone sûre, '
        'et la mesure la compte', (WidgetTester tester) async {
      await pumpHero(
        tester,
        hero(isFullscreen: true, bottomLayer: const SizedBox(height: 60)),
        safeBottom: 34,
      );
      expect(find.text('inset:${60 + 34 + edge}'), findsOneWidget);
      expect(
        creditRect(tester).bottom,
        heroRect(tester).bottom -
            (60 + 34 + edge) -
            PdlMapBottomInset.rowPadding,
      );
    });

    testWidgets('hors d\'un hero, le crédit reste au bord', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: heroWidth,
                height: heroHeight,
                child: Builder(builder: probeMap),
              ),
            ),
          ),
        ),
      );
      expect(find.text('inset:0.0'), findsOneWidget);
      expect(
        creditRect(tester).bottom,
        heroHeight - PdlMapBottomInset.rowPadding,
      );
    });
  });

  group('la colonne de boutons', () {
    Rect columnRect(WidgetTester tester) =>
        tester.getRect(find.byType(PdlMapButtonColumn));

    testWidgets('en bas à droite, au-dessus du crédit', (
      WidgetTester tester,
    ) async {
      await pumpHero(tester, hero());
      final Rect hero0 = heroRect(tester);
      final Rect column = columnRect(tester);
      expect(column.right, hero0.right - edge);
      expect(column.bottom, hero0.bottom - creditSlot);
      expect(column.bottom, lessThan(creditRect(tester).top));
      // Plus centrée verticalement : collée au bas, pas au milieu.
      expect(column.center.dy, greaterThan(hero0.center.dy));
    });

    testWidgets('monte avec ce qui occupe le bas', (WidgetTester tester) async {
      await pumpHero(tester, hero(bottomLayer: const SizedBox(height: 60)));
      expect(
        columnRect(tester).bottom,
        heroRect(tester).bottom - (60 + edge) - creditSlot,
      );
      expect(columnRect(tester).bottom, lessThan(creditRect(tester).top));
    });

    testWidgets('enjambe la zone sûre en plein écran', (
      WidgetTester tester,
    ) async {
      await pumpHero(tester, hero(isFullscreen: true), safeBottom: 34);
      expect(
        columnRect(tester).bottom,
        heroRect(tester).bottom - 34 - creditSlot,
      );
    });

    testWidgets('une vignette ne garde qu\'« Agrandir »', (
      WidgetTester tester,
    ) async {
      await pumpHero(tester, hero(vignette: true));
      expect(find.bySemanticsLabel('Plein écran'), findsOneWidget);
      expect(find.bySemanticsLabel('Choisir le fond'), findsNothing);
      expect(find.byIcon(PdlIcons.layers), findsNothing);
    });

    testWidgets('une carte interactive garde Calques', (
      WidgetTester tester,
    ) async {
      await pumpHero(tester, hero());
      expect(find.bySemanticsLabel('Plein écran'), findsOneWidget);
      expect(find.bySemanticsLabel('Choisir le fond'), findsOneWidget);
    });

    testWidgets('en plein écran, la vignette retrouve Calques', (
      WidgetTester tester,
    ) async {
      await pumpHero(tester, hero(isFullscreen: true, vignette: true));
      expect(find.bySemanticsLabel('Choisir le fond'), findsOneWidget);
      expect(find.bySemanticsLabel('Plein écran'), findsNothing);
    });
  });

  group('« Fermer »', () {
    testWidgets('en haut à gauche en plein écran, hors de la colonne', (
      WidgetTester tester,
    ) async {
      await pumpHero(tester, hero(isFullscreen: true));
      final Finder close = find.ancestor(
        of: find.byIcon(PdlIcons.close),
        matching: find.byType(PdlMapButton),
      );
      expect(close, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PdlMapButtonColumn),
          matching: find.byIcon(PdlIcons.close),
        ),
        findsNothing,
      );
      final Rect rect = tester.getRect(close);
      final Rect hero0 = heroRect(tester);
      expect(rect.topLeft, hero0.topLeft + const Offset(edge, edge));
      expect(rect.size, const Size(44, 44));
      expect(find.bySemanticsLabel('Quitter le plein écran'), findsOneWidget);
      expect(find.byIcon(PdlIcons.fullscreen), findsNothing);
    });

    testWidgets('absent hors plein écran', (WidgetTester tester) async {
      await pumpHero(tester, hero());
      expect(find.byIcon(PdlIcons.close), findsNothing);
      expect(find.bySemanticsLabel('Quitter le plein écran'), findsNothing);
    });

    testWidgets('referme la page plein écran', (WidgetTester tester) async {
      await pumpHero(
        tester,
        hero(
          fullscreenBuilder: (BuildContext context) =>
              hero(isFullscreen: true, pill: const Text('page plein écran')),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Plein écran'));
      await tester.pumpAndSettle();
      expect(find.text('page plein écran'), findsOneWidget);

      await tester.tap(find.byIcon(PdlIcons.close));
      await tester.pumpAndSettle();
      expect(find.text('page plein écran'), findsNothing);
      expect(find.bySemanticsLabel('Plein écran'), findsOneWidget);
    });

    testWidgets('la pilule s\'en écarte, des deux côtés', (
      WidgetTester tester,
    ) async {
      const Key pill = ValueKey<String>('pill');
      await pumpHero(
        tester,
        hero(
          isFullscreen: true,
          pill: const SizedBox(key: pill, width: double.infinity, height: 32),
        ),
      );
      final Rect close = tester.getRect(
        find.ancestor(
          of: find.byIcon(PdlIcons.close),
          matching: find.byType(PdlMapButton),
        ),
      );
      final Rect rect = tester.getRect(find.byKey(pill));
      expect(rect.left, greaterThan(close.right));
      expect(
        heroRect(tester).right - rect.right,
        rect.left - heroRect(tester).left,
      );
    });
  });
}
