import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/utils/formatters.dart';

import '../../support/localization.dart';

/// Le format unique du départ (docs/LEDGER_*.md BRAND-8, MOB-113, BRANDING
/// §8.3) : « sam. 12 avr. · 09:00 », l'année seulement hors de l'année en
/// cours, « Aujourd'hui » / « Demain » et aucun autre relatif — appréciés dans
/// le fuseau de la sortie.
///
/// Dates en 2036 : la base des fuseaux embarquée s'arrête en 2037.
void main() {
  const String paris = 'Europe/Paris';
  // Le vendredi 11 avril 2036, 12:00 à Paris (CEST, UTC+2).
  final DateTime now = DateTime.utc(2036, 4, 11, 10);

  String departure(DateTime instant, {String zone = paris, DateTime? at}) =>
      AppFormatters.formatDeparture(instant, zone, now: at ?? now);

  tearDown(() {
    AppFormatters.setDisplayTimezone(null);
    AppFormatters.setUse24HourFormat(true);
  });

  group('en français', () {
    setUp(() async {
      await loadTestTranslations();
      AppFormatters.setDisplayTimezone(paris);
    });

    test('un autre jour de l’année : jour et mois abrégés, sans année', () {
      expect(departure(DateTime.utc(2036, 4, 19, 7)), 'sam. 19 avr. · 09:00');
    });

    test('demain et aujourd’hui sont relatifs', () {
      expect(departure(DateTime.utc(2036, 4, 12, 7)), 'Demain · 09:00');
      expect(departure(DateTime.utc(2036, 4, 11, 16)), "Aujourd'hui · 18:00");
      expect(
        AppFormatters.formatDepartureRelative(
          DateTime.utc(2036, 4, 12, 7),
          paris,
          now: now,
        ),
        'Demain',
      );
    });

    test('hier, après-demain : aucun relatif', () {
      final DateTime yesterday = DateTime.utc(2036, 4, 10, 7);
      final DateTime afterTomorrow = DateTime.utc(2036, 4, 13, 7);

      expect(
        AppFormatters.formatDepartureRelative(yesterday, paris, now: now),
        isNull,
      );
      expect(
        AppFormatters.formatDepartureRelative(afterTomorrow, paris, now: now),
        isNull,
      );
      expect(departure(yesterday), 'jeu. 10 avr. · 09:00');
    });

    test('l’année seulement quand elle n’est pas l’année en cours', () {
      final DateTime lastDecember = DateTime.utc(2035, 12, 20, 10);

      expect(
        departure(DateTime.utc(2036, 4, 12, 7), at: lastDecember),
        'sam. 12 avr. 2036 · 09:00',
      );
      expect(
        AppFormatters.formatDepartureDate(
          DateTime.utc(2036, 4, 12, 7),
          paris,
          now: now,
        ),
        'sam. 12 avr.',
      );
    });

    test('le passage du 31 décembre au 1er janvier reste « Demain »', () {
      expect(
        departure(
          DateTime.utc(2036, 1, 1, 8),
          at: DateTime.utc(2035, 12, 31, 12),
        ),
        'Demain · 09:00',
      );
    });

    test('« demain » s’apprécie dans le fuseau de la sortie', () {
      // 11:00Z : 23:00 à Auckland (NZST, UTC+12), 13:00 à Paris. Le départ à
      // 20:00Z est le 12 à 08:00 à Auckland, le 11 à 22:00 à Paris : demain
      // pour la sortie, alors que la personne à Paris y est encore aujourd'hui.
      final DateTime late = DateTime.utc(2036, 4, 11, 11);
      final DateTime start = DateTime.utc(2036, 4, 11, 20);

      expect(
        departure(start, zone: 'Pacific/Auckland', at: late),
        'Demain · 08:00',
      );
    });

    test('l’heure suit le réglage 12 h du téléphone', () {
      AppFormatters.setUse24HourFormat(false);
      // Le motif `jm` du français reste sur 24 h ; l'anglais, plus bas, le
      // montre en AM/PM. Le format ne change pas de forme pour autant.
      expect(departure(DateTime.utc(2036, 4, 12, 7)), startsWith('Demain · '));
    });
  });

  group('in English', () {
    setUp(() async {
      await loadTestTranslations(languageCode: 'en');
      AppFormatters.setDisplayTimezone(paris);
    });

    tearDown(() => loadTestTranslations());

    test('same shape, English words', () {
      expect(departure(DateTime.utc(2036, 4, 19, 7)), 'Sat, Apr 19 · 09:00');
      expect(departure(DateTime.utc(2036, 4, 12, 7)), 'Tomorrow · 09:00');
      expect(
        departure(DateTime.utc(2036, 4, 12, 7), at: DateTime.utc(2035, 6, 1)),
        'Sat, Apr 12, 2036 · 09:00',
      );
    });

    test('12-hour clock when the phone asks for it', () {
      AppFormatters.setUse24HourFormat(false);
      final String text = departure(DateTime.utc(2036, 4, 12, 7));

      expect(text, startsWith('Tomorrow · 9:00'));
      expect(text, endsWith('AM'));
    });
  });
}
