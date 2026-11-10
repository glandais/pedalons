import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_weather_summary_line.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_weather_widgets.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

/// La ligne météo des cartes de sortie : plage min → max, vent, pluie, et
/// rien quand il n'y a rien à dire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  Future<void> pump(
    WidgetTester tester,
    RideWeatherSummaryDto? summary, {
    bool finished = false,
    UnitSystem units = UnitSystem.metric,
    String? timezone,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [unitSystemProvider.overrideWithValue(units)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: RideWeatherSummaryLine(
              summary: summary,
              timezone: timezone,
              finished: finished,
            ),
          ),
        ),
      ),
    );
  }

  const RideWeatherSummaryDto ok = RideWeatherSummaryDto(
    status: 'OK',
    condition: 'CLEAR',
    daylight: true,
    temperature: 13,
    temperatureMin: 11.6,
    temperatureMax: 18.2,
    maxPrecipitationProbability: 20,
    wind: WindDto(speed: 18, direction: 315, compass: 'NW'),
  );

  testWidgets('la plage, le vent et la pluie', (WidgetTester tester) async {
    await pump(tester, ok);

    expect(find.byKey(keys.ride.weatherSummary), findsOneWidget);
    expect(find.text('12–18 °C'), findsOneWidget);
    // La flèche porte la direction : ni « Vent » ni point cardinal (KIT §8).
    expect(find.byType(PdlWindArrow), findsOneWidget);
    expect(find.text(AppFormatters.formatSpeed(18)), findsOneWidget);
    expect(find.textContaining('Vent'), findsNothing);
    expect(find.text('Pluie 20 %'), findsOneWidget);
    // Ni ciel en toutes lettres ni alerte.
    expect(find.text('Ciel dégagé'), findsNothing);
    expect(find.byKey(keys.ride.weatherSummaryRainAlert), findsNothing);
  });

  testWidgets('14 px gris : le corps atténué', (WidgetTester tester) async {
    await pump(tester, ok);

    final Text range = tester.widget<Text>(find.text('12–18 °C'));
    final Text rain = tester.widget<Text>(find.text('Pluie 20 %'));
    expect(range.style?.fontSize, 14);
    expect(rain.style?.fontSize, 14);
    expect(rain.style?.color, range.style?.color);
  });

  testWidgets('l\'alerte pluie l\'emporte sur la probabilité maximale', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      ok.copyWith(
        rainAlert: const WeatherRainAlertDto(
          probability: 60,
          time: '2099-07-29T10:00:00Z',
          condition: 'RAIN',
        ),
      ),
    );

    expect(find.textContaining('Pluie 60 % vers'), findsOneWidget);
    expect(find.byKey(keys.ride.weatherSummaryRainAlert), findsOneWidget);
    expect(find.text('Pluie 20 %'), findsNothing);
  });

  testWidgets('l\'heure de l\'alerte se lit dans le fuseau de la sortie, '
      'sans mention', (WidgetTester tester) async {
    // Un lecteur à Paris, une sortie à Tokyo : 10:00Z = 19:00 à Tokyo, 12:00
    // chez lui. Le passage est un rendez-vous (docs/LEDGER_*.md API-60).
    AppFormatters.setDisplayTimezone('Europe/Paris');
    addTearDown(() => AppFormatters.setDisplayTimezone(null));
    await pump(
      tester,
      ok.copyWith(
        rainAlert: const WeatherRainAlertDto(
          probability: 60,
          time: '2099-07-29T10:00:00Z',
          condition: 'RAIN',
        ),
      ),
      timezone: 'Asia/Tokyo',
    );

    expect(find.textContaining('vers 19:00'), findsOneWidget);
    expect(find.textContaining('12:00'), findsNothing);
    expect(find.textContaining('Tokyo'), findsNothing);
  });

  testWidgets('le fuseau du résumé l\'emporte sur celui de la carte', (
    WidgetTester tester,
  ) async {
    // La carte d'un voyage dont la première étape est à Paris et la prochaine
    // à Tokyo : la ligne est celle de la prochaine, son heure se lit à Tokyo
    // (docs/LEDGER_*.md API-60).
    AppFormatters.setDisplayTimezone('Europe/Paris');
    addTearDown(() => AppFormatters.setDisplayTimezone(null));
    await pump(
      tester,
      ok.copyWith(
        timezone: 'Asia/Tokyo',
        rainAlert: const WeatherRainAlertDto(
          probability: 60,
          time: '2099-07-29T10:00:00Z',
          condition: 'RAIN',
        ),
      ),
      timezone: 'Europe/Paris',
    );

    expect(find.textContaining('vers 19:00'), findsOneWidget);
    expect(find.textContaining('12:00'), findsNothing);
  });

  testWidgets('STALE se signale, OK non', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pump(tester, ok);
    expect(find.byKey(keys.ride.weatherSummaryStale), findsNothing);

    await pump(tester, ok.copyWith(status: 'STALE'));
    expect(find.byKey(keys.ride.weatherSummary), findsOneWidget);
    expect(find.text('12–18 °C'), findsOneWidget);
    expect(find.byKey(keys.ride.weatherSummaryStale), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Prévision ancienne')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('NOT_YET_AVAILABLE donne la date', (WidgetTester tester) async {
    await pump(
      tester,
      const RideWeatherSummaryDto(
        status: 'NOT_YET_AVAILABLE',
        availableFrom: '2099-07-22T12:00:00Z',
      ),
    );

    expect(find.textContaining('Météo dès le 22 juillet'), findsOneWidget);
  });

  testWidgets('en impérial', (WidgetTester tester) async {
    await pump(tester, ok, units: UnitSystem.imperial);

    expect(find.text('53–65 °F'), findsOneWidget);
    expect(find.textContaining('mph'), findsOneWidget);
  });

  testWidgets('rien pour un statut inconnu, une absence ou une sortie finie', (
    WidgetTester tester,
  ) async {
    await pump(tester, ok.copyWith(status: 'SOMETHING'));
    expect(find.byKey(keys.ride.weatherSummary), findsNothing);

    await pump(tester, null);
    expect(find.byKey(keys.ride.weatherSummary), findsNothing);

    await pump(tester, ok, finished: true);
    expect(find.byKey(keys.ride.weatherSummary), findsNothing);
  });

  // RULES.md : utilisable à des tailles de police accrues. Dans une `Wrap`
  // étroite, chaque morceau doit passer à la ligne plutôt que déborder.
  group('police ×2 sur une carte étroite', () {
    Future<void> pumpNarrow(WidgetTester tester, Widget child) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              unitSystemProvider.overrideWithValue(UnitSystem.metric),
            ],
            child: MaterialApp(
              theme: PedalonsTheme.build(Brightness.light),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: Center(child: SizedBox(width: 120, child: child)),
                ),
              ),
            ),
          ),
        );

    testWidgets('le vent de la ligne de résumé ne déborde pas', (
      WidgetTester tester,
    ) async {
      await pumpNarrow(
        tester,
        const RideWeatherSummaryLine(summary: ok, timezone: null),
      );

      expect(find.text(AppFormatters.formatSpeed(18)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la légende d\'exposition ne déborde pas', (
      WidgetTester tester,
    ) async {
      await pumpNarrow(
        tester,
        const WeatherExposureLegend(
          exposure: WindExposureDto(head: 15000, cross: 22000, tail: 31000),
          units: UnitSystem.metric,
        ),
      );

      expect(find.textContaining('Travers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
