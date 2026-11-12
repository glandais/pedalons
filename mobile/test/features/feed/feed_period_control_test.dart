import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/feed/presentation/widgets/publication_feed_view.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_sections.dart';

import '../../dev/support/gallery_fonts.dart';
import '../../support/localization.dart';

/// RL15, complément du 12 novembre 2026 — la période à trois choix tient sur
/// un écran de 390 pt **sans couper un libellé** : « Toutes les dates / Je
/// participe / Plus tôt », dans les vraies polices (Inter), aux marges de la
/// barre (16 de chaque côté). Ce sont les marges internes du segmenté qui se
/// resserrent, pas le texte.
void main() {
  setUpAll(() async {
    await loadTestTranslations();
    await loadGalleryFonts();
  });

  for (final String allLabelKey in <String>[
    'lists.period.allDates',
    'lists.period.all',
  ]) {
    testWidgets('$allLabelKey : trois libellés entiers à 390 pt', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FeedPeriodControl(
                allLabelKey: allLabelKey,
                period: AgendaScope.earlier,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final Finder labels = find.descendant(
        of: find.byType(PdlSegmented<AgendaScope>),
        matching: find.byType(RichText),
      );
      expect(labels, findsNWidgets(3));
      for (final Element element in labels.evaluate()) {
        final RenderParagraph paragraph =
            element.renderObject! as RenderParagraph;
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '« ${paragraph.text.toPlainText()} » est coupé',
        );
      }
      expect(find.text('Plus tôt'), findsOneWidget);
    });
  }
}
