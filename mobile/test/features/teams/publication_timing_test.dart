import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/features/teams/domain/publication_timing.dart';

import '../../support/localization.dart';

/// Ledger `MOB-60` — « En cours » et la fin affichée, d'après la fin stockée
/// (`endDateTime`, ledger `API-85`). Même règle que `isUnderWay` au web.
void main() {
  setUpAll(loadTestTranslations);

  final DateTime now = DateTime.utc(2026, 10, 11, 10);

  group('isUnderWay', () {
    bool at(String start, String end, {String status = 'PUBLISHED'}) =>
        isUnderWay(dateTime: start, endDateTime: end, status: status, now: now);

    test('parti et pas rentré : en cours', () {
      expect(at('2026-10-11T08:30:00Z', '2026-10-11T14:10:00Z'), isTrue);
    });

    test('au départ pile : en cours ; au retour pile : plus', () {
      expect(at('2026-10-11T10:00:00Z', '2026-10-11T14:00:00Z'), isTrue);
      expect(at('2026-10-11T06:00:00Z', '2026-10-11T10:00:00Z'), isFalse);
    });

    test('pas encore parti, ou déjà rentré : pas en cours', () {
      expect(at('2026-10-12T08:30:00Z', '2026-10-12T14:00:00Z'), isFalse);
      expect(at('2026-10-10T08:30:00Z', '2026-10-10T14:00:00Z'), isFalse);
    });

    test('annulée : jamais en cours', () {
      expect(
        at('2026-10-11T08:30:00Z', '2026-10-11T14:10:00Z', status: 'CANCELLED'),
        isFalse,
      );
    });

    test('une date illisible : pas en cours', () {
      expect(at('pas une date', '2026-10-11T14:10:00Z'), isFalse);
    });
  });

  group('tripDaySpan', () {
    test(
      'un voyage multi-fuseaux finit dans le fuseau de sa dernière étape',
      () {
        // Départ de Paris le vendredi 16 à 22:00, arrivée le samedi 17 à
        // 20:00 UTC : dimanche 18 à Tokyo, encore samedi à Paris.
        expect(
          tripDaySpan(
            '2026-10-16T20:00:00Z',
            '2026-10-17T20:00:00Z',
            timezone: 'Europe/Paris',
            endTimezone: 'Asia/Tokyo',
            now: now,
          ),
          'ven. 16 → dim. 18 oct.',
        );
        expect(
          tripDaySpan(
            '2026-10-16T20:00:00Z',
            '2026-10-17T20:00:00Z',
            timezone: 'Europe/Paris',
            now: now,
          ),
          'ven. 16 → sam. 17 oct.',
        );
      },
    );

    test('BRAND-8 : format unique, l\'année seulement hors de l\'année en '
        'cours', () {
      // Du samedi 9 au mardi 12 août 2036, vus de 2026.
      expect(
        tripDaySpan(
          '2036-08-09T07:00:00Z',
          '2036-08-12T16:00:00Z',
          timezone: 'Europe/Paris',
          now: now,
        ),
        'sam. 9 → mar. 12 août 2036',
      );
      // Vus de la même année : pas d'année.
      expect(
        tripDaySpan(
          '2036-08-09T07:00:00Z',
          '2036-08-12T16:00:00Z',
          timezone: 'Europe/Paris',
          now: DateTime.utc(2036, 1, 2),
        ),
        'sam. 9 → mar. 12 août',
      );
      // Deux mois : le premier jour nomme le sien.
      expect(
        tripDaySpan(
          '2036-07-30T07:00:00Z',
          '2036-08-02T16:00:00Z',
          timezone: 'Europe/Paris',
          now: DateTime.utc(2036, 1, 2),
        ),
        'mer. 30 juil. → sam. 2 août',
      );
      // Un seul jour : « sam. 9 août », sans flèche.
      expect(
        tripDaySpan(
          '2036-08-09T07:00:00Z',
          '2036-08-09T16:00:00Z',
          timezone: 'Europe/Paris',
          now: DateTime.utc(2036, 1, 2),
        ),
        'sam. 9 août',
      );
    });

    test('plusieurs jours : une flèche ; un seul : pas de flèche', () {
      expect(
        tripDaySpan(
          '2026-10-16T08:00:00Z',
          '2026-10-18T16:00:00Z',
          timezone: 'Europe/Paris',
        ),
        contains(' → '),
      );
      expect(
        tripDaySpan(
          '2026-10-16T08:00:00Z',
          '2026-10-16T16:00:00Z',
          timezone: 'Europe/Paris',
        ),
        isNot(contains(' → ')),
      );
    });
  });
}
