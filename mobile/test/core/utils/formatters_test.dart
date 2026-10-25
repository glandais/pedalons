import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
// `Localization` et `Translations` ne sont pas ré-exportés par la façade du
// paquet, mais ce sont eux qui portent `tr()` hors de tout widget : les
// charger directement est ce qui rend `AppFormatters` testable sans pomper un
// arbre de widgets pour trois chaînes.
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/routes/domain/route_filters.dart';
import 'package:pedalons/features/routes/domain/route_filter_labels.dart';

/// Les caractères que la typographie impose, nommés une fois pour que les
/// assertions portent sur le point de code et non sur ce que l'éditeur montre.
const int nbsp = 0x00A0;
const int narrowNbsp = 0x202F;

/// Exécute [body] avec la locale [locale] à la fois côté `intl` (séparateurs
/// décimaux) et côté `easy_localization` (libellés).
///
/// Les deux sont indépendants dans l'app ; un test qui n'en fixerait qu'un
/// passerait pour de mauvaises raisons.
T withLocale<T>(
  String locale,
  Map<String, dynamic> translations,
  T Function() body,
) {
  Localization.load(
    Locale(locale),
    translations: Translations(translations),
    fallbackTranslations: Translations(translations),
  );
  return Intl.withLocale(locale, body) as T;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> fr;
  late Map<String, dynamic> en;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    fr = jsonDecode(
      File('assets/l10n/fr.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    en = jsonDecode(
      File('assets/l10n/en.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  group('formatDistance', () {
    test('impérial en anglais : 46 300 m font 28.8 mi', () {
      expect(
        withLocale(
          'en',
          en,
          () => AppFormatters.formatDistance(46300, UnitSystem.imperial),
        ),
        '28.8${String.fromCharCode(nbsp)}mi',
      );
    });

    test('métrique en français : 46 300 m font 46,3 km, espace insécable', () {
      final String value = withLocale(
        'fr',
        fr,
        () => AppFormatters.formatDistance(46300, UnitSystem.metric),
      );
      expect(value, '46,3${String.fromCharCode(nbsp)}km');
      // L'espace avant l'unité est bien insécable, pas une espace ordinaire :
      // « 46,3 » et « km » ne doivent jamais se retrouver sur deux lignes.
      expect(value.runes.elementAt(4), nbsp);
    });

    test('la locale décide du séparateur décimal, pas le système d’unités', () {
      expect(
        withLocale(
          'fr',
          fr,
          () => AppFormatters.formatDistance(46300, UnitSystem.imperial),
        ),
        '28,8${String.fromCharCode(nbsp)}mi',
      );
      expect(
        withLocale(
          'en',
          en,
          () => AppFormatters.formatDistance(46300, UnitSystem.metric),
        ),
        '46.3${String.fromCharCode(nbsp)}km',
      );
    });

    test(r'$unknown se formate comme metric', () {
      expect(
        withLocale(
          'fr',
          fr,
          () => AppFormatters.formatDistance(46300, UnitSystem.$unknown),
        ),
        withLocale(
          'fr',
          fr,
          () => AppFormatters.formatDistance(46300, UnitSystem.metric),
        ),
      );
    });

    test('la borne de filtre est arrondie au kilomètre', () {
      expect(
        withLocale(
          'fr',
          fr,
          () => AppFormatters.formatDistanceRounded(46300, UnitSystem.metric),
        ),
        '46${String.fromCharCode(nbsp)}km',
      );
      expect(
        withLocale(
          'en',
          en,
          () => AppFormatters.formatDistanceRounded(46300, UnitSystem.imperial),
        ),
        '29${String.fromCharCode(nbsp)}mi',
      );
    });
  });

  group('formatElevation', () {
    test('9 840 m se séparent par une espace fine insécable', () {
      final String value = withLocale(
        'fr',
        fr,
        () => AppFormatters.formatElevation(9840),
      );
      expect(
        value,
        '9${String.fromCharCode(narrowNbsp)}840${String.fromCharCode(nbsp)}m',
      );
      // Le séparateur de milliers du français est U+202F, pas U+0020 ni
      // U+00A0 : on assert sur le point de code, l'œil ne les distingue pas.
      expect(value.runes.elementAt(1), narrowNbsp);
      expect(value.runes.elementAt(1), isNot(0x20));
      expect(value.runes.elementAt(1), isNot(nbsp));
      // Et l'espace avant l'unité, lui, reste une insécable pleine.
      expect(value.runes.elementAt(5), nbsp);
    });

    test('en anglais le séparateur est une virgule', () {
      expect(
        withLocale('en', en, () => AppFormatters.formatElevation(9840)),
        '9,840${String.fromCharCode(nbsp)}m',
      );
    });

    test('en impérial les mètres deviennent des pieds', () {
      expect(
        withLocale(
          'en',
          en,
          () => AppFormatters.formatElevation(1000, UnitSystem.imperial),
        ),
        '3,281${String.fromCharCode(nbsp)}ft',
      );
    });

    test('D+ et D− portent leur suffixe traduit', () {
      expect(
        withLocale('fr', fr, () => AppFormatters.formatElevationGain(1200)),
        '1${String.fromCharCode(narrowNbsp)}200${String.fromCharCode(nbsp)}m D+',
      );
      expect(
        withLocale('fr', fr, () => AppFormatters.formatElevationLoss(1200)),
        '1${String.fromCharCode(narrowNbsp)}200${String.fromCharCode(nbsp)}m D−',
      );
      expect(
        withLocale('en', en, () => AppFormatters.formatElevationGain(1200)),
        '1,200${String.fromCharCode(nbsp)}m elev. +',
      );
    });
  });

  group('formatSpeed', () {
    test('les km/h de l’API se rendent en km/h ou en mph', () {
      expect(
        withLocale(
          'fr',
          fr,
          () => AppFormatters.formatSpeed(25, UnitSystem.metric),
        ),
        '25${String.fromCharCode(nbsp)}km/h',
      );
      expect(
        withLocale(
          'en',
          en,
          () => AppFormatters.formatSpeed(25, UnitSystem.imperial),
        ),
        '16${String.fromCharCode(nbsp)}mph',
      );
    });
  });

  group('formatTemperature', () {
    String n(String s) => s.replaceAll(' ', String.fromCharCode(nbsp));

    test('au degré près, en °C ou en °F', () {
      expect(
        withLocale(
          'fr',
          fr,
          () => AppFormatters.formatTemperature(14.4, UnitSystem.metric),
        ),
        n('14 °C'),
      );
      expect(
        withLocale(
          'en',
          en,
          () => AppFormatters.formatTemperature(14.4, UnitSystem.imperial),
        ),
        n('58 °F'),
      );
    });

    test('pas de « -0 °C »', () {
      expect(
        withLocale('fr', fr, () => AppFormatters.formatTemperature(-0.3)),
        n('0 °C'),
      );
    });

    test('une plage, ou une seule valeur si les bornes se confondent', () {
      expect(
        withLocale(
          'fr',
          fr,
          () => AppFormatters.formatTemperatureRange(11.6, 18.2),
        ),
        n('12–18 °C'),
      );
      expect(
        withLocale(
          'fr',
          fr,
          () => AppFormatters.formatTemperatureRange(12.2, 11.8),
        ),
        n('12 °C'),
      );
    });

    test('précipitations et pourcentage', () {
      expect(
        withLocale('fr', fr, () => AppFormatters.formatPrecipitation(0.4)),
        n('0,4 mm'),
      );
      expect(
        withLocale('fr', fr, () => AppFormatters.formatPercent(60)),
        n('60 %'),
      );
    });
  });

  group('formatGrade', () {
    test('une pente ne se convertit pas : c’est un rapport', () {
      expect(
        withLocale('fr', fr, () => AppFormatters.formatGrade(6.5)),
        '6,5${String.fromCharCode(nbsp)}%',
      );
      expect(
        withLocale('en', en, () => AppFormatters.formatGrade(6.5)),
        '6.5${String.fromCharCode(nbsp)}%',
      );
    });
  });

  group('formatFileSize', () {
    String fr_(int bytes) =>
        withLocale('fr', fr, () => AppFormatters.formatFileSize(bytes));
    String en_(int bytes) =>
        withLocale('en', en, () => AppFormatters.formatFileSize(bytes));
    final String sp = String.fromCharCode(nbsp);

    test('symboles français, espace insécable', () {
      expect(fr_(512), '512${sp}o');
      expect(fr_(240000), '240${sp}ko');
      expect(fr_(2400000), '2,4${sp}Mo');
    });

    test('symboles anglais', () {
      expect(en_(240000), '240${sp}kB');
      expect(en_(2400000), '2.4${sp}MB');
    });

    test('jamais « 1 000 ko » ni « 1,0 Mo »', () {
      expect(fr_(999700), '1${sp}Mo');
      expect(fr_(15300000), '15${sp}Mo');
    });
  });

  group('prix', () {
    test('le montant est en euros français quelle que soit la locale', () {
      const String expected = '1 200,00 €';
      expect(
        withLocale('fr', fr, () => AppFormatters.formatAmount(1200)),
        expected,
      );
      expect(
        withLocale('en', en, () => AppFormatters.formatAmount(1200)),
        expected,
      );
    });

    test('la période est un morceau distinct, jamais collé au montant', () {
      final FormattedPrice price = withLocale(
        'fr',
        fr,
        () => AppFormatters.formatPrice(25, rentalPeriod: 'WEEK'),
      );
      expect(price.amount, '25,00 €');
      expect(price.period, '/ semaine');
      expect(price.isNegotiable, isFalse);
      expect(price.flat, '25,00 € / semaine');
    });

    test('sans période, il n’y a pas de période', () {
      final FormattedPrice price = withLocale(
        'fr',
        fr,
        () => AppFormatters.formatPrice(1200),
      );
      expect(price.period, isNull);
      expect(price.flat, '1 200,00 €');
    });

    test('un prix absent se dit « Prix à négocier », jamais un tiret', () {
      final FormattedPrice frPrice = withLocale(
        'fr',
        fr,
        () => AppFormatters.formatPrice(null),
      );
      expect(frPrice.amount, 'Prix à négocier');
      expect(frPrice.isNegotiable, isTrue);
      expect(frPrice.amount, isNot(contains('—')));
      expect(frPrice.amount, isNot(contains('-')));

      final FormattedPrice enPrice = withLocale(
        'en',
        en,
        () => AppFormatters.formatPrice(null),
      );
      expect(enPrice.amount, 'Price negotiable');
      expect(enPrice.isNegotiable, isTrue);
    });
  });

  group('RelativeTime', () {
    final DateTime now = DateTime(2026, 7, 26, 12);

    test('découpe l’écart sans traduire', () {
      expect(
        RelativeTime.between(
          now.subtract(const Duration(seconds: 20)),
          now,
        ).unit,
        RelativeUnit.now,
      );
      expect(
        RelativeTime.between(now.subtract(const Duration(minutes: 5)), now),
        const RelativeTime(unit: RelativeUnit.minutes, count: 5, isPast: true),
      );
      expect(
        RelativeTime.between(now.subtract(const Duration(hours: 3)), now),
        const RelativeTime(unit: RelativeUnit.hours, count: 3, isPast: true),
      );
      expect(
        RelativeTime.between(now.subtract(const Duration(days: 3)), now),
        const RelativeTime(unit: RelativeUnit.days, count: 3, isPast: true),
      );
      expect(
        RelativeTime.between(now.add(const Duration(days: 2)), now),
        const RelativeTime(unit: RelativeUnit.days, count: 2, isPast: false),
      );
      expect(
        RelativeTime.between(now.subtract(const Duration(days: 40)), now).unit,
        RelativeUnit.absolute,
      );
    });
  });

  group('formatRelative', () {
    final DateTime now = DateTime(2026, 7, 26, 12);

    test('français', () {
      expect(
        withLocale(
          'fr',
          fr,
          () => AppFormatters.formatRelative(
            now.subtract(const Duration(days: 3)),
            now: now,
          ),
        ),
        'il y a 3 jours',
      );
      expect(
        withLocale(
          'fr',
          fr,
          () => AppFormatters.formatRelative(
            now.subtract(const Duration(days: 1)),
            now: now,
          ),
        ),
        'il y a 1 jour',
      );
      expect(
        withLocale(
          'fr',
          fr,
          () => AppFormatters.formatRelative(
            now.add(const Duration(hours: 2)),
            now: now,
          ),
        ),
        'dans 2 heures',
      );
      expect(
        withLocale('fr', fr, () => AppFormatters.formatRelative(now, now: now)),
        'à l\'instant',
      );
    });

    test('anglais', () {
      expect(
        withLocale(
          'en',
          en,
          () => AppFormatters.formatRelative(
            now.subtract(const Duration(days: 3)),
            now: now,
          ),
        ),
        '3 days ago',
      );
      expect(
        withLocale('en', en, () => AppFormatters.formatRelative(now, now: now)),
        'just now',
      );
    });

    test('au-delà du seuil, la date longue reprend la main', () {
      final DateTime old = DateTime(2026, 1, 15, 8, 30);
      expect(
        withLocale('fr', fr, () => AppFormatters.formatRelative(old, now: now)),
        'jeudi 15 janvier 2026',
      );
    });
  });

  group('dates', () {
    test('les formats longs suivent la locale', () {
      final DateTime date = DateTime(2026, 1, 15, 8, 30);
      expect(
        withLocale('fr', fr, () => AppFormatters.formatFullDate(date)),
        'jeudi 15 janvier',
      );
      expect(
        withLocale('fr', fr, () => AppFormatters.formatLongDateTime(date)),
        'jeudi 15 janvier 2026 à 08:30',
      );
      expect(
        withLocale('en', en, () => AppFormatters.formatLongDateTime(date)),
        'Thursday 15 january 2026 at 08:30',
      );
    });

    test('un instant UTC est ramené au fuseau de l’appareil', () {
      final DateTime utc = DateTime.utc(2026, 1, 15, 8, 30);
      expect(
        withLocale('fr', fr, () => AppFormatters.formatTime(utc)),
        withLocale('fr', fr, () => AppFormatters.formatTime(utc.toLocal())),
      );
    });
  });

  group('filtres de parcours', () {
    const RouteFilters filters = RouteFilters(
      minDistance: 30000,
      maxDistance: 60000,
      minElevationGain: 500,
    );

    test('les bornes suivent le système d’unités', () {
      expect(
        withLocale(
          'fr',
          fr,
          () => RouteFilterLabels.filterChip(
            filters,
            RouteFilterField.distance,
            UnitSystem.metric,
          ),
        ),
        '30 km – 60 km',
      );
      expect(
        withLocale(
          'en',
          en,
          () => RouteFilterLabels.filterChip(
            filters,
            RouteFilterField.distance,
            UnitSystem.imperial,
          ),
        ),
        '19 mi – 37 mi',
      );
    });

    test('une borne unique se rend avec son comparateur et son suffixe', () {
      expect(
        withLocale(
          'fr',
          fr,
          () => RouteFilterLabels.filterChip(
            filters,
            RouteFilterField.elevationGain,
            UnitSystem.metric,
          ),
        ),
        '> 500 m D+',
      );
    });

    test('un champ non contraint n’a pas de puce', () {
      expect(
        withLocale(
          'fr',
          fr,
          () => RouteFilterLabels.filterChip(
            filters,
            RouteFilterField.hilliness,
            UnitSystem.metric,
          ),
        ),
        isNull,
      );
    });

    test('une plage vide se dit « Tous »', () {
      expect(
        withLocale(
          'fr',
          fr,
          () => RouteFilterLabels.filterRange(
            null,
            null,
            (double m) => AppFormatters.formatDistanceRounded(m),
          ),
        ),
        'Tous',
      );
    });
  });
}
