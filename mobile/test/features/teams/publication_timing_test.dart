import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/utils/formatters.dart';
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

  group('rideReturnLabel', () {
    tearDown(() => AppFormatters.setDisplayTimezone(null));

    test('le retour se lit dans le fuseau de la sortie', () {
      // Lu de Paris, une sortie de Tokyo du dimanche 11 de 06:00 à 12:30,
      // heure de Tokyo (docs/LEDGER_*.md API-60).
      AppFormatters.setDisplayTimezone('Europe/Paris');
      expect(
        rideReturnLabel(
          '2026-10-10T21:00:00Z',
          '2026-10-11T03:30:00Z',
          timezone: 'Asia/Tokyo',
        ),
        'retour vers 12:30',
      );
    });

    test('un retour le lendemain nomme son jour', () {
      expect(
        rideReturnLabel(
          '2026-10-16T19:30:00Z',
          '2026-10-17T00:00:00Z',
          timezone: 'Europe/Paris',
        ),
        'retour vers sam. 17 oct. 02:00',
      );
    });

    test('une date illisible : rien, la ligne garde le départ seul', () {
      expect(
        rideReturnLabel('?', '2026-10-11T10:10:00Z', timezone: 'UTC'),
        isNull,
      );
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
          ),
          'ven. 16 → dim. 18 oct.',
        );
        expect(
          tripDaySpan(
            '2026-10-16T20:00:00Z',
            '2026-10-17T20:00:00Z',
            timezone: 'Europe/Paris',
          ),
          'ven. 16 → sam. 17 oct.',
        );
      },
    );

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
