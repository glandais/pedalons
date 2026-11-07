import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/core/widgets/zone_mention_line.dart';
import 'package:pedalons/features/home/presentation/widgets/next_ride_card.dart';
import 'package:pedalons/features/home/providers/next_ride_provider.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import '../rides/ride_fixtures.dart';

/// `docs/LEDGER_*.md MOB-110` : « Ma prochaine sortie » donne la date **et**
/// l'heure qui concernent la personne, le groupe ne dit son écart que s'il en a
/// un, et le badge relatif ne se confond plus avec « Inscrit ».
Future<void> _pump(
  WidgetTester tester,
  RideDto ride,
  RideGroupDto? group,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [unitSystemProvider.overrideWithValue(UnitSystem.metric)],
      child: MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: NextRideCard(
              next: NextRide(ride: ride, group: group),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

String _textOf(WidgetTester tester, Key key) => tester
    .widget<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .data!;

void main() {
  setUpAll(loadTestTranslations);
  setUp(() => AppFormatters.setDisplayTimezone('Europe/Paris'));
  tearDown(() => AppFormatters.setDisplayTimezone(null));

  // 19:30Z le 29 juillet 2036 (la base des fuseaux s'arrête en 2037) : 21:30 à Paris.
  const String rideAt = '2036-07-29T19:30:00Z';

  testWidgets('sans groupe, la date porte l’heure de la sortie', (
    WidgetTester tester,
  ) async {
    await _pump(tester, fixtureRide(dateTime: rideAt), null);

    expect(_textOf(tester, keys.home.nextRideStart), contains('21:30'));
    expect(find.byKey(keys.home.nextRideGroup), findsNothing);
  });

  testWidgets(
    'un groupe qui part avec la sortie : son nom seul, sans horloge',
    (WidgetTester tester) async {
      await _pump(
        tester,
        fixtureRide(dateTime: rideAt),
        fixtureGroup(startAt: rideAt),
      );

      expect(_textOf(tester, keys.home.nextRideStart), contains('21:30'));
      expect(_textOf(tester, keys.home.nextRideGroup), 'Chill Route Long');
      expect(
        find.descendant(
          of: find.byKey(keys.home.nextRideGroup),
          matching: find.byIcon(PdlIcons.time),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'un groupe à l’heure propre : son heure en date, l’écart en groupe',
    (WidgetTester tester) async {
      await _pump(
        tester,
        fixtureRide(dateTime: rideAt),
        fixtureGroup(startAt: '2036-07-29T20:30:00Z'),
      );

      final String date = _textOf(tester, keys.home.nextRideStart);
      expect(date, contains('22:30'));
      expect(date, isNot(contains('21:30')));
      expect(
        _textOf(tester, keys.home.nextRideGroup),
        'Chill Route Long, départ après la sortie de 21:30',
      );
    },
  );

  testWidgets('lu d’ailleurs, la mention commente l’heure du groupe', (
    WidgetTester tester,
  ) async {
    AppFormatters.setDisplayTimezone('America/New_York');
    await _pump(
      tester,
      fixtureRide(dateTime: rideAt),
      fixtureGroup(startAt: '2036-07-29T20:30:00Z'),
    );

    final Finder mention = find.descendant(
      of: find.byType(ZoneMentionLine),
      matching: find.byType(Text),
    );
    expect(mention, findsOneWidget);
    // 20:30Z en juillet : 16:30 à New York, pas les 15:30 de la sortie.
    expect(tester.widget<Text>(mention).data, contains('16:30'));
  });

  testWidgets('le badge relatif est neutre, sans la coche « inscrit »', (
    WidgetTester tester,
  ) async {
    final String soon = DateTime.now()
        .toUtc()
        .add(const Duration(days: 2, hours: 1))
        .toIso8601String();
    await _pump(tester, fixtureRide(dateTime: soon), null);

    final Finder badge = find.byKey(keys.home.nextRideRelativeBadge);
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('DANS 2 JOURS')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: badge, matching: find.byIcon(PdlIcons.check)),
      findsNothing,
    );
    expect(
      find.descendant(of: badge, matching: find.byIcon(PdlIcons.time)),
      findsOneWidget,
    );
  });

  testWidgets('au-delà d’une semaine, pas de badge qui répéterait la date', (
    WidgetTester tester,
  ) async {
    await _pump(tester, fixtureRide(dateTime: rideAt), null);

    expect(find.byKey(keys.home.nextRideRelativeBadge), findsNothing);
  });
}
