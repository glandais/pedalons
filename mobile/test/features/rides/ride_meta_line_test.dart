import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_meta_line.dart';

import '../../support/localization.dart';

/// La première ligne compacte d'une sortie (règle R11, décision du
/// 2026-11-12) : « 09:30 · Vélo Club des Monts · Groupe B », et c'est
/// l'équipe qui cède — ni l'heure ni le groupe.
void main() {
  setUpAll(loadTestTranslations);

  // La police des tests donne à chaque signe un cadratin : 8 px ici
  // approchent la largeur d'un texte de 13 px dans la vraie police.
  const TextStyle style = TextStyle(fontSize: 8);
  const String team = 'Vélo Club des Monts du Lyonnais et du Beaujolais';

  Future<void> pump(
    WidgetTester tester,
    double width,
    Widget line, {
    bool intrinsic = false,
  }) async {
    tester.view.physicalSize = Size(width, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            // La marge de la page, celle de la carte et la vignette du jour.
            padding: const EdgeInsets.only(left: 100, right: 40),
            child: intrinsic ? IntrinsicHeight(child: line) : line,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  RenderParagraph paragraph(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text, findRichText: true));

  String plain(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(RideMetaLine),
          matching: find.byType(Text),
        ),
      )
      .map((Text t) => t.data ?? t.textSpan!.toPlainText())
      .join();

  for (final double width in <double>[390, 320]) {
    testWidgets('à $width pt, l’équipe longue cède, le groupe et l’heure '
        'restent entiers', (WidgetTester tester) async {
      await pump(
        tester,
        width,
        const RideMetaLine(
          time: '09:30',
          teamName: team,
          groupName: 'B',
          style: style,
        ),
      );
      expect(plain(tester), '09:30 · $team · Groupe B');
      expect(paragraph(tester, ' · Groupe B').didExceedMaxLines, isFalse);
      expect(paragraph(tester, '09:30 · ').didExceedMaxLines, isFalse);
      expect(paragraph(tester, team).didExceedMaxLines, isTrue);
      // Pas de blanc entre l'équipe abrégée et le groupe.
      expect(
        tester.getTopLeft(find.text(' · Groupe B')).dx -
            tester.getTopLeft(find.text(team)).dx,
        paragraph(tester, team).textSize.width,
      );
      // Le groupe se termine au bord droit de la ligne, pas au-delà.
      expect(
        tester.getTopRight(find.text(' · Groupe B')).dx,
        lessThanOrEqualTo(width - 40),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('répond aux mesures intrinsèques (carte d’agenda)', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      320,
      const RideMetaLine(
        time: '09:30',
        teamName: team,
        groupName: 'B',
        style: style,
      ),
      intrinsic: true,
    );
    expect(tester.takeException(), isNull);
    expect(find.text(' · Groupe B'), findsOneWidget);
  });

  testWidgets('un nom de groupe trop long pour la ligne s’abrège plutôt que '
      'de déborder', (WidgetTester tester) async {
    await pump(
      tester,
      320,
      const RideMetaLine(
        time: '09:30',
        teamName: 'VC',
        groupName: 'Les Rapides du dimanche matin, côté vallée',
        style: style,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('un nom de groupe long s’affiche tel quel', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      390,
      const RideMetaLine(
        time: '09:30',
        teamName: 'VC',
        groupName: 'Les Rapides',
        style: style,
      ),
    );
    expect(plain(tester), '09:30 · VC · Les Rapides');
  });

  testWidgets('sans groupe, la ligne s’arrête à l’équipe', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      390,
      const RideMetaLine(time: '09:30', teamName: 'VC Craponne', style: style),
    );
    expect(plain(tester), '09:30 · VC Craponne');
  });
}
