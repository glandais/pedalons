import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pedalons/core/utils/formatters.dart';

import '../../support/localization.dart';

/// Le fuseau d'affichage (docs/LEDGER_*.md API-15) : `UserDto.timezone` quand
/// l'utilisateur en a choisi un, l'appareil sinon — la règle du web.
///
/// Les cas posent tous un fuseau explicite : le fuseau de la machine qui lance
/// les tests ne doit rien décider.
void main() {
  // L'étape du lundi 17 août 2026 à 08:00 à Auckland (NZST, UTC+12) : le
  // dimanche 16 à 20:00 UTC, et le dimanche 16 à 13:00 à Los Angeles (PDT).
  final DateTime stage = DateTime.utc(2026, 8, 16, 20);

  setUpAll(() => initializeDateFormatting('fr'));

  tearDown(() => AppFormatters.setDisplayTimezone(null));

  test(
    'un instant du contrat est rendu à l\'heure murale du fuseau choisi',
    () {
      AppFormatters.setDisplayTimezone('Pacific/Auckland');
      final DateTime wall = AppFormatters.toDisplayTime(stage);

      expect(
        <int>[wall.year, wall.month, wall.day, wall.hour],
        <int>[2026, 8, 17, 8],
      );
      expect(wall.weekday, DateTime.monday);
    },
  );

  test('le même instant change de jour avec le fuseau', () {
    AppFormatters.setDisplayTimezone('America/Los_Angeles');
    final DateTime wall = AppFormatters.toDisplayTime(stage);

    expect(<int>[wall.day, wall.hour], <int>[16, 13]);
    expect(wall.weekday, DateTime.sunday);
  });

  test('aucune double conversion : une heure murale reste ce qu\'elle est', () {
    AppFormatters.setDisplayTimezone('Pacific/Auckland');
    final DateTime once = AppFormatters.toDisplayTime(stage);

    expect(AppFormatters.toDisplayTime(once), once);
    expect(AppFormatters.tryParseDisplayTime('2026-08-16T20:00:00Z'), once);
  });

  test('les formateurs rendent l\'heure du fuseau choisi', () {
    AppFormatters.setDisplayTimezone('Pacific/Auckland');

    expect(
      Intl.withLocale('fr', () => AppFormatters.formatTime(stage)),
      '08:00',
    );
  });

  test(
    'une borne de mois repart vers l\'API en UTC, dans le fuseau choisi',
    () {
      AppFormatters.setDisplayTimezone('Pacific/Auckland');

      expect(
        AppFormatters.displayWallClockToUtc(DateTime(2026, 8)),
        DateTime.utc(2026, 7, 31, 12),
      );
      expect(
        AppFormatters.displayWallClockToUtc(AppFormatters.toDisplayTime(stage)),
        stage,
      );
    },
  );

  test('sans préférence, ou avec un nom inconnu, c\'est l\'appareil', () {
    AppFormatters.setDisplayTimezone(null);
    expect(AppFormatters.toDisplayTime(stage), stage.toLocal());

    AppFormatters.setDisplayTimezone('Mars/Olympus_Mons');
    expect(AppFormatters.toDisplayTime(stage), stage.toLocal());
  });

  /// Les rendez-vous (docs/LEDGER_*.md API-60, plan §7) : l'heure du fuseau de
  /// l'entité, et la mention quand son décalage diffère de celui du lecteur.
  group('rendez-vous', () {
    // Dimanche 11 octobre 2026 à 06:00 à Tokyo (UTC+9) : samedi 10 à 23:00 à
    // Paris (CEST, UTC+2).
    final DateTime tokyoDawn = DateTime.utc(2026, 10, 10, 21);
    // Dimanche 11 à 08:00 à Tokyo : dimanche 11 à 01:00 à Paris.
    final DateTime tokyoMorning = DateTime.utc(2026, 10, 10, 23);
    final DateTime summer = DateTime.utc(2026, 7, 11, 6);
    final DateTime winter = DateTime.utc(2026, 1, 10, 7);

    setUpAll(loadTestTranslations);

    test('l\'heure murale est celle du fuseau de l\'entité', () {
      AppFormatters.setDisplayTimezone('Europe/Paris');
      final DateTime wall = AppFormatters.toZoneTime(tokyoDawn, 'Asia/Tokyo');

      expect(<int>[wall.day, wall.hour], <int>[11, 6]);
      expect(AppFormatters.formatTime(wall), '06:00');
      expect(
        AppFormatters.tryParseZoneTime('2026-10-10T21:00:00Z', 'Asia/Tokyo'),
        wall,
      );
      expect(AppFormatters.toZoneTime(wall, 'Asia/Tokyo'), wall);
    });

    test('Tokyo lu de Paris : mention, avec le jour quand il change', () {
      AppFormatters.setDisplayTimezone('Europe/Paris');

      expect(
        AppFormatters.zoneMention(tokyoDawn, 'Asia/Tokyo'),
        'heure de Tokyo',
      );
      expect(
        AppFormatters.formatZoneMention(tokyoDawn, 'Asia/Tokyo'),
        'heure de Tokyo (sam. 23:00 chez vous)',
      );
      expect(
        AppFormatters.formatZoneMention(tokyoMorning, 'Asia/Tokyo'),
        'heure de Tokyo (01:00 chez vous)',
      );
      expect(
        AppFormatters.formatRendezvous(
          tokyoDawn,
          'Asia/Tokyo',
          now: DateTime.utc(2026, 9),
        ),
        'dim. 11 oct. · 06:00 · heure de Tokyo (sam. 23:00 chez vous)',
      );
    });

    test('Paris lu de Bruxelles : aucune mention, été comme hiver', () {
      AppFormatters.setDisplayTimezone('Europe/Brussels');

      expect(AppFormatters.sameOffsetAt(summer, 'Europe/Paris'), isTrue);
      expect(AppFormatters.sameOffsetAt(winter, 'Europe/Paris'), isTrue);
      expect(AppFormatters.formatZoneMention(summer, 'Europe/Paris'), isNull);
      expect(
        AppFormatters.formatRendezvous(
          summer,
          'Europe/Paris',
          now: DateTime.utc(2026, 6),
        ),
        'sam. 11 juil. · 08:00',
      );
    });

    test('Londres lu en UTC : le décalage se juge à l\'instant', () {
      AppFormatters.setDisplayTimezone('UTC');

      expect(AppFormatters.zoneMention(winter, 'Europe/London'), isNull);
      expect(
        AppFormatters.zoneMention(summer, 'Europe/London'),
        'heure de Londres',
      );
    });

    test(
      'un fuseau d\'entité inconnu retombe sur le lecteur, sans mention',
      () {
        AppFormatters.setDisplayTimezone('Europe/Paris');

        expect(
          AppFormatters.toZoneTime(tokyoDawn, 'Mars/Olympus_Mons'),
          AppFormatters.toDisplayTime(tokyoDawn),
        );
        expect(
          AppFormatters.zoneMention(tokyoDawn, 'Mars/Olympus_Mons'),
          isNull,
        );
        expect(AppFormatters.zoneMention(tokyoDawn, null), isNull);
      },
    );

    test('12 h en anglais, 24 h en français : la langue décide', () {
      AppFormatters.setDisplayTimezone('Asia/Tokyo');
      final String time = Intl.withLocale(
        'en',
        () => AppFormatters.formatTime(tokyoMorning),
      );

      // Selon la version des données CLDR, l'espace avant « AM » est fine.
      expect(time.replaceAll('\u202F', ' '), '8:00 AM');
      expect(
        Intl.withLocale('fr', () => AppFormatters.formatTime(tokyoMorning)),
        '08:00',
      );
    });
  });
}
