import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/features/rides/domain/markdown_edit.dart';

TextEditingValue _v(String text, int start, [int? end]) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end ?? start),
);

/// La barre d'outils markdown de l'éditeur de sortie (ledger `MOB-80`).
void main() {
  group('wrapSelection', () {
    test('entoure la sélection et la garde sélectionnée', () {
      final TextEditingValue v = wrapSelection(_v('un mot ici', 3, 6), '**');
      expect(v.text, 'un **mot** ici');
      expect(v.selection.textInside(v.text), 'mot');
    });

    test('sans sélection, place le curseur entre la paire', () {
      final TextEditingValue v = wrapSelection(_v('ab', 1), '_');
      expect(v.text, 'a__b');
      expect(v.selection.baseOffset, 2);
    });

    test('un champ jamais focalisé écrit à la fin', () {
      final TextEditingValue v = wrapSelection(
        const TextEditingValue(text: 'fin'),
        '**',
      );
      expect(v.text, 'fin****');
    });
  });

  group('toggleLinePrefix', () {
    test('préfixe chaque ligne touchée, puis le retire', () {
      final TextEditingValue on = toggleLinePrefix(_v('a\nb\nc', 0, 3), '- ');
      expect(on.text, '- a\n- b\nc');
      final TextEditingValue off = toggleLinePrefix(on, '- ');
      expect(off.text, 'a\nb\nc');
    });

    test('n\'agit que sur la ligne du curseur', () {
      expect(toggleLinePrefix(_v('a\nb', 3), '## ').text, 'a\n## b');
    });
  });

  test('insertLink prend le texte sélectionné, sinon le libellé', () {
    expect(
      insertLink(_v('voir ici', 5, 8), url: 'https://x.fr').text,
      'voir [ici](https://x.fr)',
    );
    expect(
      insertLink(_v('', 0), url: 'https://x.fr', label: 'site').text,
      '[site](https://x.fr)',
    );
  });

  group('directives d\'image', () {
    test('au format du site, taille par défaut omise', () {
      expect(assetDirective('a1'), '::asset{id="a1"}');
      expect(
        assetDirective('a1', alt: 'Le "col" {du}\nmatin'),
        '::asset{id="a1" alt="Le \'col\' (du) matin"}',
      );
    });

    test('insertBlock la pose seule sur sa ligne', () {
      expect(
        insertBlock(_v('avantaprès', 5), '::asset{id="a1"}').text,
        'avant\n::asset{id="a1"}\naprès',
      );
      expect(
        insertBlock(_v('avant\n', 6), '::asset{id="a1"}').text,
        'avant\n::asset{id="a1"}\n',
      );
    });

    test('retirer une image retire ses directives, et elles seules', () {
      const String md =
          'Intro\n::asset{id="a1"}\nMilieu\n::asset{id="a2" size="full"}\nFin';
      expect(
        removeAssetDirectives(md, 'a1'),
        'Intro\nMilieu\n::asset{id="a2" size="full"}\nFin',
      );
    });
  });
}
