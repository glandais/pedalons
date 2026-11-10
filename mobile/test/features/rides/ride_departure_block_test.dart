import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/core/widgets/zone_mention_line.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_departure_block.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// Le bloc de départ (docs/LEDGER_*.md MOB-113, BRANDING §7.8) : l'heure en
/// 22/700, la pastille seulement pour aujourd'hui et demain, l'année hors de
/// l'année en cours, la ligne du groupe à heure propre et la mention de fuseau
/// sur l'heure affichée.
///
/// Dates en 2036 : la base des fuseaux s'arrête en 2037.
void main() {
  // Le vendredi 11 avril 2036, 12:00 à Paris.
  final DateTime now = DateTime.utc(2036, 4, 11, 10);
  // Le samedi 12 avril 2036, 09:00 à Paris ; retour par défaut à 12:00.
  const String tomorrow = '2036-04-12T07:00:00Z';

  setUpAll(loadTestTranslations);
  setUp(() => AppFormatters.setDisplayTimezone('Europe/Paris'));
  tearDown(() => AppFormatters.setDisplayTimezone(null));

  Future<void> pump(
    WidgetTester tester,
    RideDto ride, {
    RideGroupDto? group,
    String? arrival,
    DateTime? at,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(brightness),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: RideDepartureBlock(
              ride: ride,
              group: group,
              arrival: arrival,
              now: at ?? now,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('demain : l’heure en 22/700, la pastille, le jour', (
    WidgetTester tester,
  ) async {
    await pump(tester, fixtureRide(dateTime: tomorrow));

    final Text headline = tester.widget<Text>(find.text('Départ 09:00'));
    expect(headline.style?.fontSize, 22);
    expect(headline.style?.fontWeight, FontWeight.w700);
    expect(find.text('DEMAIN'), findsOneWidget);
    // La date n'est dite qu'une fois : par la boîte du jour.
    expect(find.text('sam. 12 avr.'), findsNothing);
    // La boîte du jour : « sam. / 12 / avr. ».
    expect(
      find.descendant(of: find.byType(PdlDayBox), matching: find.text('12')),
      findsOneWidget,
    );
    expect(find.byType(ZoneMentionLine), findsNothing);
  });

  testWidgets('aujourd’hui : la pastille « Aujourd’hui »', (
    WidgetTester tester,
  ) async {
    await pump(tester, fixtureRide(dateTime: '2036-04-11T16:00:00Z'));

    expect(find.text('Départ 18:00'), findsOneWidget);
    expect(find.text("AUJOURD'HUI"), findsOneWidget);
  });

  testWidgets('plus loin : aucune pastille', (WidgetTester tester) async {
    await pump(tester, fixtureRide(dateTime: '2036-04-19T07:00:00Z'));

    expect(find.text('DEMAIN'), findsNothing);
    expect(find.text("AUJOURD'HUI"), findsNothing);
    expect(find.text('sam. 19 avr.'), findsNothing);
  });

  testWidgets('une autre année : l’année dans la boîte du jour', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      fixtureRide(dateTime: tomorrow),
      at: DateTime.utc(2035, 12, 20, 10),
    );

    expect(
      find.descendant(of: find.byType(PdlDayBox), matching: find.text('2036')),
      findsOneWidget,
    );
    expect(find.text('sam. 12 avr. 2036'), findsNothing);
    expect(find.text('DEMAIN'), findsNothing);
  });

  Future<void> pumpFirst(WidgetTester tester, RideDto ride, RideGroupDto g) =>
      tester.pumpWidget(
        MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RideDepartureBlock(
                ride: ride,
                group: g,
                firstDeparture: true,
                now: now,
              ),
            ),
          ),
        ),
      );

  testWidgets(
    'plusieurs groupes, inscrite dans un groupe à heure propre : '
    'son heure en gros, puis « Groupe B · premier départ » (MOB-134, lot 8)',
    (WidgetTester tester) async {
      final RideGroupDto b = fixtureGroup(
        id: 'b',
        name: 'B',
        registered: true,
        startAt: '2036-04-12T07:30:00Z',
      );
      await pumpFirst(
        tester,
        fixtureRide(
          dateTime: tomorrow,
          groups: <RideGroupDto>[b],
          registered: true,
          registeredGroupId: 'b',
        ),
        b,
      );

      expect(find.text('Départ 09:30'), findsOneWidget);
      expect(find.text('Départ 09:00'), findsNothing);
      final Finder line = find.text(
        'Groupe B · premier départ 09:00',
        findRichText: true,
      );
      expect(line, findsOneWidget);
      // Le nom du groupe en 600, la suite atténuée.
      final TextSpan root =
          tester
                  .widget<Text>(find.byType(Text).at(_richIndex(tester)))
                  .textSpan!
              as TextSpan;
      final List<TextSpan> spans = root.children!.cast<TextSpan>();
      expect(spans.first.text, 'Groupe B');
      expect(spans.first.style?.fontWeight, FontWeight.w600);
      expect(spans.last.text, ' · premier départ 09:00');
      expect(spans.last.style?.fontWeight, isNot(FontWeight.w600));
    },
  );

  testWidgets('plusieurs groupes, un groupe qui part avec la sortie : pas de '
      'seconde ligne', (WidgetTester tester) async {
    final RideGroupDto a = fixtureGroup(
      id: 'a',
      name: 'A',
      registered: true,
      startAt: tomorrow,
    );
    await pumpFirst(
      tester,
      fixtureRide(
        dateTime: tomorrow,
        groups: <RideGroupDto>[a],
        registered: true,
        registeredGroupId: 'a',
      ),
      a,
    );

    expect(find.text('Départ 09:00'), findsOneWidget);
    expect(
      find.textContaining('premier départ', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('un nom de groupe qui dit déjà « Groupe » ne le répète pas', (
    WidgetTester tester,
  ) async {
    final RideGroupDto b = fixtureGroup(
      id: 'b',
      name: 'Groupe 2',
      registered: true,
      startAt: '2036-04-12T07:30:00Z',
    );
    await pumpFirst(tester, fixtureRide(dateTime: tomorrow), b);

    expect(
      find.text('Groupe 2 · premier départ 09:00', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('la sortie seule, même inscrite : l’heure de la sortie, rien de '
      'plus', (WidgetTester tester) async {
    final RideGroupDto b = fixtureGroup(
      id: 'b',
      name: 'B',
      registered: true,
      startAt: '2036-04-12T07:30:00Z',
    );
    await pump(
      tester,
      fixtureRide(
        dateTime: tomorrow,
        groups: <RideGroupDto>[b],
        registered: true,
        registeredGroupId: 'b',
      ),
    );

    expect(find.text('Départ 09:00'), findsOneWidget);
    expect(find.textContaining('Votre groupe'), findsNothing);
    expect(
      find.textContaining('premier départ', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('page d’un groupe : son heure et sa relation à la sortie', (
    WidgetTester tester,
  ) async {
    final RideGroupDto b = fixtureGroup(
      id: 'b',
      name: 'B',
      startAt: '2036-04-12T07:30:00Z',
    );
    await pump(
      tester,
      fixtureRide(dateTime: tomorrow, groups: <RideGroupDto>[b]),
      group: b,
      arrival: 'Arrivée estimée 12:10',
    );

    expect(find.text('Départ 09:30'), findsOneWidget);
    expect(find.textContaining('la sortie de'), findsNothing);
    expect(find.text('Arrivée estimée 12:10'), findsOneWidget);
    expect(find.textContaining('Votre groupe'), findsNothing);
  });

  testWidgets(
    'lu d’ailleurs : la mention de fuseau porte sur l’heure affichée',
    (WidgetTester tester) async {
      AppFormatters.setDisplayTimezone('America/New_York');
      final RideGroupDto b = fixtureGroup(
        id: 'b',
        name: 'B',
        startAt: '2036-04-12T07:30:00Z',
      );
      await pump(
        tester,
        fixtureRide(dateTime: tomorrow, groups: <RideGroupDto>[b]),
        group: b,
      );

      final Finder mention = find.descendant(
        of: find.byType(ZoneMentionLine),
        matching: find.byType(Text),
      );
      expect(mention, findsOneWidget);
      // 07:30Z en avril : 03:30 à New York (EDT), pas les 03:00 de la sortie.
      expect(tester.widget<Text>(mention).data, contains('03:30'));
    },
  );

  testWidgets('le bloc se lit d’un tenant', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, fixtureRide(dateTime: tomorrow));

    expect(
      find.bySemanticsLabel('Départ 09:00, Demain, sam. 12 avr.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final Brightness mode in Brightness.values) {
    testWidgets('se rend sans débordement — $mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final RideGroupDto b = fixtureGroup(
        id: 'b',
        name: 'Groupe au nom vraiment très long',
        registered: true,
        startAt: '2036-04-12T07:30:00Z',
      );
      await pump(
        tester,
        fixtureRide(
          dateTime: tomorrow,
          groups: <RideGroupDto>[b],
          registered: true,
          registeredGroupId: 'b',
        ),
        brightness: mode,
      );

      expect(tester.takeException(), isNull);
    });
  }
}

/// L'index du seul `Text.rich` du bloc : la ligne du groupe.
int _richIndex(WidgetTester tester) {
  final List<Text> texts = tester.widgetList<Text>(find.byType(Text)).toList();
  return texts.indexWhere((Text t) => t.textSpan != null);
}
