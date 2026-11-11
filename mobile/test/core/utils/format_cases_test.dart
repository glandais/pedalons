import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
// `Localization` et `Translations` portent `tr()` hors de tout widget — même
// montage que `formatters_test.dart`.
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/teams/domain/publication_timing.dart';

/// Le jeu de cas partagé avec le site (`contracts/format-cases.json`, voir
/// `contracts/format-cases.md`) : la même valeur, dans la même langue et les
/// mêmes unités, doit donner le même texte dans l'app et sur le site
/// (docs/LEDGER_*.md MOB-139, WEB-167). Le site lit le même fichier dans
/// `frontend/src/utils/formatCases.test.ts`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<dynamic> cases = jsonDecode(
    File('../contracts/format-cases.json').readAsStringSync(),
  ) as List<dynamic>;
  late Map<String, Map<String, dynamic>> translations;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    translations = <String, Map<String, dynamic>>{
      for (final String locale in <String>['fr', 'en'])
        locale: jsonDecode(
          File('assets/l10n/$locale.json').readAsStringSync(),
        ) as Map<String, dynamic>,
    };
  });

  tearDown(() => AppFormatters.setDisplayTimezone(null));

  String render(Map<String, dynamic> c) {
    final UnitSystem units = c['units'] == 'imperial'
        ? UnitSystem.imperial
        : UnitSystem.metric;
    final DateTime? now = c['now'] == null
        ? null
        : DateTime.parse(c['now'] as String);
    final dynamic input = c['input'];
    Map<String, dynamic> map() => input as Map<String, dynamic>;
    return switch (c['kind']) {
      'distance' => AppFormatters.formatDistance(input as num, units),
      'elevation' => AppFormatters.formatElevation(input as num, units),
      'speed' => AppFormatters.formatSpeed(input as num, units),
      'percent' => AppFormatters.formatPercent(input as num),
      'grade' => AppFormatters.formatGrade(input as num),
      'price' => AppFormatters.formatPrice(
        map()['price'] as num?,
        rentalPeriod: map()['rentalPeriod'] as String?,
      ).flat,
      'shortDateTime' => AppFormatters.formatTimestamp(
        DateTime.parse(map()['date'] as String),
        zone: map()['zone'] as String,
        now: now,
      ),
      'tripSpan' => tripDaySpan(
        map()['start'] as String,
        map()['end'] as String,
        timezone: map()['zone'] as String,
        now: now,
      )!,
      'relative' => () {
        AppFormatters.setDisplayTimezone(map()['zone'] as String);
        return AppFormatters.formatRelative(
          DateTime.parse(map()['date'] as String),
          now: now,
        );
      }(),
      'memberSince' => () {
        AppFormatters.setDisplayTimezone(map()['zone'] as String);
        return 'teams.membersList.since'.tr(
          namedArgs: <String, String>{
            'date': AppFormatters.formatMonthAndYear(
              DateTime.parse(map()['date'] as String),
            ),
          },
        );
      }(),
      final Object? kind => throw UnsupportedError('Unknown kind $kind'),
    };
  }

  for (final dynamic raw in cases) {
    final Map<String, dynamic> c = raw as Map<String, dynamic>;
    final String locale = c['locale'] as String;
    test('${c['kind']} ${jsonEncode(c['input'])} [$locale, ${c['units']}]', () {
      Localization.load(
        Locale(locale),
        translations: Translations(translations[locale]!),
        fallbackTranslations: Translations(translations[locale]!),
      );
      final String actual = Intl.withLocale(locale, () => render(c)) as String;
      // Comparé point de code par point de code : une espace ordinaire à la
      // place d'une insécable doit échouer, et le dire.
      expect(
        actual.runes.toList(),
        (c['expected'] as String).runes.toList(),
        reason: '« $actual » ≠ « ${c['expected']} »',
      );
    });
  }
}
