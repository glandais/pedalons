import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/visibility/domain/content_visibility.dart';

/// Règle R1 des cartes (KIT §9, docs/LEDGER_*.md MOB-139) : la visibilité ne
/// se badge que lorsqu'elle diffère de celle de l'équipe ; une équipe ne se
/// badge que privée.
void main() {
  group('cardVisibility', () {
    test('la visibilité de l’équipe ne se badge pas', () {
      expect(cardVisibility('TEAM', reference: 'TEAM'), isNull);
      expect(cardVisibility('PUBLIC', reference: 'PUBLIC'), isNull);
    });

    test('lisible par lien dans une équipe privée : sa visibilité', () {
      expect(cardVisibility('PUBLIC', reference: 'TEAM'), Visibility.public);
      expect(
        cardVisibility('PUBLIC_UNLISTED', reference: 'TEAM'),
        Visibility.publicUnlisted,
      );
    });

    test('« Équipe uniquement » dans une équipe publique : se badge', () {
      expect(cardVisibility('TEAM', reference: 'PUBLIC'), Visibility.team);
    });

    test('une valeur inconnue ne se badge pas', () {
      expect(cardVisibility('SECRET', reference: 'TEAM'), isNull);
    });
  });

  test('teamCardVisibility : « Équipe uniquement » sur une équipe privée, '
      'rien sur une équipe publique', () {
    expect(teamCardVisibility('TEAM'), Visibility.team);
    expect(teamCardVisibility('PUBLIC'), isNull);
  });
}
