import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/core/widgets/zone_mention_line.dart';
import 'package:pedalons/features/rides/domain/group_start.dart';
import 'package:pedalons/features/rides/domain/ride_group_action.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_group_card.dart';

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
  // Le compteur « 3/16 participants » passe par `.plural()`, qui exige une
  // locale chargée.
  late final String joinLabel;
  late final String leaveLabel;
  late final String fullLabel;
  late final String joiningLabel;
  setUpAll(() async {
    await loadTestTranslations();
    joinLabel = 'rides.groupJoin'.tr();
    leaveLabel = 'rides.groupLeave'.tr();
    fullLabel = 'rides.groupFull'.tr();
    joiningLabel = 'rides.joining'.tr();
  });

  Future<void> pump(
    WidgetTester tester, {
    required RideGroupDto g,
    required RideGroupAction action,
    bool pending = false,
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
    String timezone = 'Europe/Paris',
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
                action: action,
                pending: pending,
                trackColor: multiTrackColor(g.sortOrder),
                units: UnitSystem.metric,
                onJoin: () {},
                onLeave: () {},
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
      expect(find.text('08:30'), findsOneWidget);
      expect(find.textContaining(':00:'), findsNothing);
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
      expect(find.text('15:30'), findsOneWidget);
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

    testWidgets('« Quitter » côtoie le badge « Inscrit » — $mode', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        g: fixtureGroup(registered: true),
        action: RideGroupAction.leave,
        brightness: brightness,
      );
      expect(find.text(leaveLabel), findsOneWidget);
      // Le badge de la charte est en capitales.
      expect(find.text('rides.registered'.tr().toUpperCase()), findsOneWidget);
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
    expect(find.textContaining('Meneur'), findsNothing);
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
