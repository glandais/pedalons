import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
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

/// `docs/LEDGER_*.md MOB-111` : « Ma prochaine sortie » donne la date **et**
/// l'heure qui concernent la personne, le groupe ne dit son écart que s'il en a
/// un ; `BRAND-8` : le seul relatif est la pastille « Aujourd'hui » /
/// « Demain » sur l'image.
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

/// Le premier texte sous [key] : pour la ligne de départ, « Départ 21:30 ».
String _textOf(WidgetTester tester, Key key) => tester
    .widget<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)).first,
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

  testWidgets('BRANDING §7.8 : boîte du jour posée sur l’image, « Départ '
      '21:30 » en 20/700, le jour dit au lecteur d’écran', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    // Fin par défaut de la fixture : trois heures plus tard, 00:30 le
    // lendemain à Paris.
    await _pump(tester, fixtureRide(dateTime: rideAt), null);

    final PdlDayBox box = tester.widget<PdlDayBox>(find.byType(PdlDayBox));
    expect(box.posed, isTrue);
    expect(box.day, '29');
    expect(
      find.descendant(
        of: find.byType(PdlCardMedia),
        matching: find.byType(PdlDayBox),
      ),
      findsOneWidget,
    );
    final Text headline = tester.widget<Text>(find.text('Départ 21:30'));
    expect(headline.style?.fontSize, 20);
    expect(headline.style?.fontWeight, FontWeight.w700);
    expect(find.textContaining('retour vers'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'^Départ 21:30, mar\. 29 juil\.')),
      findsOneWidget,
    );
    semantics.dispose();
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
      expect(_textOf(tester, keys.home.nextRideGroup), 'Chill Route Long');
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

  testWidgets('BRAND-8 : plus de « dans 2 jours », ni pastille au-delà de '
      'demain', (WidgetTester tester) async {
    // Dans deux à trois jours civils, quelle que soit l'heure du test : ni
    // aujourd'hui ni demain.
    final DateTime soon = DateTime.now().toUtc().add(
      const Duration(days: 2, hours: 1),
    );
    await _pump(tester, fixtureRide(dateTime: soon.toIso8601String()), null);

    expect(find.textContaining('DANS'), findsNothing);
    expect(find.textContaining('dans 2'), findsNothing);
    expect(find.byType(PdlDayPill), findsNothing);
    expect(find.byKey(keys.home.nextRideDayPill), findsNothing);
  });

  testWidgets('bientôt : la pastille « Aujourd’hui » / « Demain » posée sur '
      'l’image, et aucun badge relatif dans l’en-tête', (
    WidgetTester tester,
  ) async {
    final DateTime soon = DateTime.now().toUtc().add(
      const Duration(minutes: 5),
    );
    final RideDto ride = fixtureRide(dateTime: soon.toIso8601String());
    await _pump(tester, ride, null);

    // « Aujourd'hui », sauf si le test passe à minuit dans le fuseau de la
    // sortie : « Demain ».
    final String expected = AppFormatters.formatDepartureRelative(
      soon,
      ride.timezone,
    )!;
    final Finder pill = find.byKey(keys.home.nextRideDayPill);
    expect(pill, findsOneWidget);
    expect(tester.widget<PdlDayPill>(pill).label, expected);
    expect(
      find.descendant(of: find.byType(PdlCardMedia), matching: pill),
      findsOneWidget,
    );
    // L'ancien badge relatif, neutre et à l'horloge, a disparu.
    expect(
      tester
          .widgetList<PdlBadge>(find.byType(PdlBadge))
          .where((PdlBadge b) => b.icon == PdlIcons.time),
      isEmpty,
    );
  });

  testWidgets('au-delà d’une semaine, pas de pastille', (
    WidgetTester tester,
  ) async {
    await _pump(tester, fixtureRide(dateTime: rideAt), null);

    expect(find.byKey(keys.home.nextRideDayPill), findsNothing);
  });
}
