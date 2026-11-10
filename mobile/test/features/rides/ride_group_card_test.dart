import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_colors.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/core/widgets/zone_mention_line.dart';
import 'package:pedalons/features/rides/domain/group_start.dart';
import 'package:pedalons/features/rides/domain/ride_group_action.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_group_card.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';

/// S12-2 — les six états du bouton d'une carte de groupe.
///
/// Ils sont testés ici parce qu'ils sont la correction du défaut le plus grave
/// du produit : la v1 les *devinait* en parcourant `participants[]`, une liste
/// tronquée à cinq entrées et vide sans droit de lecture. Un inscrit assez loin
/// dans un gros groupe se voyait proposer « Participer », puis se prenait un
/// 409. Chaque cas ci-dessous fixe une dérivation qui ne dépend plus que de
/// `registered` et `full`.
///
/// Le test n'installe pas easy_localization : `.tr()` rend alors la clé, ce
/// qui identifie un libellé sans faire dépendre l'assertion d'un chargement
/// d'assets ni d'une traduction qui peut légitimement changer.
void main() {
  // Le compteur « 3/16 personnes » passe par `.plural()`, qui exige une
  // locale chargée.
  late final String joinLabel;
  late final String leaveLabel;
  late final String fullLabel;
  late final String joiningLabel;
  setUpAll(() async {
    await loadTestTranslations();
    joinLabel = 'rides.groupJoin'.tr();
    leaveLabel = 'rides.groupLeaveLong'.tr();
    fullLabel = 'rides.groupFull'.tr();
    joiningLabel = 'rides.joining'.tr();
  });

  int switched = 0;
  int left = 0;
  setUp(() {
    switched = 0;
    left = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    required RideGroupDto g,
    required RideGroupAction action,
    bool pending = false,
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
    String timezone = 'Europe/Paris',
    bool? showDeparture,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(brightness),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: RideGroupCard(
                group: g,
                rideDateTime: '2026-10-11T06:00:00Z',
                timezone: timezone,
                showDeparture:
                    showDeparture ??
                    groupLeavesAtOwnTime(g.startAt, '2026-10-11T06:00:00Z'),
                action: action,
                pending: pending,
                trackColor: multiTrackColor(g.sortOrder),
                units: UnitSystem.metric,
                onJoin: () {},
                onSwitch: () => switched++,
                onLeave: () => left++,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── La dérivation elle-même, sans widget ────────────────────────────────

  group('rideGroupAction', () {
    test('un groupe rejoignable propose « Rejoindre »', () {
      expect(
        rideGroupAction(
          ride: fixtureRide(),
          group: fixtureGroup(),
          isMember: true,
        ),
        RideGroupAction.join,
      );
    });

    test('le groupe où je suis inscrit propose « Quitter »', () {
      expect(
        rideGroupAction(
          ride: fixtureRide(registered: true, registeredGroupId: 'g1'),
          group: fixtureGroup(registered: true),
          isMember: true,
        ),
        RideGroupAction.leave,
      );
    });

    test(
      'un groupe plein est terminal : « Complet », sans liste d\'attente',
      () {
        expect(
          rideGroupAction(
            ride: fixtureRide(),
            group: fixtureGroup(full: true, countParticipants: 16),
            isMember: true,
          ),
          RideGroupAction.full,
        );
      },
    );

    test('un non-membre ne se voit offrir aucune action', () {
      expect(
        rideGroupAction(
          ride: fixtureRide(),
          group: fixtureGroup(),
          isMember: false,
        ),
        RideGroupAction.none,
      );
    });

    test('une sortie passée n\'offre plus rien', () {
      expect(
        rideGroupAction(
          ride: fixtureRide(dateTime: '2020-01-01T08:00:00Z'),
          group: fixtureGroup(),
          isMember: true,
        ),
        RideGroupAction.none,
      );
    });

    test('une sortie annulée n\'offre rien, pas même « Quitter »', () {
      expect(
        rideGroupAction(
          ride: fixtureRide(
            status: 'CANCELLED',
            registered: true,
            registeredGroupId: 'g1',
          ),
          group: fixtureGroup(registered: true),
          isMember: true,
        ),
        RideGroupAction.none,
      );
    });

    group('inscrit dans un autre groupe', () {
      // Le groupe visé part le 11 octobre 2026 à 06:00Z.
      final DateTime before = DateTime.utc(2026, 10, 10, 12);
      final DateTime after = DateTime.utc(2026, 10, 11, 7);
      RideDto inG1() => fixtureRide(
        registered: true,
        registeredGroupId: 'g1',
        groups: <RideGroupDto>[
          fixtureGroup(registered: true),
          fixtureGroup(id: 'g2', name: 'G2', sortOrder: 1),
        ],
      );

      test('un groupe ouvert propose « Changer pour »', () {
        expect(
          rideGroupAction(
            ride: inG1(),
            group: fixtureGroup(id: 'g2', name: 'G2'),
            isMember: true,
            now: before,
          ),
          RideGroupAction.switchTo,
        );
      });

      test('un groupe complet reste « Complet »', () {
        expect(
          rideGroupAction(
            ride: inG1(),
            group: fixtureGroup(id: 'g2', full: true),
            isMember: true,
            now: before,
          ),
          RideGroupAction.full,
        );
      });

      test('un groupe parti ne propose pas de changer', () {
        // Jugé sur le départ du groupe (API-170) ; la carte garde alors
        // l'action d'avant ce lot.
        expect(
          rideGroupAction(
            ride: inG1(),
            group: fixtureGroup(id: 'g2'),
            isMember: true,
            now: after,
          ),
          RideGroupAction.join,
        );
      });

      test('mon propre groupe propose toujours « Quitter »', () {
        expect(
          rideGroupAction(
            ride: inG1(),
            group: fixtureGroup(registered: true),
            isMember: true,
            now: before,
          ),
          RideGroupAction.leave,
        );
      });
    });

    test('la détection ne lit jamais participants[]', () {
      // Le cas exact du défaut : l'utilisateur est inscrit, mais la liste
      // renvoyée est vide (droit de lecture absent). `registered` suffit.
      const RideGroupDto opaque = RideGroupDto(
        startAt: '2026-10-11T06:00:00Z',
        id: 'g1',
        name: 'G1',
        countParticipants: 18,
        participants: <PublicUserDto>[],
        sortOrder: 0,
        registered: true,
        full: true,
      );
      expect(
        rideGroupAction(
          ride: fixtureRide(registered: true, registeredGroupId: 'g1'),
          group: opaque,
          isMember: true,
        ),
        RideGroupAction.leave,
      );
    });
  });

  // ── L'heure du groupe : `startAt`, dans le fuseau de la sortie ─────────

  group('heure du groupe (docs/LEDGER_*.md API-60)', () {
    setUp(() => AppFormatters.setDisplayTimezone('Europe/Paris'));
    tearDown(() => AppFormatters.setDisplayTimezone(null));

    testWidgets('un groupe qui part à son heure la montre, sans secondes', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        g: fixtureGroup(startAt: '2026-10-11T06:30:00Z'),
        action: RideGroupAction.join,
      );
      expect(find.text('Départ 08:30'), findsOneWidget);
      expect(find.textContaining(':00:'), findsNothing);
    });

    for (final Brightness brightness in Brightness.values) {
      testWidgets('BRAND-8 : l\'heure propre quitte les statistiques pour un '
          'bandeau indigo très doux sous le nom (${brightness.name})', (
        WidgetTester tester,
      ) async {
        await pump(
          tester,
          g: fixtureGroup(startAt: '2026-10-11T06:30:00Z'),
          action: RideGroupAction.join,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);

        final Finder band = find.descendant(
          of: find.byKey(keys.ride.groupDeparture('g1')),
          matching: find.byType(Container),
        );
        final BoxDecoration decoration =
            tester.widget<Container>(band.first).decoration! as BoxDecoration;
        final PdlColors c = PdlColors.of(brightness);
        expect(decoration.color, c.primaryFaint);
        expect(decoration.borderRadius, PdlRadii.mdAll);
      });
    }

    testWidgets('BRAND-8 : « Départ 08:30 » en 16/700, sans mention de la '
        'sortie', (WidgetTester tester) async {
      await pump(
        tester,
        g: fixtureGroup(startAt: '2026-10-11T06:30:00Z'),
        action: RideGroupAction.join,
      );

      final Finder line = find.byKey(keys.ride.groupDeparture('g1'));
      expect(line, findsOneWidget);
      final Text headline = tester.widget<Text>(
        find.descendant(of: line, matching: find.text('Départ 08:30')),
      );
      expect(headline.style?.fontWeight, FontWeight.w700);
      expect(headline.style?.fontSize, 16);
      expect(find.textContaining('la sortie de'), findsNothing);
      // Plus d'horloge dans la rangée de statistiques.
      expect(
        tester
            .widgetList<PdlStat>(find.byType(PdlStat))
            .where((PdlStat s) => s.icon == PdlIcons.time),
        isEmpty,
      );
      // Sous le nom du groupe.
      expect(
        tester.getTopLeft(line).dy,
        greaterThan(tester.getTopLeft(find.text('Chill Route Long')).dy),
      );
    });

    testWidgets('BRAND-8 : le jour quand il diffère', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        g: fixtureGroup(startAt: '2026-10-11T05:30:00Z'),
        action: RideGroupAction.join,
      );
      expect(find.textContaining('dim. 11 oct.'), findsNothing);

      // Le lendemain, 08:30 : le jour suit l'heure (« lun. 12 oct. »).
      await pump(
        tester,
        g: fixtureGroup(startAt: '2026-10-12T06:30:00Z'),
        action: RideGroupAction.join,
      );
      final Finder line = find.byKey(keys.ride.groupDeparture('g1'));
      expect(
        find.descendant(
          of: line,
          matching: find.textContaining(RegExp(r'^lun\. 12 oct\.')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('l\'heure de la sortie s\'affiche aussi quand un autre groupe '
        'part à une autre heure', (WidgetTester tester) async {
      await pump(
        tester,
        g: fixtureGroup(startAt: '2026-10-11T06:00:00Z'),
        action: RideGroupAction.join,
        showDeparture: true,
      );
      expect(find.text('Départ 08:00'), findsOneWidget);
    });

    testWidgets('BRAND-8 : un groupe qui part avec la sortie n\'a pas de '
        'ligne de départ', (WidgetTester tester) async {
      await pump(
        tester,
        g: fixtureGroup(startAt: '2026-10-11T06:00:00Z'),
        action: RideGroupAction.join,
      );
      expect(find.byKey(keys.ride.groupDeparture('g1')), findsNothing);
      expect(find.byType(PdlDepartureLine), findsNothing);
    });

    testWidgets('un groupe qui part avec la sortie ne répète pas l\'heure', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        g: fixtureGroup(startAt: '2026-10-11T08:00:00+02:00'),
        action: RideGroupAction.join,
      );
      expect(find.text('08:00'), findsNothing);
    });

    testWidgets('lue d\'un autre décalage, l\'heure porte sa mention', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        g: fixtureGroup(startAt: '2026-10-11T06:30:00Z'),
        action: RideGroupAction.join,
        timezone: 'Asia/Tokyo',
      );
      expect(find.text('Départ 15:30'), findsOneWidget);
      expect(find.byType(ZoneMentionLine), findsOneWidget);
    });

    testWidgets('au décalage du lecteur, pas de mention', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        g: fixtureGroup(startAt: '2026-10-11T06:30:00Z'),
        action: RideGroupAction.join,
      );
      expect(find.byType(ZoneMentionLine), findsNothing);
    });
  });

  test('someGroupLeavesAtOwnTime : un seul horaire différent suffit', () {
    const String ride = '2026-10-11T06:00:00Z';
    expect(someGroupLeavesAtOwnTime(<String>[ride, ride], ride), isFalse);
    expect(
      someGroupLeavesAtOwnTime(<String>[ride, '2026-10-11T06:30:00Z'], ride),
      isTrue,
    );
  });

  test('groupLeavesAtOwnTime compare des instants, pas des chaînes', () {
    expect(
      groupLeavesAtOwnTime('2026-10-11T08:00:00+02:00', '2026-10-11T06:00:00Z'),
      isFalse,
    );
    expect(
      groupLeavesAtOwnTime('2026-10-11T06:30:00Z', '2026-10-11T06:00:00Z'),
      isTrue,
    );
    expect(formatGroupStart('2026-10-11T06:30:00Z', 'Asia/Tokyo'), '15:30');
  });

  // ── Le rendu des six états, dans les deux modes ─────────────────────────

  for (final Brightness brightness in Brightness.values) {
    final String mode = brightness == Brightness.light ? 'clair' : 'sombre';

    testWidgets('« Rejoindre » est la seule action pleine — $mode', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        g: fixtureGroup(),
        action: RideGroupAction.join,
        brightness: brightness,
      );
      expect(find.text(joinLabel), findsOneWidget);
      expect(find.byType(PdlButton), findsOneWidget);
    });

    testWidgets('l\'appel en vol substantive le libellé — $mode', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        g: fixtureGroup(),
        action: RideGroupAction.join,
        pending: true,
        brightness: brightness,
      );
      expect(find.text(joiningLabel), findsOneWidget);
      expect(find.text(joinLabel), findsNothing);
    });

    testWidgets('inscrite ici : le badge « J\'y vais » à côté du nom, aucun '
        'bouton en tête, « Quitter le groupe » en pied de carte — $mode', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        g: fixtureGroup(registered: true),
        action: RideGroupAction.leave,
        brightness: brightness,
      );
      // Le badge de la charte est en capitales.
      final Finder badge = find.byKey(keys.ride.groupGoingBadge('g1'));
      expect(
        find.descendant(
          of: badge,
          matching: find.text('rides.registered'.tr().toUpperCase()),
        ),
        findsOneWidget,
      );
      expect(find.byType(PdlButton), findsNothing);
      final Finder link = find.byKey(keys.ride.groupLeaveButton('g1'));
      expect(
        find.descendant(of: link, matching: find.text(leaveLabel)),
        findsOneWidget,
      );
      // Tout en bas : sous les visages et le compte.
      expect(
        tester.getTopLeft(link).dy,
        greaterThan(tester.getTopLeft(find.textContaining('3/16')).dy),
      );
      await tester.tap(link);
      expect(left, 1);
    });

    testWidgets('inscrite ailleurs : « Changer pour {groupe} », plein, un seul '
        'geste — $mode', (WidgetTester tester) async {
      await pump(
        tester,
        g: fixtureGroup(id: 'g2', name: 'A'),
        action: RideGroupAction.switchTo,
        brightness: brightness,
      );
      final Finder button = find.byKey(keys.ride.groupSwitchButton('g2'));
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.text('Changer pour A')),
        findsOneWidget,
      );
      expect(tester.widget<PdlButton>(button).variant, PdlButtonVariant.fill);
      expect(find.text(joinLabel), findsNothing);
      expect(find.byKey(keys.ride.groupLeaveButton('g2')), findsNothing);
      await tester.tap(button);
      expect(switched, 1);
    });

    testWidgets('« Complet » n\'est pas actionnable — $mode', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        g: fixtureGroup(full: true, countParticipants: 18, maxParticipants: 18),
        action: RideGroupAction.full,
        brightness: brightness,
      );
      expect(find.text(fullLabel), findsOneWidget);
      final Semantics node = tester.widget(
        find
            .descendant(
              of: find.byType(PdlButton),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(node.properties.enabled, isFalse);
      // Le groupe plein montre sa barre de places, pas ses visages.
      expect(find.byType(PdlProgressBar), findsOneWidget);
      expect(find.text('18/18'), findsOneWidget);
    });

    testWidgets('l\'état sans action ne rend aucun bouton — $mode', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        g: fixtureGroup(),
        action: RideGroupAction.none,
        brightness: brightness,
      );
      expect(find.byType(PdlButton), findsNothing);
    });
  }

  // ── Le meneur, conditionnel ─────────────────────────────────────────────

  testWidgets('un groupe sans meneur ne réserve aucune place', (
    WidgetTester tester,
  ) async {
    await pump(tester, g: fixtureGroup(), action: RideGroupAction.join);
    expect(find.textContaining('Capitaine'), findsNothing);
  });

  testWidgets('un meneur désigné est rendu avec son nom', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      g: fixtureGroup(
        leader: const PublicUserDto(id: 'u9', displayName: 'Antoine Yvon'),
      ),
      action: RideGroupAction.join,
    );
    expect(find.textContaining('Antoine Yvon'), findsOneWidget);
  });

  // ── La ligne de statistiques ────────────────────────────────────────────

  testWidgets('la ligne de statistiques ne se coupe jamais', (
    WidgetTester tester,
  ) async {
    for (final double scale in <double>[1.0, 1.3, 2.0]) {
      await pump(
        tester,
        g: fixtureGroup(),
        action: RideGroupAction.join,
        textScale: scale,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'débordement à textScaleFactor = $scale',
      );
      // Le dénivelé, dernier de la rangée, est toujours rendu : c'est lui que
      // la troncature sacrifiait.
      expect(find.textContaining('413'), findsOneWidget);
    }
  });
}
