import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/utils/zone_label.dart';

/// Le nom d'un fuseau pour la mention (docs/LEDGER_*.md API-60, plan §7).
/// Mêmes cas que `frontend/src/utils/zoneLabel.test.ts` : les deux tables
/// avancent ensemble.
void main() {
  group('zoneCityName', () {
    test('nomme un fuseau par le dernier segment de son identifiant', () {
      expect(zoneCityName('Asia/Tokyo', 'fr'), 'Tokyo');
      expect(zoneCityName('Europe/Paris', 'en'), 'Paris');
      expect(
        zoneCityName('America/Argentina/Buenos_Aires', 'en'),
        'Buenos Aires',
      );
    });

    test('les soulignés deviennent des espaces', () {
      expect(zoneCityName('America/New_York', 'fr'), 'New York');
      expect(zoneCityName('America/Los_Angeles', 'en'), 'Los Angeles');
    });

    test('traduit les villes courantes, en français seulement', () {
      expect(zoneCityName('Europe/London', 'fr'), 'Londres');
      expect(zoneCityName('Europe/Brussels', 'fr'), 'Bruxelles');
      expect(zoneCityName('Europe/Lisbon', 'fr_FR'), 'Lisbonne');
      expect(zoneCityName('Africa/Cairo', 'fr'), 'Le Caire');
      expect(zoneCityName('Asia/Singapore', 'fr'), 'Singapour');
      expect(zoneCityName('America/Montreal', 'fr'), 'Montréal');
      expect(zoneCityName('Indian/Reunion', 'fr'), 'La Réunion');

      expect(zoneCityName('Europe/London', 'en'), 'London');
      expect(zoneCityName('Africa/Cairo', 'en'), 'Cairo');
    });

    test('nomme UTC et les décalages fixes rendus en mer', () {
      expect(zoneCityName('UTC', 'fr'), 'UTC');
      expect(zoneCityName('Etc/UTC', 'en'), 'UTC');
      expect(zoneCityName('Etc/GMT', 'fr'), 'UTC');
      // POSIX inverse le signe : Etc/GMT-9 a neuf heures d'avance sur UTC.
      expect(zoneCityName('Etc/GMT-9', 'fr'), 'UTC+9');
      expect(zoneCityName('Etc/GMT+5', 'en'), 'UTC-5');
    });
  });

  group('zoneCityOf', () {
    test('construit le complément français : de, élision, contraction', () {
      expect(zoneCityOf('Asia/Tokyo', 'fr'), 'de Tokyo');
      expect(zoneCityOf('Europe/Athens', 'fr'), "d'Athènes");
      expect(zoneCityOf('Africa/Algiers', 'fr'), "d'Alger");
      expect(zoneCityOf('Europe/Istanbul', 'fr'), "d'Istanbul");
      expect(zoneCityOf('Europe/Helsinki', 'fr'), "d'Helsinki");
      expect(zoneCityOf('Asia/Hong_Kong', 'fr'), 'de Hong Kong');
      expect(zoneCityOf('Africa/Cairo', 'fr'), 'du Caire');
      expect(zoneCityOf('Atlantic/Azores', 'fr'), 'des Açores');
      expect(zoneCityOf('Atlantic/Canary', 'fr_FR'), 'des Canaries');
      expect(zoneCityOf('Indian/Reunion', 'fr'), 'de La Réunion');
    });

    test('laisse UTC nu en français : « heure UTC+9 »', () {
      expect(zoneCityOf('UTC', 'fr'), 'UTC');
      expect(zoneCityOf('Etc/GMT-9', 'fr'), 'UTC+9');
    });

    test('est la ville nue en anglais', () {
      expect(zoneCityOf('Europe/Athens', 'en'), 'Athens');
      expect(zoneCityOf('Africa/Cairo', 'en'), 'Cairo');
      expect(zoneCityOf('Atlantic/Azores', 'en'), 'Azores');
    });

    test('se lit juste une fois interpolé dans les deux catalogues', () {
      String mention(String language, String zone) {
        final Map<String, dynamic> catalog = json.decode(
          File('assets/l10n/$language.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        final String text =
            (catalog['dates'] as Map<String, dynamic>)['zoneMention'] as String;
        return text
            .replaceAll('{city}', zoneCityName(zone, language))
            .replaceAll('{ofCity}', zoneCityOf(zone, language));
      }

      expect(mention('fr', 'Europe/Athens'), "heure d'Athènes");
      expect(mention('fr', 'Africa/Cairo'), 'heure du Caire');
      expect(mention('fr', 'Atlantic/Azores'), 'heure des Açores');
      expect(mention('en', 'Africa/Cairo'), 'Cairo time');
    });
  });
}
