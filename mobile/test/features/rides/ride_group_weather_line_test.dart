import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_group_card.dart';
import 'package:pedalons/features/rides/domain/ride_group_action.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_group_weather_line.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// La ligne météo, non cliquable, de la carte d'un groupe (ledger `MOB-67`) :
/// température et ciel au départ du groupe, pluie, Face et Dos — et rien sans
/// prévision de son leg.
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

  testWidgets('avec pluie : température, ciel, pluie, Face et Dos', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, fixtureLeg(rainAlert: rain));

    expect(find.byKey(keys.ride.groupWeatherLine('g1')), findsOneWidget);
    expect(inLine(find.text('14 °C')), findsOneWidget);
    expect(inLine(find.text('Partiellement nuageux')), findsOneWidget);
    // L'heure de l'alerte, dans le fuseau de la sortie.
    expect(inLine(find.textContaining('PLUIE 40')), findsOneWidget);
    expect(inLine(find.textContaining(' VERS ')), findsOneWidget);
    expect(inLine(find.textContaining('FACE 15')), findsOneWidget);
    expect(inLine(find.textContaining('DOS 15')), findsOneWidget);
    // Une ligne qui ne mène nulle part : aucun geste à elle.
    expect(inLine(find.byType(InkWell)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans pluie : pas de puce pluie', (WidgetTester tester) async {
    await pumpCard(tester, fixtureLeg());

    expect(find.byKey(keys.ride.groupWeatherLine('g1')), findsOneWidget);
    expect(inLine(find.textContaining('PLUIE')), findsNothing);
    expect(inLine(find.textContaining('FACE')), findsOneWidget);
  });

  testWidgets('sans vent de face ni de dos : ni Face ni Dos', (
    WidgetTester tester,
  ) async {
    await pumpCard(
      tester,
      fixtureLeg().copyWith(
        windExposure: const WindExposureDto(head: 0, cross: 30000, tail: 0),
      ),
    );

    expect(inLine(find.textContaining('FACE')), findsNothing);
    expect(inLine(find.textContaining('DOS')), findsNothing);
    expect(inLine(find.textContaining('TRAVERS')), findsNothing);
  });

  testWidgets('sans météo : rien', (WidgetTester tester) async {
    await pumpCard(tester, null);

    expect(find.byKey(keys.ride.groupWeatherLine('g1')), findsNothing);
    expect(find.byType(RideGroupWeatherLine), findsNothing);
  });

  for (final String status in <String>[
    'NOT_YET_AVAILABLE',
    'UNAVAILABLE',
    'NO_LOCATION',
  ]) {
    testWidgets('leg $status : rien', (WidgetTester tester) async {
      await pumpCard(tester, fixtureLeg(status: status));

      expect(find.byKey(keys.ride.groupWeatherLine('g1')), findsNothing);
    });
  }

  test('shows : un leg prévu, avec des conditions au départ', () {
    expect(RideGroupWeatherLine.shows(fixtureLeg()), isTrue);
    expect(RideGroupWeatherLine.shows(fixtureLeg(status: 'STALE')), isTrue);
    expect(RideGroupWeatherLine.shows(null), isFalse);
    expect(
      RideGroupWeatherLine.shows(
        fixtureLeg().copyWith(checkpoints: const <WeatherCheckpointDto>[]),
      ),
      isFalse,
    );
  });

  testWidgets('les couleurs ne disent rien seules : chaque puce a un libellé', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, fixtureLeg(rainAlert: rain));

    for (final PdlBadge badge in tester.widgetList<PdlBadge>(
      inLine(find.byType(PdlBadge)),
    )) {
      expect(badge.label, isNotEmpty);
    }
  });
}
