import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/enum_colors.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/tags/presentation/content_tags.dart';
import 'package:pedalons/features/tags/presentation/tag_filter.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

TagWithUsageDto _tag(String id, String label, {String color = 'GREEN'}) =>
    TagWithUsageDto(
      id: id,
      label: label,
      color: color,
      type: 'ROUTE',
      usageCount: 1,
    );

final List<TagWithUsageDto> _vocabulary = <TagWithUsageDto>[
  _tag('a1', 'Café'),
  _tag('b2', 'Gravel', color: 'ORANGE'),
  _tag('c3', 'Montagne', color: 'GRAPE'),
];

/// Ledger `MOB-39` — le filtre par tag des listes d'équipe.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Widget host(Widget child) => MaterialApp(
    theme: PedalonsTheme.build(Brightness.light),
    home: Scaffold(body: Center(child: child)),
  );

  group('tagFamily', () {
    test('la couleur du contrat est le nom de la famille, en capitales', () {
      expect(tagFamily('GREEN'), PdlFamily.green);
      expect(tagFamily('GRAPE'), PdlFamily.grape);
      expect(tagFamily('INDIGO'), PdlFamily.indigo);
    });

    test('une couleur inconnue retombe sur le gris', () {
      expect(tagFamily('MAUVE'), PdlFamily.gray);
    });
  });

  group('sélection', () {
    test('triée et dédoublonnée : une seule clé pour un même jeu', () {
      expect(normalizeTagSelection(<String>['b2', 'a1', 'b2']), <String>[
        'a1',
        'b2',
      ]);
    });

    test('le libellé de la puce suit la sélection', () {
      expect(tagFilterLabel(_vocabulary, const <String>[]), 'Tags');
      expect(tagFilterLabel(_vocabulary, const <String>['b2']), 'Gravel');
      expect(tagFilterLabel(_vocabulary, const <String>['a1', 'c3']), '2 tags');
    });

    test('un tag supprimé depuis n\'est pas compté', () {
      expect(tagFilterLabel(_vocabulary, const <String>['zz']), 'Tags');
      expect(tagFilterLabel(_vocabulary, const <String>['zz', 'a1']), 'Café');
    });
  });

  testWidgets('la feuille combine plusieurs tags et rend une sélection triée', (
    WidgetTester tester,
  ) async {
    List<String>? applied;
    await tester.pumpWidget(
      host(
        TagFilterChip(
          vocabulary: _vocabulary,
          selected: const <String>[],
          onChanged: (List<String> ids) => applied = ids,
        ),
      ),
    );

    await tester.tap(find.byKey(keys.tags.filterChip));
    await tester.pumpAndSettle();

    // La règle OU est dite dans la feuille.
    expect(
      find.text("Un contenu apparaît s'il porte au moins un des tags choisis."),
      findsOneWidget,
    );

    await tester.tap(find.byKey(keys.tags.pickerRow('c3')));
    await tester.tap(find.byKey(keys.tags.pickerRow('a1')));
    await tester.pump();
    await tester.tap(find.byKey(keys.tags.pickerApply));
    await tester.pumpAndSettle();

    expect(applied, <String>['a1', 'c3']);
  });

  testWidgets('fermer la feuille sans valider ne change rien', (
    WidgetTester tester,
  ) async {
    bool changed = false;
    await tester.pumpWidget(
      host(
        TagFilterChip(
          vocabulary: _vocabulary,
          selected: const <String>['a1'],
          onChanged: (_) => changed = true,
        ),
      ),
    );

    // Une sélection se lit sur la puce.
    expect(
      tester.widget<PdlChip>(find.byKey(keys.tags.filterChip)).selected,
      isTrue,
    );
    expect(find.text('Café'), findsOneWidget);

    await tester.tap(find.byKey(keys.tags.filterChip));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(keys.tags.pickerRow('b2')));
    await tester.pump();
    // Un appui sur la barrière ferme la feuille.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(changed, isFalse);
  });

  testWidgets('« Effacer » vide la sélection', (WidgetTester tester) async {
    List<String>? applied;
    await tester.pumpWidget(
      host(
        TagFilterChip(
          vocabulary: _vocabulary,
          selected: const <String>['a1', 'b2'],
          onChanged: (List<String> ids) => applied = ids,
        ),
      ),
    );

    await tester.tap(find.byKey(keys.tags.filterChip));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(keys.tags.pickerClear));
    await tester.pump();
    await tester.tap(find.byKey(keys.tags.pickerApply));
    await tester.pumpAndSettle();

    expect(applied, isEmpty);
  });

  testWidgets('ContentTagRow rend les tags d\'un contenu en pastilles', (
    WidgetTester tester,
  ) async {
    const List<TagDto> tags = <TagDto>[
      TagDto(id: 'a1', label: 'Café', color: 'GREEN'),
      TagDto(id: 'b2', label: 'Gravel', color: 'ORANGE'),
      TagDto(id: 'c3', label: 'Montagne', color: 'GRAPE'),
      TagDto(id: 'd4', label: 'Nuit', color: 'INDIGO'),
      TagDto(id: 'e5', label: 'Pluie', color: 'BLUE'),
    ];
    await tester.pumpWidget(
      host(const ContentTagRow(tags: tags, maxVisible: kCardTagLimit)),
    );

    expect(find.byType(PdlTag), findsNWidgets(3));
    expect(find.text('+2'), findsOneWidget);
    // Une pastille, pas un badge métier.
    expect(find.byType(PdlBadge), findsNothing);
  });
}
