import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/features/comments/domain/comment_links.dart';

/// Décision du 2026-11-12 (KIT §9) : dans un commentaire, une adresse
/// complète devient un lien ; rien d'autre n'est interprété.
void main() {
  List<String> links(String s) => <String>[
    for (final CommentSegment seg in splitCommentLinks(s))
      if (seg.isLink) seg.text,
  ];

  test('les morceaux redonnent le texte à l’identique', () {
    const String typed = 'Plan : https://x.example/a, puis (http://y.example).';
    expect(
      splitCommentLinks(typed).map((CommentSegment s) => s.text).join(),
      typed,
    );
  });

  test('la ponctuation finale reste à la phrase', () {
    expect(links('Voir https://x.example.'), <String>['https://x.example']);
    expect(links('Voir https://x.example/?a=1 !'), <String>[
      'https://x.example/?a=1',
    ]);
    expect(links('« https://x.example »'), <String>['https://x.example']);
    expect(links('(voir https://x.example)'), <String>['https://x.example']);
  });

  test('une parenthèse appariée appartient à l’adresse', () {
    expect(links('https://fr.wikipedia.org/wiki/Col_(géographie)'), <String>[
      'https://fr.wikipedia.org/wiki/Col_(géographie)',
    ]);
  });

  test('ni adresse sans schéma, ni e-mail, ni mention, ni schéma seul', () {
    expect(links('pedalons.fr www.pedalons.fr lea@exemple.fr @Karim'), isEmpty);
    expect(links('ftp://x.example mailto:lea@exemple.fr'), isEmpty);
    expect(links('https:// seul'), isEmpty);
  });

  test('sans adresse, un seul morceau de texte', () {
    expect(splitCommentLinks('Oui, 8 h 45.'), <CommentSegment>[
      (text: 'Oui, 8 h 45.', isLink: false),
    ]);
  });
}
