import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// Le sélecteur de fond, **en plein écran**.
///
/// Le piège que ce test tient, et que deux corrections successives ont raté :
/// une route opaque éteint le `TickerMode` de ce qu'elle recouvre, et Riverpod
/// met alors en pause les `ref.watch` de l'écran masqué. L'écran ne se
/// reconstruit plus tant que la page plein écran est au-dessus — il ne repart
/// qu'au `pop`. Toute mécanique qui fait *redescendre* une configuration
/// depuis l'écran vers la page est donc morte-née : la page doit relire les
/// providers elle-même, ce que `fullscreenBuilder` lui impose.
///
/// Le test échoue si on revient à une page plein écran recopiée : le fond y
/// resterait celui d'avant.
void main() {
  const PdlMapHeroLabels labels = PdlMapHeroLabels(
    enterFullscreen: 'Plein écran',
    exitFullscreen: 'Quitter le plein écran',
    chooseBackground: 'Choisir le fond',
    backgroundSheetTitle: 'Fond de carte',
  );

  Widget host() => ProviderScope(
    child: MaterialApp(
      theme: PedalonsTheme.build(Brightness.light),
      home: const Scaffold(body: _Map()),
    ),
  );

  testWidgets('le fond choisi en plein écran atteint la carte', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.tap(find.bySemanticsLabel('Plein écran'));
    await tester.pumpAndSettle();
    // La page plein écran est bien celle de l'écran, pas une copie du hero.
    expect(find.bySemanticsLabel('Quitter le plein écran'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Choisir le fond'));
    await tester.pumpAndSettle();
    expect(find.text('Fond de carte'), findsOneWidget);

    await tester.tap(find.text('Satellite'));
    await tester.pumpAndSettle();

    // La carte de la page plein écran porte le nouveau fond, **sans attendre
    // le retour** : c'est tout l'objet du correctif.
    expect(find.text('carte:satellite'), findsOneWidget);
  });

  group('vignette qui ouvre le plein écran au toucher', () {
    // Une vignette inerte comme celle de l'onglet Météo d'un groupe : la carte
    // se réduit à un texte, et porte le crédit ⓘ que `PdlMap` pose en dernier.
    Widget thumbnail() => MaterialApp(
      theme: PedalonsTheme.build(Brightness.light),
      home: Scaffold(
        body: SizedBox(
          height: 240,
          child: PdlMapHero(
            labels: labels,
            tapOpensFullscreen: true,
            fullscreenBuilder: (BuildContext context) =>
                const Text('page plein écran'),
            mapBuilder: (BuildContext context) => const Stack(
              children: <Widget>[
                Center(child: Text('carte')),
                PdlMapAttribution(
                  credit: PdlMapCredit(
                    toggleLabel: 'Crédits de la carte',
                    extra: 'IGN — Geoportail',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    testWidgets('le ⓘ déplie les crédits et n\'ouvre pas le plein écran', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(thumbnail());
      expect(find.text('IGN — Geoportail'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Crédits de la carte'));
      await tester.pumpAndSettle();

      expect(find.text('IGN — Geoportail'), findsOneWidget);
      expect(find.text('page plein écran'), findsNothing);

      // Le ⓘ replie, toujours sans quitter la vignette.
      await tester.tap(find.bySemanticsLabel('Crédits de la carte'));
      await tester.pumpAndSettle();
      expect(find.text('IGN — Geoportail'), findsNothing);
      expect(find.text('page plein écran'), findsNothing);
    });

    testWidgets('ailleurs, le toucher ouvre le plein écran', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(thumbnail());

      // La couche, pas la carte, reçoit le toucher : c'est ce qu'on vérifie.
      await tester.tap(find.byKey(PdlMapHero.tapTargetKey));
      await tester.pumpAndSettle();

      expect(find.text('page plein écran'), findsOneWidget);
    });
  });

  testWidgets('un bouton plein écran sans page est refusé', (
    WidgetTester tester,
  ) async {
    expect(
      () => PdlMapHero(
        labels: labels,
        mapBuilder: (BuildContext context) => const SizedBox.shrink(),
      ),
      throwsAssertionError,
    );
  });
}

/// L'écran : il lit le fond dans un provider, comme les vraies cartes, et
/// construit lui-même sa page plein écran.
class _Map extends ConsumerWidget {
  const _Map({this.fullscreen = false});

  final bool fullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String selected = ref.watch(_styleId);
    return PdlMapHero(
      isFullscreen: fullscreen,
      fullscreenBuilder: fullscreen
          ? null
          : (BuildContext context) => const _Map(fullscreen: true),
      labels: const PdlMapHeroLabels(
        enterFullscreen: 'Plein écran',
        exitFullscreen: 'Quitter le plein écran',
        chooseBackground: 'Choisir le fond',
        backgroundSheetTitle: 'Fond de carte',
      ),
      styles: const <PdlMapStyleOption>[
        PdlMapStyleOption(id: 'plan', label: 'Plan'),
        PdlMapStyleOption(id: 'satellite', label: 'Satellite'),
      ],
      selectedStyleId: selected,
      onStyleSelected: (String id) => ref.read(_styleId.notifier).select(id),
      // MapLibre ne tourne pas dans un test : la carte se réduit au fond
      // qu'on lui a passé, qui est justement ce qu'on vérifie.
      mapBuilder: (BuildContext context) =>
          Center(child: Text('carte:$selected')),
    );
  }
}

/// Le pendant minimal de `mapStyleIdProvider` : un fond choisi, persisté nulle
/// part.
final NotifierProvider<_StyleIdNotifier, String> _styleId =
    NotifierProvider<_StyleIdNotifier, String>(_StyleIdNotifier.new);

class _StyleIdNotifier extends Notifier<String> {
  @override
  String build() => 'plan';

  void select(String id) => state = id;
}
