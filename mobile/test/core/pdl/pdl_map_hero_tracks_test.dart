import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';

/// La section « Tracés » de la feuille des couches : une case par tracé, qui
/// ne referme pas la feuille, et rien quand il n'y a qu'un tracé.
void main() {
  const PdlMapHeroLabels labels = PdlMapHeroLabels(
    enterFullscreen: 'Plein écran',
    exitFullscreen: 'Quitter le plein écran',
    chooseBackground: 'Choisir le fond',
    backgroundSheetTitle: 'Fond de carte',
    tracks: 'Tracés',
  );

  Widget host(
    List<PdlMapTrackToggle> toggles,
    void Function(String, bool) onChanged,
  ) => MaterialApp(
    theme: PedalonsTheme.build(Brightness.light),
    home: Scaffold(
      body: PdlMapHero(
        labels: labels,
        showFullscreenButton: false,
        trackToggles: toggles,
        onTrackVisibilityChanged: onChanged,
        mapBuilder: (BuildContext context) => const SizedBox.shrink(),
      ),
    ),
  );

  PdlMapTrackToggle toggle(String id, String label, int i) => PdlMapTrackToggle(
    id: id,
    label: label,
    color: multiTrackColor(i),
    visible: true,
  );

  testWidgets('décocher un tracé le signale sans refermer la feuille', (
    WidgetTester tester,
  ) async {
    final List<(String, bool)> calls = <(String, bool)>[];
    await tester.pumpWidget(
      host(<PdlMapTrackToggle>[
        toggle('court', 'Chill · G1', 0),
        toggle('long', 'Sportif', 1),
      ], (String id, bool v) => calls.add((id, v))),
    );

    await tester.tap(find.bySemanticsLabel('Choisir le fond'));
    await tester.pumpAndSettle();
    expect(find.text('Tracés'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.text('Sportif'));
    await tester.pumpAndSettle();
    expect(calls, <(String, bool)>[('long', false)]);
    // La feuille reste ouverte, la case suit le tap.
    expect(find.text('Tracés'), findsOneWidget);
    final Checkbox box = tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('pdlMapTrackToggle_long')),
        matching: find.byType(Checkbox),
      ),
    );
    expect(box.value, isFalse);

    await tester.tap(find.text('Sportif'));
    await tester.pumpAndSettle();
    expect(calls.last, ('long', true));
  });

  testWidgets('un seul tracé : ni section, ni bouton des couches', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(<PdlMapTrackToggle>[
        toggle('court', 'Chill', 0),
      ], (String id, bool v) {}),
    );
    // Sans fond ni ombrage proposés, rien d'autre n'ouvrirait la feuille.
    expect(find.bySemanticsLabel('Choisir le fond'), findsNothing);
  });
}
