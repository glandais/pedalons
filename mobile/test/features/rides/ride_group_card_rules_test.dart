import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/domain/ride_group_action.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_registration_control.dart';

import 'ride_fixtures.dart';

/// Règles R6 et R7 des cartes de groupe (KIT §9, docs/LEDGER_*.md MOB-139) :
/// « Quitter le groupe » et « GPS » jusqu'à la **fin** de la sortie — pas
/// masqués au départ —, jamais sur une sortie annulée ; « Complet » même
/// inscrite ailleurs.
void main() {
  // La sortie de la fixture part le 29 juillet 2099 à 19:30Z et finit 3 h
  // plus tard.
  final DateTime before = DateTime.utc(2099, 7, 29, 18);
  final DateTime during = DateTime.utc(2099, 7, 29, 20, 30);
  final DateTime after = DateTime.utc(2099, 7, 29, 23);

  RideDto ride({String status = 'PUBLISHED'}) => fixtureRide(
    status: status,
    registered: true,
    registeredGroupId: 'g1',
    groups: <RideGroupDto>[
      fixtureGroup(id: 'g1', registered: true, startAt: '2099-07-29T19:30:00Z'),
      fixtureGroup(
        id: 'g2',
        full: true,
        countParticipants: 16,
        startAt: '2099-07-29T19:30:00Z',
      ),
    ],
  );

  RideGroupAction actionOf(RideDto r, String id, DateTime now) =>
      rideGroupCardAction(
        ride: r,
        group: r.groups.firstWhere((RideGroupDto g) => g.id == id),
        canRegister: true,
        now: now,
      );

  test('« Quitter le groupe » avant le départ et pendant la sortie', () {
    expect(actionOf(ride(), 'g1', before), RideGroupAction.leave);
    expect(actionOf(ride(), 'g1', during), RideGroupAction.leave);
  });

  test('plus de « Quitter » une fois la sortie terminée', () {
    expect(actionOf(ride(), 'g1', after), RideGroupAction.none);
  });

  test('rien sur une sortie annulée', () {
    expect(
      actionOf(ride(status: 'CANCELLED'), 'g1', before),
      RideGroupAction.none,
    );
  });

  test('« Complet » sur un groupe plein, même inscrite ailleurs', () {
    expect(actionOf(ride(), 'g2', before), RideGroupAction.full);
  });

  test('« GPS » sur sa carte jusqu’à la fin, jamais ailleurs ni annulée', () {
    final RideDto r = ride();
    final RideGroupDto mine = r.groups.first;
    expect(rideGroupCardOffersGps(r, mine, now: before), isTrue);
    expect(rideGroupCardOffersGps(r, mine, now: during), isTrue);
    expect(rideGroupCardOffersGps(r, mine, now: after), isFalse);
    expect(rideGroupCardOffersGps(r, r.groups[1], now: before), isFalse);
    final RideDto cancelled = ride(status: 'CANCELLED');
    expect(
      rideGroupCardOffersGps(cancelled, cancelled.groups.first, now: before),
      isFalse,
    );
  });
}
