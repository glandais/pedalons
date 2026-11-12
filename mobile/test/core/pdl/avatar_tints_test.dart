import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';

/// Règle R5 des cartes (KIT §8 et §9, docs/LEDGER_*.md MOB-139) : des
/// initiales blanches lisibles sur toutes les teintes d'avatar, une grappe
/// qui ne mange plus la seconde initiale, une barre de places primaire puis
/// rouge.
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('onze teintes, les mêmes dans les deux thèmes, ≥ 3:1 avec le blanc', () {
    expect(PdlColors.light.avatarAccents, hasLength(11));
    expect(PdlColors.dark.avatarAccents, PdlColors.light.avatarAccents);
    for (final Color tint in PdlColors.light.avatarAccents) {
      expect(
        _contrast(tint, PdlColors.light.onPrimary),
        greaterThanOrEqualTo(3),
        reason: tint.toString(),
      );
    }
  });

  test('les quatre teintes de KIT §8 en font partie', () {
    expect(
      PdlColors.light.avatarAccents,
      containsAll(const <Color>[
        Color(0xFFE8590C),
        Color(0xFF1971C2),
        Color(0xFF2F9E44),
        Color(0xFFAE3EC9),
      ]),
    );
  });

  test('l’indigo est réservé à la personne qui lit (2026-11-12)', () {
    const Color indigo = Color(0xFF3B5BDB);
    expect(PdlColors.light.avatarAccents, isNot(contains(indigo)));
    expect(PdlColors.dark.avatarAccents, isNot(contains(indigo)));
    expect(
      PdlColors.light.avatarAccents,
      isNot(contains(PdlColors.light.primary)),
    );
    expect(
      PdlColors.dark.avatarAccents,
      isNot(contains(PdlColors.dark.primary)),
    );
    expect(
      PdlAvatar.tintFor(PdlColors.dark, 'Léa Martin', isCurrentUser: true),
      PdlColors.dark.primary,
    );
  });

  test('la table, dans l’ordre que le site recopie', () {
    expect(PdlColors.light.avatarAccents, const <Color>[
      Color(0xFF087F5B),
      Color(0xFF6741D9),
      Color(0xFF0B7285),
      Color(0xFF1971C2),
      Color(0xFF5C940D),
      Color(0xFFAE3EC9),
      Color(0xFFC2255C),
      Color(0xFFA16207),
      Color(0xFFC92A2A),
      Color(0xFF2F9E44),
      Color(0xFFE8590C),
    ]);
  });

  test('la grappe se recouvre de 4 pt', () {
    expect(PdlSpacing.avatarOverlap, -4);
  });

  Future<Color> fillOf(WidgetTester tester, double value) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(body: PdlProgressBar(value: value)),
      ),
    );
    final Iterable<ColoredBox> boxes = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(PdlProgressBar),
        matching: find.byType(ColoredBox),
      ),
    );
    return boxes.last.color;
  }

  testWidgets('la barre de places : primaire, rouge seulement pleine', (
    WidgetTester tester,
  ) async {
    expect(await fillOf(tester, 0.5), PdlColors.light.primary);
    expect(await fillOf(tester, 0.9), PdlColors.light.primary);
    expect(await fillOf(tester, 1), PdlColors.light.danger);
  });
}
