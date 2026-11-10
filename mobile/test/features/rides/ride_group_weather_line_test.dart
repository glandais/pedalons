import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_group_card.dart';
import 'package:pedalons/features/rides/domain/ride_group_action.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_group_weather_line.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// La ligne météo, non cliquable, de la carte d'un groupe (ledgers `MOB-67`,
/// `MOB-132`) : la ligne des cartes, lue sur le résumé du leg — plage, vent
/// fléché, pluie ou alerte — et rien sans résumé à montrer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  const WeatherRainAlertDto rain = WeatherRainAlertDto(
    probability: 40,
    time: '2099-07-29T20:05:00Z',
    condition: 'RAIN',
    distance: 15000,
  );

  Future<void> pumpCard(WidgetTester tester, WeatherLegDto? leg) async {
    final RideGroupDto g = fixtureGroup();
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RideGroupCard(
              group: g,
              rideDateTime: '2026-10-11T06:00:00Z',
              timezone: 'Europe/Paris',
              showDeparture: false,
              action: RideGroupAction.join,
              trackColor: multiTrackColor(g.sortOrder),
              units: UnitSystem.metric,
              weatherLeg: leg,
              onTap: () {},
              onJoin: () {},
            ),
          ),
        ),
      ),
    );
  }

  Finder inLine(Finder matching) => find.descendant(
    of: find.byKey(keys.ride.groupWeatherLine('g1')),
    matching: matching,
  );

  testWidgets('la ligne des cartes : plage, vent fléché, pluie', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, fixtureLeg(summary: fixtureLegSummary()));

    expect(find.byKey(keys.ride.groupWeatherLine('g1')), findsOneWidget);
    expect(inLine(find.text('10–13 °C')), findsOneWidget);
    // La flèche porte la direction ; le texte ne dit que la vitesse.
    expect(inLine(find.byType(PdlWindArrow)), findsOneWidget);
    expect(inLine(find.text(AppFormatters.formatSpeed(18))), findsOneWidget);
    expect(inLine(find.textContaining('NO')), findsNothing);
    expect(inLine(find.text('Pluie 20 %')), findsOneWidget);
    // Ni ciel en toutes lettres, ni badges Face / Dos (KIT §8).
    expect(inLine(find.text('Partiellement nuageux')), findsNothing);
    expect(inLine(find.byType(PdlBadge)), findsNothing);
    // Une ligne qui ne mène nulle part : aucun geste à elle.
    expect(inLine(find.byType(InkWell)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avec alerte : « Pluie 40 % vers … » à la place de la pluie', (
    WidgetTester tester,
  ) async {
    await pumpCard(
      tester,
      fixtureLeg(
        rainAlert: rain,
        summary: fixtureLegSummary(rainAlert: rain),
      ),
    );

    // L'heure de l'alerte se lit dans le fuseau de la sortie (testé par
    // `ride_weather_summary_line_test`).
    expect(
      inLine(find.byKey(keys.ride.weatherSummaryRainAlert)),
      findsOneWidget,
    );
    expect(inLine(find.textContaining('Pluie 40 % vers ')), findsOneWidget);
    expect(inLine(find.text('Pluie 20 %')), findsNothing);
  });

  testWidgets('un leg sans résumé : rien', (WidgetTester tester) async {
    await pumpCard(tester, fixtureLeg());

    expect(find.byKey(keys.ride.groupWeatherLine('g1')), findsNothing);
  });

  testWidgets('sans météo : rien', (WidgetTester tester) async {
    await pumpCard(tester, null);

    expect(find.byKey(keys.ride.groupWeatherLine('g1')), findsNothing);
    expect(find.byType(RideGroupWeatherLine), findsNothing);
  });

  for (final String status in <String>['UNAVAILABLE', 'NO_LOCATION']) {
    testWidgets('résumé $status : rien', (WidgetTester tester) async {
      await pumpCard(
        tester,
        fixtureLeg(
          status: status,
          summary: fixtureLegSummary(status: status),
        ),
      );

      expect(find.byKey(keys.ride.groupWeatherLine('g1')), findsNothing);
    });
  }

  test('shows : un leg dont le résumé a quelque chose à montrer', () {
    expect(
      RideGroupWeatherLine.shows(fixtureLeg(summary: fixtureLegSummary())),
      isTrue,
    );
    expect(
      RideGroupWeatherLine.shows(
        fixtureLeg(summary: fixtureLegSummary(status: 'STALE')),
      ),
      isTrue,
    );
    expect(RideGroupWeatherLine.shows(null), isFalse);
    expect(RideGroupWeatherLine.shows(fixtureLeg()), isFalse);
    expect(
      RideGroupWeatherLine.shows(
        fixtureLeg(summary: fixtureLegSummary(status: 'UNAVAILABLE')),
      ),
      isFalse,
    );
  });
}
