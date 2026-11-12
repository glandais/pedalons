import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/features/rides/domain/group_title.dart';

/// Décision du 2026-11-12 (KIT §9) : « Groupe » devant un nom de 1 ou 2
/// caractères seulement ; tout autre nom tel quel.
void main() {
  test('un nom de 1 ou 2 caractères prend le mot du gabarit', () {
    expect(groupTitle('B', 'Groupe {name}'), 'Groupe B');
    expect(groupTitle('A1', 'Groupe {name}'), 'Groupe A1');
    expect(groupTitle(' B ', 'Groupe {name}'), 'Groupe B');
    expect(groupTitle('A', 'Group {name}'), 'Group A');
  });

  test('tout autre nom s’affiche tel quel', () {
    expect(groupTitle('Les Rapides', 'Groupe {name}'), 'Les Rapides');
    expect(groupTitle('Groupe 1', 'Groupe {name}'), 'Groupe 1');
    expect(groupTitle('Gr. A', 'Groupe {name}'), 'Gr. A');
    expect(groupTitle('Intermédiaire', 'Groupe {name}'), 'Intermédiaire');
    expect(groupTitle('ABC', 'Group {name}'), 'ABC');
  });

  test('un caractère accentué compte pour un', () {
    expect(groupTitle('É2', 'Groupe {name}'), 'Groupe É2');
  });

  test('un nom vide reste vide', () {
    expect(groupTitle('  ', 'Groupe {name}'), '');
  });
}
