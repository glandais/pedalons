import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/features/rides/domain/group_title.dart';

void main() {
  test('prefixes a bare group name', () {
    expect(
      groupTitle('Intermédiaire', 'Groupe {name}'),
      'Groupe Intermédiaire',
    );
    expect(groupTitle('A', 'Group {name}'), 'Group A');
  });

  test('does not repeat the word the name already starts with', () {
    expect(
      groupTitle('Groupe intermédiaire', 'Groupe {name}'),
      'Groupe intermédiaire',
    );
    expect(groupTitle('group B', 'Group {name}'), 'group B');
    expect(groupTitle('Groupe', 'Groupe {name}'), 'Groupe');
  });

  test('only a whole word counts', () {
    expect(groupTitle('Groupement', 'Groupe {name}'), 'Groupe Groupement');
  });
}
